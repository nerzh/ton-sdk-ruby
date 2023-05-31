class Mask

  def initialize(mask)
    if mask.class.to_s.downcase == "mask"
      @value = mask.value
    elsif mask.class.to_s.downcase == "integer"
      @value = mask
    end

    @hashIndex = countSetBits(value)
    @hashCount = @hashIndex + 1
  end

  def value
    @value
  end

  def level
    32 - clz(value)
  end

  def hashIndex
    @hashIndex
  end

  def hashCount
    @hashCount
  end

  def isSignificant(level)
    level == 0 || (self.value >> (level - 1)) % 2 != 0
  end

  def apply(level)
    Mask.new(self.value & ((1 << level) - 1))
  end

  private

  def clz(number, size = 32)
    bits_string = number.to_i.to_s(2)
    if bits_string.size > size
      bits_string.slice((bits_string.size - size)..bits_string.size)
    else
      size - bits_string.size
    end
  end

  def countSetBits(n)
    n = n - ((n >> 1) & 0x55555555)
    n = (n & 0x33333333) + ((n >> 2) & 0x33333333)
    ((n + (n >> 4) & 0xF0F0F0F) * 0x1010101) >> 24
  end
end