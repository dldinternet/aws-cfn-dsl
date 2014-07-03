require 'slop'

class Object
  def with(instance, *args, &block)
    instance.instance_exec(*args, &block)
    instance
  end
end

module Aws
  module Cfn
    module Dsl
      module Options
        attr_reader   :opts
        attr_reader   :config

        require "dldinternet/mixlib/cli/mixins/parsers"
        include ::DLDInternet::Mixlib::CLI::Parsers

        def setup_options(opts=@opts)
          @on_off_regex = %r/0|1|yes|no|on|off|enable|disable|set|unset|true|false|raw/i
          @format_regex = %r/ruby|rb|yaml|yml|json|js/i
          @on_yes_regex = %r'^(1|true|on|yes|enable|set)$'
          @optional   ||= {}
          unless opts
            @opts ||= Slop.new(help: true)
            opts = @opts
          end

          with opts do
            on :t, :template=,      'The template', as: String
            on :d, :directory=,     'The directory with template components.', as: String

            on :l, :log_level=, "Logging level. [#{::Logging::LEVELS.keys.join('|')}]", {as: String,
                                                                                           default: 'step',
                                                                                           match: %r/#{::Logging::LEVELS.keys.join('|')}/i}

            [
                { short: :n, long: :functions=,    default: 'off', on: 'on',      desc: 'Enable function use'},
                { short: :x, long: :expandedpaths, default: 'off', on:      'on', desc: 'Show expanded paths in output',                                       },
                { short: :O, long: :overwrite,     default: 'off', on:      'on', desc: 'Overwrite existing generated source files. (HINT: Think twice ...)',  },
            ].each do |opt|
              on opt[:short], opt[:long], opt[:desc], {as: String,
                                             optional_argument: true,
                                             default: opt[:default],
                                             match: @on_off_regex } do |_|
                me = @options.select { |o|
                  o.long == opt[:long].to_s
                }[0]
                me.config[:default] = opt[:on]
              end
            end
            [
                { short: :overwrite,  default: 'off', on:      'on', desc: 'Overwrite existing generated source files. (HINT: Think twice ...)',  },
                { short: :force,      default: 'off', on:      'on', desc: 'Continue processing and ignore warnings',                             },
                { short: :debug,      default: 'off', on:      'on', desc: 'Turn on debugging',                                                   },
                { short: :trace,      default: 'off', on:      'on', desc: 'Turn on tracing',                                                     },
            ].each do |opt|
              on opt[:short], opt[:desc], {as: String,
                                             optional_argument: true,
                                             default: opt[:default],
                                             match: @on_off_regex } do |_|
                me = @options.select { |o|
                  o.long == opt[:short].to_s
                }[0]
                me.config[:default] = opt[:on]
              end
            end
          end

        end

        def parse_options

          setup_options

          @opts.parse!

          setup_config

        end

        def setup_config

          unless @opts[:directory] or @optional[:directory]
            puts @opts
            abort! "Missing required option. --directory is required"
          end

          unless @opts[:template]
            puts @opts
            abort! "Missing required option --template"
          end

          [:overwrite, :functions, :force, :expandedpaths, :debug, :trace  ].each { |cfg|
            @config[cfg] = (not (@opts[cfg].nil? or @opts[cfg].downcase.match(@on_yes_regex).nil?))
          }

          @opts.options.each{ |opt|
            key = opt.long.to_sym
            unless @config.has_key?(key)
              @config[key] = opt.value unless opt.value.nil?
            end
          }

          lcs = ::Logging::ColorScheme.new( 'compiler', :levels => {
              :trace => :blue,
              :debug => :cyan,
              :info  => :green,
              :step  => :green,
              :warn  => :yellow,
              :error => :red,
              :fatal => :red,
              :todo  => :purple,
          })
          scheme = lcs.scheme
          scheme['trace'] = "\e[38;5;33m"
          scheme['fatal'] = "\e[38;5;89m"
          scheme['todo']  = "\e[38;5;55m"
          lcs.scheme scheme
          @config[:log_level] ||= :info
          @config[:log_opts] = lambda{|mlll| {
              :pattern      => "%#{mlll}l: %m %g\n",
              :date_pattern => '%Y-%m-%d %H:%M:%S',
              :color_scheme => 'compiler',
              :trace        => (@config[:trace].nil? ? false : @config[:trace]),
              # [2014-06-30 Christo] DO NOT do this ... it needs to be a FixNum!!!!
              # If you want to do ::Logging.init first then fine ... go ahead :)
              # :level        => @config[:log_level],
          }
          }
          @logger = getLogger(@config)

        end

        def self.included(includer)

        end

      end
    end
  end
end
