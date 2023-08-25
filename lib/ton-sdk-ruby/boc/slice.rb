module TonSdkRuby

  class Slice
    def initialize(bits, refs)
      @bits = bits
      @refs = refs
    end

    def bits
      Array.new(@bits)
    end

    def refs
      Array.new(@refs)
    end

    def skip(size)
      skip_bits(size)
    end

    def skip_bits(size)
      if @bits.length < size
        raise 'Slice: bits overflow.'
      end

      @bits.shift(size)
      self
    end

    def skip_refs(size)
      if @refs.length < size
        raise 'Slice: refs overflow.'
      end

      @refs.shift(size)
      self
    end

    def skip_dict
      is_empty = load_bit == 0
      return skip_refs(1) unless is_empty

      self
    end

    def load_ref
      raise 'Slice: refs overflow.' if @refs.empty?

      @refs.shift
    end

    def preload_ref
      raise 'Slice: refs overflow.' if @refs.empty?

      @refs[0]
    end

    def load_maybe_ref
      load_bit == 1 ? load_ref : nil
    end

    def preload_maybe_ref
      preload_bit == 1 ? preload_ref : nil
    end

    def load_bit
      raise 'Slice: bits overflow.' if @bits.empty?

      @bits.shift
    end

    def preload_bit
      raise 'Slice: bits overflow.' if @bits.empty?

      @bits[0]
    end

    def preload_bit
      raise 'Slice: bits overflow.' if @bits.empty?

      @bits[0]
    end

    def load_bits(size)
      raise 'Slice: bits overflow.' if size < 0 || @bits.length < size

      @bits.shift(size)
    end

    def preload_bits(size)
      raise 'Slice: bits overflow.' if size < 0 || @bits.length < size

      @bits[0, size]
    end

    def load_int(size)
      bits = load_bits(size)
      bits_to_int_uint(bits, { type: :int })
    end

    def preload_int(size)
      bits = preload_bits(size)
      bits_to_int_uint(bits, { type: :int })
    end

    def load_big_int(size)
      bits = load_bits(size)
      bits_to_big_int(bits)[:value]
    end

    def preload_big_int(size)
      bits = preload_bits(size)
      bits_to_big_int(bits)[:value]
    end

    def load_uint(size)
      bits = load_bits(size)

      bits_to_int_uint(bits, { type: :uint })
    end

    def preload_uint(size)
      bits = preload_bits(size)
      bits_to_int_uint(bits, { type: :uint })
    end

    def load_big_uint(size)
      bits = load_bits(size)
      bits_to_big_uint(bits)[:value]
    end

    def preload_big_uint(size)
      bits = preload_bits(size)
      bits_to_big_uint(bits)[:value]
    end

    def load_var_int(length)
      size = Math.log2(length).ceil

      size_bytes = preload_uint(size)
      size_bits = size_bytes * 8

      raise 'Slice: can\'t perform loadVarInt – not enough bits' if @bits.length < size_bits + size

      skip(size)
      load_int(size_bits)
    end

    def preload_var_int(length)
      size = Math.log2(length).ceil
      size_bytes = preload_uint(size)
      size_bits = size_bytes * 8
      bits = preload_bits(size + size_bits)[size..-1]

      bits_to_int_uint(bits, { type: :int })
    end

    def load_var_big_int(length)
      size = Math.log2(length).ceil

      size_bytes = preload_uint(size)
      size_bits = size_bytes * 8

      raise 'Slice: can\'t perform loadVarBigInt – not enough bits' if @bits.length < size_bits + size

      bits = load_bits(size_bits)
      bits_to_big_int(bits)[:value]
    end

    def preload_var_big_int(length)
      size = Math.log2(length).ceil
      size_bytes = preload_uint(size)
      size_bits = size_bytes * 8
      bits = preload_bits(size + size_bits)[size..-1]
      bits_to_big_int(bits)[:value]
    end

    def load_var_uint(length)
      size = Math.log2(length).ceil

      size_bytes = preload_uint(size)
      size_bits = size_bytes * 8

      raise 'Slice: can\'t perform loadVarUint – not enough bits' if @bits.length < size_bits + size

      skip(size)
      load_uint(size_bits)
    end

    def preload_var_uint(length)
      size = Math.log2(length).ceil
      size_bytes = preload_uint(size)
      size_bits = size_bytes * 8
      bits = preload_bits(size + size_bits)[size..-1]

      bits_to_int_uint(bits, { type: :uint })
    end

    def load_var_big_uint(length)
      size = Math.log2(length).ceil
      size_bytes = preload_uint(size)
      size_bits = size_bytes * 8

      raise 'Slice: can\'t perform loadVarBigUint – not enough bits' if @bits.length < size_bits + size

      bits = skip(size).load_bits(size_bits)
      bits_to_big_uint(bits)[:value]
    end

    def preload_var_big_uint(length)
      size = Math.log2(length).ceil
      size_bytes = preload_uint(size)
      size_bits = size_bytes * 8
      bits = preload_bits(size + size_bits)[size..-1]
      bits_to_big_uint(bits)[:value]
    end

    def load_bytes(size)
      bits = load_bits(size * 8)
      bits_to_bytes(bits)
    end

    def preload_bytes(size)
      bits = preload_bits(size * 8)
      bits_to_bytes(bits)
    end

    def load_string(size = nil)
      bytes = size.nil? ? load_bytes(@bits.length / 8) : load_bytes(size)
      bytes_to_string(bytes)
    end

    def preload_string(size = nil)
      bytes = size.nil? ? preload_bytes(@bits.length / 8) : preload_bytes(size)
      bytes_to_string(bytes)
    end

    def load_address
      flag_address_no = [0, 0]
      flag_address = [1, 0]
      flag = preload_bits(2)

      if flag == flag_address_no
        skip(2)
        Address::NONE
      elsif flag == flag_address
        # 2 bits flag, 1 bit anycast, 8 bits workchain, 256 bits address hash
        size = 2 + 1 + 8 + 256
        # Slice 2 because we don't need flag bits
        bits = load_bits(size)[2..-1]

        # Anycast is currently unused
        _anycast = bits.shift

        workchain = bits_to_int_uint(bits.shift(8), type: 'int')
        hash = bits_to_hex(bits.shift(256))
        raw = "#{workchain}:#{hash}"

        Address.new(raw)
      else
        raise 'Slice: bad address flag bits.'
      end
    end

    def preload_address
      flag_address_no = [0, 0]
      flag_address = [1, 0]
      flag = preload_bits(2)

      if flag == flag_address_no
        Address::NONE
      elsif flag == flag_address
        # 2 bits flag, 1 bit anycast, 8 bits workchain, 256 bits address hash
        size = 2 + 1 + 8 + 256
        bits = preload_bits(size)[2..-1]
        # Splice 2 because we don't need flag bits

        # Anycast is currently unused
        _anycast = bits.shift

        workchain = bits_to_int_uint(bits.shift(8), { type: 'int' })
        hash = bits_to_hex(bits.shift(256))
        raw = "#{workchain}:#{hash}"

        Address.new(raw)
      else
        raise 'Slice: bad address flag bits.'
      end
    end

    def load_coins(decimals = 9)
      coins = load_var_big_uint(16)
      Coins.new(coins, is_nano: true, decimals: decimals)
    end

    def preload_coins(decimals = 9)
      coins = preload_var_big_uint(16)
      Coins.new(coins, is_nano: true, decimals: decimals)
    end

    def load_dict(key_size, options = {})
      dict_constructor = load_bit
      is_empty = dict_constructor.zero?

      if !is_empty
        HashmapE.parse(
          key_size,
          Slice.new([dict_constructor], [load_ref]),
          options
        )
      else
        HashmapE.new(key_size, options)
      end
    end

    def preload_dict(key_size, options = {})
      dict_constructor = preload_bit
      is_empty = dict_constructor.zero?

      if !is_empty
        HashmapE.parse(
          key_size,
          Slice.new([dict_constructor], [preload_ref]),
          options
        )
      else
        HashmapE.new(key_size, options)
      end
    end

    def self.parse(cell)
      Slice.new(cell.bits.dup, cell.refs.dup)
    end
  end
end