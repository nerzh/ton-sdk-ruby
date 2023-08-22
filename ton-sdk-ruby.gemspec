
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ton-sdk-ruby/version"

Gem::Specification.new do |spec|
  spec.name          = "ton-sdk-ruby"
  spec.version       = TonSdkRuby::VERSION
  spec.authors       = ["nerzh"]
  spec.email         = ["emptystamp@gmail.com"]

  spec.summary       = 'This is gem ton-sdk-ruby'
  spec.description   = 'Gem Ton SDK Ruby for all TVM ruby projects'
  spec.homepage      = 'https://github.com/nerzh/ton-sdk-ruby'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*']
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.bindir        = "bin"
  spec.executables   = ["ton-sdk-ruby"]

  spec.add_dependency 'ed25519', '~> 1.3.0'

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rake"
end
