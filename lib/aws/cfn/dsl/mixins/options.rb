require 'slop'
module Aws
  module Cfn
    module Dsl
      module Options
        attr_reader   :opts
        attr_reader   :config

        def setup_options
          @on_off_regex = %r/0|1|yes|no|on|off|enable|disable|set|unset|true|false|raw/i
          @format_regex = %r/ruby|rb|yaml|yml|json|js/i
          @on_yes_regex = %r'^(1|true|on|yes|enable|set)$'

          @opts = Slop.new(help: true) do
            on :t, :template=,      'The template', as: String
            on :d, :directory=,     'The directory with template components.', as: String

            on :l, :log_level=, "Logging level. [#{::Logging::LEVELS.keys.join('|')}]", {as: String,
                                                                                           default: 'step',
                                                                                           match: %r/#{::Logging::LEVELS.keys.join('|')}/i}

            on :n, :functions=,     'Enable function use.', { as: String,
                                                              default: 'off',
                                                              match: @on_off_regex } do |_|
              me = @options.select { |o|
                o.long == 'functions'
              }[0]
              me.config[:default] = 'on'
            end
            on :x, :expandedpaths, 'Show expanded paths in output', {as: String,
                                                                     optional_argument: true,
                                                                     default: 'off',
                                                                     match: @on_off_regex } do |objects|
              me = @options.select { |o|
                o.long == 'expandedpaths'
              }[0]
              me.config[:default] = 'on'
            end
            on :O, :overwrite, 'Overwrite existing generated source files. (HINT: Think twice ...)', {as: String,
                                                                                                      optional_argument: true,
                                                                                                      default: 'off',
                                                                                                      match: @on_off_regex } do |objects|
              me = @options.select { |o|
                o.long == 'overwrite'
              }[0]
              me.config[:default] = 'on'
            end
            on :force, 'Continue processing and ignore warnings', {as: String,
                                                                   optional_argument: true,
                                                                   default: 'off',
                                                                   match: @on_off_regex } do |objects|
              me = @options.select { |o|
                o.long == 'force'
              }[0]
              me.config[:default] = 'on'
            end
          end

        end

        def parse_options

          setup_options

          @opts.parse!

          setup_config

        end

        def setup_config

          unless @opts[:directory]
            puts @opts
            abort! "Missing required option --directory"
          end

          unless @opts[:template]
            puts @opts
            abort! "Missing required option --template"
          end

          [:overwrite, :functions, :force, :expandedpaths  ].each { |cfg|
            @config[cfg] = (not @opts[cfg].downcase.match(@on_yes_regex).nil?)
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
          @config[:log_opts] = lambda{|mlll| {
              :pattern      => "%#{mlll}l: %m %C\n",
              :date_pattern => '%Y-%m-%d %H:%M:%S',
              :color_scheme => 'compiler'
          }
          }
          @config[:log_level] ||= :info
          @logger = getLogger(@config)
        end

        def self.included(includer)

        end

      end
    end
  end
end
