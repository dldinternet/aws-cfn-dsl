module Aws
  module Cfn
    module Dsl
      module DSL

        # Attempt to figure out what fragment of the template we have.  This is imprecise and can't
        # detect Mappings and Outputs sections reliably, so it doesn't attempt to.
        def detect_type(val)
          if val.is_a?(Hash) && val['AWSTemplateFormatVersion']
            :template
          elsif val.is_a?(Hash) && /^(String|Number)$/ =~ val['Type']
            :parameter
          elsif val.is_a?(Hash) && val['Type']
            :resource
          elsif val.is_a?(Hash) && val.values.all? { |v| detect_type(v) == :parameter }
            :parameters
          elsif val.is_a?(Hash) && val.values.all? { |v| detect_type(v) == :resource }
            :resources
          end
        end

        def add_brick(subdir,name)
          if @config[:directory]
            #file = rb_file(subdir, name).gsub(%r'^#{@config[:directory]}/','')
            #writeln "  file '#{file}'"
            s = subdir.downcase.gsub(%r's$','')
            writeln "  #{s} '#{name}'"
          end
        end

        def rb_file(subdir, name)
          path = File.join(@config[:directory], subdir)
          unless File.directory? path
            Dir.mkdir path
          end
          file = File.join(path, "#{name}.rb")
        end

        def module_name(parts=-1)
          name = self.class.to_s.split("::")
          name[0..parts-1].join('::')
        end


        def self.included(includer)

        end

      end
    end
  end
end
