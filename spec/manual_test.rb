require 'spec_helper'
require 'pp'
include TonSdkRuby

describe TonSdkRuby do
  before(:all) do
  end

  it 'manual_test' do

    b = Builder.new
    b
      .store_uint(200, 30)
      # .store_coins(Coins.new(1_000_000))

    b2 = Builder.new.store_ref(b.cell)

    # b2.cell
    bytes =  TonSdkRuby.serialize(b2.cell)

    p TonSdkRuby.bytes_to_base64(bytes)
    p ""
    pp TonSdkRuby.deserialize(bytes)

    # p augment(bits: [1, 0 ,1], divider: 8)
    # p rollback(bits: [0,0,0])
  end
end



















