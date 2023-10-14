require 'spec_helper'
require 'pp'
include TonSdkRuby

describe TonSdkRuby do
  before(:all) do
    @address_raw = "0:93c5a151850b16de3cb2d87782674bc5efe23e6793d343aa096384aafd70812c"

    options = {
      serializers: {
        key: ->(k) { Builder.new.store_uint(k, 16).bits },
        value: ->(v) { Builder.new.store_uint(v, 16).cell }
      }
    }

    @dict = HashmapE.new(16, options)
    @dict.set(17, 289)
    @dict.set(239, 57121)
    @dict.set(32781, 169)
  end

  it 'test_builder' do
    # UInt
    b = Builder.new
    b.store_uint(200, 30)
    expect(b.cell.hash).to eq("e6a7bd4728b8b6267951833bed536c2e203ba91445a94905f358961cc685fbc2")

    b = Builder.new
    b.store_uint(2 ** 30 - 1, 30)
    expect(b.cell.hash).to eq("20423e02436d18957feb0c7b303561df0d4061256f27cc51ef6595f03a3fab1d")

    b = Builder.new
    expect{b.store_uint(2 ** 30, 30)}.to raise_error(StandardError)

    b = Builder.new
    expect{b.store_uint(-1, 30)}.to raise_error(StandardError)

    b = Builder.new
    b.store_uint(0, 30)
    expect(b.cell.hash).to eq("f41a95995fccb3bf442ae56e28cdf165a87290de141db9ec028b2af28846c0ea")

    b = Builder.new
    b.store_uint(2 ** 1023 - 1 , 1023)
    expect(b.cell.hash).to eq("82970d4664b7683c3d14d49b1f9ff34966128170301a7becc27af1adbe6a31c9")

    # Coins
    b = Builder.new
    b.store_coins(Coins.new(0))
    expect(b.cell.hash).to eq("5331fed036518120c7f345726537745c5929b8ea1fa37b99b2bb58f702671541")

    b = Builder.new
    b.store_coins(Coins.new(13))
    expect(b.cell.hash).to eq("f331a2b0952843b5323d24096759f6bc27d87f060b27ef8c54175d278a437400")

    b = Builder.new
    b.store_coins(Coins.from_nano(2 ** 120 - 1))
    expect(b.cell.hash).to eq("07d470f83cea8b41383aab0113b84f4be3842bc6ec0c46d84664a647d5550dc9")

    b = Builder.new
    expect{b.store_coins(Coins.from_nano(2 ** 120))}.to raise_error(StandardError)

    # Ref
    b = Builder.new
    b.store_uint(40, 32)
    b2 = Builder.new
    b2.store_uint(20, 32)
    b2.store_ref(b.cell)
    b3 = Builder.new
    b3.store_uint(30, 32)
    b4 = Builder.new
    b5 = Builder.new
    b5.store_uint(10, 32)
    b5.store_ref(b2.cell)
    b5.store_ref(b3.cell)
    b5.store_ref(b4.cell)
    expect(b5.cell.hash).to eq("e72f05f1692dbf5ef676ff754286a96d022ddc4583dfa9e92637b9aaa14b5a18")

    b = Builder.new
    b.store_ref(Builder.new.cell)
    b.store_ref(Builder.new.cell)
    b.store_ref(Builder.new.cell)
    b.store_ref(Builder.new.cell)
    expect(b.cell.hash).to eq("2a6109474805b984fe2125a54016161fc8c819fc010905d0c2e7067cf23f8980")

    b = Builder.new
    b.store_refs([Builder.new.cell, Builder.new.cell])
    expect(b.cell.hash).to eq("f25bd30a545897dac24c1a3283e197788964eb16a46efcc509b2024c42c7f213")

    b = Builder.new
    b.store_maybe_ref(Builder.new.cell)
    expect(b.cell.hash).to eq("9770d42f6d781e048a432b849b56d5329de4667b37cfb918429a23f90cb9884b")

    b = Builder.new
    b.store_maybe_ref(nil)
    expect(b.cell.hash).to eq("90aec8965afabb16ebc3cb9b408ebae71b618d78788bc80d09843593cac98da4")

    b = Builder.new
    b.store_ref(Builder.new.cell)
    b.store_ref(Builder.new.cell)
    b.store_ref(Builder.new.cell)
    b.store_ref(Builder.new.cell)
    expect{b.store_ref(Builder.new.cell)}.to raise_error(StandardError)

    # Address
    b = Builder.new
    b.store_address(Address.new(@address_raw))
    expect(b.cell.hash).to eq("2104ffbf59587630833903fd8c9bbb26a84d6c08ba9d55b74e55acff6b9b269e")

    # Bytes
    b = Builder.new
    b.store_bytes([0, 1, 7, 255])
    expect(b.cell.hash).to eq("049453e2b528b2f7750fd76eb015660b30eb294c69958a9aa3cf55a0db08718a")

    b = Builder.new
    b.store_bytes(Array.new(127) { 0 })
    expect(b.cell.hash).to eq("0ebcf79f9d50dad8e07a7840a9928fe8c5dad0fb506155bcba8d2902a632f130")

    b = Builder.new
    expect{b.store_bytes(Array.new(128) { 0 })}.to raise_error(StandardError)

    # Int
    b = Builder.new
    b.store_int(-1, 8)
    expect(b.cell.hash).to eq("81f3b92f222078b1606cfc3eebfee22216cc40ac99e6524b00fbaa933a6bcd47")

    b = Builder.new
    b.store_int(-2 ** 31, 32)
    expect(b.cell.hash).to eq("fc0483d2794fdfcf966ed72ff8a05edd06dce073f181ffa7dda71d80ac3119de")

    b = Builder.new
    expect{b.store_int(-2 ** 31 - 1, 32)}.to raise_error(StandardError)

    b = Builder.new
    b.store_int(2 ** 31 - 1, 32)
    expect(b.cell.hash).to eq("dfd15d01ae93bac2ac4f4637ac40b957cda2f5036fe1c702b7fe3bd529be8063")

    b = Builder.new
    expect{b.store_int(2 ** 31, 32)}.to raise_error(StandardError)

    # VarInt
    b = Builder.new
    b.store_var_int(0, 8)
    expect(b.cell.hash).to eq("eb58904b617945cdf4f33042169c462cd36cf1772a2229f06171fd899e920b7f")

    # VarUInt
    b = Builder.new
    b.store_var_uint(1329227995784915872903807060280344575, 16)
    expect(b.cell.hash).to eq("07d470f83cea8b41383aab0113b84f4be3842bc6ec0c46d84664a647d5550dc9")

    b = Builder.new
    expect{b.store_var_uint(1329227995784915872903807060280344575 + 1, 16)}.to raise_error(StandardError)

    # String
    b = Builder.new
    b.store_string("Hello")
    expect(b.cell.hash).to eq("bb1cba91be1e73057ed9eadc8484d50bdfa70e14bad6065b82a88fd68929d243")

    b = Builder.new
    b.store_string("")
    expect(b.cell.hash).to eq("96a296d224f285c67bee93c30f8a309157f0daa35dc5b87e410b78630a09cfc7")

    b = Builder.new
    expect{b.store_string("1" * 128)}.to raise_error(StandardError)


    # Dict
    b = Builder.new
    b.store_dict(@dict)
    expect(b.cell.hash).to eq("863cdf82df752f65f8386646b1e92770fd3545d726762cae82e3b9a0100c501e")
  end

  it 'test_serializer' do
    b = Builder.new
    b.store_uint(200, 30)
    b2 = Builder.new.store_ref(b.cell)
    bytes =  TonSdkRuby.serialize(b2.cell)
    base64 = TonSdkRuby.bytes_to_base64(bytes)
    expect(base64).to eq("te6cckEBAgEACQABAAEABwAAAyL2hlPi")

    b = Builder.new
    b.store_uint(200, 30)
    b.store_coins(Coins.from_nano(1_000_000))
    b2 = Builder.new.store_ref(b.cell)
    bytes =  TonSdkRuby.serialize(b2.cell)
    base64 = TonSdkRuby.bytes_to_base64(bytes)
    expect(base64).to eq("te6cckEBAgEADQABAAEADwAAAyDD0JAgExM09w==")
  end

  it 'test_deserializer' do
    b = Builder.new
    b.store_uint(200, 30)
    b2 = Builder.new.store_ref(b.cell)
    bytes =  TonSdkRuby.serialize(b2.cell)
    base64 = TonSdkRuby.bytes_to_base64(bytes)
    expect(base64).to eq("te6cckEBAgEACQABAAEABwAAAyL2hlPi")
    expect(TonSdkRuby.deserialize(bytes).first.hash).to eq("5e3573edda7aa9074e83eb706aec33f4ed9ccdd708a82ea92b8eafa947f0ee75")
  end

  it 'test_address' do
    a = Address.new(@address_raw)
    expect(a.workchain).to eq(0)
    expect(a.bounceable).to eq(false)
    expect(a.test_only).to eq(false)
    expected = TonSdkRuby.hex_to_bytes(@address_raw.split(":").last)
    expect(a.hash).to eq(expected)

    a = Address.new("EQCTxaFRhQsW3jyy2HeCZ0vF7-I-Z5PTQ6oJY4Sq_XCBLPPw")
    expect(a.workchain).to eq(0)
    expect(a.bounceable).to eq(true)
    expect(a.test_only).to eq(false)
    expected = TonSdkRuby.hex_to_bytes(@address_raw.split(":").last)
    expect(a.hash).to eq(expected)

    a = Address.new("UQCTxaFRhQsW3jyy2HeCZ0vF7-I-Z5PTQ6oJY4Sq_XCBLK41")
    expect(a.workchain).to eq(0)
    expect(a.bounceable).to eq(false)
    expect(a.test_only).to eq(false)
    expected = TonSdkRuby.hex_to_bytes(@address_raw.split(":").last)
    expect(a.hash).to eq(expected)

    a = Address.new("kQCTxaFRhQsW3jyy2HeCZ0vF7-I-Z5PTQ6oJY4Sq_XCBLEh6")
    expect(a.workchain).to eq(0)
    expect(a.bounceable).to eq(true)
    expect(a.test_only).to eq(true)
    expected = TonSdkRuby.hex_to_bytes(@address_raw.split(":").last)
    expect(a.hash).to eq(expected)

    a = Address.new("0QCTxaFRhQsW3jyy2HeCZ0vF7-I-Z5PTQ6oJY4Sq_XCBLBW_")
    expect(a.workchain).to eq(0)
    expect(a.bounceable).to eq(false)
    expect(a.test_only).to eq(true)
    expected = TonSdkRuby.hex_to_bytes(@address_raw.split(":").last)
    expect(a.hash).to eq(expected)
  end

  it 'test_slice' do
    string = "/^Hello world[\\s\\S]+\n$"

    b = Builder.new
    b.store_uint(10, 8)
    b.store_int(127, 8)
    b.store_coins(Coins.new(13))
    b.store_address(Address.new(@address_raw))
    b.store_string(string)
    b.store_bytes([0, 255, 13])
    b.store_maybe_ref(Builder.new.cell)
    b.store_maybe_ref(nil)
    b.store_ref(Builder.new.store_int(13, 8).cell)
    b.store_bit(1)
    b.store_bit(0)
    b.store_bits([0, 1, 0, 1])
    b.store_dict(@dict)

    slice = b.cell.parse
    expect(slice.load_uint(8)).to eq(10)
    expect(slice.load_uint(8)).to eq(127)
    expect(slice.load_coins.to_nano).to eq(13 * 1_000_000_000)
    expect(slice.load_address.eq(Address.new(@address_raw))).to eq(true)
    expect(slice.load_string(string.size)).to eq(string)
    expect(slice.load_bytes(3)).to eq([0, 255, 13])
    expect(slice.load_maybe_ref.hash).to eq(Builder.new.cell.hash)
    expect(slice.load_maybe_ref).to eq(nil)
    expect(slice.load_ref.hash).to eq(Builder.new.store_int(13, 8).cell.hash)
    expect(slice.load_bit).to eq(1)
    expect(slice.load_bit).to eq(0)
    expect(slice.load_bits(4)).to eq([0, 1, 0, 1])
    expect(slice.load_dict(16).cell.hash).to eq(@dict.cell.hash)
    expect(slice.bits.size).to eq(0)



    slice = b.cell.parse
    bits = slice.bits.size
    expect(slice.preload_uint(8)).to eq(10)
    expect(slice.bits.size).to eq(bits)
    slice.skip(8)

    bits = slice.bits.size
    expect(slice.preload_uint(8)).to eq(127)
    expect(slice.bits.size).to eq(bits)
    slice.skip(8)

    bits = slice.bits.size
    expect(slice.preload_coins.to_nano).to eq(13 * 1_000_000_000)
    expect(slice.bits.size).to eq(bits)
    slice.skip(44)

    bits = slice.bits.size
    expect(slice.preload_address.eq(Address.new(@address_raw))).to eq(true)
    expect(slice.bits.size).to eq(bits)
    slice.skip(267)

    bits = slice.bits.size
    expect(slice.preload_string(string.size)).to eq(string)
    expect(slice.bits.size).to eq(bits)
    slice.skip(string.bytes.size * 8)

    bits = slice.bits.size
    expect(slice.preload_bytes(3)).to eq([0, 255, 13])
    expect(slice.bits.size).to eq(bits)
    slice.skip(3 * 8)

    bits = slice.bits.size
    expect(slice.preload_maybe_ref.hash).to eq(Builder.new.cell.hash)
    expect(slice.bits.size).to eq(bits)
    slice.skip(1)
    slice.skip_refs(1)

    bits = slice.bits.size
    expect(slice.preload_maybe_ref).to eq(nil)
    expect(slice.bits.size).to eq(bits)
    slice.skip(1)

    bits = slice.bits.size
    expect(slice.preload_ref.hash).to eq(Builder.new.store_int(13, 8).cell.hash)
    expect(slice.bits.size).to eq(bits)
    slice.skip_refs(1)

    bits = slice.bits.size
    expect(slice.preload_bit).to eq(1)
    expect(slice.bits.size).to eq(bits)
    slice.skip(1)

    bits = slice.bits.size
    expect(slice.preload_bit).to eq(0)
    expect(slice.bits.size).to eq(bits)
    slice.skip(1)

    bits = slice.bits.size
    expect(slice.preload_bits(4)).to eq([0, 1, 0, 1])
    expect(slice.bits.size).to eq(bits)
    slice.skip(4)

    bits = slice.bits.size
    expect(slice.preload_dict(16).cell.hash).to eq(@dict.cell.hash)
    expect(slice.bits.size).to eq(bits)
    slice.skip(1)
    slice.skip_refs(1)

    expect(slice.bits.size).to eq(0)
  end

  it 'Numbers' do
    bits = [1, 1, 0, 0, 1]
    expect(bits_to_int_uint(bits, { type: :uint })).to eq(25)
  end

  # Hashmap
  it 'should (de)serialize dict with mixed empty edges' do
    boc = 'te6cckEBEwEAVwACASABAgIC2QMEAgm3///wYBESAgEgBQYCAWIODwIBIAcIAgHODQ0CAdQNDQIBIAkKAgEgCxACASAQDAABWAIBIA0NAAEgAgEgEBAAAdQAAUgAAfwAAdwXk+eF'
    boc_network_config = deserialize(base64_to_bytes(boc)).first
    keys_network_config = [0, 1, 9, 10, 12, 14, 15, 16, 17, 32, 34, 36, -1001, -1000]

    deserializers = {
      deserializers: {
        key: ->(k) { Slice.parse(Builder.new.store_bits(k).cell).load_int(32) },
        value: ->(v) { v }
      }
    }

    parsed = Hashmap.parse(32, Slice.parse(boc_network_config), deserializers)
    array = parsed.each { |key, value|  {key: key, value: value} }

    expect(array.map { |item| item[:key] }).to eq(keys_network_config)
    expect(array.map { |item| item[:value].bits.empty? }.uniq).to eq([true])
  end

  it 'should (de)serialize dict with both edges' do
    boc = 'B5EE9C7241010501001D0002012001020201CF03040009BC0068054C0007B91012180007BEFDF218CFA830D9'
    boc_fift = deserialize(hex_to_bytes(boc)).first

    options = {
      serializers: {
        key: ->(k) { Builder.new.store_uint(k, 16).bits },
        value: ->(v) { Builder.new.store_uint(v, 16).cell }
      }
    }

    deserializers = {
      deserializers: {
        key: ->(k) { Slice.parse(Builder.new.store_bits(k).cell).load_uint(16) },
        value: ->(v) { Slice.parse(v).load_uint(16) }
      }
    }

    options.merge!(deserializers)

    dict = Hashmap.new(16, options)

    dict.set(17, 289)
    dict.set(239, 57121)
    dict.set(32781, 169)

    array = dict.each { |key, value|  {key: key, value: value} }
    parsed = Hashmap.parse(16, Slice.parse(boc_fift), deserializers).each { |key, value|  {key: key, value: value} }

    expect(array).to eq(parsed)
  end

  it 'should (de)serialize dict with empty right edges' do
    boc = 'B5EE9C72410106010020000101C0010202C8020302016204050007BEFDF2180007A68054C00007A08090C08D16037D'
    boc_fift = deserialize(hex_to_bytes(boc)).first

    serializers = {
      key: ->(k) { Builder.new.store_uint(k, 16).bits },
      value: ->(v) { Builder.new.store_uint(v, 16).cell }
    }

    deserializers = {
      key: ->(k) { Slice.parse(Builder.new.store_bits(k).cell).load_uint(16) },
      value: ->(v) { Slice.parse(v).load_uint(16) }
    }

    dict = HashmapE.new(16, {serializers: serializers, deserializers: deserializers})

    dict.set(13, 169)
    dict.set(17, 289)
    dict.set(239, 57121)

    result = dict.each { |key, value|  {key: key, value: value} }
    parsed = HashmapE.parse(16, Slice.parse(boc_fift), deserializers: deserializers).each { |key, value|  {key: key, value: value} }

    expect(result).to eq(parsed)
  end

  it 'Test Johnny Mnemonic' do
    mnemonic = TonMnemonic.new
    expect(mnemonic.mnemonic_array.size).to eq(24)
  end
end







