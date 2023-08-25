# ton-sdk-ruby

Ruby SDK for interaction with TON (The Open Network) blockchain

## Installation

Install ton-sdk-ruby:

- `gem install ton-sdk-ruby`

###### ⚠️ You might also find it beneficial to make use of the [ton-sdk-ruby-smc](https://github.com/nerzh/ton-sdk-ruby-smc) package, which implements basic wrappers for TON smart contracts (please be aware that ton-sdk-ruby-smc is distributed under the LGPL-3.0 license).

## Example

```ruby
require 'ton-sdk-ruby'

class Ton
  include TonSdkRuby
  
  def main
    # Init address from string
    tf = Address.new("EQCD39VS5jcptHL8vMjEXrzGaRcCVYto7HUn4bpAOg8xqB2N")

    # Init and fill the builder
    b = Builder.new
    b.store_uint(200, 30)
    b.store_address(tf)
    b.store_coins(Coins.new(0.0001))

    # End builder and serialize to boc
    bytes = serialize(b.cell)
    base64 = bytes_to_base64(bytes)

    p 'boc in base64 format:', base64, ''

    # Deserialize base64 boc 
    cell = deserialize(base64_to_bytes(base64)).first

    # Parse cell into slice
    cs = cell.parse

    # Load and print values
    p cs.load_uint(30)
    p cs.load_address.to_s
    p cs.load_coins
  end
end

Ton.new.main
```

## License

MIT

## Mentions

I would like to thank [cryshado](https://github.com/cryshado) for their valuable advice and help in developing this library.
