require 'digest'
require_relative 'helpers.rb'

module TonSdkRuby

  def sha256(bytes)
    digest = Digest::SHA256.digest(bytes.pack('C*'))
    bytes_to_hex(digest)
  end

  def sha512(bytes)
    digest = Digest::SHA512.digest(bytes.pack('C*'))
    bytes_to_hex(digest)
  end
end