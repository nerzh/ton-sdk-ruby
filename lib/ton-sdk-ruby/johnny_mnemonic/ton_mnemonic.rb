require 'securerandom'
require 'digest'
require 'openssl'
require 'openssl/pkcs5'
require "ed25519"

module TonSdkRuby
  class TonMnemonic
    extend TonSdkRuby
    include TonSdkRuby

    TON_PBKDF_ITERATIONS = 100_000
    TON_KEYS_SALT = 'TON default seed'
    TON_SEED_SALT = 'TON seed version'
    TON_PASSWORD_SALT = 'TON fast seed version'

    attr_accessor :seed, :mnemonic_array, :keys, :password, :words_count

    def initialize(password = nil, words_count = 24)
      @words_count = words_count
      @password = password
      @mnemonic_array = generate_seed(words_count, password)
      @seed = mnemonic_array.join(' ')
      @keys = mnemonic_to_private_key(mnemonic_array, password)
    end

    def self.parse(mnemonic_string, password = nil)
      mnemonic = new
      mnemonic_string.gsub!(/\s+/, ' ')
      mnemonic.mnemonic_array = mnemonic_string.split(' ')
      mnemonic.words_count = mnemonic.mnemonic_array.size
      mnemonic.password = password
      mnemonic.seed = mnemonic.mnemonic_array.join(' ')
      mnemonic.keys = mnemonic.mnemonic_to_private_key(mnemonic.mnemonic_array, password)
      mnemonic
    end

    def get_secure_random_number(min, max)
      range = max - min
      bits_needed = Math.log2(range).ceil
      raise 'Range is too large' if bits_needed > 53
      bytes_needed = (bits_needed / 8.0).ceil
      mask = (2 ** bits_needed) - 1

      loop do
        res = SecureRandom.random_bytes(bytes_needed)
        power = (bytes_needed - 1) * 8
        number_value = 0
        res.each_byte do |byte|
          number_value += byte.ord * (2 ** power)
          power -= 8
        end
        number_value = number_value & mask # Truncate
        return min + number_value if number_value < range
      end
    end

    def generate_seed(words_count = 24, password = nil)
      mnemonic_array = []
      while true
        # Regenerate new mnemonics
        mnemonic_array = generate_words_ton(words_count)
        # # Check password conformance
        if password && password.length > 0
          next unless password_needed?(mnemonic_array)
        end
        # Check if basic seed correct
        unless basic_seed?(mnemonic_to_entropy(mnemonic_array, password))
          next
        end
        break
      end
      mnemonic_array
    end

    def mnemonic_to_entropy(mnemonic_array, password = nil)
      mnemonic_string = mnemonic_array.join(' ')
      password_string = password || ''
      # OpenSSL::HMAC.digest(digest, key, data)
      hmac = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha512'), mnemonic_string, password_string)
      entropy = bytes_to_hex(hmac.unpack('C*'))

      entropy
    end

    def generate_words_ton(length)
      mnemonic_array = []
      current_file_path = File.expand_path(File.dirname(__FILE__))
      bip0039en = JSON.parse(File.read("#{current_file_path}/words/english.json"))
      length.times do
        index = get_secure_random_number(0, length)
        mnemonic_array.push(bip0039en[index])
      end

      mnemonic_array
    end

    def mnemonic_to_private_key(mnemonic_array, password = nil)
      mnemonic_array = normalize_mnemonic(mnemonic_array)
      seed = mnemonic_to_seed(mnemonic_array, TON_KEYS_SALT, password)
      key_pair = Ed25519::SigningKey.new(seed[0, 32])
      {
        public: key_pair.verify_key.to_bytes.unpack1('H*'),
        secret: key_pair.to_bytes.unpack1('H*')
      }
    end

    def mnemonic_to_seed(mnemonic_array, salt, password)
      entropy_hex = mnemonic_to_entropy(mnemonic_array, password)
      entropy = bytes_to_data_string(hex_to_bytes(entropy_hex))
      hash = OpenSSL::Digest::SHA512.new
      OpenSSL::KDF.pbkdf2_hmac(entropy, salt: salt, iterations: TON_PBKDF_ITERATIONS, length: 64, hash: hash)
    end

    private
    def basic_seed?(entropy_hex)
      # pbkdf2_hmac(pass, salt, iter, keylen, digest)
      entropy = bytes_to_data_string(hex_to_bytes(entropy_hex))
      iter = [1, TON_PBKDF_ITERATIONS / 256].max
      hash = OpenSSL::Digest::SHA512.new
      key = OpenSSL::KDF.pbkdf2_hmac(entropy, salt: TON_SEED_SALT, iterations: iter, length: 64, hash: hash)

      key.bytes.first == 0
    end

    def password_seed?(entropy_hex)
      # pbkdf2_hmac(pass, salt, iter, keylen, digest)
      entropy = bytes_to_data_string(hex_to_bytes(entropy_hex))
      iter = 1
      hash = OpenSSL::Digest::SHA512.new
      key = OpenSSL::KDF.pbkdf2_hmac(entropy, salt: TON_PASSWORD_SALT, iterations: iter, length: 64, hash: hash)

      key.bytes.first == 1
    end

    def password_needed?(mnemonic_array)
      passless_entropy = mnemonic_to_entropy(mnemonic_array)
      password_seed?(passless_entropy) && !basic_seed?(passless_entropy)
    end

    def normalize_mnemonic(words)
      words.map { |v| v.downcase.strip }
    end
  end
end
