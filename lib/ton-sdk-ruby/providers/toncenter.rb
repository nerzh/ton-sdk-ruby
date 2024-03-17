module TonSdkRuby

  class TonCenter
    extend TonSdkRuby
    include TonSdkRuby

    URL = 'https://toncenter.com/api/v2/jsonRPC'
    attr_accessor :api_key, :url

    def initialize(url = nil, api_key)
      @url = url || URL
      @api_key = api_key
    end

    def send_request(metod, params)
      headers = {
        "X-API-Key": api_key
      }
      body = jrpc_wrap(metod, params)
      read_post_json_from_link(url, body, headers)
    end

    def send_boc(boc)
      send_request('sendBoc', {boc: boc})
    end

    def get_address_information(address)
      send_request('getAddressInformation', {address: address})
    end

    def get_transactions(address, archival, limit, lt, hash, to_lt)
      params = {
        address: address, archival: archival, limit: limit, lt: lt, hash: hash, to_lt: to_lt
      }
      send_request('getTransactions', params)
    end

    def get_extended_address_information(address)
      send_request('getExtendedAddressInformation', {address: address})
    end

    def get_address_balance(address)
      send_request('getAddressBalance', {address: address})
    end

    def get_address_state(address)
      send_request('getAddressState', {address: address})
    end

    def get_token_data(address)
      send_request('getTokenData', {address: address})
    end

    def run_get_method(address, method, stack = [])
      params = {
        address: address, method: method, stack: stack
      }
      send_request('runGetMethod', params)
    end

    def estimate_fee(address, body, init_code, init_data, ignore_chksig = false)
      params = {
        address: address, body: body, init_code: init_code, init_data: init_data, ignore_chksig: ignore_chksig
      }
      send_request('estimateFee', params)
    end

    private
    def jrpc_wrap(method, params = {})
      {
        id: '1',
        jsonrpc: '2.0',
        method: method,
        params: params.compact
      }
    end
  end
end
