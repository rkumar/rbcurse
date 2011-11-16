## this class allows us to do multiple key mappings such as emacs
# See the example keytest.rb
# However, integrating this into our library seems a little difficult now
# since each widget handles keys and often there are heirachies of widgets.
# However, this being a terminal app, mouseless, we really need to make it key-friendly.
require 'rbcurse/orderedhash'
class Mapper
  attr_reader :keymap
  attr_reader :view
  attr_accessor :mode
  attr_reader :keys
  def initialize handler
    #@handler = handler
    @view = handler       # caller program
    @keys = {}
    @mode = nil  # used when defining
    @pendingkeys = nil
    @prevkey = nil   # in case of a key sequence such as C-x C-c, will have C-x
    @arg = nil # regex matched this key.
  end
  def let mode, &block
    h = OrderedHash.new
    @keys[mode] = h
    @mode = mode
    instance_eval(&block)
    $log.debug("KEYS: #{@keys[mode].inspect}")
  end

  ## mapping keys to blocks or symbols
  # 2010-02-23 19:17 added check for string, so no required to use getbyte everywhere, esp for existing app
  # However, this means that we can't map an actual string, which we may want to for commands
  # which cuold be passed outside keys, or as aliases.
  def map(*args, &block)
    if block_given?

      # We check for cases like C-x C-c etc. Only 2 levels.
      #args = arg.split(/ +/)
      arg0 = args[0]
      arg0 = args[0].getbyte(0) if args[0].class.to_s == 'String'
      if args.length == 2
        arg1 = args[1]
        arg1 = args[1].getbyte(0) if args[1].class.to_s == 'String'
        $log.debug "  KEY2 #{args[0]} , #{args[0].class},  #{args[1]} , #{args[1].class} "
        @keys[@mode][arg0] ||= OrderedHash.new
        @keys[@mode][arg0][arg1]=block
      else
        # single key or control key
        $log.debug "  KEY #{args[0]} , #{args[0].class} "
        @keys[@mode][arg0]=block
      end
    else
       #no block, last arg shold be a symbol
       symb = args.pop
       raise "If block not passed, last arg should be a method symbol" if !symb.is_a? Symbol
       arg0 = args[0]
       arg0 = args[0].getbyte(0) if args[0].class.to_s == 'String'
       if args.length == 2
         arg1 = args[1]
         arg1 = args[1].getbyte(0) if args[1].class.to_s == 'String'
         @keys[@mode][arg0] ||= OrderedHash.new
         @keys[@mode][arg0][arg1]=symb
       else
         # single key or control key
         @keys[@mode][arg0]=symb
       end
    end
  end

  ## manages key pressing
  # takes care of multiple key combos too
  def press key
    #$log.debug("press Got: #{key}")
    # for a double key combination such as C-x C-c this has the set of pending keys to check against
    if @pendingkeys != nil
      blk = @pendingkeys[key]
    else
      # this is the regular single key mode
      #blk = @keys[@view.mode][key]
      blk = match(key)
    end
    # this means this key expects more keys to follow such as C-x could
    if blk.is_a? OrderedHash
      @pendingkeys = blk
      @prevkey = key
      return
    end
    if blk.nil? # this should go up XXX
      if !@pendingkeys.nil?
        # this error message to be modified if using numeric keys -- need to convert to char
        view.info("%p not valid in %p. Try: #{@pendingkeys.keys.join(', ')}" % [key, @prevkey]) # XXX
      else
        view.info("%p not valid in %p. " % [key, @view.mode]) 
      end
      return
    end
    # call the block or symbol - our user defined key mappings use symbols
    if blk.is_a? Symbol
      @view.send(blk)
    else
      blk.call
    end
    @prevkey = nil
    @pendingkeys = nil
  end
  def match key
       #$log.debug "MATCH #{key} "
      #blk = @keys[@view.mode][key]
    @keys[@view.mode].each_pair do |k,v|
     #$log.debug "LOOP #{k.class}, #{k}, #{v} "
      case k.class.to_s
      when "String"
        return v if k == key
      when "Fixnum" # for keyboard2
     #$log.debug "FIXNUM LOOP #{k.class}, #{k}, #{v} "
        return v if k == key
      when "Regexp"
#       $log.debug "REGEX #key , #k, #{k.match(key)}"
        key1 = key.chr if key.is_a? Fixnum
        if !k.match(key1).nil?
          @arg = key1
          return v 
        end
      else
        $log.error "MATCH: Unhandled class #{k.class} "
      end
    end
       $log.debug "MATCH #{key} ret nil "
    return nil
  end
end
