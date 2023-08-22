require 'base64'
module TonSdkRuby

  def uint_to_hex(uint)
    hex = sprintf("%#x", uint)
    hex[-(hex.length / 2 * 2)..-1]
  end

  def hex_to_bits(hex)
    result = hex.split('').flat_map do |val|
      chunk = val.to_i(16)
                 .to_s(2)
                 .rjust(4, '0')
                 .split('')
                 .map(&:to_i)

      chunk
    end

    result
  end

  def bytes_to_uint(bytes)
    uint = bytes.each_with_index.inject(0) do |acc, (byte, i)|
      acc *= 256
      acc += byte
      acc
    end
    uint
  end

  def bytes_compare(a, b)
    return false if a.length != b.length

    a.each_with_index.all? { |uint, i| uint == b[i] }
  end

  def hex_to_bytes(hex)
    hex.scan(/.{1,2}/).map { |byte| byte.to_i(16) }
  end

  def bytes_to_bits(data)
    bytes = data.is_a?(Array) ? data : data.unpack("C*")

    result = bytes.reduce([]) do |acc, uint|
      chunk = uint.to_s(2)
                  .rjust(8, '0')
                  .split('')
                  .map(&:to_i)

      acc.concat(chunk)
    end
    result
  end

  def bits_to_hex(bits)
    bitstring = bits.join('')
    hex = bitstring.scan(/.{1,4}/).map { |el| el.rjust(4, '0').to_i(2).to_s(16) }
    hex.join('')
  end

  def bits_to_bytes(bits)
    return [].pack("C*") if bits.empty?

    hex_to_bytes(bits_to_hex(bits))
  end

  def bytes_to_hex(bytes)
    if bytes.is_a?(Array)
      bytes.pack('C*').unpack('H*').first
    else
      bytes.unpack('H*').first
    end
  end

  def bytes_to_string(bytes)
    bytes.pack("C*").force_encoding('utf-8')
  end

  def bytes_to_data_string(bytes)
    raise 'Only byte array' unless bytes.is_a?(Array)
    bytes.pack('C*')
  end

  def string_to_bytes(value)
    value.bytes
  end

  def bytes_to_base64(data)
    bytes = data.is_a?(String) ? data.unpack("C*") : data
    str = bytes.map(&:chr).join

    Base64.strict_encode64(str)
  end

  def base64_to_bytes(base64)
    binary = Base64.strict_decode64(base64)
    binary.bytes
  end

  def slice_into_chunks(arr, chunk_size)
    res = []

    (0...arr.length).step(chunk_size) do |i|
      chunk = arr[i, chunk_size]
      res.push(chunk)
    end

    res
  end

  INT32_MAX = 2147483647
  INT32_MIN = -2147483648


end