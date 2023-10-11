module TonSdkRuby

  class BitArray < Array
    extend TonSdkRuby

    attr_accessor :read_cursor

    def initialize(size: 0, value: false)
      @read_cursor = 0
      super(size) { |_| get_value(value) }
    end

    def to_s
      self.map { |e| e ? 1 : 0 }.join('')
    end

    def show_cursor
      self.map { |e| e ? 1 : 0 }.join('').insert(cursor, '⏶')
    end

    def set_bit!(index: nil, value: nil)
      raise "Wrong index #{index}. Out of bounds array" if index > size || index < 0
      self[index] = get_value(value)
    end

    def get_bit(index: nil)
      raise "Wrong index #{index}. Out of bounds array" if index > size - 1 || index < 0
      self[index]
    end

    def set_byte!(index: nil, value: nil)
      set_number!(index: index, value: value, size: 8)
    end

    def get_byte(index: nil)
      raise "Wrong index #{index}. Out of bounds array" if index > size - 1 || index < 0
      self[index..index+7].map { |e| e.to_i}.join('').to_i(2)
    end

    def store_uint!(value: nil, size: nil)
      store_number!(value: value, size: size)
    end

    def store_sint!(value: nil, size: nil)
      # i.e. signed int and one first bit reserved for sign size = (size - 1)
      # and restrict for max value = value >= (1 << size - 1)
      max_sint = (1 << size - 1)
      raise "Wrong value #{value}" if value < -max_sint || value >= max_sint
      set_number!(value: value, size: size)
    end

    def read_uint!(bits_amount: nil)
      raise "Wrong bits_amount #{bits_amount}" if bits_amount > self.size
      bits_string = ""
      (read_cursor + bits_amount).times do |index|
        bits_string << self[index] ? '1' : '0'
        @read_cursor = index
      end
      bits_string.to_i(2)
    end

    def read_sint!(bits_amount: nil)
      raise "Wrong bits_amount #{bits_amount}" if bits_amount > self.size
      negative_sign = false
      bits_string = ""
      (read_cursor + bits_amount).times do |index|
        bits_string << (self[index] ? '1' : '0')
        @read_cursor = index
      end
      calc_signed_integer(bits_string: bits_string)
    end


    private

    # 00001101 -> set as 00001101
    def set_number!(index: nil, value: nil, size: nil)
      index = index ? index : self.size
      raise "Wrong index #{index}. Out of bounds array" if index > self.size || index < 0
      # if size = 4 bit and max value in bits = 1111, then error (value >= 10000) == (value >= (1 << 4))
      raise "Wrong value #{value}" if value >= (1 << size)
      size.times do |i|
        bit_index = size - i - 1
        # if size = 4 bit and value in bots = 1000, then (1000 >> (4 - 1)) == 0001
        most_significant_bit = (value >> bit_index)
        # p most_significant_bit.to_s(2)
        # & (AND) 101 & 1 == 001 or 101 & 001 == 001
        bit = (most_significant_bit & 1) == 1
        set_bit!(index: index, value: bit)
        index += 1
      end
      self
    end

    # # 00001101 -> set as 00001101
    # def store_number!(index: nil, value: nil, size: nil)
    #   @cursor = index ? index : cursor
    #   raise "Wrong index #{cursor}. Out of bounds array" if cursor > self.size || cursor < 0
    #   # if size = 4 bit and max value in bits = 1111, then error (value >= 10000) == (value >= (1 << 4))
    #   raise "Wrong value #{value}" if value < 0 || value >= (1 << size)
    #   size.times do |i|
    #     bit_index = size - i - 1
    #     # if size = 4 bit and value in bots = 1000, then (1000 >> (4 - 1)) == 0001
    #     most_significant_bit = (value >> bit_index)
    #     # p most_significant_bit.to_s(2)
    #     # & (AND) 101 & 1 == 001 or 101 & 001 == 001
    #     bit = (most_significant_bit & 1) == 1
    #     set_bit!(index: cursor, value: bit)
    #     @cursor += 1
    #   end
    #   self
    # end

    def calc_signed_integer(bits_string: nil)
      value = bits_string.to_i(2)
      index = bits_string.size - 1
      (value & ~(1 << index)) - (value & (1 << index))
    end

    def get_value(val)
      if val.class == TrueClass
        val
      elsif val.class == FalseClass
        val
      elsif val.class == String
        val == "1" ? true : false
      elsif val.class == Integer
        val == 0 ? false : true
      else
        raise "Wrong data type of #{val}"
      end
    end
  end
end

class FalseClass
  def to_i
    0
  end
end

class TrueClass
  def to_i
    1
  end
end
