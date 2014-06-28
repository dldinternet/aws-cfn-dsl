require "aws/cfn/dsl/fncall"

require 'ap'

module Aws
  module Cfn
    module Dsl
      class Base
        attr_accessor :items
        attr_reader   :output

        require 'dldinternet/mixlib/logging'
        include DLDInternet::Mixlib::Logging

        def initialize
          super
          @output = []
          @config ||= {}

          lcs = ::Logging::ColorScheme.new( 'compiler', :levels => {
              :trace => :blue,
              :debug => :cyan,
              :info  => :green,
              :step  => :green,
              :warn  => :yellow,
              :error => :red,
              :fatal => :red,
              :todo  => :purple,
          })
          scheme = lcs.scheme
          scheme['trace'] = "\e[38;5;33m"
          scheme['fatal'] = "\e[38;5;89m"
          scheme['todo']  = "\e[38;5;55m"
          lcs.scheme scheme
          @config[:log_opts] = lambda{|mlll| {
              :pattern      => "%#{mlll}l: %m %C\n",
              :date_pattern => '%Y-%m-%d %H:%M:%S',
              :color_scheme => 'compiler'
          }
          }
          @config[:log_level] = :info
          @logger = getLogger(@config)

        end

        def save_dsl(path=nil,parts=@items)
          pprint(simplify(parts,true))
          @logger.step "*** DSL generated ***"
        end

        def load_template(file=nil)
          if file
            logStep "Loading #{file}"
            begin
              abs = File.absolute_path(File.expand_path(file))
              unless File.exists?(abs) or @opts[:output].nil?
                abs = File.absolute_path(File.expand_path(File.join(@opts[:output],file)))
              end
            rescue
              # pass
            end
            if File.exists?(abs)
              case File.extname(File.basename(abs)).downcase
                when /json|js/
                  @items = JSON.parse(File.read(abs))
                when /yaml|yml/
                  @items = YAML.load(File.read(abs))
                else
                  abort! "Unsupported file type for specification: #{file}"
              end
            else
              abort! "Unable to open template: #{abs}"
            end
          end
        end

        protected

        def simplify(val,start=false)
          logStep "Simplify a block ..." if start
          if val.is_a?(Hash)
            val = Hash[val.map { |k,v| [k, simplify(v)] }]
            if val.length != 1
              val
            else
              k, v = val.entries[0]
              case @opts[:functions]
              when /1|on|set|enable|yes|true/ then
                case
                  # CloudFormation functions
                  when k == 'Fn::Base64'
                    FnCall.new 'base64', [v], true
                  when k == 'Fn::FindInMap'
                    FnCall.new 'find_in_map', v
                  when k == 'Fn::GetAtt'
                    FnCall.new 'get_att', v
                  when k == 'Fn::GetAZs'
                    FnCall.new 'get_azs', v != '' ? [v] : []
                  when k == 'Fn::Join'
                    FnCall.new 'join', [v[0]] + v[1], true
                  when k == 'Fn::Select'
                    FnCall.new 'select', v
                  when k == 'Ref' && v == 'AWS::Region'
                    FnCall.new 'aws_region', []
                  when k == 'Ref' && v == 'AWS::StackName'
                    FnCall.new 'aws_stack_name', []
                  # CloudFormation internal references
                  when k == 'Ref'
                    FnCall.new 'ref', [v]
                  else
                    val
                end
              else
                val
              end
            end
          elsif val.is_a?(Array)
            val.map { |v| simplify(v) }
          else
            val
          end
        end

        def pprint(val)
          logStep "Pretty print ..."
          case detect_type(val)
            when :template
              pprint_cfn_template(val)
            when :parameter
              pprint_cfn_section 'parameter', 'TODO', val, 'Parameters'
            when :resource
              pprint_cfn_resource 'TODO', val
            when :parameters
              val.each { |k, v| pprint_cfn_section 'parameter', k, v, 'Parameters' }
            when :resources
              val.each { |k, v| pprint_cfn_resource k, v }
            else
              pprint_value(val, '')
          end
        end

        def module_name(parts=-1)
          name = self.class.to_s.split("::")
          name[0..parts-1].join('::')
        end

        def abort!(msg=nil,rc=1)
          @logger.error msg if msg
          @logger.fatal '!!! Aborting !!!'
          exit rc
        end

        def write(*s)
          if s.is_a?(Array)
            s = s.join('')
          end
          if @output.size > 0
            @output[0].write s
          else
            print s
          end
        end

        def writeln(s='')
          if @output.size > 0
            @output[0].puts s
          else
            puts s
          end
        end

        # Attempt to figure out what fragment of the template we have.  This is imprecise and can't
        # detect Mappings and Outputs sections reliably, so it doesn't attempt to.
        def detect_type(val)
          if val.is_a?(Hash) && val['AWSTemplateFormatVersion']
            :template
          elsif val.is_a?(Hash) && /^(String|Number)$/ =~ val['Type']
            :parameter
          elsif val.is_a?(Hash) && val['Type']
            :resource
          elsif val.is_a?(Hash) && val.values.all? { |v| detect_type(v) == :parameter }
            :parameters
          elsif val.is_a?(Hash) && val.values.all? { |v| detect_type(v) == :resource }
            :resources
          end
        end

        def pprint_cfn_template(tpl)
          file = File.basename(@opts[:template]).gsub(%r'\.(json|yaml|js|yaml)$'i, '.rb')
          # noinspection RubyParenthesesAroundConditionInspection
          if (iam = open_output('', file.gsub(%r'\.(json|yaml|js|yml|rb)'i, '')))
            logStep "Saving #{file}"
            writeln "#!/usr/bin/env ruby"
            print_maintainer('')
            writeln
            if @opts[:output]
              writeln "$:.unshift(File.dirname(__FILE__))"
              # noinspection RubyExpressionInStringInspection
              writeln '$:.unshift File.absolute_path("#{File.dirname(__FILE__)}/../lib")'
            end
            writeln "require 'bundler/setup'"
            writeln "require 'aws/cfn/dsl/template'"
            #writeln "require 'cloudformation-ruby-dsl/spotprice'"
            #writeln "require 'cloudformation-ruby-dsl/table'"
            writeln
            writeln "template do"
            writeln
            tpl.each do |section, v|
              case section
                when 'Parameters'
                when 'Mappings'
                when 'Resources'
                when 'Outputs'
                else
                  write "  value #{fmt_key(section)} => "
                  pprint_value v, '  '
                  writeln
                  writeln
              end
            end
          else
            @logger.warn "Not overwriting template: '#{file}'"
          end
          %w(Mappings Parameters Resources Outputs).each do |section|
            writeln "  # #{section}" if iam
            v = tpl[section]
            case section
              when 'Parameters'
                v.each { |name, options| pprint_cfn_section 'parameter', name, options, 'Parameters', iam }
              when 'Mappings'
                v.each { |name, options| pprint_cfn_section 'mapping', name, options, 'Mappings', iam }
              when 'Resources'
                v.each { |name, options| pprint_cfn_resource name, options, iam }
              when 'Outputs'
                v.each { |name, options| pprint_cfn_section 'output', name, options, 'Outputs', iam }
              else
                abort! "Internal Error: Unexpected section '#{section}'"
            end
            writeln if iam
          end
          writeln "end.exec!" if iam
        end

        def open_output(subdir,name)
          if @opts[:output]
            file = rb_file(subdir, name)
            if i_am_maintainer(file)
              @output.unshift File.open(file, 'w')
              true
            else
              false
            end
          else
            true
          end
        end

        def add_brick(subdir,name)
          if @opts[:output]
            #file = rb_file(subdir, name).gsub(%r'^#{@opts[:output]}/','')
            #writeln "  file '#{file}'"
            s = subdir.downcase.gsub(%r's$','')
            writeln "  #{s} '#{name}'"
          end
        end

        def rb_file(subdir, name)
          path = File.join(@opts[:output], subdir)
          unless File.directory? path
            Dir.mkdir path
          end
          file = File.join(path, "#{name}.rb")
        end

        def close_output()
          if @opts[:output] and @output.size > 0
            fp = @output.shift
            fp.close
          end
        end

        def maintainer(parts=-1)
          "maintainer: #{module_name parts}"
        end

        def maintainer_comment(indent='  ')
          "#{indent}# WARNING: This code is generated. Your changes may be overwritten!\n" +
          "#{indent}# Remove this message and/or set the 'maintainer: <author name>' when you need your changes to survive.\n" +
          "#{indent}# Abscence of the 'maintainer: ' will be considered conscent to overwrite.\n" +
          "#{indent}# #{maintainer 3}\n" +
          "#\n"
        end

        def print_maintainer(indent='  ')
          writeln maintainer_comment(indent)
        end

        def i_am_maintainer(file)
          # mod = module_name 2
          if File.exists?(file)
            src = IO.read(file)
            mtc = src.match(%r'#{maintainer 2}')
            iam = (not mtc.nil? or src.match(%r'#\s*maintainer:').nil?)
            ovr = @config[:overwrite]
            iam or ovr
          else
            true
          end
        end

        def prelude_code(indent='  ')
          "scope = Aws::Cfn::Compiler.binding[File.basename(File.dirname(__FILE__))][File.basename(__FILE__, '.rb')]\n"+
          "template = scope[:template]\n"+
          "\n"+
          "# noinspection RubyStringKeysInHashInspection\n"+
          "template." +
          ""
        end

        def print_with_wrapper(code,indent='  ')
          write prelude_code(indent)+code.gsub(%r'^\s+','')
        end

        def pprint_cfn_section(section, name, options, subdir, brick=true)
          if open_output(subdir,name)
            @logger.info "Pretty print #{section} '#{name}' to '#{rb_file(subdir, name)}'"
            print_maintainer ''
            print_with_wrapper "#{section} #{fmt_string(name)}"
            indent = '  ' + (' ' * section.length) + ' '
            hang   = true
            options.each do |k, v|
              if hang
                writeln ','
                hang = false
              end
              write indent, fmt_key(k), " => "
              pprint_value v, indent
              hang = true
            end
            writeln
            writeln
            close_output
            add_brick(subdir,name) if brick
          else
            @logger.warn "NOT overwriting existing source file '#{rb_file(subdir, name)}'"
          end
        end

        def pprint_cfn_resource(name, options, brick=true)
          subdir = 'Resources'
          if open_output(subdir,name)
            @logger.info "Pretty print resource '#{name}' to '#{rb_file(subdir, name)}'"
            print_maintainer ''
            print_with_wrapper "resource #{fmt_string(name)}"
            indent = '  '
            hang   = true
            options.each do |k, v|
              if hang
                writeln ','
                hang = false
              end

              case k
                when /^(Metadata|Properties)$/
                  write   "#{indent}#{fmt_key(k)} => "
                  pprint_value options[k], indent
                  hang = true
                else
                  write   "#{indent}#{fmt_key(k)} => "
                  write "#{fmt(v)}"
                  hang = true
              end
            end
            writeln
            close_output
            add_brick(subdir,name) if brick
          else
            @logger.warn "NOT overwriting existing source file '#{rb_file(subdir, name)}'"
          end
        end

        def pprint_value(val, indent)
          # Prefer to write the value on a single line if it's reasonable to do so
          single_line = is_single_line(val) || is_single_line_hack(val)
          if single_line && !is_multi_line_hack(val)
            s = fmt(val)
            if s.length < 120 || is_single_line_hack(val)
              write s
              return
            end
          end

          # Print the value across multiple lines
          if val.is_a?(Hash)
            writeln "{"
            val.each do |k, v|
              write "#{indent}    #{fmt_key(k)} => "
              pprint_value v, indent + '    '
              writeln ","
            end
            write "#{indent}}"

          elsif val.is_a?(Array)
            writeln "["
            val.each do |v|
              write "#{indent}    "
              pprint_value v, indent + '    '
              writeln ","
            end
            write "#{indent}]"

          elsif val.is_a?(FnCall) && val.multiline && @opts[:functions] != 'raw'
            write val.name, "("
            args = val.arguments
            sep = ''
            sub_indent = indent + '    '
            if val.name == 'join' && args.length > 1
              pprint_value args[0], indent + '  '
              args = args[1..-1]
              sep = ','
              sub_indent = indent + '     '
            end
            unless args.empty?
              args.each do |v|
                writeln sep
                write sub_indent
                pprint_value v, sub_indent
                sep = ','
              end
              if val.name == 'join' && args.length > 1
                write ","
              end
              writeln
              write indent
            end
            write ")"

          else
            write fmt(val)
          end
        end

        def is_single_line(val)
          if val.is_a?(Hash)
            is_single_line(val.values)
          elsif val.is_a?(Array)
            val.empty? ||
                (val.length == 1 && is_single_line(val[0]) && !val[0].is_a?(Hash)) ||
                val.all? { |v| v.is_a?(String) }
          else
            true
          end
        end

        # Emo-specific hacks to force the desired output formatting
        def is_single_line_hack(val)
          is_array_of_strings_hack(val)
        end

        # Emo-specific hacks to force the desired output formatting
        def is_multi_line_hack(val)
          val.is_a?(Hash) && val['email']
        end

        # Emo-specific hacks to force the desired output formatting
        def is_array_of_strings_hack(val)
          val.is_a?(Array) && val.all? { |v| v.is_a?(String) } && val.grep(/\s/).empty? && (
          val.include?('autoscaling:EC2_INSTANCE_LAUNCH') ||
              val.include?('m1.small')
          )
        end

        def fmt(val)
          if val == {}
            '{}'
          elsif val == []
            '[]'
          elsif val.is_a?(Hash)
            '{ ' + (val.map { |k,v| fmt_key(k) + ' => ' + fmt(v) }).join(', ') + ' }'
          elsif val.is_a?(Array) && is_array_of_strings_hack(val)
            '%w(' + val.join(' ') + ')'
          elsif val.is_a?(Array)
            '[ ' + (val.map { |v| fmt(v) }).join(', ') + ' ]'
          elsif val.is_a?(FnCall) && val.arguments.empty?
            val.name
          elsif val.is_a?(FnCall)
            val.name + '(' + (val.arguments.map { |v| fmt(v) }).join(', ') + ')'
          elsif val.is_a?(String)
            fmt_string(val)
          elsif val == nil
            'null'
          else
            val.to_s  # number, boolean
          end
        end

        def fmt_key(s)
          ':' + (/^[a-zA-Z_]\w+$/ =~ s ? s : fmt_string(s))  # returns a symbol like :Foo or :'us-east-1'
        end

        def fmt_string(s)
          if /[^ -~]/ =~ s
            s.dump  # contains, non-ascii or control char, return double-quoted string
          else
            '\'' + s.gsub(/([\\'])/, '\\\\\1') + '\''  # return single-quoted string, escape \ and '
          end
        end

      end
    end
  end
end
