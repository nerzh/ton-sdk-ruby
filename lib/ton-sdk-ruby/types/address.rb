require 'base64'

module TonSdkRuby

  FLAG_BOUNCEABLE = 0x11
  FLAG_NON_BOUNCEABLE = 0x51
  FLAG_TEST_ONLY = 0x80

  class Address
    extend TonSdkRuby
    include TonSdkRuby

    NONE = nil

    class Type
      BASE64 = 'base64'
      RAW = 'raw'
    end

    attr_reader :hash, :workchain, :bounceable, :test_only, :type

    def hash
      Array.new(@hash)
    end

    def initialize(address, options = {})
      is_address = Address.is_address?(address.clone)
      is_encoded = Address.is_encoded?(address.clone)
      is_raw = Address.is_raw?(address.clone)

      case true
      when is_address
        result = Address.parse_address(address)
      when is_encoded
        result = Address.parse_encoded(address)
      when is_raw
        result = Address.parse_raw(address)
      else
        raise 'Address: can\'t parse address. Unknown type.'
      end

      if result.nil?
        raise 'Address: can\'t parse address. Unknown type.'
      end

      @workchain = options[:workchain] || result[:workchain]
      @bounceable = options[:bounceable] || result[:bounceable]
      @test_only = options[:test_only] || result[:test_only]
      @hash = result[:hash]
    end

    def self.encode_tag(options)
      bounceable = options[:bounceable]
      test_only = options[:test_only]
      tag = bounceable ? FLAG_BOUNCEABLE : FLAG_NON_BOUNCEABLE

      test_only ? (tag | FLAG_TEST_ONLY) : tag
    end

    def self.decode_tag(tag)
      data = tag
      test_only = (data & FLAG_TEST_ONLY) != 0

      if test_only
        data ^= FLAG_TEST_ONLY
      end

      if ![FLAG_BOUNCEABLE, FLAG_NON_BOUNCEABLE].include?(data)
        raise 'Address: bad address tag.'
      end

      bounceable = data == FLAG_BOUNCEABLE

      {
        bounceable: bounceable,
        test_only: test_only
      }
    end

    def eq(address)
      address == self ||
        (bytes_compare(hash, address.hash) && workchain == address.workchain)
    end

    def to_s(options = {})
      type = options[:type] || Type::BASE64
      workchain = options[:workchain] || self.workchain
      bounceable = options[:bounceable] || self.bounceable
      test_only = options[:test_only] || self.test_only
      url_safe = options.key?(:url_safe) ? options[:url_safe] : true

      raise 'Address: workchain must be int8.' unless workchain.is_a?(Numeric) && workchain >= -128 && workchain < 128
      raise 'Address: bounceable flag must be a boolean.' unless [true, false].include?(bounceable)
      raise 'Address: testOnly flag must be a boolean.' unless [true, false].include?(test_only)
      raise 'Address: urlSafe flag must be a boolean.' unless [true, false].include?(url_safe)

      if type == Type::RAW
        "#{workchain}:#{bytes_to_hex(hash)}"
      else
        tag = Address.encode_tag(bounceable: bounceable, test_only: test_only)
        address = [tag, [workchain].pack("c*").unpack("C*").last] + hash
        checksum = crc16_bytes_be(address)
        base64 = bytes_to_base64(address + checksum)

        if url_safe
          base64 = base64.tr('/', '_').tr('+', '-')
        else
          base64 = base64.tr('_', '/').tr('-', '+')
        end

        base64
      end
    end



    private

    def self.is_encoded?(address)
      re = /^([a-zA-Z0-9_-]{48}|[a-zA-Z0-9\/\+]{48})$/
      address.is_a?(String) && re.match?(address)
    end

    def self.is_raw?(address)
      re = /^-?[0-9]:[a-zA-Z0-9]{64}$/
      address.is_a?(String) && re.match?(address)
    end

    def self.parse_encoded(value)
      base64 = value.tr('-', '+').tr('_', '/')
      bytes = base64_to_bytes(base64)
      data = Array.new(bytes)
      address = data.shift(34)
      checksum = data.shift(2)
      crc = crc16_bytes_be(address)

      raise 'Address: can\'t parse address. Wrong checksum.' unless bytes_compare(crc, checksum)

      buffer = address.shift(2).pack('C2')

      tag = buffer.unpack('C*').first
      workchain = buffer.unpack('c*').last

      hash = address.shift(32)

      decoded_tag = decode_tag(tag)
      bounceable = decoded_tag[:bounceable]
      test_only = decoded_tag[:test_only]

      {
        bounceable: bounceable,
        test_only: test_only,
        workchain: workchain,
        hash: hash,
        type: Type::BASE64
      }
    end

    def self.parse_address(value)
      workchain = value.workchain
      bounceable = value.bounceable
      test_only = value.test_only
      hash = value.hash.clone
      type = value.type

      {
        bounceable: bounceable,
        test_only: test_only,
        workchain: workchain,
        hash: hash,
        type: type
      }
    end

    def self.parse_raw(value)
      data = value.split(':')
      workchain = data[0].to_i
      hash = hex_to_bytes(data[1])
      bounceable = false
      test_only = false

      {
        bounceable: bounceable,
        test_only: test_only,
        workchain: workchain,
        hash: hash,
        type: Type::RAW
      }
    end

    def self.is_address?(address)
      address.is_a?(Address)
    end

    def self.is_valid?(address)
      begin
        new(address)
        true
      rescue
        false
      end
    end
  end
end
