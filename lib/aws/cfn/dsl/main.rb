require 'slop'
require "aws/cfn/dsl/base"

module Aws
  module Cfn
    module Dsl
      class Main < Base

        def run

          @opts = Slop.parse(help: true) do
            on :j, :template=,      'The template to convert', as: String
            on :o, :output=,        'The directory to output the DSL to.', as: String
          end

          unless @opts[:template]
            abort! @opts
          end

          load(@opts[:template])

          save(@opts[:output])

        end
      end
    end
  end
end
