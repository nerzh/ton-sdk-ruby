module TonSdkRuby

  def crc16(data)
    poly = 0x1021
    bytes = data.pack("C*")
    int16 = bytes.reduce(0) do |acc, el|
      crc = acc ^ (el << 8)

      8.times do
        crc = (crc & 0x8000) == 0x8000 ? (crc << 1) ^ poly : crc << 1
      end

      crc
    end & 0xffff

    [int16].pack("S").unpack1("S")
  end

  def crc16_bytes_be(data)
    crc = crc16(data)
    [crc].pack("S>").bytes
  end

  def crc32c(data)
    poly = 0x82f63b78
    bytes = data.pack("C*")

    int32 = bytes.reduce(0 ^ 0xffffffff) do |acc, el|
      crc = acc ^ el

      8.times do
        crc = crc & 1 == 1 ? (crc >> 1) ^ poly : crc >> 1
      end

      crc
    end ^ 0xffffffff

    [int32].pack("L>").unpack1("L>")
  end

  def crc32c_bytes_le(data)
    crc = crc32c(data)
    [crc].pack("L<").bytes
  end

end