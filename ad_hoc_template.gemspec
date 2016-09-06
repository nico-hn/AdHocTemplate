# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ad_hoc_template/version'

Gem::Specification.new do |spec|
  spec.name          = "ad_hoc_template"
  spec.version       = AdHocTemplate::VERSION
  spec.authors       = ["HASHIMOTO, Naoki"]
  spec.email         = ["hashimoto.naoki@gmail.com"]
  spec.description   = %q{AdHocTemplate is a template processor with simple but sufficient rules for some ad hoc tasks.}
  spec.summary       = %q{A tiny template processor}
  spec.homepage      = "https://github.com/nico-hn/AdHocTemplate"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  spec.add_runtime_dependency "pseudohikiparser", "0.0.5.develop"
  spec.add_runtime_dependency "optparse_plus"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", "~> 10.1"
  spec.add_development_dependency "rspec", "~> 3.2"
end
