module TonSdkRuby

  def augment(bits: [], divider: 8)
    amount = divider - (bits.size % divider)
    overage = Array.new(amount, 0)
    overage[0] = 1

    if (overage.size != 0 && overage.size != divider)
      return bits.concat(overage)
    end

    bits
  end
end