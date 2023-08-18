module TonSdkRuby
  class Builder
    attr_reader :size, :refs, :bits

    def bytes
      bits_to_bytes(@bits)
    end

    def remainder
      size - bits.length
    end

    def initialize(size: 1023)
      @size = size
      @bits = []
      @refs = []
    end

    def store_bit(bit)
      value = Builder.check_bits_type_and_normalize([bit])

      check_bits_overflow(1)
      @bits.concat!(value)

      self
    end

    def store_bits(bits)
      value = Builder.check_bits_type_and_normalize(bits)

      check_bits_overflow(value.length)
      @bits.concat!(value)

      self
    end

    def store_int(value, size)
      int = value.is_a?(Integer) ? value : value.to_i
      int_bits = 1 << (size - 1)

      if int < -int_bits || int >= int_bits
        raise StandardError.new("Builder: can't store an Int, because its value allocates more space than provided.")
      end

      store_number(int, size)

      self
    end

    def store_uint(value, size)
      uint = value.is_a?(Integer) ? value : value.to_i

      if uint < 0 || uint >= (1 << size)
        raise StandardError.new("Builder: can't store an UInt, because its value allocates more space than provided.")
      end

      store_number(uint, size)

      self
    end

    def store_var_int(value, length)
      int = value.is_a?(Integer) ? value : value.to_i
      size = (Math.log2(length)).ceil
      size_bytes = (int.to_s(2).length / 8).ceil
      size_bits = size_bytes * 8

      check_bits_overflow(size + size_bits)

      if int == 0
        store_uint(0, size)
      else
        store_uint(size_bytes, size).store_int(value, size_bits)
      end

      self
    end

    def store_var_uint(value, length)
      uint = value.is_a?(Integer) ? value : value.to_i
      size = (Math.log2(length)).ceil
      size_bytes = (uint.to_s(2).length / 8).ceil
      size_bits = size_bytes * 8

      check_bits_overflow(size + size_bits)

      if uint == 0
        store_uint(0, size)
      else
        store_uint(size_bytes, size).store_uint(value, size_bits)
      end

      self
    end

    def store_bytes(value)
      check_bits_overflow(value.length * 8)

      value.each { |byte| store_uint(byte, 8) }

      self
    end

    def store_string(value)
      bytes = string_to_bytes(value)

      store_bytes(bytes)

      self
    end

    private

    def check_bits_overflow(size)
      if size > remainder
        raise StandardError.new("Builder: bits overflow. Can't add #{size} bits. Only #{remainder} bits left.")
      end
    end

    def self.check_bits_type_and_normalize(bits)
      bits.map do |bit|
        unless [0, 1, false, true].include?(bit)
          raise StandardError.new("Builder: can't store bit, because its type is not a Number or Boolean, or value doesn't equal 0 nor 1.")
        end

        bit == 1 || bit == true ? 1 : 0
      end
    end

    def check_refs_overflow(size)
      if size > (4 - @refs.length)
        raise StandardError.new("Builder: refs overflow. Can't add #{size} refs. Only #{4 - @refs.length} refs left.")
      end
    end

    def store_number(value, size)
      bits = Array.new(size) { |i| ((value >> i) & 1) == 1 ? 1 : 0 }.reverse
      store_bits(bits)
      self
    end

  end
end