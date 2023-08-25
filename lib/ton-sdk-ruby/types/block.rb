module TonSdkRuby
  class TickTockOptions
    attr_accessor :tick, :tock

    def initialize(tick, tock)
      @tick = tick
      @tock = tock
    end
  end

  class SimpleLibOptions
    attr_accessor :public, :root

    def initialize(public_value, root_value)
      @public = public_value
      @root = root_value
    end
  end

  class TickTock
    attr_reader :data, :cell

    def initialize(options)
      @data = options
      @cell = Builder.new
                     .store_bit(options[:tick])
                     .store_bit(options[:tock])
                     .cell
    end

    def self.parse(cs)
      tick = cs.load_bit == 1
      tock = cs.load_bit == 1
      options = { tick: tick, tock: tock }
      new(options)
    end
  end

  class SimpleLib
    attr_reader :data, :cell

    def initialize(options)
      @data = options
      @cell = Builder.new
                     .store_bit(options[:public])
                     .store_ref(options[:root])
                     .cell
    end

    def self.parse(cs)
      simple_lib = SimpleLib.new(
        public: cs.load_bit == 1,
        root: cs.load_ref
      )
      simple_lib
    end
  end

  class StateInitOptions
    attr_accessor :split_depth, :special, :code, :data, :library

    def initialize(options = {})
      @split_depth = options[:split_depth]
      @special = options[:special]
      @code = options[:code]
      @data = options[:data]
      @library = options[:library]
    end
  end

  class StateInit
    attr_reader :data, :cell

    def initialize(state_init_options)
      @data = state_init_options

      b = Builder.new

      # split_depth
      if data.split_depth
        b.store_uint(data.split_depth, 5)
      else
        b.store_bit(0)
      end

      # special
      b.store_maybe_ref(data.special&.cell)
      # code
      b.store_maybe_ref(data.code)
      b.store_maybe_ref(data.data)
      b.store_dict(data.library)

      @cell = b.cell
    end

    def self.parse(cs)
      options = StateInitOptions.new()

      options.split_depth = cs.load_bit.nonzero? ? cs.load_uint(5) : nil
      options.special = TickTock.parse(cs) if cs.load_bit.nonzero?
      options.code = cs.load_ref if cs.load_bit.nonzero?
      options.data = cs.load_ref if cs.load_bit.nonzero?

      deserializers = {
        key: ->(k) { k },
        value: ->(v) { SimpleLib.parse(Slice.parse(v.parse)) }
      }

      options.library = HashmapE.parse(256, cs, deserializers)

      new(options)
    end
  end

  class IntMsgInfo
    attr_accessor :tag, :ihr_disabled, :bounce, :bounced, :src, :dest, :value,
                  :ihr_fee, :fwd_fee, :created_lt, :created_at

    def initialize(options = {})
      @tag = 'int_msg_info'
      @ihr_disabled = options[:ihr_disabled]
      @bounce = options[:bounce]
      @bounced = options[:bounced]
      @src = options[:src]
      @dest = options[:dest]
      @value = options[:value]
      @ihr_fee = options[:ihr_fee]
      @fwd_fee = options[:fwd_fee]
      @created_lt = options[:created_lt]
      @created_at = options[:created_at]
    end
  end

  class ExtInMsgInfo
    attr_accessor :tag, :src, :dest, :import_fee

    def initialize(options = {})
      @tag = 'ext_in_msg_info'
      @src = options[:src]
      @dest = options[:dest]
      @import_fee = options[:import_fee]
    end
  end

  class CommonMsgInfo
    attr_reader :data, :cell

    def initialize(data)
      case data.tag
      when 'int_msg_info'
        int_msg_info(data)
      when 'ext_in_msg_info'
        ext_in_msg_info(data)
      else
        raise 'OutAction: unexpected tag'
      end
    end

    private

    def int_msg_info(data)
      b = Builder.new
                 .store_bits([0]) # int_msg_info$0
                 .store_bit(data.ihr_disabled || false) # ihr_disabled:Bool
                 .store_bit(data.bounce) # bounce:Bool
                 .store_bit(data.bounced || false) # bounced:Bool
                 .store_address(data.src || Address::NONE) # src:MsgAddressInt
                 .store_address(data.dest) # dest:MsgAddressInt
                 .store_coins(data.value) # value: -> grams:Grams
                 .store_bit(0) # value: -> other:ExtraCurrencyCollection
                 .store_coins(data.ihr_fee || Coins.new(0)) # ihr_fee:Grams
                 .store_coins(data.fwd_fee || Coins.new(0)) # fwd_fee:Grams
                 .store_uint(data.created_lt || 0, 64) # created_lt:uint64
                 .store_uint(data.created_at || 0, 32) # created_at:uint32

      @data = data
      @cell = b.cell
    end

    def ext_in_msg_info(data)
      b = Builder.new
                 .store_bits([1, 0]) # ext_in_msg_info$10
                 .store_address(data.src || Address::NONE) # src:MsgAddress
                 .store_address(data.dest) # dest:MsgAddressExt
                 .store_coins(data.import_fee || Coins.new(0)) # import_fee:Grams

      @data = data
      @cell = b.cell
    end

    public

    def self.parse(cs)
      frst = cs.load_bit

      if frst == 1
        scnd = cs.load_bit
        raise 'CommonMsgInfo: ext_out_msg_info unimplemented' if scnd == 1

        return new(ExtInMsgInfo.new(
          tag: 'ext_in_msg_info',
          src: cs.load_address,
          dest: cs.load_address,
          import_fee: cs.load_coins
        ))
      end

      if frst == 0
        data = IntMsgInfo.new({
                                tag: 'int_msg_info',
                                ihr_disabled: cs.load_bit == 1,
                                bounce: cs.load_bit == 1,
                                bounced: cs.load_bit == 1,
                                src: cs.load_address,
                                dest: cs.load_address,
                                value: cs.load_coins
                              })

        # TODO: support with ExtraCurrencyCollection
        cs.skip_bits(1)

        data.ihr_fee = cs.load_coins
        data.fwd_fee = cs.load_coins
        data.created_lt = cs.load_uint(64)
        data.created_at = cs.load_uint(32)

        return new(data)
      end

      raise 'CommonMsgInfo: invalid tag'
    end
  end

  class MessageOptions
    attr_accessor :info, :init, :body

    def initialize(options = {})
      @info = options[:info]
      @init = options[:init]
      @body = options[:body]
    end
  end

  class Message
    attr_reader :data, :cell

    def initialize(options)
      @data = options
      b = Builder.new
      b.store_slice(data.info.cell.parse) # info:CommonMsgInfo

      # init:(Maybe (Either StateInit ^StateInit))
      if data.init
        b.store_bits([1, 0])
        b.store_slice(data.init.cell.parse)
      else
        b.store_bit(0)
      end

      # body:(Either X ^X)
      if data.body
        if (b.bits.length + data.body.bits.length + 1 <= 1023) &&
          (b.refs.length + data.body.refs.length <= 4)
          b.store_bit(0)
          b.store_slice(data.body.parse)
        else
          b.store_bit(1)
          b.store_ref(data.body)
        end
      else
        b.store_bit(0)
      end

      @cell = b.cell
    end

    def self.parse(cs)
      data = {}
      data.info = CommonMsgInfo.parse(cs)

      if cs.load_bit
        init = cs.load_bit ? cs.load_ref.parse : cs
        data.init = StateInit.parse(init)
      end

      if cs.load_bit
        data.body = cs.load_ref
      else
        data.body = Builder.new.store_slice(cs).cell
      end

      new(data)
    end
  end

  class ActionSendMsg
    attr_reader :tag, :mode, :out_msg

    def initialize(options)
      @tag = 'action_send_msg'
      @mode = options[:mode]
      @out_msg = options[:out_msg]
    end
  end

  class ActionSetCode
    attr_reader :tag, :new_code

    def initialize(options)
      @tag = 'action_set_code'
      @new_code = options[:new_code]
    end
  end

  class OutAction
    def initialize(data)
      case data.tag
      when 'action_send_msg' then action_send_msg(data)
      when 'action_set_code' then action_set_code(data)
      else
        raise 'OutAction: unexpected tag'
      end
    end

    private def action_send_msg(data)
      b = Builder.new
      b.store_uint(0x0ec3c86d, 32)
      b.store_uint(data.mode, 8)
      b.store_ref(data.out_msg.cell)
      @data = data
      @cell = b.cell
    end

    private def action_set_code(data)
      b = Builder.new
      b.store_uint(0xad4de08e, 32)
      b.store_ref(data.new_code)
      @data = data
      @cell = b.cell
    end

    def self.parse(cs)
      tag = cs.load_uint(32)
      data = {}

      case tag
      when 0x0ec3c86d # action_send_msg
        mode = cs.load_uint(8)
        out_msg = cs.load_ref.parse
        data = ActionSendMsg.new({ tag: 'action_send_msg', mode: mode, out_msg: Message.parse(out_msg) })
      when 0xad4de08e # action_set_code
        data = ActionSetCode.new({ tag: 'action_set_code', new_code: cs.load_ref })
      else
        raise 'OutAction: unexpected tag'
      end

      OutAction.new(data)
    end

    attr_reader :data, :cell
  end

  class OutListOptions
    attr_reader :actions

    def initialize(options)
      @actions = options[:actions]
    end
  end

  class OutList

    attr_reader :cell, :data
    def initialize(action)
      @data = action
      cur = Builder.new.cell

      data.actions.each do |a|
        cur = Builder.new
                      .store_ref(cur)
                      .store_slice(a.cell.parse)
                      .cell
      end

      @cell = cur
    end
  end
end