require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/table'
#require 'cloudformation-ruby-dsl/spotprice'
require 'slop'

module Aws
  module Cfn
    module Dsl
      class Template < ::TemplateDSL
        attr_reader :dict

        def dict
          @dict
        end

        def initialize(path=nil,&block)
          @path = path || File.dirname(caller[2].split(%r'\s+').shift.split(':')[0])
          super() do
            # We do nothing with the template for now
          end
        end

        def file(b)
          block = File.read File.join(@path,b)
          eval block
        end

        def mapping(name, options=nil)
          if options.nil?
            file "Mappings/#{name}.rb"
          else
            super(name,options)
          end
        end

        # def mapping_file(p)
        #   file "Mappings/#{p}.rb"
        # end

        def parameter(name, options=nil)
          if options.nil?
            file "Parameters/#{name}.rb"
          else
            super(name,options)
          end
        end

        # def parameter_file(p)
        #   file "Parameters/#{p}.rb"
        # end

        def resource(name, options=nil)
          if options.nil?
            file "Resources/#{name}.rb"
          else
            super(name,options)
          end
        end

        # def resource_file(p)
        #   file "Resources/#{p}.rb"
        # end

        def output(name, options=nil)
          if options.nil?
            file "Outputs/#{name}.rb"
          else
            super(name,options)
          end
        end

        def hash_refs(line,scope)
          block_regex = %r/\{\s*:\S+\s*=>.*?\}|\{\s*\S+:\s*.*?\}/
          match = line.match %r/^([^#]*?)(#{block_regex})(.*)$/
          if match
            left = match[1]
            code = match[2]
            tail = match[3]
            while true
              braces = code.gsub(%r/[^{}]+/, '')
              len    = braces.size
              if len % 2 != 0
                nest = tail.match %r/^(.*\})(.*)$/
                if nest
                  code += nest[1]
                  tail  = nest[2]
                else
                  abort! "Mismatched {}'s"
                end
              else
                break
              end
            end
            h = nil
            eval "h = #{code}", binding
            k = h.keys[0]
            v = h.delete(k)
            v = scope[:compiler].sym_to_s(v)
            h[k.to_s] = v
            scope[:logger].debug h
            [left, h, tail.size > 0 ? hash_refs(tail,scope) : tail ]
          else
            "#{line}\n"
          end
        end

      end
    end
  end
end

# Main entry point
def template(&block)
  Aws::Cfn::Dsl::Template.new(&block)
end
