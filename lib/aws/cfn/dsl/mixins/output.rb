module Aws
  module Cfn
    module Dsl
      module Output

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

        def open_output(subdir,name)
          if @config[:directory]
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

        def close_output()
          if @config[:directory] and @output.size > 0
            fp = @output.shift
            fp.close
          end
        end

        def self.included(includer)

        end

      end
    end
  end
end
