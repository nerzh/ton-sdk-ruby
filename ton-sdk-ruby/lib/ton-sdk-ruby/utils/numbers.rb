module TonSdkRuby

  def bits_to_big_uint(bits)
    return { value: 0, is_safe: true } if bits.empty?

    value = bits.reverse.each_with_index.inject(0) { |acc, (bit, i)| bit.to_i * (2 ** i) + acc }

    is_safe = value <= Float::MAX.to_i

    {
      value: value,
      is_safe: is_safe
    }
  end

  def bits_to_big_int(bits)
    return { value: 0, is_safe: true } if bits.empty?

    uint_result = bits_to_big_uint(bits)
    uint = uint_result[:value]
    size = bits.size
    int = 1 << (size - 1)
    value = uint >= int ? (uint - (int * 2)) : uint
    is_safe = value >= Float::MIN.to_i && value <= Float::MAX.to_i

    {
      value: value,
      is_safe: is_safe
    }
  end

  def bits_to_int_uint(bits, options = { type: 'int' })
    type = options[:type].to_s || 'uint'
    result = if type == 'uint'
               bits_to_big_uint(bits)
             else
               bits_to_big_int(bits)
             end

    result[:value]
  end
end