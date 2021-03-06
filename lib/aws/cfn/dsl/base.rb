require "aws/cfn/dsl/fncall"

require 'ap'

module Aws
  module Cfn
    module Dsl
      class Base
        attr_accessor :items
        attr_reader   :template

        require 'dldinternet/mixlib/logging'
        include DLDInternet::Mixlib::Logging

        def initialize
          super
          @output = []
          @config ||= {}

          # noinspection RubyStringKeysInHashInspection
          @formats = {
              'yaml' => 'yaml',
              'yml' => 'yaml',
              'yts' => 'yaml',
              'ytf' => 'yaml',
              'ytp' => 'yaml',
              'json' => 'json',
              'jml' => 'json',
              'jts' => 'json',
              'jtf' => 'json',
              'jtp' => 'json',
              'tpl' => 'json',
              'template' => 'json',
              'ruby' => 'ruby',
              'rb' => 'ruby',
          }

          @all_sections = %w{Mappings Parameters Conditions Resources Outputs}
          @valid_functions = %w(Fn::Base64 Fn::GetAtt Fn::GetAZs Fn::Join Fn::FindInMap Fn::Select Ref Fn::Equals Fn::If Fn::Not Condition Fn::And Fn::Or)

        end

        def ext2format(ext)
          @formats.has_key? ext ? @formats[ext] : nil
        end

        def format2exts(format)
          exts = @formats.select{ |_,v| v == format }
          if exts.size > 0
            exts.keys
          else
            []
          end
        end

        def formats_compatible?(format, match)
          @formats[match] == @formats[format]
        end

        def save_dsl(path=nil,parts=@items)
          pprint(simplify(parts,true))
          @logger.step "*** DSL generated ***"
        end

        def load_template(file=nil)
          if file
            filn = File.join(File.dirname(file), file)
            filn = File.expand_path(file) if @config[:expandedpaths]
            logStep "Loading #{filn}"
            begin
              abs = File.absolute_path(File.expand_path(file))
              unless File.exists?(abs) or @config[:directory].nil?
                abs = File.absolute_path(File.expand_path(File.join(@config[:directory],file)))
              end
            rescue
              # pass
            end
            if File.exists?(abs)
              case File.extname(File.basename(abs)).downcase
                # TODO: [2014-0-16 Christo] Replace these with @json_template_ext_regex
                when /json|js|template|jtf/
                  @items = JSON.parse(File.read(abs))
                # TODO: [2014-0-16 Christo] Replace these with @yaml_template_ext_regex
                when /yaml|yml|ytf/
                  @items = YAML.load(File.read(abs))
                else
                  abort! "Unsupported file type for specification: #{file}"
              end
            else
              abort! "Unable to open template: #{abs}"
            end
            @items
          else
            nil
          end
        end

        protected

        def abort!(msg=nil,rc=1,st=nil)
          cfg = :trace
          st  = (not (@opts[cfg].nil? or @opts[cfg].downcase.match(@on_yes_regex).nil?))
          exp = '!!! Aborting !!!'
          exp += "\n"+caller[0..-1].join("\n") if st
          if @logger
            ::Logging::LogEvent.caller_index += 1
            @logger.error msg if msg
            @logger.fatal exp
          else
            puts msg if msg
            puts exp
          end
          exit rc
        end

        require "aws/cfn/dsl/mixins/options"
        include Aws::Cfn::Dsl::Options

        require "aws/cfn/dsl/mixins/maintainer"
        include Aws::Cfn::Dsl::Maintainer

        require "aws/cfn/dsl/mixins/simplify"
        include Aws::Cfn::Dsl::Simplify

        require "aws/cfn/dsl/mixins/prettyprint"
        include Aws::Cfn::Dsl::PrettyPrint

        require "aws/cfn/dsl/mixins/output"
        include Aws::Cfn::Dsl::Output

        require "aws/cfn/dsl/mixins/dsl"
        include Aws::Cfn::Dsl::DSL


      end
    end
  end
end
