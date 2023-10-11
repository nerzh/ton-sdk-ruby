module TonSdkRuby
  class Provider
    extend TonSdkRuby

    attr_accessor :provider

    def initialize(provider)
      @provider = provider
    end

    def get_address_information(address)
      provider.get_address_information(address)
    end

    def get_extended_address_information(address)
      provider.get_extended_address_information(address)
    end

    def get_address_balance(address)
      provider.get_address_balance(address)
    end

    def get_token_data(address)
      provider.get_token_data(address)
    end

    def get_transactions(address, archival, limit, lt, hash, to_lt)
      provider.get_transactions(address, archival, limit, lt, hash, to_lt)
    end

    def run_get_method(address, method, stack = [])
      provider.run_get_method(address, method, stack)
    end

    def send_boc(boc)
      provider.send_boc(boc)
    end

    def estimate_fee(address, body, init_code, init_data, ignore_chksig = false)
      provider.estimate_fee(address, body, init_code, init_data, ignore_chksig)
    end
  end
end
