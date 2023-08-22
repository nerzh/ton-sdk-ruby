require_relative './utils'
require 'securerandom'
require 'json'
require 'openssl'
require 'openssl/pkcs5'

module TonSdkRuby

  private def derive_checksum_bits_bip39(entropy_bytes)
    cs = (entropy_bytes.size * 8) / 32
    hex = sha256(entropy_bytes)
    bits = hex_to_bits(hex)

    bits.slice(0, cs)
  end

  def generate_words_bip39(length)
    current_file_path = File.expand_path(File.dirname(__FILE__))
    bip0039en = JSON.parse(File.read("#{current_file_path}/words/english.json"))
    entropy = SecureRandom.random_bytes(bytes_needed_for_words(length)).unpack('C*')
    checksum_bits = derive_checksum_bits(entropy)
    entropy_bits = bytes_to_bits(entropy)
    full_bits = entropy_bits + checksum_bits
    chunks = full_bits.join('').scan(/.{1,11}/)
    words = chunks.map do |chunk|
      index = chunk.to_i(2)
      bip0039en[index]
    end

    words
  end

  def bytes_needed_for_words_bip39(word_count)
    full_entropy = word_count * 11
    checksum = full_entropy % 32
    initial_entropy = full_entropy - checksum
    initial_entropy / 8
  end
end