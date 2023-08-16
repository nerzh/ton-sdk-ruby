require 'spec_helper'
include TonSdkRuby

describe TonSdkRuby do
  before(:all) do
  end

  it 'manual_test' do
    p augment(bits: [1, 0 ,1], divider: 8)
  end
end



















