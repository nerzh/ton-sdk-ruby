require 'securerandom'
require 'digest'
require 'openssl'

module TonSdkRuby
  class TonMnemonic

    attr_reader :seed, :keys

    def initialize

    end


    def self.generate_seed
      entropy = SecureRandom.random_bytes(32)
    end
  end
end