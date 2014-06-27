require "aws/cfn/decompiler"

module Aws
  module Cfn
    module Dsl
      class FnCall
        attr_reader :name, :arguments, :multiline

        def initialize(name, arguments, multiline = false)
          @name = name
          @arguments = arguments
          @multiline = multiline
        end

        def to_s()
          @name + "(" + @arguments.join(', ') + ")"
        end
      end
    end
  end
end
