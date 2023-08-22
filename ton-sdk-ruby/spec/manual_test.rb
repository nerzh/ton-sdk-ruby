require 'spec_helper'
require 'pp'
include TonSdkRuby

describe TonSdkRuby do
  before(:all) do
  end

  it 'manual_test' do
    # p TonSdkRuby

    # seed = generate_words(24)

    # p seed.join(' ')

    m = TonMnemonic.new()
    p m.seed
    p m.keys
  end
end



















