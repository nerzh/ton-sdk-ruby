module TonSdkRuby
  class Builder
    extend TonSdkRuby
    include TonSdkRuby

    attr_reader :size, :refs, :bits

    def bytes
      bits_to_bytes(@bits)
    end

    def remainder
      size - bits.length
    end

    def initialize(size = 1023)
      @size = size
      @bits = []
      @refs = []
    end

    def store_slice(slice)
      require_type('slice', slice, Slice)
      Builder.check_slice_type(slice)

      bits = slice.bits
      refs = slice.refs

      check_bits_overflow(bits.length)
      check_refs_overflow(refs.length)
      store_bits(bits)

      refs.each { |ref| store_ref(ref) }

      self
    end

    def store_ref(ref)
      require_type('ref', ref, Cell)
      Builder.check_refs_type([ref])
      check_refs_overflow(1)
      @refs.push(ref)

      self
    end

    def store_maybe_ref(ref = nil)
      require_type('ref', ref, Cell) if ref
      return store_bit(0) unless ref
      store_bit(1).store_ref(ref)
    end

    def store_refs(refs)
      Builder.check_refs_type(refs)
      check_refs_overflow(refs.length)
      @refs.push(*refs)

      self
    end

    def store_bit(bit)
      bit = bit.to_i
      value = Builder.check_bits_type_and_normalize([bit])
      check_bits_overflow(1)
      @bits += value

      self
    end

    def store_bits(bits)
      require_type('bits', bits, Array)
      require_type('bit', bits[0], Integer) if bits.size > 0
      value = Builder.check_bits_type_and_normalize(bits)
      check_bits_overflow(value.length)
      @bits += value

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
      size_bytes = (int.to_s(2).length.to_f / 8).ceil
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
      size_bytes = (uint.to_s(2).length.to_f / 8).ceil
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
      require_type('value', value, Array)
      check_bits_overflow(value.size * 8)
      value.each { |byte| store_uint(byte, 8) }

      self
    end

    def store_string(value)
      require_type('value', value, String)
      bytes = string_to_bytes(value)

      store_bytes(bytes)

      self
    end

    def store_address(address = nil)
      require_type('address', address, Address) if address
      if address.nil?
        store_bits([0, 0])
        return self
      end

      anycast = 0
      address_bits_size = 2 + 1 + 8 + 256

      Builder.check_address_type(address)
      check_bits_overflow(address_bits_size)
      store_bits([1, 0])
      store_uint(anycast, 1)
      store_int(address.workchain, 8)
      store_bytes(address.hash)

      self
    end

    def store_coins(coins)
      require_type('coins', coins, Coins)
      if coins.negative?
        raise 'Builder: coins value can\'t be negative.'
      end

      nano = coins.to_nano

      # https://github.com/ton-blockchain/ton/blob/master/crypto/block/block.tlb#L116
      store_var_uint(nano, 16)

      self
    end

    def store_dict(hashmap = nil)
      return store_bit(0) unless hashmap

      slice = hashmap.cell.parse
      store_slice(slice)

      self
    end

    def clone
      data = Builder.new(size)

      # Use getters to get copy of arrays
      data.store_bits(bits)
      refs.each { |ref| data.store_ref(ref) }

      data
    end

    def cell(type = CellType::Ordinary)
      # Use getters to get copies of arrays
      cell = Cell.new(bits: bits, refs: refs, type: type)

      cell
    end

    private

    def self.check_slice_type(slice)
      unless slice.is_a?(Slice)
        raise StandardError, "Builder: can't store slice, because it's type is not a Slice."
      end
    end

    def self.check_address_type(address)
      unless address.is_a?(Address)
        raise StandardError, "Builder: can't store address, because it's type is not an Address."
      end
    end

    def check_bits_overflow(size)
      if size > remainder
        raise StandardError.new("Builder: bits overflow. Can't add #{size} bits. Only #{remainder} bits left.")
      end
    end

    def self.check_refs_type(refs)
      unless refs.all? { |cell| cell.is_a?(Cell) }
        raise StandardError, "Builder: can't store ref, because it's type is not a Cell."
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
