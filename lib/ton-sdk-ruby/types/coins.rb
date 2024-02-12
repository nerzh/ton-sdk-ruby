require 'bigdecimal'

module TonSdkRuby

  class Coins
    extend TonSdkRuby
    include TonSdkRuby

    attr_reader :value, :decimals, :multiplier

    def initialize(value, options = {})
      is_nano = options[:is_nano] || false
      decimals = options[:decimals] || 9

      value = value.to_s
      Coins.check_coins_type(value)
      Coins.check_coins_decimals(decimals)

      decimal = BigDecimal(value)

      if decimal.dp > decimals
        raise "Invalid Coins value, decimals places \"#{decimal.dp}\" can't be greater than selected \"#{decimals}\""
      end

      @decimals = decimals
      @multiplier = (1 * 10) ** @decimals
      @value = is_nano ? decimal : decimal * @multiplier
    end

    def self.from_nano(value, decimals = 9)
      check_coins_type(value)
      check_coins_decimals(decimals)

      Coins.new(value, is_nano: true, decimals: decimals)
    end

    def add(coins)
      Coins.check_coins(coins)
      Coins.compare_coins_decimals(self, coins)

      @value += coins.value

      self
    end

    def sub(coins)
      Coins.check_coins(coins)
      Coins.compare_coins_decimals(self, coins)

      @value -= coins.value

      self
    end

    def mul(value)
      Coins.check_value(value)
      Coins.check_convertability(value)

      multiplier = value.to_s

      @value *= multiplier.to_i

      self
    end

    def div(value)
      Coins.check_value(value)
      Coins.check_convertibility(value)

      divider = value.to_s

      @value /= divider.to_i

      self
    end

    def eq(coins)
      Coins.check_coins(coins)
      Coins.compare_coins_decimals(self, coins)

      @value == coins.value
    end

    def gt(coins)
      Coins.check_coins(coins)
      Coins.compare_coins_decimals(self, coins)

      @value > coins.value
    end

    def gte(coins)
      Coins.check_coins(coins)
      Coins.compare_coins_decimals(self, coins)

      @value >= coins.value
    end

    def lt(coins)
      Coins.check_coins(coins)
      Coins.compare_coins_decimals(self, coins)

      @value < coins.value
    end

    def lte(coins)
      Coins.check_coins(coins)
      Coins.compare_coins_decimals(self, coins)

      @value <= coins.value
    end

    def negative?
      @value.negative?
    end

    def positive?
      @value.positive?
    end

    def zero?
      @value.zero?
    end

    def to_s
      value = (@value / @multiplier.to_f).round(@decimals).to_s

      # Remove all trailing zeroes
      coins = value.sub(/\.0{#{@decimals}}$/, '').sub(/(\.[0-9]*?[0-9])0+$/, '\1')

      coins
    end

    def to_nano
      @value.to_i
    end


    private

    def self.check_coins_type(value)
      raise 'Invalid Coins value' unless valid?(value) && convertable?(value)
      raise 'Invalid Coins value' if coins?(value)
    end

    def self.check_coins_decimals(decimals)
      raise 'Invalid decimals value, must be 0-18' if decimals < 0 || decimals > 18
    end

    def self.compare_coins_decimals(a, b)
      raise "Can't perform mathematical operation of Coins with different decimals" if a.decimals != b.decimals
    end

    def self.check_value(value)
      raise 'Invalid value' unless valid?(value)
    end

    def self.check_coins(value)
      raise 'Invalid value' unless coins?(value)
    end

    def self.check_convertability(value)
      raise 'Invalid value' unless convertable?(value)
    end

    def self.valid?(value)
      value.class == String || value.class == Integer
    end

    def self.coins?(value)
      value.is_a?(Coins)
    end

    def self.convertable?(value)
      begin
        BigDecimal(value.to_s)
        true
      rescue StandardError
        false
      end
    end
  end
end

class BigDecimal
  def dp
    digits_after_comma = self.to_s("F").split(".").last
    return 0 if digits_after_comma == '0'
    digits_after_comma.size
  end
end
