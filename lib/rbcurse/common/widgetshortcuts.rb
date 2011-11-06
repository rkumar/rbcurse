# ------------------------------------------------------------ #
#         File: widgetshortcuts.rb 
#  Description: A common module for shortcuts to create widgets
#               Also, stacks and flows objects
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 05.11.11 - 15:13 
#  Last update: 06.11.11 - 10:57
#  == TODO
#     add multirow comps like textview and textarea, list
#     add blocks that make sense like in app
#     - what if user does not want form attached - app uses useform ot
#       to check for this, if current_object don't add form
#
#     - usage of _position inside means these shortcuts cannot be reused
#     with other positioning systems, we'll be cut-pasting forever
#
#  == CHANGES
# ------------------------------------------------------------ #
#

# what is the real purpose of the shortcuts, is it to avoid putting nil
# for form there if not required.
# Or is it positioning, such as in a stack. or just a method ?
module RubyCurses
  module WidgetShortcuts
    class Ws
      attr_reader :config
      def initialize config={}
        @config = config
      end
      def [](sym)
        @config[sym]
      end
      def []=(sym, val)
        @config[sym] = val
      end
    end
    class WsStack < Ws; end
    class WsFlow < Ws; end
    def widget_shortcuts_init
      @_ws_app_row = @_ws_app_col = 0
      @_ws_active = []
      @_ws_components = []
      @variables = {}
    end
    def field config={}, &block 
      w = Field.new nil, config #, &block
      _position w
      if block
        w.bind(:CHANGED, &block)
      end
      return w
    end
    def label config={}, &block 
      w = Label.new nil, config, &block
      _position w
    end
    def blank
      label :text => ""
    end
    def line config={}
      #horizontal line TODO
      #row = config[:row] || @app_row
      #width = config[:width] || 20
      #_position config
      #col = config[:col] || 1
      #@color_pair = config[:color_pair] || $datacolor
      #@attrib = config[:attrib] || Ncurses::A_NORMAL
      #@window.attron(Ncurses.COLOR_PAIR(@color_pair) | @attrib)
      #@window.mvwhline( row, col, FFI::NCurses::ACS_HLINE, width)
      #@window.attron(Ncurses.COLOR_PAIR(@color_pair) | @attrib)
    end
    def check config={}, &block
      w = CheckBox.new nil, config #, &block
      _position w
      if block
        w.bind(:PRESS, &block)
      end
      return w
    end
    def button config={}, &block
      w = Button.new nil, config #, &block
      _position w
      if block
        w.bind(:PRESS, &block)
      end
      return w
    end
    def radio config={}, &block
      a = config[:group]
      # should we not check for a nil
      if @variables.has_key? a
        v = @variables[a]
      else
        v = Variable.new
        @variables[a] = v
      end
      config[:variable] = v
      config.delete(:group)
      w = RadioButton.new nil, config #, &block
      _position w
      if block
        w.bind(:PRESS, &block)
      end
      return w
    end
    # editable text area
    def textarea config={}, &block
      require 'rbcurse/rtextarea'
      # TODO confirm events many more
      events = [ :CHANGE,  :LEAVE, :ENTER ]
      block_event = events[0]
      #_process_args args, config, block_event, events
      #config[:width] = config[:display_length] unless config.has_key? :width
      # if no width given, expand to flows width
      #config[:width] ||= @stack.last.width if @stack.last
      useform = nil
      #useform = @form if @current_object.empty?
      w = TextArea.new useform, config
      w.width = :expand unless w.width
      w.height ||= 8 # TODO
      _position(w)
      # need to expand to stack's width or flows itemwidth if given
      if block
        w.bind(block_event, &block)
      end
      return w
    end
    def textview config={}, &block
      require 'rbcurse/rtextview'
      events = [ :LEAVE, :ENTER ]
      block_event = events[0]
      #_process_args args, config, block_event, events
      #config[:width] = config[:display_length] unless config.has_key? :width
      # if no width given, expand to flows width
      #config[:width] ||= @stack.last.width if @stack.last
      useform = nil
      #useform = @form if @current_object.empty?
      w = TextView.new useform, config
      w.width = :expand unless w.width
      w.height ||= 8 # TODO
      _position(w)
      # need to expand to stack's width or flows itemwidth if given
      if block
        w.bind(block_event, &block)
      end
      return w
    end
    def _position w
      cur = @_ws_active.last
      # this is outside any stack or flow, so we do the minimal
      # user should specify row and col
      unless cur
        w.row ||= 0
        w.col ||= 0
        $log.debug "XXX:  LABEL #{w.row} , #{w.col} "
        w.set_form @form if @form # temporary,, only set if not inside an object FIXME
        if w.width == :expand
          w.width = FFI::NCurses.COLS-0 # or take windows width since this could be in a message box
        end
        if w.height == :expand
          # take from current row, and not zero  FIXME
          w.height = FFI::NCurses.LINES-0 # or take windows width since this could be in a message box
        end
        return
      end
      r = cur[:row] || 0
      c = cur[:col] || 0
      w.row = r
      w.col = c
      if cur.is_a? WsStack
        r += w.height || 1
        cur[:row] = r
      else
        wid = cur[:item_width] || w.width || 10
        c += wid + 1
        cur[:col] = c
      end
      if w.width == :expand
        w.width = cur[:width] or raise "Width not known for stack"
      end
      if w.height == :expand
        w.height = cur[:height] or raise "height not known for flow"
      end
      w.color   ||= cur[:color]
      w.bgcolor ||= cur[:bgcolor]
      w.set_form @form if @form # temporary
      @_ws_components << w
      cur[:components] << w
    end
    # make it as simple as possible, don't try to be intelligent or
    # clever, put as much on the user 
    def stack config={}, &block
      s = WsStack.new config
      _configure s
      @_ws_active << s
      yield_or_eval &block if block_given?
      @_ws_active.pop 
      
      # ---- stack is finished now
      last = @_ws_active.last
      if last 
        case last
        when WsStack
        when WsFlow
          last[:col] += last[:item_width] || 0 
          # this tries to set height of outer flow based on highest row
          # printed, however that does not account for height of object,
          # so user should give a height to the flow.
          last[:height] = s[:row] if s[:row] > (last[:height]||0)
          $log.debug "XXX: STACK setting col to #{s[:col]} "
        end
      end

    end
    #
    # item_width - width to use per item 
    #   but the item width may apply to stacks inside not to items
    def flow config={}, &block
      s = WsFlow.new config
      _configure s
      @_ws_active << s
      yield_or_eval &block if block_given?
      @_ws_active.pop 
      last = @_ws_active.last
      if last 
        case last
        when WsStack
          if s[:height]
            last[:row] += s[:height] 
          else
            #last[:row] += last[:highest_row]  
            last[:row] += 1
          end
        when WsFlow
          last[:col] += last[:item_width] || 0 
        end
      end
    end
    # flow and stack could have a border option
    def box config={}, &block
      require 'rbcurse/extras/box'
      # take current stacks row and col
      # advance row by one and col by one
      # at end note row and advance by one
      # draw a box around using these coordinates. width should be
      # provided unless we have item width or something.
      last = @_ws_active.last
      if last
        r = last[:row]
        c = last[:col]
        config[:row] = r
        config[:col] = c
        last[:row] += config[:margin_top] || 1
        last[:col] += config[:margin_left] || 1
        _box = Box.new @form, config # needs to be created first or will overwrite area after others painted
        yield_or_eval &block if block_given?
        h = config[:height] || last[:height] || (last[:row] - r)
        h = 2 if h < 2
        w = config[:width] || last[:width] || 15 # tmp
        case last
        when WsFlow
          w = last[:col]
        when WsStack
          #h += 1
        end
        config[:row] = r
        config[:col] = c
        config[:height] = h
        config[:width] = w
        _box.row r
        _box.col c
        _box.height h
        _box.width w
        last[:row] += 1
        last[:col] += 1 # ??? XXX if flow we need to increment properly or not ?
      end
    end
    def _configure s
      s[:row] ||= 0
      s[:col] ||= 0
      s[:row] += (s[:margin_top] || 0)
      s[:col] += (s[:margin_left] || 0)
      s[:width] = FFI::NCurses.COLS if s[:width] == :expand
      last = @_ws_active.last
      if last
        if last.is_a? WsStack
          s[:row] += (last[:row] || 0)
          s[:col] += (last[:col] || 0)  
        else
          s[:row] += (last[:row] || 0)
          s[:col] += (last[:col] || 0)  # we are updating with item_width as each st finishes
          s[:width] ||= last[:item_width] # 
        end
      end
      s[:components] = []
    end



  end
end
