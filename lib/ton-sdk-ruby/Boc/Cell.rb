module TonSdkRuby

  HASH_BITS = 256
  DEPTH_BITS = 16

  module CellType
    Ordinary = -1
    PrunedBranch = 1
    LibraryReference = 2
    MerkleProof = 3
    MerkleUpdate = 4
  end

  def validate_ordinary(bits, refs)
    if bits.length > 1023
      raise "Ordinary cell can't have more than 1023 bits, got #{bits.length}"
    end

    if refs.length > 4
      raise "Ordinary cell can't have more than 4 refs, got #{refs.length}"
    end
  end

  def validate_pruned_branch(bits, refs)
    min_size = 8 + 8 + (1 * (HASH_BITS + DEPTH_BITS))

    if bits.length < min_size
      raise "Pruned Branch cell can't have less than (8 + 8 + 256 + 16) bits, got #{bits.length}"
    end

    if refs.length != 0
      raise "Pruned Branch cell can't have refs, got #{refs.length}"
    end

    type = bits_to_int_uint(bits[0...8], { type: 'int' })

    if type != CellType::PrunedBranch
      raise "Pruned Branch cell type must be exactly #{CellType::PrunedBranch}, got #{type}"
    end

    mask = Mask.new(bits_to_int_uint(bits[8...16], { type: 'uint' }))

    if mask.level < 1 || mask.level > 3
      raise "Pruned Branch cell level must be >= 1 and <= 3, got #{mask.level}"
    end

    hash_count = mask.apply(mask.level - 1)[:hashCount]
    size = 8 + 8 + (hash_count * (HASH_BITS + DEPTH_BITS))

    if bits.length != size
      raise "Pruned Branch cell with level #{mask.level} must have exactly #{size} bits, got #{bits.length}"
    end
  end

  def validate_library_reference(bits, refs)
    # Type + hash
    size = 8 + HASH_BITS

    if bits.length != size
      raise "Library Reference cell must have exactly (8 + 256) bits, got \"#{bits.length}\""
    end

    if refs.length != 0
      raise "Library Reference cell can't have refs, got \"#{refs.length}\""
    end

    type = bits_to_int_uint(bits[0..7], { type: 'int' })

    if type != CellType::LibraryReference
      raise "Library Reference cell type must be exactly #{CellType::LibraryReference}, got \"#{type}\""
    end
  end

  def validate_merkle_proof(bits, refs)
    # Type + hash + depth
    size = 8 + HASH_BITS + DEPTH_BITS

    if bits.length != size
      raise "Merkle Proof cell must have exactly (8 + 256 + 16) bits, got \"#{bits.length}\""
    end

    if refs.length != 1
      raise "Merkle Proof cell must have exactly 1 ref, got \"#{refs.length}\""
    end

    type = bits_to_int_uint(bits[0..7], { type: 'int' })

    if type != CellType::MerkleProof
      raise "Merkle Proof cell type must be exactly #{CellType::MerkleProof}, got \"#{type}\""
    end

    data = bits[8..-1]
    proof_hash = bits_to_hex(data[0..(HASH_BITS - 1)])
    proof_depth = bits_to_int_uint(data[HASH_BITS..(HASH_BITS + DEPTH_BITS - 1)], { type: 'uint' })
    ref_hash = refs[0].hash(0)
    ref_depth = refs[0].depth(0)

    if proof_hash != ref_hash
      raise "Merkle Proof cell ref hash must be exactly \"#{proof_hash}\", got \"#{ref_hash}\""
    end

    if proof_depth != ref_depth
      raise "Merkle Proof cell ref depth must be exactly \"#{proof_depth}\", got \"#{ref_depth}\""
    end
  end

  def validate_merkle_update(bits, refs)
    size = 8 + (2 * (256 + 16))

    if bits.length != size
      raise "Merkle Update cell must have exactly (8 + (2 * (256 + 16))) bits, got #{bits.length}"
    end

    if refs.length != 2
      raise "Merkle Update cell must have exactly 2 refs, got #{refs.length}"
    end

    type = bits_to_int_uint(bits[0..7], { type: 'int' })

    if type != CellType::MerkleUpdate
      raise "Merkle Update cell type must be exactly #{CellType::MerkleUpdate}, got #{type}"
    end

    data = bits[8..-1]
    hashes = [data[0..255], data[256..511]].map { |el| bits_to_hex(el) }
    depths = [data[512..527], data[528..543]].map { |el| bits_to_int_uint(el, { type: 'uint' }) }

    refs.each_with_index do |ref, i|
      proof_hash = hashes[i]
      proof_depth = depths[i]
      ref_hash = ref.hash(0)
      ref_depth = ref.depth(0)

      if proof_hash != ref_hash
        raise "Merkle Update cell ref ##{i} hash must be exactly '#{proof_hash}', got '#{ref_hash}'"
      end

      if proof_depth != ref_depth
        raise "Merkle Update cell ref ##{i} depth must be exactly '#{proof_depth}', got '#{ref_depth}'"
      end
    end
  end

  def get_mapper(type)
    map = {
      CellType::Ordinary => {
        validate: method(:validate_ordinary),
        mask: -> (_b, r) { Mask.new(r.reduce(0) { |acc, el| acc | el.mask.value }) }
      },
      CellType::PrunedBranch => {
        validate: method(:validate_pruned_branch),
        mask: lambda { |b| Mask.new(bits_to_int_uint(b[8..15], { type: 'uint' })) }
      },
      CellType::LibraryReference => {
        validate: method(:validate_library_reference),
        mask: -> { Mask.new(0) }
      },
      CellType::MerkleProof => {
        validate: method(:validate_merkle_proof),
        mask: lambda { |_b, r| Mask.new(r[0].mask.value >> 1) }
      },
      CellType::MerkleUpdate => {
        validate: method(:validate_merkle_update),
        mask: lambda { |_b, r| Mask.new((r[0].mask.value | r[1].mask.value) >> 1) }
      }
    }

    result = map[type]

    if result.nil?
      raise 'Unknown cell type'
    end

    result
  end


  class Cell
    attr_accessor :bits, :refs, :type, :mask
    attr_reader :hashes, :depths
    private :bits, :refs, :type, :mask, :hashes, :depths

    def initialize(options = {})
      options = { bits: [], refs: [], type: CellType::Ordinary }.merge(options)

      mapper = get_mapper(options[:type])
      validate = mapper[:validate]
      mask = mapper[:mask]

      validate.call(options[:bits], options[:refs])
      @mask = mask.call(options[:bits], options[:refs])
      @type = options[:type]
      @bits = options[:bits]
      @refs = options[:refs]
      @depths = {}
      @hashes = {}

      init()
    end

    # Get current Cell instance bits
    def bits
      @bits.dup
    end

    # Get current Cell instance refs
    def refs
      @refs.dup
    end

    # Get current Cell instance Mask (that includes level, hashes count, etc...)
    def mask
      @mask
    end

    # Get current Cell instance CellType
    def type
      @type
    end

    # Check if current Cell instance is exotic type
    def exotic
      @type != CellType::Ordinary
    end

    # Calculate depth descriptor
    def self.get_depth_descriptor(depth)
      descriptor = [(depth / 256).floor, depth % 256].pack('C*')
      bytes_to_bits(descriptor)
    end

    # Get current Cell instance refs descriptor
    def get_refs_descriptor(mask = nil)
      value = @refs.length +
        (exotic ? 8 : 0) +
        ((mask ? mask.value : @mask.value) * 32)

      descriptor = [value].pack('C')
      bytes_to_bits(descriptor)
    end

    # Get current Cell instance bits descriptor
    def get_bits_descriptor
      value = (@bits.length / 8.0).ceil + (@bits.length / 8.0).floor
      descriptor = [value].pack('C')
      bytes_to_bits(descriptor)
    end

    # Get current Cell instance augmented bits
    def get_augmented_bits
      augment(@bits)
    end

    # Get cell's hash in hex (max level by default)
    def hash(level = 3)
      return @hashes[@mask.apply(level).hash_index] if @type != CellType::PrunedBranch

      hash_index = @mask.apply(level).hash_index
      this_hash_index = @mask.hash_index
      skip = 16 + hash_index * HASH_BITS

      if hash_index != this_hash_index
        bits_to_hex(@bits[skip...(skip + HASH_BITS)])
      else
        @hashes[0]
      end
    end

    # Get cell's depth (max level by default)
    def depth(level = 3)
      return @depths[@mask.apply(level).hash_index] if @type != CellType::PrunedBranch

      hash_index = @mask.apply(level).hash_index
      this_hash_index = @mask.hash_index
      skip = 16 + this_hash_index * HASH_BITS + hash_index * DEPTH_BITS

      if hash_index != this_hash_index
        bits_to_int_uint(@bits[skip...(skip + DEPTH_BITS)], type: 'uint')
      else
        @depths[0]
      end
    end

    # Get Slice from current instance
    def parse
      Slice.parse(self)
    end

    # Print cell as fift-hex
    def print(indent = 1, size = 0)
      # TODO: fix this logic

      bits = @bits.dup
      are_divisible = bits.length % 4 == 0
      augmented = are_divisible ? bits : augment(bits, 4)
      fift_hex = "#{bits_to_hex(augmented).upcase}#{are_divisible ? '' : '_'}"
      output = ["#{' ' * (indent * size)}x{#{fift_hex}}\n"]

      @refs.each do |ref|
        output.push(ref.print(indent, size + 1))
      end

      output.join('')
    end

    # Checks Cell equality by comparing cell hashes
    def eq(cell)
      hash == cell.hash
    end


    private

    def init
      has_refs = @refs.length.positive?
      is_merkle = [CellType::MerkleProof, CellType::MerkleUpdate].include?(@type)
      is_pruned_branch = @type == CellType::PrunedBranch
      hash_index_offset = is_pruned_branch ? @mask.hash_count - 1 : 0

      hash_index = 0
      (0..@mask.level).each do |level_index|
        next unless @mask.is_significant(level_index)
        next if hash_index < hash_index_offset

        if (hash_index == hash_index_offset && level_index != 0 && !is_pruned_branch) ||
          (hash_index != hash_index_offset && level_index == 0 && is_pruned_branch)
          raise 'Can\'t deserialize cell'
        end
        ref_level = level_index + (is_merkle ? 1 : 0)
        refs_descriptor = get_refs_descriptor(@mask.apply(level_index))
        bits_descriptor = get_bits_descriptor
        data = if hash_index != hash_index_offset
                 hex_to_bits(@hashes[hash_index - hash_index_offset - 1])
               else
                 get_augmented_bits
               end
        depth_repr = []
        hash_repr = []
        depth = 0
        @refs.each do |ref|
          ref_depth = ref.depth(ref_level)
          ref_hash = ref.hash(ref_level)

          depth_repr.concat(Cell.get_depth_descriptor(ref_depth))
          hash_repr.concat(hex_to_bits(ref_hash))
          depth = [depth, ref_depth].max
        end
        representation = refs_descriptor + bits_descriptor + data + depth_repr + hash_repr

        if @refs.length.positive? && depth >= 1024
          raise 'Cell depth can\'t be more than 1024'
        end
        dest = hash_index - hash_index_offset

        @depths[dest] = depth + (has_refs ? 1 : 0)
        @hashes[dest] = sha256(bits_to_bytes(representation))
        hash_index += 1
      end
    end

  end
end