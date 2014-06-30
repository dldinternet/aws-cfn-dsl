module Aws
  module Cfn
    module Dsl
      module Maintainer

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

        def self.included(includer)

        end

      end
    end
  end
end
