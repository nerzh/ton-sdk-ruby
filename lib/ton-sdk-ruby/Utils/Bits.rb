module TonSdkRuby

  def augment(bits, divider = 8)
    bits = Array.new(bits)
    amount = divider - (bits.size % divider)
    overage = Array.new(amount, 0)
    overage[0] = 1

    if overage.size != 0 && overage.size != divider
      return bits.concat(overage)
    end

    bits
  end

  def rollback(bits)
    index = bits.last(7).reverse.index(1)

    if index.nil?
      raise StandardError.new('Incorrectly augmented bits.')
    end

    bits[0, bits.length - (index + 1)]
  end
end