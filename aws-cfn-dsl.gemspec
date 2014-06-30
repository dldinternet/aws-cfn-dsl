# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aws/cfn/dsl/version'

Gem::Specification.new do |spec|
  spec.name          = "aws-cfn-dsl"
  spec.version       = Aws::Cfn::Dsl::VERSION
  spec.authors       = ["Christo DeLange"]
  spec.email         = ["rubygems@dldinternet.com"]
  spec.summary       = %q{Ruby DSL for creating Cloudformation templates}
  spec.description   = %q{Ruby DSL for creating Cloudformation templates}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'awesome_print', '~> 1.2', '>= 1.2.0'
  spec.add_dependency 'psych'
  spec.add_dependency 'json'
  spec.add_dependency 'slop'
  spec.add_dependency 'cloudformation-ruby-dsl', '~> 0.4', '>= 0.4.3'

end
