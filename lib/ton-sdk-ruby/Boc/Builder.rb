module TonSdkRuby
  class Builder
    attr_reader :size, :refs, :bits

    def bytes
      bits_to_bytes(@bits)
    end

    def remainder
      @size - @bits.length
    end

    def initialize(size: 1023)
      @size = size
      @bits = []
      @refs = []
    end


    private

    def check_bits_overflow(size)
      if size > remainder
        raise StandardError.new("Builder: bits overflow. Can't add #{size} bits. Only #{@remainder} bits left.")
      end
    end

    def self.check_bits_type_and_normalize(bits: [])
      bits.map do |bit|
        unless [0, 1, false, true].include?(bit)
          raise StandardError.new("Builder: can't store bit, because its type is not a Number or Boolean, or value doesn't equal 0 nor 1.")
        end

        bit == 1 || bit == true ? 1 : 0
      end
    end
  end
end