module Aws
  module Cfn
    module Dsl
      module PrettyPrint

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

        def pprint_cfn_template(tpl)
          file = File.join(@config[:directory],File.basename(@config[:template].gsub(%r'\.(json|yaml|js|yaml)$'i, '.rb')))
          filn = if @config[:expandedpaths]
                   File.expand_path(file)
                 else
                   file
                 end
          file = File.basename(@config[:template].gsub(%r'\.(json|yaml|js|yaml)$'i, '.rb'))
          # noinspection RubyParenthesesAroundConditionInspection
          if (iam = open_output('', file.gsub(%r'\.(json|yaml|js|yml|rb)'i, '')))
            logStep "Saving #{filn}"
            writeln "#!/usr/bin/env ruby"
            print_maintainer('')
            writeln
            if @config[:directory]
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
          filn = rb_file(subdir, name)
          filn = File.expand_path(filn) if @config[:expandedpaths]
          if open_output(subdir,name)
            @logger.info "Pretty print #{section} '#{name}' to '#{filn}'"
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
            @logger.warn "NOT overwriting existing source file '#{filn}'"
          end
        end

        def pprint_cfn_resource(name, options, brick=true)
          subdir = 'Resources'
          filn = rb_file(subdir, name)
          filn = File.expand_path(filn) if @config[:expandedpaths]
          if open_output(subdir,name)
            @logger.info "Pretty print resource '#{name}' to '#{filn}'"
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
            @logger.warn "NOT overwriting existing source file '#{filn}'"
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

          elsif val.is_a?(FnCall) && val.multiline && @config[:functions] != 'raw'
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

        def self.included(includer)

        end

      end
    end
  end
end
