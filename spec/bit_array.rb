require 'spec_helper'


describe TonSdkRuby::BitArray do
  before(:all) do
  end

  it 'test_set_number!' do
    arr = TonSdkRuby::BitArray.new()
    expect(arr.send(:set_number!, index: 0, value: 3, size: 3)).to eq([false, true, true])
    
    arr.send(:set_number!, index: 3, value: 3, size: 3)
    expect(arr).to eq([false, true, true, false, true, true])
    
    arr.send(:set_number!, index: 6, value: 3, size: 3)
    expect(arr).to eq([false, true, true, false, true, true, false, true, true])
  end

  it 'test_set_signed_number!' do
    arr = TonSdkRuby::BitArray.new()
    expect(arr.send(:set_number!, index: 0, value: -3, size: 3)).to eq([true, false, true])
  end

  # it 'test_store_number!' do
  #   arr = TonSdkRuby::BitArray.new()
  #   expect(arr.send(:store_number!, index: 0, value: 3, size: 3)).to eq([false, true, true])
    
  #   arr.send(:store_number!, index: 3, value: 3, size: 3)
  #   expect(arr).to eq([false, true, true, false, true, true])
    
  #   arr.send(:store_number!, value: 3, size: 3)
  #   expect(arr).to eq([false, true, true, false, true, true, false, true, true])
  # end

  it 'test_set_byte!' do
    arr = TonSdkRuby::BitArray.new(size: 9, value: true)
    expect(arr.set_byte!(index: 1, value: 3)).to eq([true, false, false, false, false, false, false, true, true])
  end

  # it 'test_store_byte!' do
  #   arr = TonSdkRuby::BitArray.new(size: 2, value: true)
  #   expect(arr.store_byte!(value: 3)).to eq([false, false, false, false, false, false, true, true])

  #   expect(arr.store_byte!(value: 3)).to eq([false, false, false, false, false, false, true, true, false, false, false, false, false, false, true, true])
  # end

  it 'test_get_byte' do
    arr = TonSdkRuby::BitArray.new(size: 16, value: true)
    expect(arr.get_byte(index: 0)).to eq(255)
    expect(arr.get_byte(index: 8)).to eq(255)
  end

  it 'test_fill_trailing' do
    p Mask.new(1000)
    # arr = TonSdkRuby::BitArray.new()
    # arr.store_number(index: 2, value: 3, size: 3)
    # arr.store_sint!(value: 1, size: 1)
    # p arr
    # p arr.read_sint!(bits_amount: 1)
    # expect().to eq("")
  end
end



















