require "aws/cfn/dsl/base"

module Aws
  module Cfn
    module Dsl
      class Main < Base

        def run

          parse_options

          load_template(@opts[:template])

          save_dsl(@opts[:directory])

        end
      end
    end
  end
end
