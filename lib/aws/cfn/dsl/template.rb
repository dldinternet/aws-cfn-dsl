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
          match = line.match %r/^(.*?)(\{\s*:\S+\s*=>.*?\}|\{\s*\S+:\s*.*?\})(.*)$/
          if match
            h = nil
            eval "h = #{match[2]}", binding
            k = h.keys[0]
            v = h.delete(k)
            v = if v.is_a?Array
                  v.map{|e| e.to_s }
                else
                  v.to_s
                end

            h[k.to_s] = v
            scope[:logger].debug h
            [match[1], h, hash_refs(match[3],scope) ]
          else
            "#{line}\n"
          end
        end

        def exec!(argv=ARGV)
          @opts = Slop.parse(help: true) do
            banner "usage: #{$PROGRAM_NAME} <expand|diff|validate|create|update|delete>"
            on :o, :output=,        'The template file to save this DSL expansion to', as: String
          end

          action = argv[0] || 'expand'
          unless %w(expand diff validate create update delete).include? action
            $stderr.puts "usage: #{$PROGRAM_NAME} <expand|diff|validate|create|update|delete>"
            exit(2)
          end
          unless (argv & %w(--template-file --template-url)).empty?
            $stderr.puts "#{File.basename($PROGRAM_NAME)}:  The --template-file and --template-url command-line options are not allowed. (You are running the template itself right now ... !)"
            exit(2)
          end

          # Find parameters where extension attribute :Immutable is true then remove it from the
          # cfn template since we can't pass it to CloudFormation.
          immutable_parameters = excise_parameter_attribute!(:Immutable)

          # Tag CloudFormation stacks based on :Tags defined in the template
          cfn_tags = excise_tags!
          # The command line string looks like: --tag "Key=key; Value=value" --tag "Key2=key2; Value2=value"
          cfn_tags_options = cfn_tags.sort.map { |tag| ["--tag", "Key=%s; Value=%s" % tag.split('=')] }.flatten

          # example: <template.rb> cfn-create-stack my-stack-name --parameters "Env=prod" --region eu-west-1
          # Execute the AWS CLI cfn-cmd command to validate/create/update a CloudFormation stack.
          if action == 'diff' or (action == 'expand' and not nopretty)
            template_string = JSON.pretty_generate(self)
          else
            template_string = JSON.generate(self)
          end

          if action == 'expand'
            # Write the pretty-printed JSON template to stdout and exit.  [--nopretty] option writes output with minimal whitespace
            # example: <template.rb> expand --parameters "Env=prod" --region eu-west-1 --nopretty
            if @opts[:output]
              dest = @opts[:output]
              if File.directory? dest
                file = File.basename $PROGRAM_NAME
                file.gsub!(%r'\.rb', '.json')
                dest = File.join dest, file
              end
              IO.write(dest, template_string)
            else
              puts template_string
            end
            exit(true)
          end

          temp_file = File.absolute_path("#{$PROGRAM_NAME}.expanded.json")
          File.write(temp_file, template_string)

          cmdline = ['cfn-cmd'] + argv + ['--template-file', temp_file] + cfn_tags_options

          case action
            when 'diff'
              # example: <template.rb> diff my-stack-name --parameters "Env=prod" --region eu-west-1
              # Diff the current template for an existing stack with the expansion of this template.

              # The --parameters and --tag options were used to expand the template but we don't need them anymore.  Discard.
              _, cfn_options = extract_options(argv[1..-1], %w(), %w(--parameters --tag))

              # Separate the remaining command-line options into options for 'cfn-cmd' and options for 'diff'.
              cfn_options, diff_options = extract_options(cfn_options, %w(),
                                                          %w(--stack-name --region --parameters --connection-timeout -I --access-key-id -S --secret-key -K --ec2-private-key-file-path -U --url))

              # If the first argument is a stack name then shift it from diff_options over to cfn_options.
              if diff_options[0] && !(/^-/ =~ diff_options[0])
                cfn_options.unshift(diff_options.shift)
              end

              # Run CloudFormation commands to describe the existing stack
              cfn_options_string           = cfn_options.map { |arg| "'#{arg}'" }.join(' ')
              old_template_raw             = exec_capture_stdout("cfn-cmd cfn-get-template #{cfn_options_string}")
              # ec2 template output is not valid json: TEMPLATE  "<json>\n"\n
              old_template_object          = JSON.parse(old_template_raw[11..-3])
              old_template_string          = JSON.pretty_generate(old_template_object)
              old_stack_attributes         = exec_describe_stack(cfn_options_string)
              old_tags_string              = old_stack_attributes["TAGS"]
              old_parameters_string        = old_stack_attributes["PARAMETERS"]

              # Sort the tag strings alphabetically to make them easily comparable
              old_tags_string = (old_tags_string || '').split(';').sort.map { |tag| %Q(TAG "#{tag}"\n) }.join
              tags_string     = cfn_tags.sort.map { |tag| "TAG \"#{tag}\"\n" }.join

              # Sort the parameter strings alphabetically to make them easily comparable
              old_parameters_string = (old_parameters_string || '').split(';').sort.map { |param| %Q(PARAMETER "#{param}"\n) }.join
              parameters_string     = parameters.sort.map { |key, value| "PARAMETER \"#{key}=#{value}\"\n" }.join

              # Diff the expanded template with the template from CloudFormation.
              old_temp_file = File.absolute_path("#{$PROGRAM_NAME}.current.json")
              new_temp_file = File.absolute_path("#{$PROGRAM_NAME}.expanded.json")
              File.write(old_temp_file, old_tags_string + old_parameters_string + old_template_string)
              File.write(new_temp_file, tags_string + parameters_string + template_string)

              # Compare templates
              system(*["diff"] + diff_options + [old_temp_file, new_temp_file])

              File.delete(old_temp_file)
              File.delete(new_temp_file)

              exit(true)

            when 'cfn-validate-template'
              # The cfn-validate-template command doesn't support --parameters so remove it if it was provided for template expansion.
              _, cmdline = extract_options(cmdline, %w(), %w(--parameters --tag))

            when 'cfn-update-stack'
              # Pick out the subset of cfn-update-stack options that apply to cfn-describe-stacks.
              cfn_options, other_options = extract_options(argv[1..-1], %w(),
                                                           %w(--stack-name --region --connection-timeout -I --access-key-id -S --secret-key -K --ec2-private-key-file-path -U --url))

              # If the first argument is a stack name then shift it over to cfn_options.
              if other_options[0] && !(/^-/ =~ other_options[0])
                cfn_options.unshift(other_options.shift)
              end

              # Run CloudFormation command to describe the existing stack
              cfn_options_string = cfn_options.map { |arg| "'#{arg}'" }.join(' ')
              old_stack_attributes = exec_describe_stack(cfn_options_string)

              # If updating a stack and some parameters are marked as immutable, fail if the new parameters don't match the old ones.
              if not immutable_parameters.empty?
                old_parameters_string = old_stack_attributes["PARAMETERS"]
                old_parameters = Hash[(old_parameters_string || '').split(';').map { |pair| pair.split('=', 2) }]
                new_parameters = parameters

                immutable_parameters.sort.each do |param|
                  if old_parameters[param].to_s != new_parameters[param].to_s
                    $stderr.puts "Error: cfn-update-stack may not update immutable parameter " +
                                     "'#{param}=#{old_parameters[param]}' to '#{param}=#{new_parameters[param]}'."
                    exit(false)
                  end
                end
              end

              # Tags are immutable in CloudFormation.  The cfn-update-stack command doesn't support --tag options, so remove
              # the argument (if it exists) and validate against the existing stack to ensure tags haven't changed.
              # Compare the sorted arrays for an exact match
              old_cfn_tags = old_stack_attributes['TAGS'].split(';').sort rescue [] # Use empty Array if .split fails
              if cfn_tags != old_cfn_tags
                $stderr.puts "CloudFormation stack tags do not match and cannot be updated. You must either use the same tags or create a new stack." +
                                 "\n" + (old_cfn_tags - cfn_tags).map {|tag| "< #{tag}" }.join("\n") +
                                 "\n" + "---" +
                                 "\n" + (cfn_tags - old_cfn_tags).map {|tag| "> #{tag}"}.join("\n")
                exit(false)
              end
              _, cmdline = extract_options(cmdline, %w(), %w(--tag))
          end

          # Execute command cmdline
          unless system(*cmdline)
            $stderr.puts "\nExecution of 'cfn-cmd' failed.  To facilitate debugging, the generated JSON template " +
                             "file was not deleted.  You may delete the file manually if it isn't needed: #{temp_file}"
            exit(false)
          end

          File.delete(temp_file)

          exit(true)
        end


      end
    end
  end
end

# Main entry point
def template(&block)
  Aws::Cfn::Dsl::Template.new(&block)
end
