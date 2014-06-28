require 'slop'
require "aws/cfn/dsl/base"

module Aws
  module Cfn
    module Dsl
      class Main < Base

        def run

          @opts = Slop.parse(help: true) do
            on :j, :template=,      'The template to convert', as: String, argument: true
            on :o, :output=,        'The directory to output the DSL to.', as: String, argument: true
            on :O, :overwrite,      'Overwrite existing generated source files. (HINT: Think twice ...)', { as: String, optional_argument: true, default: 'off', match: %r/0|1|yes|no|on|off|enable|disable|set|unset|true|false|raw/i }
          end

          @config[:overwrite] = if @opts[:overwrite].downcase.match %r'^(1|true|on|yes|enable|set)$'
                                  true
                                else
                                  false
                                end

          unless @opts[:template]
            abort! @opts
          end

          load_template(@opts[:template])

          save_dsl(@opts[:output])

        end
      end
    end
  end
end
