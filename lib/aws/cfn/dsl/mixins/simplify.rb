module Aws
  module Cfn
    module Dsl
      module Simplify

        def simplify(val,start=false)
          logStep "Simplify a block ..." if start
          if val.is_a?(Hash)
            val = Hash[val.map { |k,v| [k, simplify(v)] }]
            if val.length != 1
              val
            else
              k, v = val.entries[0]
              case @config[:functions]
                when @on_yes_regex then
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


        def self.included(includer)

        end

      end
    end
  end
end
