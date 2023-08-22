
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ton-sdk-ruby-smc/version"

Gem::Specification.new do |spec|
  spec.name          = "ton-sdk-ruby-smc"
  spec.version       = TonSdkRubySmc::VERSION
  spec.authors       = ["nerzh"]
  spec.email         = ["emptystamp@gmail.com"]

  spec.summary       = 'This is gem ton-sdk-ruby-smc'
  spec.description   = 'Gem Ton SDK Ruby for all TVM ruby projects'
  spec.homepage      = 'https://github.com/nerzh/ton-sdk-ruby'
  spec.license       = 'LGPL-3.0-or-later'

  spec.files         = Dir['lib/**/*']
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.bindir        = "bin"
  spec.executables   = ["ton-sdk-ruby-smc"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rake"
end
