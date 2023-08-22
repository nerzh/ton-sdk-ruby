require 'pp'

module TonSdkRuby
  extend TonSdkRuby

  REACH_BOC_MAGIC_PREFIX = hex_to_bytes('B5EE9C72')
  LEAN_BOC_MAGIC_PREFIX = hex_to_bytes('68FF65F3')
  LEAN_BOC_MAGIC_PREFIX_CRC = hex_to_bytes('ACC3A728')

  class BOCOptions
    attr_accessor :has_index, :hash_crc32, :has_cache_bits, :topological_order, :flags
  end

  class BocHeader
    attr_accessor :has_index, :hash_crc32, :has_cache_bits, :flags, :size_bytes,
                  :offset_bytes, :cells_num, :roots_num, :absent_num,
                  :tot_cells_size, :root_list, :cells_data
  end

  class CellNode
    attr_accessor :cell, :children, :scanned
  end

  class BuilderNode
    attr_accessor :builder, :indent
  end

  class CellPointer
    attr_accessor :cell, :type, :builder, :refs
  end

  class CellData
    attr_accessor :pointer, :remainder
  end

  def deserialize_fift(data)
    raise 'Can\'t deserialize. Empty fift hex.' if data.nil? || data.empty?

    re = /((\s*)x{([0-9a-zA-Z_]+)}\n?)/mi
    matches = data.scan(re) || []

    raise 'Can\'t deserialize. Bad fift hex.' if matches.empty?

    parse_fift_hex = lambda do |fift|
      return [] if fift == '_'

      bits = fift.split('')
                 .map { |el| el == '_' ? el : hex_to_bits(el).join('') }
                 .join('')
                 .sub(/1[0]*_$/, '')
                 .split('')
                 .map(&:to_i)

      bits
    end

    if matches.length == 1
      return [Cell.new(bits: parse_fift_hex.call(matches[0][2]))]
    end

    is_last_nested = lambda do |stack, indent|
      last_stack_indent = stack[-1][:indent]
      last_stack_indent != 0 && last_stack_indent >= indent
    end

    stack = matches.each_with_object([]).with_index do |(el, acc), i|
      _, spaces, fift = el
      is_last = i == matches.length - 1
      indent = spaces.length
      bits = parse_fift_hex.call(fift)
      builder = Builder.new.store_bits(bits)

      while !acc.empty? && is_last_nested.call(acc, indent)
        b = acc.pop[:builder]
        acc[-1][:builder].store_ref(b.cell)
      end

      if is_last
        acc[-1][:builder].store_ref(builder.cell)
      else
        acc.push(indent: indent, builder: builder)
      end
    end

    stack.map { |el| el[:builder].cell }
  end


  def deserialize_header(bytes)
    raise 'Not enough bytes for magic prefix' if bytes.length < 4 + 1

    crcbytes = bytes[0, bytes.length - 4]
    prefix = bytes.shift(4)
    flags_byte = bytes.shift
    header = {
      has_index: true,
      hash_crc32: nil,
      has_cache_bits: false,
      flags: 0,
      size_bytes: flags_byte,
      offset_bytes: nil,
      cells_num: nil,
      roots_num: nil,
      absent_num: nil,
      tot_cells_size: nil,
      root_list: nil,
      cells_data: nil
    }

    if bytes_compare(prefix, REACH_BOC_MAGIC_PREFIX)
      header[:has_index] = (flags_byte & 128) != 0
      header[:has_cache_bits] = (flags_byte & 32) != 0
      header[:flags] = (flags_byte & 16) * 2 + (flags_byte & 8)
      header[:size_bytes] = flags_byte % 8
      header[:hash_crc32] = flags_byte & 64
    elsif bytes_compare(prefix, LEAN_BOC_MAGIC_PREFIX)
      header[:hash_crc32] = 0
    elsif bytes_compare(prefix, LEAN_BOC_MAGIC_PREFIX_CRC)
      header[:hash_crc32] = 1
    else
      raise 'Bad magic prefix'
    end

    raise 'Not enough bytes for encoding cells counters' if bytes.length < 1 + 5 * header[:size_bytes]

    offset_bytes = bytes.shift
    header[:offset_bytes] = offset_bytes
    header[:cells_num] = bytes_to_uint(bytes.shift(header[:size_bytes]))
    header[:roots_num] = bytes_to_uint(bytes.shift(header[:size_bytes]))
    header[:absent_num] = bytes_to_uint(bytes.shift(header[:size_bytes]))
    header[:tot_cells_size] = bytes_to_uint(bytes.shift(offset_bytes))

    raise 'Not enough bytes for encoding root cells hashes' if bytes.length < header[:roots_num] * header[:size_bytes]

    header[:root_list] = Array.new(header[:roots_num]) do
      ref_index = bytes_to_uint(bytes.shift(header[:size_bytes]))
      ref_index
    end

    if header[:has_index]
      raise 'Not enough bytes for index encoding' if bytes.length < header[:offset_bytes] * header[:cells_num]
      Array.new(header[:cells_num]) { bytes.shift(header[:offset_bytes]) }
    end

    raise 'Not enough bytes for cells data' if bytes.length < header[:tot_cells_size]
    # byebug
    header[:cells_data] = bytes.shift(header[:tot_cells_size])

    if header[:hash_crc32]
      raise 'Not enough bytes for crc32c hashsum' if bytes.length < 4

      result = crc32c_bytes_le(crcbytes)

      raise 'Crc32c hashsum mismatch' unless bytes_compare(result, bytes.shift(4))
    end

    raise 'Too much bytes in BoC serialization' unless bytes.empty?

    header
  end

  def deserialize_cell(remainder, ref_index_size)
    raise "BoC not enough bytes to encode cell descriptors" if remainder.length < 2

    refs_descriptor = remainder.shift
    level = refs_descriptor >> 5
    total_refs = refs_descriptor & 7
    has_hashes = (refs_descriptor & 16) != 0
    is_exotic = (refs_descriptor & 8) != 0
    is_absent = total_refs == 7 && has_hashes

    # For absent cells (i.e., external references), only refs descriptor is present
    # Currently not implemented
    if is_absent
      raise "BoC can't deserialize absent cell"
    end

    raise "BoC cell can't has more than 4 refs #{total_refs}" if total_refs > 4

    bits_descriptor = remainder.shift
    is_augmented = (bits_descriptor & 1) != 0
    data_size = (bits_descriptor >> 1) + (is_augmented ? 1 : 0)
    hashes_size = has_hashes ? (level + 1) * 32 : 0
    depth_size = has_hashes ? (level + 1) * 2 : 0

    required_bytes = hashes_size + depth_size + data_size + ref_index_size * total_refs

    raise "BoC not enough bytes to encode cell data" if remainder.length < required_bytes

    remainder.shift(hashes_size + depth_size) if has_hashes

    bits = if is_augmented
             rollback(bytes_to_bits(remainder.shift(data_size)))
           else
             bytes_to_bits(remainder.shift(data_size))
           end

    raise "BoC not enough bytes for an exotic cell type" if is_exotic && bits.length < 8

    type = if is_exotic
             bits_to_int_uint(bits[0, 8], { type: "int" })
           else
             CellType::Ordinary
           end

    raise "BoC an exotic cell can't be of ordinary type" if is_exotic && type == CellType::Ordinary

    pointer = {
      type: type,
      builder: Builder.new(bits.length).store_bits(bits),
      refs: Array.new(total_refs) { bytes_to_uint(remainder.shift(ref_index_size)) }
    }

    { pointer: pointer, remainder: remainder }
  end

  def deserialize(data, check_merkle_proofs = false)
    has_merkle_proofs = false
    bytes = Array.new(data)
    pointers = []
    header = deserialize_header(bytes)

    header[:cells_num].times do
      deserialized = deserialize_cell(header[:cells_data], header[:size_bytes])
      header[:cells_data] = deserialized[:remainder]
      pointers.push(deserialized[:pointer])
    end
    # header[:cells_data].each_with_index do |_, i|
    #   deserialized = deserialize_cell(header[:cells_data][i], header[:size_bytes])
    #   header[:cells_data][i] = deserialized[:remainder]
    #   pointers.push(deserialized[:pointer])
    # end

    pointers.reverse_each.with_index do |pointer, i|
      pointer_index = pointers.length - i - 1
      cell_builder = pointer[:builder]
      cell_type = pointer[:type]

      pointer[:refs].each do |ref_index|
        ref_builder = pointers[ref_index][:builder]
        ref_type = pointers[ref_index][:type]

        raise "Topological order is broken" if ref_index < pointer_index

        if ref_type == CellType::MerkleProof || ref_type == CellType::MerkleUpdate
          has_merkle_proofs = true
        end

        cell_builder.store_ref(ref_builder.cell(ref_type))
      end

      if cell_type == CellType::MerkleProof || cell_type == CellType::MerkleUpdate
        has_merkle_proofs = true
      end

      pointers[pointer_index][:cell] = cell_builder.cell(cell_type)
    end

    raise "BOC does not contain Merkle Proofs" if check_merkle_proofs && !has_merkle_proofs

    header[:root_list].map { |ref_index| pointers[ref_index][:cell] }
  end

  def depth_first_sort(root)
    stack = [{
               cell: Cell.new(refs: root),
               children: root.length,
               scanned: 0
             }]

    cells = []
    hash_indexes = {}

    process = lambda do |node|
      ref = node[:cell].refs[node[:scanned]]
      hash = ref.hash
      index = hash_indexes[hash]
      length = index.nil? ? cells.push(cell: ref, hash: hash) : cells.push(cells.delete_at(index))

      stack.push(cell: ref, children: ref.refs.length, scanned: 0)
      hash_indexes[hash] = length - 1
    end

    while !stack.empty?
      current = stack.last

      if current[:children] != current[:scanned]
        process.call(current)
      else
        while !stack.empty? && current && current[:children] == current[:scanned]
          stack.pop
          current = stack.last
        end

        process.call(current) if current
      end
    end

    result = cells.each_with_index.reduce({ cells: [], hashmap: {} }) do |acc, (el, i)|
      unless el.nil?
        acc[:cells].push(el[:cell])
        acc[:hashmap][el[:hash]] = i
      end

      acc
    end

    result
  end

  def breadth_first_sort(root)
    root = [*root]
    stack = root.dup
    cells = root.map { |el| { cell: el, hash: el.hash } }
    hash_indexes = cells.map.with_index { |el, i| [el[:hash], i] }.to_h

    process = lambda do |node|
      hash = node.hash
      index = hash_indexes[hash]
      length = index.nil? ? cells.push(cell: node, hash: hash).size : cells.push(cells.delete_at(index)).size

      stack.push(node)
      hash_indexes[hash] = length - 1
    end

    while !stack.empty?
      length = stack.length

      stack.each do |node|
        node.refs.each { |ref| process.call(ref) }
      end

      stack.shift(length)
    end

    result = cells.each_with_index.reduce({ cells: [], hashmap: {} }) do |acc, (el, i)|
      unless el.nil?
        acc[:cells].push(el[:cell])
        acc[:hashmap][el[:hash]] = i
      end

      acc
    end

    result
  end

  def serialize_cell(cell, hashmap, ref_index_size)
    representation = cell.get_refs_descriptor +
      cell.get_bits_descriptor +
      cell.get_augmented_bits

    serialized = cell.refs.reduce(representation) do |acc, ref|
      ref_index = hashmap[ref.hash]
      bits = Array.new(ref_index_size) { |i| (ref_index >> i) & 1 }

      acc + bits.reverse
    end

    serialized
  end


  def serialize(root, options = {})
    root = [*root]
    # TODO: Implement breadthFirstSort and depthFirstSort functions

    has_index = options.fetch(:has_index, false)
    has_cache_bits = options.fetch(:has_cache_bits, false)
    hash_crc32 = options.fetch(:hash_crc32, true)
    topological_order = options.fetch(:topological_order, 'breadth-first')
    flags = options.fetch(:flags, 0)

    if topological_order == 'breadth-first'
      breadth = breadth_first_sort(root)
      cells_list = breadth[:cells]
      hashmap = breadth[:hashmap]
    else
      breadth = depth_first_sort(root)
      cells_list = breadth[:cells]
      hashmap = breadth[:hashmap]
    end

    cells_num = cells_list.size
    size = cells_num.to_s(2).size
    size_bytes = [(size.to_f / 8).ceil, 1].max
    cells_bits = []
    size_index = []

    cells_list.each do |cell|
      bits = serialize_cell(cell, hashmap, size_bytes * 8)
      cells_bits.concat(bits)
      size_index.push(bits.length / 8)
    end

    full_size = cells_bits.length / 8
    offset_bits = full_size.to_s(2).length
    offset_bytes = [offset_bits / 8, 1].max
    builder_size = (32 + 3 + 2 + 3 + 8) +
      (cells_bits.length) +
      ((size_bytes * 8) * 4) +
      (offset_bytes * 8) +
      (has_index ? (cells_list.length * (offset_bytes * 8)) : 0)

    result = Builder.new(builder_size)

    result.store_bytes(REACH_BOC_MAGIC_PREFIX)
          .store_bit(has_index ? 1 : 0)
          .store_bit(hash_crc32 ? 1 : 0)
          .store_bit(has_cache_bits ? 1 : 0)
          .store_uint(flags, 2)
          .store_uint(size_bytes, 3)
          .store_uint(offset_bytes, 8)
          .store_uint(cells_num, size_bytes * 8)
          .store_uint(root.length, size_bytes * 8)
          .store_uint(0, size_bytes * 8)
          .store_uint(full_size, offset_bytes * 8)
          .store_uint(0, size_bytes * 8)

    if has_index
      size_index.each do |index|
        result.store_uint(index, offset_bytes * 8)
      end
    end

    augmented_bits = augment(result.store_bits(cells_bits).bits)
    bytes = bits_to_bytes(augmented_bits)

    if hash_crc32
      hashsum = crc32c_bytes_le(bytes)
      bytes + hashsum
    else
      bytes
    end
  end
end