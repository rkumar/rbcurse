=begin
  * Name: rwidget: base class and then popup and other derived widgets
  * $Id$
  * Description   
    Some simple light widgets for creating ncurses applications. No reliance on ncurses
    forms and fields.
        I expect to pass through this world but once. Any good therefore that I can do, 
        or any kindness or ablities that I can show to any fellow creature, let me do it now. 
        Let me not defer it or neglect it, for I shall not pass this way again.  
  * Author: rkumar (arunachalesha)
  * Date: 2008-11-19 12:49 
  * License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
TODO 
  - repaint only what is modified
  - save data in a hash when called for.
  - make some methods private/protected
  - Add bottom bar also, perhaps allow it to be displayed on a key so it does not take 
  - Can key bindings be abstracted so they can be inherited /reused.
  - some kind of CSS style sheet.


=end
require 'rubygems'
require 'ncurses'
require 'logger'
#require 'rbcurse/mapper'
require 'rbcurse/colormap'
require 'rbcurse/orderedhash'
require 'rbcurse/io'

module DSL
## others may not want this, if = sent, it creates DSL and sets
  # using this resulted in time lost in bedebugging why some method was not working.
  def OLD_method_missing(sym, *args)
    $log.debug "METHOD MISSING : #{sym} #{self} "
    #if "#{sym}"[-1].chr=="="
    #  sym = "#{sym}"[0..-2]
    #else
    self.class.dsl_accessor sym
    #end
    send(sym, *args)
  end
end
class Module
## others may not want this, sets config, so there's a duplicate hash
  # also creates a attr_writer so you can use =.
  def dsl_accessor(*symbols)
    symbols.each { |sym|
      class_eval %{
        def #{sym}(*val)
          if val.empty?
            @#{sym}
          else
            @#{sym} = val.size == 1 ? val[0] : val
            @config["#{sym}"]=@#{sym}
          end
        end
    attr_writer sym
      }
    }
  end
  def dsl_property(*symbols)
    symbols.each { |sym|
      class_eval %{
        def #{sym}(*val)
          if val.empty?
            @#{sym}
          else
            oldvalue = @#{sym}
            @#{sym} = val.size == 1 ? val[0] : val
            newvalue = @#{sym}
            @config["#{sym}"]=@#{sym}
            if oldvalue != newvalue
              fire_property_change("#{sym}", oldvalue, newvalue)
            end
          end
        end
    #attr_writer sym
        def #{sym}=val
           #{sym}(val)
        end
      }
    }
  end

end

# 2009-10-04 14:13 added RK after suggestion on http://www.ruby-forum.com/topic/196618#856703
# these are for 1.8 compatibility
class Fixnum
   def ord
     self
   end
## mostly for control and meta characters
   def getbyte(n)
     self
   end
end unless "a"[0] == "a"

include Ncurses
module RubyCurses
  extend self
  include ColorMap
    class FieldValidationException < RuntimeError
    end
    module Utils
      ## this is the numeric argument used to repeat and action by repeatm()
      $multiplier = 0

      # 2010-03-04 18:01 
      ## this may come in handy for methods to know whether they are inside a batch action or not
      # e.g. a single call of foo() may set a var, a repeated call of foo() may append to var
      $inside_multiplier_action = true

      ## 
      # wraps text given max length, puts newlines in it.
      # it does not take into account existing newlines
      # Some classes have @maxlen or display_length which may be passed as the second parameter
      def wrap_text(txt, max )
        txt.gsub(/(.{1,#{max}})( +|$\n?)|(.{1,#{max}})/,
                 "\\1\\3\n") 
      end
      def clean_string! content
          content.chomp! # don't display newline
          content.gsub!(/[\t\n]/, '  ') # don't display tab
          content.gsub!(/[^[:print:]]/, '')  # don't display non print characters
          content
      end
      # needs to move to a keystroke class
      def keycode_tos keycode
        case keycode
        when 33..126
          return keycode.chr
        when ?\C-a.getbyte(0) .. ?\C-z.getbyte(0)
          return "C-" + (keycode + ?a.getbyte(0) -1).chr 
        when ?\M-A.getbyte(0)..?\M-z.getbyte(0)
          return "M-"+ (keycode - 128).chr
        when ?\M-\C-A.getbyte(0)..?\M-\C-Z.getbyte(0)
          return "M-C-"+ (keycode - 32).chr
        when ?\M-0.getbyte(0)..?\M-9.getbyte(0)
          return "M-"+ (keycode-?\M-0.getbyte(0)).to_s
        when 32
          return "Space"
        when 27
          return "Esc"
        when ?\C-].getbyte(0)
          return "C-]"
        when 258
          return "down"
        when 259
          return "up"
        when 260
          return "left"
        when 261
          return "right"
        when KEY_F1..KEY_F12
          return "F"+ (keycode-264).to_s
        when 330
          return "delete"
        when 127
          return "bs"
        when 353
          return "btab"
        when 481
          return "M-S-tab"
        when 393..402
          return "M-F"+ (keycode-392).to_s
        when 0
          return "C-space" # i hope this is correct, just guessing
        else
          others=[?\M--,?\M-+,?\M-=,?\M-',?\M-",?\M-;,?\M-:,?\M-\,, ?\M-.,?\M-<,?\M->,?\M-?,?\M-/]
          others.collect! {|x| x.getbyte(0)  }  ## added 2009-10-04 14:25 for 1.9
          s_others=%w[M-- M-+ M-= M-' M-"   M-;   M-:   M-, M-. M-< M-> M-? M-/ ]
          if others.include? keycode
            index =  others.index keycode
            return s_others[index]
          end
          # all else failed
          return keycode.to_s
        end
      end

      def get_color default=$datacolor, color=@color, bgcolor=@bgcolor
        if bgcolor.is_a? String and color.is_a? String
          acolor = ColorMap.get_color(color, bgcolor)
        else
          acolor = default
        end
        return acolor
      end
      ## repeats the given action based on how value of universal numerica argument
      ##+ set using the C-u key. Or in vim-mode using numeric keys
      def repeatm
        $inside_multiplier_action = true
        _multiplier = ( ($multiplier.nil? || $multiplier == 0) ? 1 : $multiplier )
        _multiplier.times { yield }
        $multiplier = 0
        $inside_multiplier_action = false
      end
 
    ##
    # bind an action to a key, required if you create a button which has a hotkey
    # or a field to be focussed on a key, or any other user defined action based on key
    # e.g. bind_key ?\C-x, object, block 
    # added 2009-01-06 19:13 since widgets need to handle keys properly
    #  2010-02-24 12:43 trying to take in multiple key bindings, TODO unbind
    #  TODO add symbol so easy to map from config file or mapping file
    def bind_key keycode, *args, &blk
      @key_handler ||= {}
      if !block_given?
        blk = args.pop
        raise "If block not passed, last arg should be a method symbol" if !blk.is_a? Symbol
        $log.debug " #{@name} bind_key received a symbol #{blk} "
      end
      case keycode
      when String
        keycode = keycode.getbyte(0) #if keycode.class==String ##    1.9 2009-10-05 19:40 
        $log.debug " #{name} Widg String called bind_key BIND #{keycode}, #{keycode_tos(keycode)}  "
        @key_handler[keycode] = blk
      when Array
        # for starters lets try with 2 keys only
        a0 = keycode[0]
        a0 = keycode[0].getbyte(0) if keycode[0].class == String
        a1 = keycode[1]
        a1 = keycode[1].getbyte(0) if keycode[1].class == String
        @key_handler[a0] ||= OrderedHash.new
        @key_handler[a0][a1] = blk
      else
        @key_handler[keycode] = blk
      end
      @key_args ||= {}
      @key_args[keycode] = args
    end
    # e.g. process_key ch, self
    # returns UNHANDLED if no block for it
    # after form handles basic keys, it gives unhandled key to current field, if current field returns
    # unhandled, then it checks this map.
    # added 2009-01-06 19:13 since widgets need to handle keys properly
    # added 2009-01-18 12:58 returns ret val of blk.call
    # so that if block does not handle, the key can still be handled
    # e.g. table last row, last col does not handle, so it will auto go to next field
    #  2010-02-24 13:45 handles 2 key combinations, copied from Form, must be identical in logic
    #  except maybe for window pointer. TODO not tested
    def _process_key keycode, object, window
      return :UNHANDLED if @key_handler.nil?
      blk = @key_handler[keycode]
      return :UNHANDLED if blk.nil?
      if blk.is_a? OrderedHash
          ch = window.getch
          if ch < 0 || ch > 255
            #next
            return nil
          end
          $log.debug " process_key: got #{keycode} , #{ch} "
          yn = ch.chr
          blk1 = blk[ch]
          return nil if blk1.nil?
          $log.debug " process_key: found block for #{keycode} , #{ch} "
          blk = blk1
      end
      #$log.debug "called process_key #{object}, kc: #{keycode}, args  #{@key_args[keycode]}"
      if blk.is_a? Symbol
        return send(blk, *@key_args[keycode])
      else
        return blk.call object,  *@key_args[keycode]
      end
      #0
    end
    end

    module EventHandler
      ##
      # bind an event to a block, optional args will also be passed when calling
      def bind event, *xargs, &blk
       #$log.debug "#{self} called EventHandler BIND #{event}, args:#{xargs} "
        @handler ||= {}
        @event_args ||= {}
        #@handler[event] = blk
        #@event_args[event] = xargs
        @handler[event] ||= []
        @handler[event] << blk
        @event_args[event] ||= []
        @event_args[event] << xargs
      end
      alias :add_binding :bind   # temporary, needs a proper name to point out that we are adding

      # NOTE: Do we have a way of removing bindings
      # # TODO check if event is valid. Classes need to define what valid event names are
    
      ##
      # Fire all bindings for given event
      # e.g. fire_handler :ENTER, self
      # currently object usually contains self which is perhaps a bit of a waste,
      # could contain an event object with source, and some relevant methods or values
      def fire_handler event, object
        $log.debug " def fire_handler evt:#{event}, o: #{object.class}, hdnler:#{@handler}"
        if !@handler.nil?
        #blk = @handler[event]
          ablk = @handler[event]
          if !ablk.nil?
            aeve = @event_args[event]
            ablk.each_with_index do |blk, ix|
              #$log.debug "#{self} called EventHandler firehander #{@name}, #{event}, obj: #{object},args: #{aeve[ix]}"
              $log.debug "#{self} called EventHandler firehander #{@name}, #{event}"
              blk.call object,  *aeve[ix]
            end
          end # if
        end # if
      end
      ## added on 2009-01-08 00:33 
      # goes with dsl_property
      # Need to inform listeners - done 2010-02-25 23:09 
    def fire_property_change text, oldvalue, newvalue
      #$log.debug " FPC #{self}: #{text} #{oldvalue}, #{newvalue}"
      if @pce.nil?
        @pce = PropertyChangeEvent.new(self, text, oldvalue, newvalue)
      else
        @pce.set( self, text, oldvalue, newvalue)
      end
      fire_handler :PROPERTY_CHANGE, @pce
      @repaint_required = true # this was a hack and shoudl go, someone wanted to set this so it would repaint (viewport line 99 fire_prop
    end

    end # module eventh

    module ConfigSetup
      # private
      def variable_set var, val
        nvar = "@#{var}"
        send("#{var}", val)   # 2009-01-08 01:30 BIG CHANGE calling methods too here.
        #instance_variable_set(nvar, val)   # we should not call this !!! bypassing 
      end
      def configure(*val , &block)
        case val.size
        when 1
          return @config[val[0]]
        when 2
          @config[val[0]] = val[1]
          variable_set(val[0], val[1]) 
        end
        instance_eval &block if block_given?
      end
      ## 
      # returns param from hash. Unused and untested. 
      def cget param
        @config[param]
      end
       # this bypasses our methods and sets directly !
      def config_setup aconfig
        @config = aconfig
        @config.each_pair { |k,v| variable_set(k,v) }
      end
    end # module config
    ##
    # Basic widget class. 
    # NOTE: I may soon remove the config hash. I don't use it and its just making things heavy.
    # Unless someone convinces me otherwise.
  class Widget
    include DSL
    include EventHandler
    include ConfigSetup
    include RubyCurses::Utils
    include Io # added 2010-03-06 13:05 
    dsl_property :text

    # next 3 to be checked if used or not. Copied from TK.
    dsl_property :select_foreground, :select_background  # color init_pair
    dsl_property :highlight_foreground, :highlight_background  # color init_pair
    dsl_property :disabled_foreground, :disabled_background  # color init_pair

    # FIXME is enabled used?
    dsl_accessor :focusable, :enabled # boolean
    dsl_property :row, :col            # location of object
    dsl_property :color, :bgcolor      # normal foreground and background
    dsl_property :attr                 # attribute bold, normal, reverse
    dsl_accessor :name                 # name to refr to or recall object by_name
    attr_accessor :id #, :zorder
    attr_accessor :curpos              # cursor position inside object - column, not row.
    attr_reader  :config             # COULD GET AXED SOON NOTE
    attr_accessor  :form              # made accessor 2008-11-27 22:32 so menu can set
    attr_accessor :state              # normal, selected, highlighted
    attr_reader  :row_offset, :col_offset # where should the cursor be placed to start with
    dsl_property :visible # boolean     # 2008-12-09 11:29 
    #attr_accessor :modified          # boolean, value modified or not (moved from field 2009-01-18 00:14 )
    dsl_accessor :help_text          # added 2009-01-22 17:41 can be used for status/tooltips

    dsl_property :preferred_width  # added 2009-10-28 13:40 for splitpanes and better resizing
    dsl_property :preferred_height  # added 2009-10-28 13:40 for splitpanes and better resizing
    dsl_property :min_width  # added 2009-10-28 13:40 for splitpanes and better resizing
    dsl_property :min_height  # added 2009-10-28 13:40 for splitpanes and better resizing

    ## 2010-01-05 13:27 create buffer conditionally, if enclosing component asks. Needs to be passed down
    ##+ to further children or editor components. Default false.
    attr_accessor  :should_create_buffer              # added  2010-01-05 13:16 BUFFERED, trying to create buffersonly where required.
    
    ## I think parent_form was not a good idea since i can't add parent widget offsets
    ##+ thus we should use parent_comp and push up.
    attr_accessor :parent_component  # added 2010-01-12 23:28 BUFFERED - to bubble up
    # tired of getting the cursor wrong and guessing, i am now going to try to get absolute
    # coordinates - 2010-02-07 20:17 this should be updated by parent.
    attr_accessor :ext_col_offset, :ext_row_offset # 2010-02-07 20:16  to get abs position for cursor
    #attr_accessor :manages_cursor # does this widget manage cursor, or should form handle it 2010-02-07 20:54 
    attr_accessor :rows_panned # moved from form, how many rows scrolled.panned 2010-02-11 15:26 
    attr_accessor :cols_panned # moved from form, how many cols scrolled.panned 2010-02-11 15:26 

    def initialize form, aconfig={}, &block
      @form = form
      @bgcolor ||=  "black" # 0
      @row_offset = @col_offset = 0
      @ext_row_offset = @ext_col_offset = 0 # 2010-02-07 20:18 
      @state = :NORMAL
      @color ||= "white" # $datacolor
      @attr = nil
      @handler = {}
      @event_args = {}
      config_setup aconfig # @config.each_pair { |k,v| variable_set(k,v) }
      instance_eval &block if block_given?
  #    @id = form.add_widget(self) if !form.nil? and form.respond_to? :add_widget
      set_form(form) unless form.nil? 
    end
    def init_vars
      # just in case anyone does a super. Not putting anything here
      # since i don't want anyone accidentally overriding
      @buffer_modified = false 
      #@manages_cursor = false # form should manage it, I will pass row and col to it. XXX ?
    end

    # modified
    ##
    # typically read will be overridden to check if value changed from what it was on enter.
    # getter and setter for modified (added 2009-01-18 12:31 )
    def modified?
      @modified
    end
    def set_modified tf=true
      @modified = tf
      @form.modified = true if tf
    end
    alias :modified :set_modified
    ##
    # getter and setter for text_variable
    def text_variable(*val)
      if val.empty?
        @text_variable
      else
        @text_variable = val[0] 
        $log.debug " GOING TO CALL ADD DELPENDENT #{self}"
        @text_variable.add_dependent(self)
      end
    end

    ## got left out by mistake 2008-11-26 20:20 
    def on_enter
      fire_handler :ENTER, self
    end
    ## got left out by mistake 2008-11-26 20:20 
    def on_leave
      fire_handler :LEAVE, self
    end
    ## 
    # @return row and col of a widget where painting data actually starts
    # row and col is where a widget starts. offsets usually take into account borders.
    # the offsets typically are where the cursor should be positioned inside, upon on_enter.
    def rowcol
    # $log.debug "widgte rowcol : #{@row+@row_offset}, #{@col+@col_offset}"
      return @row+@row_offset, @col+@col_offset
    end
    ## return the value of the widget.
    #  In cases where selection is possible, should return selected value/s
    def getvalue
      @text_variable && @text_variable.value || @text
    end
    ##
    # Am making a separate method since often value for print differs from actual value
    def getvalue_for_paint
      getvalue
    end
    ##
    # default repaint method. Called by form for all widgets.
    def repaint
        r,c = rowcol
        $log.debug("widget repaint : r:#{r} c:#{c} col:#{@color}" )
        value = getvalue_for_paint
        len = @display_length || value.length
        if @bgcolor.is_a? String and @color.is_a? String
          acolor = ColorMap.get_color(@color, @bgcolor)
        else
          acolor = $datacolor
        end
        @graphic.printstring r, c, "%-*s" % [len, value], acolor, @attr
        # next line should be in same color but only have @att so we can change att is nec
        #@form.window.mvchgat(y=r, x=c, max=len, Ncurses::A_NORMAL, @bgcolor, nil)
        @buffer_modified = true # required for form to call buffer_to_screen
    end

    def destroy
      $log.debug "DESTROY : widget #{@name} "
      panel = @window.panel
      Ncurses::Panel.del_panel(panel) if !panel.nil?   
      @window.delwin if !@window.nil?
    end
    # @deprecated pls call windows method
    def printstring(win, r,c,string, color, att = Ncurses::A_NORMAL)

      att = Ncurses::A_NORMAL if att.nil?
      case att.to_s.downcase
      when 'underline'
        att = Ncurses::A_UNDERLINE
        $log.debug "UL att #{att}"
      when 'bold'
        att = Ncurses::A_BOLD
      when 'blink'
        att = Ncurses::A_BLINK
      when 'reverse'
        att = Ncurses::A_REVERSE
      else
        att = Ncurses::A_NORMAL
      end
      #$log.debug "att #{att}"

      #att = bold ? Ncurses::A_BLINK|Ncurses::A_BOLD : Ncurses::A_NORMAL
      #     att = bold ? Ncurses::A_BOLD : Ncurses::A_NORMAL
      win.attron(Ncurses.COLOR_PAIR(color) | att)
      win.mvprintw(r, c, "%s", string);
      win.attroff(Ncurses.COLOR_PAIR(color) | att)
    end
    # in those rare cases where we create widget without a form, and later give it to 
    # some other program which sets the form. Dirty, we should perhaps create widgets
    # without forms, and add explicitly. 
    def set_form form
      raise "Form is nil in set_form" if form.nil?
      @form = form
      @id = form.add_widget(self) if !form.nil? and form.respond_to? :add_widget
      # 2009-10-29 15:04 use form.window, unless buffer created
      # should not use form.window so explicitly everywhere.
      # added 2009-12-27 20:05 BUFFERED in case child object needs a form.
      # We don;t wish to overwrite the graphic object
      if @graphic.nil?
        $log.debug " setting graphic to form window for #{self.class}, #{form} "
        @graphic = form.window unless form.nil? # use screen for writing, not buffer
      end
    end
    # puts cursor on correct row.
    def set_form_row
      raise "empty todo widget"
    #  @form.row = @row + 1 + @winrow
      @form.row = @row + 1 
    end
    # set cursor on correct column, widget
    # Ideally, this should be overriden, as it is not likely to be correct.
    def set_form_col col1=@curpos
      @curpos = col1 || 0 # 2010-01-14 21:02 
      #@form.col = @col + @col_offset + @curpos
      c = @col + @col_offset + @curpos
      $log.debug " #{@name} widget WARNING super set_form_col #{c}, #{@form} "
      setrowcol nil, c
    end
    def hide
      @visible = false
    end
    def show
      @visible = true
    end
    def remove
      @form.remove_widget(self)
    end
    def move row, col
      @row = row
      @col = col
    end
    ##
    # moves focus to this field
    # XXX we must look into running on_leave of previous field
    def focus
      return if !@focusable
      if @form.validate_field != -1
        @form.select_field @id
      end
    end
    def get_color default=$datacolor, _color=@color, _bgcolor=@bgcolor
      if _bgcolor.is_a? String and _color.is_a? String
        acolor = ColorMap.get_color(_color, _bgcolor)
      else
        acolor = default
      end
      return acolor
    end
    ##
    # bind an action to a key, required if you create a button which has a hotkey
    # or a field to be focussed on a key, or any other user defined action based on key
    # e.g. bind_key ?\C-x, object, block 
    # added 2009-01-06 19:13 since widgets need to handle keys properly
    #  2010-02-24 12:43 trying to take in multiple key bindings, TODO unbind
    #  TODO add symbol so easy to map from config file or mapping file
    def OLDbind_key keycode, *args, &blk
      @key_handler ||= {}
      if !block_given?
        blk = args.pop
        raise "If block not passed, last arg should be a method symbol" if !blk.is_a? Symbol
        $log.debug " #{@name} bind_key received a symbol #{blk} "
      end
      case keycode
      when String
        $log.debug "Widg String called bind_key BIND #{keycode} #{keycode_tos(keycode)}  "
        keycode = keycode.getbyte(0) #if keycode.class==String ##    1.9 2009-10-05 19:40 
        @key_handler[keycode] = blk
      when Array
        # for starters lets try with 2 keys only
        a0 = keycode[0]
        a0 = keycode[0].getbyte(0) if keycode[0].class == String
        a1 = keycode[1]
        a1 = keycode[1].getbyte(0) if keycode[1].class == String
        @key_handler[a0] ||= OrderedHash.new
        @key_handler[a0][a1] = blk
      else
        @key_handler[keycode] = blk
      end
      @key_args ||= {}
      @key_args[keycode] = args
    end
    ##
    # remove a binding that you don't want
    def unbind_key keycode
      @key_args.delete keycode unless @key_args.nil?
      @key_handler.delete keycode unless @key_handler.nil?
    end

    # e.g. process_key ch, self
    # returns UNHANDLED if no block for it
    # after form handles basic keys, it gives unhandled key to current field, if current field returns
    # unhandled, then it checks this map.
    # added 2009-01-06 19:13 since widgets need to handle keys properly
    # added 2009-01-18 12:58 returns ret val of blk.call
    # so that if block does not handle, the key can still be handled
    # e.g. table last row, last col does not handle, so it will auto go to next field
    #  2010-02-24 13:45 handles 2 key combinations, copied from Form, must be identical in logic
    #  except maybe for window pointer. TODO not tested
    def process_key keycode, object
      return _process_key keycode, object, @graphic
    end
    ## 
    # to be added at end of handle_key of widgets so instlalled actions can be checked
    def handle_key(ch)
      ret = process_key ch, self
      return :UNHANDLED if ret == :UNHANDLED
    end
    # @since 0.1.3
    def get_preferred_size
      return @preferred_height, @preferred_width
    end
    ## 
    #  creates a buffer for the widget to write to.
    #  This is typically called in the constructor. Sometimes, the constructor
    #  does not have a height or width, since the object will be resized based on parents
    #  size, as in splitpane
    #  Please use this only if embedding this object in another object/s that would wish
    #  to crop this. Otherwise, you could have many pads in your app.
    #  Sets @graphic which can be used in place of @form.window
    #  
    # @return [buffer] returns pad created
    # @since 0.1.3
    # NOTE: 2010-01-12 11:14  there are some parent widgets that may want this w to have a larger top and left.
    # Setting it later, means that the first repaint can be off.

    def create_buffer()
      $log.debug " #{self.class}  CB called with #{@should_create_buffer} H: #{@height} W #{@width}  "
      if @should_create_buffer
         @height or $log.warn " CB height is nil, setting to 1. This may not be what you want"
        mheight = @height ||  1 # some widgets don't have height XXX
        mwidth  = @width ||  30 # some widgets don't have width as yet
        mrow    = @row || 0
        mcol    = @col || 0
        layout  = { :height => mheight, :width => mwidth, :top => mrow, :left => mcol }
        $log.debug "  cb .. #{@name} create_buffer #{mrow} #{mcol} #{mheight} #{mwidth}"
        @screen_buffer = VER::Pad.create_with_layout(layout)
        @is_double_buffered = true # will be checked prior to blitting
        @buffer_modified = true # set this in repaint 
        @repaint_all = true # added 2010-01-08 19:02 
      else
        ## NOTE: if form has not been set, you could run into problems
        ## Typically a form MUST be set by now, unless you are buffering, in which
        ##+ case it should go in above block.
        @screen_buffer = @form.window if @form
      end

      @graphic = @screen_buffer # use buffer for writing, not screen window
      return @screen_buffer
    end # create_buffer

    ##
    # checks if buffer not created already, and figures
    # out dimensions.
    # Preferable to use this instead of directly using create_buffer.
    #
    def safe_create_buffer
      if @screen_buffer == nil
        if @height == nil
          @height = @preferred_height || @min_height
        end
        if @width == nil
          @width = @preferred_width || @min_width
        end
        create_buffer
      end
      return @screen_buffer
    end
    ##
    # Inform the system that the buffer has been modified
    # and should be blitted over the screen or copied to parent.
    def set_buffer_modified(tf=true)
      @buffer_modified = tf
    end


    ## 
    #  copy the buffer to the screen, or given window/pad.
    #  Relevant only in double_buffered case since pad has to be written
    #  to screen. Should be called only by outer form, not by widgets as a widget
    #  could be inside another widget.
    #  Somewhere we need to clear screen if scrolling.???
    #  aka b2s
    # @param [Window, #get_window, nil] screen to write to, if nil then write to phys screen
    # @return 0 - copy success, -1 copy failure, 1 - did nothing, usually since buffer_modified false

   def buffer_to_screen(screen=nil, pminrow=0, pmincol=0)
      raise "deprecated b2s "
      return 1 unless @is_double_buffered and @buffer_modified
      # screen is nil when form calls this to write to physical screen
      $log.debug " screen inside buffer_to_screen b2s :#{screen} "
      $log.error "ERROR !I have moved away fomr this method. Your program is broken and will not be working"
      ## 2010-01-03 19:38 i think its wrong to put the pad onto the screen
      ##+ since wrefreshing the window will cause this to be overwriting
      ##+ so i put current window here.
      if screen == nil
        #$log.debug " XXX calling graphic.wrefresh 2010-01-03 12:27 (parent_buffer was nil) "
        $log.debug " XXX 2010-01-03 20:47 now copying pad #{@graphic} onto form.window"
        ret = @graphic.wrefresh
       ## 2010-01-03 20:45 rather than writing to phys screen, i write to forms window
       ##+ so later updates to that window do not overwrite this widget.
       ## We need to check this out with scrollpane and splitpane.
        #ret = @graphic.copywin(@form.window.get_window, 0, 0, @row, @col, @row+@height-1, @col+@width-1,0)
      else
      # screen is passed when a parent object calls this to copy child buffer to itself
        @graphic.set_backing_window(screen)
        $log.debug "   #{@name} #{@graphic} calling copy pad to win COPY"
        ret = @graphic.copy_pad_to_win
      end
      @buffer_modified = false
      return ret
    end # buffer_to_screen
    ## 
    #  returns screen_buffer or nil
    #  
    # @return [screen_buffer, nil] screen_buffer earlier created
    # @since 0.1.3

    def get_buffer()
      @screen_buffer
    end # get_buffer

    ## 
    #  destroys screen_buffer if present
    #  
    # @return 
    # @since 0.1.3

    def destroy_buffer()
        if @screen_buffer != nil
            @screen_buffer.destroy # ??? 
        end
    end # destroy_buffer

     ## 
     #  Does the widget buffer its output in a pad
     #  
     # @return [true, false] comment
    
     def is_double_buffered?()
       @is_double_buffered
     end # is_double_buffered

     ##
     # getter and setter for width - 2009-10-29 22:45 
     # Using dsl_property style
     #
     # @param [val, nil] value to set
     # @return [val] earlier value if nil param
     # @since 0.1.3
     #
     def width(*val)
       #$log.debug " inside XXX width() #{val[0]}"
       if val.empty?
         return @width
       else
         #$log.debug " inside XXX width()"
         oldvalue = @width || 0 # is this default okay, else later nil cries
         @width = val.size == 1 ? val[0] : val
         newvalue = @width
         @config["width"]=@width
         if oldvalue != newvalue
           fire_property_change("width", oldvalue, newvalue)
           repaint_all(true)  # added 2010-01-08 18:51 so widgets can redraw everything.
         end
         if is_double_buffered? and newvalue != oldvalue
           $log.debug " #{@name} w calling resize of screen buffer with #{newvalue}. WARNING: does not change buffering_params"
           @screen_buffer.resize(0, newvalue)
         end
       end
     end
     def width=val
       width(val)
     end
     ##
     # getter and setter for height - 2009-10-30 12:25 
     # Using dsl_property style
     # SO WE've finally succumbed and added height to widget
     # @param [val, nil] height to set
     # @return [val] earlier height if nil param
     # @since 0.1.3
     #
     def height(*val)
       #$log.debug " inside XXX height() #{val[0]}"
       if val.empty?
         return @height
       else
         #$log.debug " inside #{@name} height()"
         oldvalue = @height || 0 # is this default okay, else later nil cries
         @height = val.size == 1 ? val[0] : val
         newvalue = @height
         @config["height"]=@height
         if oldvalue != newvalue
           fire_property_change("height", oldvalue, newvalue)
           $log.debug " widget #{@name} setting repaint_all to true"
           @repaint_all=true
         end
         # XXX this troubles me a lot. gets fired more than we would like
         # XXX When both h and w change then happens 2 times.
         if is_double_buffered? and newvalue != oldvalue
           $log.debug " #{@name} h calling resize of screen buffer with #{newvalue}"
           @screen_buffer.resize(newvalue, 0)
         end
       end
     end
     def height=val
       height(val)
     end
    # to give simple access to other components, (eg, parent) to tell a comp to either
    # paint its data, or to paint all - borders, headers, footers due to a big change (ht/width)
    def repaint_required(tf=true)
      @repaint_required = tf
    end
    def repaint_all(tf=true)
      @repaint_all = tf
      @repaint_required = tf
    end

     ## 
     # When an enclosing component creates a pad (buffer) and the child component
     #+ should write onto the same pad, then the enclosing component should override
     #+ the default graphic of child. This applies mainly to editor components in
     #+ listboxes and tables. 
     # @param graphic graphic object to use for writing contents
     # @see prepare_editor in rlistbox.
     # added 2010-01-05 15:25 
     def override_graphic gr
       @graphic = gr
     end

     ## passing a cursor up and adding col and row offsets
     ## Added 2010-01-13 13:27 I am checking this out.
     ## I would rather pass the value down and store it than do this recursive call
     ##+ for each cursor display
     # @see Form#setrowcol
     def setformrowcol r, c
           @form.row = r unless r.nil?
           @form.col = c unless c.nil?
           # this is stupid, going through this route i was losing windows top and left
           # And this could get repeated if there are mult objects. 
        if !@parent_component.nil? and @parent_component != self
           r+= @parent_component.form.window.top unless  r.nil?
           c+= @parent_component.form.window.left unless c.nil?
           $log.debug " (#{@name}) calling parents setformrowcol #{r}, #{c} pa: #{@parent_component.name} self: #{name}, #{self.class}, poff #{@parent_component.row_offset}, #{@parent_component.col_offset}, top:#{@form.window.left} left:#{@form.window.left} "
           @parent_component.setformrowcol r, c
        else
           # no more parents, now set form
           $log.debug " name NO MORE parents setting #{r}, #{c}    in #{@form} "
           @form.setrowcol r, c
        end
     end
     ## widget: i am putting one extra level of indirection so i can switch here
     # between form#setrowcol and setformrowcol, since i am not convinced either
     # are giving the accurate result. i am not sure what the issue is.
     def setrowcol r, c
         # 2010-02-07 21:32 is this where i should add ext_offsets
        #$log.debug " #{@name}  w.setrowcol #{r} + #{@ext_row_offset}, #{c} + #{@ext_col_offset}  "
        # commented off 2010-02-15 18:22 
        #r += @ext_row_offset unless r.nil?
        #c += @ext_col_offset unless c.nil?
        if @form
          @form.setrowcol r, c
        else
          @parent_component.setrowcol r, c
        end
        #setformrowcol r,c 
     end

     # move from TextView
     # parameters relating to buffering - new 2010-02-12 12:09 RFED16
     # I am merging so i can call multiple times
     # WARNING NOTE : this does not set Pad's top and left since Pad may not be created yet, or at all
     def set_buffering params
       @buffer_params ||= {}
       #@should_create_buffer = params[:should_create_buffer] || true
       @target_window ||= params[:target_window]
       # trying out, 2010-02-12 19:40 sometimes no form even with parent.
       @form = params[:form] unless @form
       ## XXX trying this out.
       # what if container does not ask child to buffer, as in splitpane
       # then graphic could be nil
       if @graphic.nil? # and should_create_buffer not set or false XXX
         @graphic = @target_window
       end
       $log.debug " set_buffering #{@name} got target window #{@target_window}, #{@graphic} - THIS DOES NOT UPDATE PAD ... sr:#{params[:screen_top]} sc:#{params[:screen_left]} top:#{params[:top]} left:#{params[:left]} bot:#{params[:bottom]} rt:#{params[:right]} "
       # @top = params[:top]
       # @left = params[:left]
       # @bottom = params[:bottom]
       # @right = params[:right]
       # offsets ?
       # warning, this does not touch @top and left of Pad, often pad will bot yet be created
       @buffer_params.merge!(params)
       if !@screen_buffer.nil?
         # update Pad since some folks take from there such as print_border
         @screen_buffer.top = params[:screen_top] if !params[:screen_top].nil?
         @screen_buffer.left = params[:screen_left] if !params[:screen_left].nil?
       end
     end
 
     # copy buffer onto window
     # RFED16 added 2010-02-12 14:42 0 simpler buffer management
     def buffer_to_window
       if @is_double_buffered and @buffer_modified
         raise " #{@name} @buffer_params not passed. Use set_buffering()" unless @buffer_params
         # we are notchecking for TV's width exceedingg, could get -1 if TV exceeds parent/
          $log.debug "RFED16 paint  #{@name} calling b2s #{@graphic}  "
          # TODO need to call set_screen_row_col (top, left), set_pad_top_left (pminrow, pmaxrow), set_screen_max_row_col
          if false
            # boh these print the pad behind 0,0, later scroll etc cover it and show bars.
            # adding window was giving error
              ret = buffer_to_screen #@target_window.get_window
              #ret = @graphic.wrefresh
          else
             # ext gives me parents offset. often the row would be zero, so we still need one extra
              r1 = @ext_row_offset # XXX NO, i should use top and left 
              c1 = @ext_col_offset  
              r = @graphic.top # 2010-02-12 21:12 TRYING THIS.
              c = @graphic.left
              maxr = @buffer_params[:bottom]
              maxc = @buffer_params[:right]
              r = @buffer_params[:screen_top] || 0
              c = @buffer_params[:screen_left] || 0
              $log.debug " b2w #{r1} #{c1} , #{r} #{c} "
              ## sadly this is bypassing the method that does this stuff in Pad. We need to assimilate it back, so not so much work here
              pminr = @graphic.pminrow
              pminc = @graphic.pmincol
              border_width = 0 # 2 #XXX  2010-02-15 23:40 2 to 0
              $log.debug " #{@name} ret = @graphic.copywin(@target_window.get_window, #{pminr}, #{pminc}, #{r}, #{c}, #{r}+#{maxr} - #{border_width}, #{c} + #{maxc} - #{border_width} ,0)"
              # this print the view at 0,0, byt covers the scrllare, bars not shown.
              # this can crash if textview is smaller than container dimension
              # can crash/give -1 when panning, giong beyond pad size XXX
              ret = @graphic.copywin(@target_window.get_window, pminr, pminc, r, c, r+maxr-border_width, c+maxc-border_width,0)
              if ret == -1
                $log.debug " copywin #{@name} h #{@height} w #{@width} "
                if @height <= maxr-border_width
                  $log.warn " h #{@height} is <= :bottom #{maxr} "
                end
                if @width <= maxc-border_width
                  $log.warn " h #{@width} is <= :right #{maxc} "
                end
                $log.warn "ERROR !!! copywin returns -1 check Target: #{@target_window}, #{@target_window.get_window} " if ret == -1
              end
          end
          $log.debug " copywin ret --> #{ret} "
          #
      end
     end
     ##
    ## ADD HERE WIDGET
  end

  ##
  #
  # TODO: we don't have an event for when form is entered and exited.
  # Current ENTER and LEAVE are for when any widgt is entered, so a common event can be put for all widgets
  # in one place.
  class Form
    include EventHandler
    include RubyCurses::Utils
    attr_reader :value
    attr_reader :widgets
    attr_accessor :window
    attr_accessor :row, :col
#   attr_accessor :color
#   attr_accessor :bgcolor
    attr_accessor :padx
    attr_accessor :pady
    attr_accessor :modified
    attr_accessor :active_index
    attr_reader :by_name   # hash containing widgets by name for retrieval
    attr_reader :menu_bar
    attr_accessor :navigation_policy  # :CYCLICAL will cycle around. Needed to move to other tabs
    ## i need some way to move the cursor by telling the main form what the coords are
    ##+ perhaps this will work
    attr_accessor :parent_form  # added 2009-12-28 23:01 BUFFERED - to bubble up row col changes
    # how many rows the component is panning embedded widget by
    attr_accessor :rows_panned  # HACK added 2009-12-30 16:01 BUFFERED 
    # how many cols the component is panning embedded widget by
    attr_accessor :cols_panned  # HACK added 2009-12-30 16:01 BUFFERED 
    ## next 2 added since tabbedpanes offset needs to be accounted by form inside it.
    attr_accessor :add_cols # 2010-01-26 20:23 additional columns due to being placed in some container
    attr_accessor :add_rows # 2010-01-26 20:23 additional columns due to being placed in some container
    attr_accessor :name # for debugging 2010-02-02 20:12 
    attr_accessor :ext_col_offset, :ext_row_offset # 2010-02-07 20:16  to get abs position for cursor
#    attr_accessor :allow_alt_digits # catch Alt-1-9 as digit_argument
    def initialize win, &block
      @window = win
      @widgets = []
      @by_name = {}
      @active_index = -1
      @padx = @pady = 0
      @row = @col = -1
      @ext_row_offset = @ext_col_offset = 0 # 2010-02-07 20:18 
      @add_cols = @add_rows = 0 # 2010-01-26 20:28 
      @handler = {}
      @modified = false
      @focusable = true
      @navigation_policy ||= :CYCLICAL
      instance_eval &block if block_given?
      @firsttime = true # internal, don't touch
      ## I need some counter so a widget knows it has been panned and can send a correct
      ##+ cursor coordinate to system.
      @rows_panned = @cols_panned = 0 # how many rows were panned, typically at a higher level
      @firsttime = true; # added on 2010-01-02 19:21 to prevent scrolling crash ! 
      @name ||= ""
      $kill_ring ||= [] # 2010-03-09 22:42 so textarea and others can copy and paste
      $kill_ring_pointer = 0 # needs to be incremented with each append, moved with yank-pop
      $append_next_kill = false
      $kill_last_pop_size = 0 # size of last pop which has to be cleared

      #@allow_alt_digits = true ; # capture Alt-1-9 as digit_args. Set to false if you wish to map
                                 # Alt-1-9 to buttons of tabs 
    end
    ##
    # set this menubar as the form's menu bar.
    # also bind the toggle_key for popping up.
    # Should this not be at application level ?
    def set_menu_bar mb
      @menu_bar = mb
      add_widget mb
      mb.toggle_key ||= 27 # ESC
      if !mb.toggle_key.nil?
        ch = mb.toggle_key
        bind_key(ch) do |_form| 
          if !@menu_bar.nil?
            @menu_bar.toggle
            @menu_bar.handle_keys
          end
        end
      end
    end
    ##
    # Add given widget to widget list and returns an incremental id.
    # Adding to widgets, results in it being painted, and focussed.
    # removing a widget and adding can give the same ID's, however at this point we are not 
    # really using ID. But need to use an incremental int in future.
    def add_widget widget
      # this help to access widget by a name
      if widget.respond_to? :name and !widget.name.nil?
        @by_name[widget.name] = widget
      end


      $log.debug " #{self} adding a widget #{@widgets.length} .. #{widget} "
      @widgets << widget
      # add form offsets to widget's external offsets - 2010-02-07 20:22 
      if widget.is_a? RubyCurses::Widget
        if @window # ext seems redundant
          widget.ext_col_offset += @window.left # just hope window aint undef!! XXX
          $log.debug " #{@name} add widget ( #{widget.name} ) ext_row #{widget.ext_row_offset} += #{@window.top} "
          widget.ext_row_offset += @window.top
        end
      end
      return @widgets.length-1
    end
    alias :add :add_widget

    # remove a widget
    #  added 2008-12-09 12:18 
   def remove_widget widget
     if widget.respond_to? :name and !widget.name.nil?
       $log.debug "removing from byname: #{widget.name} " 
       @by_name.delete(widget.name)
     end
     @widgets.delete widget
   end
   # form repaint
   # to be called at some interval, such as after each keypress.
    def repaint
      $log.debug " form repaint:#{self}, #{@name} , r #{@row} c #{@col} "
      @widgets.each do |f|
        next if f.visible == false # added 2008-12-09 12:17 
        f.repaint
        # added 2009-10-29 20:11 for double buffered widgets
        # this should only happen if painting actually happened
        #$log.debug " #{self} form repaint parent_buffer (#{@parent_buffer}) if #{f.is_double_buffered?} : #{f.name} "
        pb = @parent_buffer #|| @window
        # is next line used 2010-02-05 00:04 its wiping off top in scrollpane in tabbedpane
        # RFED16 - the next line should never execute now, since no outer object is buffered
        #+ only those within containers are.
        # Drat - this line is happeing since components inside a TP are double_buffered
        #x f.buffer_to_screen(pb) if f.is_double_buffered? 
      end
      @window.clear_error # suddenly throwing up on a small pad 2010-03-02 15:22 TPNEW
      @window.print_status_message $status_message unless $status_message.nil?
      @window.print_error_message $error_message unless $error_message.nil?
      $error_message = $status_message = nil
      #  this can bomb if someone sets row. We need a better way!
      if @row == -1 and @firsttime == true
        #set_field_cursor 0
        #  this part caused an endless loop on 2010-01-02 19:20 when scrollpane scrolled up
       $log.debug "form repaint calling select field 0 SHOULD HAPPEN FIRST TIME ONLY"
        #select_field 0
        req_first_field
        @firsttime = false
      end
       setpos 
       # XXX this creates a problem if window is a pad
       # although this does show cursor movement etc.
       ### XXX@window.wrefresh
       if @window.window_type == :WINDOW
         $log.debug " formrepaint #{@name} calling window.wrefresh #{@window} "
         @window.wrefresh
       else
         # UGLY HACK TO MAKE TABBEDPANES WORK !!
         # If the form is based on a Pad, then it would come here to write the Pad onto the parent_buffer
         # However, I've obviated the need to handle anything here by adding a display_form after handle_key
         # in TP.
         #x if @parent_buffer!=nil
           #x $log.debug " formrep coming to set backing window part #{@window} , type:#{@window.window_type}, #{@parent_buffer}, #{@parent_buffer.window_type} "
           # XXX RFED19 do we need at all 2010-02-19 15:26 
           # this is required so that each key stroke registers on tabbedpane
           # for this to work both have to be pads
           #x @window.set_backing_window(@parent_buffer)
           #x @window.copy_pad_to_win
           #x @window.wrefresh #since the pads are writing onto window directly, i don't think we need  this
           #x $log.debug " DO I NEED TO DO SOMETHING HERE FOR TABBEDPANES now ? WARN ?? YES, else keystrokes won't be updated "
         #x end
       end
    end
    ## 
    # move cursor to where the fields row and col are
    # private
    def setpos r=@row, c=@col
      # next 2 lines added, only do cursor if current field doesn't manage it.
      #curr = get_current_field
      #return if curr.manages_cursor
      $log.debug "setpos : (#{self}) #{r} #{c}"
      ## adding just in case things are going out of bounds of a parent and no cursor to be shown
      return if r.nil? or c.nil?  # added 2009-12-29 23:28 BUFFERED
      return if r<0 or c<0  # added 2010-01-02 18:49 stack too deep coming if goes above screen
      @window.wmove r,c
    end
    def get_current_field
      select_next_field if @active_index == -1
      return nil if @active_index.nil?   # for forms that have no focusable field 2009-01-08 12:22 
      @widgets[@active_index]
    end
    def req_first_field
      @active_index = -1 # FIXME HACK
      select_next_field
    end
    def req_last_field
      @active_index = nil 
      select_prev_field
    end
    ## do not override
    # form's trigger, fired when any widget loses focus
    #  This wont get called in editor components in tables, since  they are formless XXX
    def on_leave f
      return if f.nil?
      f.state = :NORMAL
      # on leaving update text_variable if defined. Should happen on modified only
      # should this not be f.text_var ... f.buffer ? XXX 2008-11-25 18:58 
      #f.text_variable.value = f.buffer if !f.text_variable.nil? # 2008-12-20 23:36 
      f.on_leave if f.respond_to? :on_leave
      fire_handler :LEAVE, f 
      ## to test XXX in combo boxes the box may not be editable by be modified by selection.
      if f.respond_to? :editable and f.modified?
        $log.debug " Form about to fire CHANGED for #{f} "
        f.fire_handler(:CHANGED, f) 
      end
    end
    def on_enter f
      return if f.nil?
      f.state = :HIGHLIGHTED
      f.modified false
      #f.set_modified false
      f.on_enter if f.respond_to? :on_enter
      fire_handler :ENTER, f 
    end
    ## is a field focusable
    # Added a method here, so forms can extend this to avoid focussing on off-screen components
    def focusable?(f)
      return f.focusable
    end
    ##
    # puts focus on the given field/widget index
    # XXX if called externally will not run a on_leave of previous field
    def select_field ix0
      #return if @widgets.nil? or @widgets.empty? or !@widgets[ix0].focusable
      return if @widgets.nil? or @widgets.empty? or !focusable?(@widgets[ix0])
     #$log.debug "insdie select  field :  #{ix0} ai #{@active_index}" 
      f = @widgets[ix0]
      if focusable?(f)
        @active_index = ix0
        @row, @col = f.rowcol
       #$log.debug " WMOVE insdie sele nxt field : ROW #{@row} COL #{@col} " 
        @window.wmove @row, @col
        on_enter f
        f.curpos = 0
        repaint
        @window.refresh
      else
        $log.debug "insdie sele nxt field ENABLED FALSE :   act #{@active_index} ix0 #{ix0}" 
      end
    end
    ##
    # run validate_field on a field, usually whatevers current
    # before transferring control
    # We should try to automate this so developer does not have to remember to call it.
    def validate_field f=@widgets[@active_index]
      begin
        on_leave f
      rescue => err
        $log.debug "form: validate_field caught EXCEPTION #{err}"
        $log.debug(err.backtrace.join("\n")) 
        $error_message = "#{err}"
        Ncurses.beep
        return -1
      end
      return 0
    end
    # put focus on next field
    # will cycle by default, unless navigation policy not :CYCLICAL
    # in which case returns :NO_NEXT_FIELD.
    def select_next_field
      return if @widgets.nil? or @widgets.empty?
      $log.debug "insdie sele nxt field :  #{@active_index} WL:#{@widgets.length}" 
      if @active_index.nil?
        @active_index = -1 
      else
        f = @widgets[@active_index]
        begin
          on_leave f
        rescue => err
         $log.debug "select_next_field: caught EXCEPTION #{err}"
         $log.debug(err.backtrace.join("\n")) 
         $error_message = "#{err}"
         Ncurses.beep
         return
        end
      end
      index = @active_index + 1
      index.upto(@widgets.length-1) do |i|
        f = @widgets[i]
        $log.debug "insdie sele nxt field :  i #{i}  #{index} WL:#{@widgets.length}, field #{f}" 
        if focusable?(f)
          select_field i
          return
        end
      end
      #req_first_field
      #$log.debug "insdie sele nxt field FAILED:  #{@active_index} WL:#{@widgets.length}" 
      ## added on 2008-12-14 18:27 so we can skip to another form/tab
      if @navigation_policy == :CYCLICAL
        @active_index = nil
        # recursive call worked, but bombed if no focusable field!
        #select_next_field
        0.upto(index-1) do |i|
          f = @widgets[i]
          if focusable?(f)
            select_field i
            return
          end
        end
      end
      $log.debug "insdie sele nxt field : NO NEXT  #{@active_index} WL:#{@widgets.length}" 
      return :NO_NEXT_FIELD
    end
    ##
    # put focus on previous field
    # will cycle by default, unless navigation policy not :CYCLICAL
    # in which case returns :NO_PREV_FIELD.
    def select_prev_field
      return if @widgets.nil? or @widgets.empty?
      #$log.debug "insdie sele prev field :  #{@active_index} WL:#{@widgets.length}" 
      if @active_index.nil?
        @active_index = @widgets.length 
      else
        f = @widgets[@active_index]
        begin
          on_leave f
        rescue => err
         $log.debug " cauGHT EXCEPTION #{err}"
         Ncurses.beep
         return
        end
      end

      index = @active_index - 1
      (index).downto(0) do |i|
        f = @widgets[i]
        if focusable?(f)
          select_field i
          return
        end
      end
      # $log.debug "insdie sele prev field FAILED:  #{@active_index} WL:#{@widgets.length}" 
      ## added on 2008-12-14 18:27 so we can skip to another form/tab
      # 2009-01-08 12:24 no recursion, can be stack overflows if no focusable field
      if @navigation_policy == :CYCLICAL
        @active_index = nil # HACK !!!
        #select_prev_field
        total = @widgets.length-1
        total.downto(index-1) do |i|
          f = @widgets[i]
          if focusable?(f)
            select_field i
            return
          end
        end
      end
      return :NO_PREV_FIELD
    end
    alias :req_next_field :select_next_field
    alias :req_prev_field :select_prev_field
    ##
    # move cursor by num columns. Form
    def addcol num
      return if @col.nil? or @col == -1
      @col += num
      @window.wmove @row, @col
      ## 2010-01-30 23:45 exchange calling parent with calling this forms setrow
      # since in tabbedpane with table i am not gietting this forms offset. 
        setrowcol nil, col
      # added on 2010-01-05 22:26 so component widgets like scrollpane can get the cursor
      #if !@parent_form.nil? and @parent_form != self #@form
        #$log.debug " #{@name} addcol calling parents setrowcol #{row}, #{col}: #{@parent_form}   "
        #@parent_form.setrowcol nil, col
      #end
    end
    ##
    # move cursor by given rows and columns, can be negative.
    # 2010-01-30 23:47 FIXME, if this is called we should call setrowcol like in addcol
    def addrowcol row,col
      return if @col.nil? or @col == -1   # contradicts comment on top
      return if @row.nil? or @row == -1
      @col += col
      @row += row
      @window.wmove @row, @col
      # added on 2010-01-05 22:26 so component widgets like scrollpane can get the cursor
      if !@parent_form.nil? and @parent_form != @form
        $log.debug " #{@name} addrowcol calling parents setrowcol #{row}, #{col}  "
        @parent_form.setrowcol row, col
      end
    end

    ## added 2009-12-29 15:46  BUFFERED
    # Set forms row and col, so that the cursor can be displayed at that point.
    # Widgets should call this rather than touch row and col
    # directly. This should percolate the row and col
    # upwards to parent forms, after comparing to prevent 
    # infinite recursion.
    # This is being done for embedded objects so that the cursor
    # can be maintained correctly.
    def OLDsetrowcol r, c
      @row = r unless r.nil?
      @col = c unless c.nil?
           r +=  @add_rows unless r.nil? # 2010-01-26 20:31 
           c +=  @add_cols unless c.nil? # 2010-01-26 20:31 
           $log.debug " addcols #{@add_cols} addrow #{@add_rows} : #{self}  "
      if !@parent_form.nil? and @parent_form != self
        $log.debug " (#{@name}) calling parents setrowcol #{r}, #{c} : pare: #{@parent_form}; self:  #{self}, #{self.class}  "
        r += @parent_form.window.top unless  r.nil?
        c += @parent_form.window.left unless c.nil?
        @parent_form.setrowcol r, c
      end
    end
    ## Form
    # New attempt at setting cursor using absolute coordinates
    # Also, trying NOT to go up. let this pad or window print cursor.
    def setrowcol r, c
      @row = r unless r.nil?
      @col = c unless c.nil?
      r +=  @add_rows unless r.nil? # 2010-01-26 20:31 
      c +=  @add_cols unless c.nil? # 2010-01-26 20:31 
      $log.debug " addcols #{@add_cols} addrow #{@add_rows} : #{self}  "
      if !@parent_form.nil? and @parent_form != self
        $log.debug " (#{@name}) calling parents setrowcol #{r}, #{c} : pare: #{@parent_form}; self:  #{self}, #{self.class}  "
        #r += @parent_form.window.top unless  r.nil?
        #c += @parent_form.window.left unless c.nil?
        @parent_form.setrowcol r, c
      end
    end
  ##
  # bind an action to a key, required if you create a button which has a hotkey
  # or a field to be focussed on a key, or any other user defined action based on key
  # e.g. bind_key ?\C-x, object, block
    # 1.9 if string passed then getbyte so user does not need to change much and
    # less chance of error 2009-10-04 16:08 
  def OLDbind_key keycode, *args, &blk
      @key_handler ||= {}
      case keycode
      when String
        $log.debug "FORM String called bind_key BIND #{keycode} #{keycode_tos(keycode)}  "
        keycode = keycode.getbyte(0) #if keycode.class==String ##    1.9 2009-10-05 19:40 
        @key_handler[keycode] = blk
      when Array
        # for starters lets try with 2 keys only
        a0 = keycode[0]
        a0 = keycode[0].getbyte(0) if keycode[0].class == String
        a1 = keycode[1]
        a1 = keycode[1].getbyte(0) if keycode[1].class == String
        @key_handler[a0] ||= OrderedHash.new
        @key_handler[a0][a1] = blk
      else
        @key_handler[keycode] = blk
      end
      @key_args ||= {}
      @key_args[keycode] = args
  end

  # e.g. process_key ch, self
  # returns UNHANDLED if no block for it
  # after form handles basic keys, it gives unhandled key to current field, if current field returns
  # unhandled, then it checks this map.
  # Please update widget with any changes here. TODO: match regexes as in mapper
  def process_key keycode, object
    return _process_key keycode, object, @window
  end
      #return :UNHANDLED if @key_handler.nil?
      #blk = @key_handler[keycode]
      #return :UNHANDLED if blk.nil?
      #if blk.is_a? OrderedHash
        ## Please note that this does not wait too long, you have to press next key fast
        ## since i have set halfdelay in ncurses.rb, test this with getchar to get more keys TODO
          #ch = @window.getch
          #if ch < 0 || ch > 255
            ##next
            #return nil
          #end
          #$log.debug " process_key: got #{keycode} , #{ch} "
          #yn = ch.chr
          #blk1 = blk[ch]
          #return nil if blk1.nil?
          #$log.debug " process_key: found block for #{keycode} , #{ch} "
          #blk = blk1
      #end
      #$log.debug "called process_key #{object}, kc: #{keycode}, args  #{@key_args[keycode]}"
     ## return blk.call object,  *@key_args[keycode]
    #blk.call object,  *@key_args[keycode]
    #0
  #end
  # Defines how user can give numeric args to a command even in edit mode
  # User either presses universal_argument (C-u) which generates a series of 4 16 64.
  # Or he presses C-u and then types some numbers. Followed by the action.
  # @returns [0, :UNHANDLED] :UNHANDLED implies that last keystroke is still to evaluated
  # by system. ) implies only numeric args were obtained. This method updates $multiplier
  def universal_argument
    $multiplier = ( ($multiplier.nil? || $multiplier == 0) ? 4 : $multiplier *= 4)
        $log.debug " inside UNIV MULT0: #{$multiplier} "
    # See if user enters numerics. If so discard existing varaible and take only 
    #+ entered values
    _m = 0
    while true
      ch = @window.getchar()
      case ch
      when -1
        next 
      when ?0.getbyte(0)..?9.getbyte(0)
        _m *= 10 ; _m += (ch-48)
        $multiplier = _m
        $log.debug " inside UNIV MULT #{$multiplier} "
      when ?\C-u.getbyte(0)
        if _m == 0
          # user is incrementally hitting C-u
          $multiplier *= 4
        else
          # user is terminating some numbers so he can enter a numeric command next
          return 0
        end
      else
        $log.debug " inside UNIV MULT else got #{ch} "
        # here is some other key that is the function key to be repeated. we must honor this
        # and ensure it goes to the right widget
        return ch
        #return :UNHANDLED
      end
    end
    return 0
  end
  def digit_argument ch
    $multiplier = ch - ?\M-0.getbyte(0)
    $log.debug " inside UNIV MULT 0 #{$multiplier} "
    # See if user enters numerics. If so discard existing varaible and take only 
    #+ entered values
    _m = $multiplier
    while true
      ch = @window.getchar()
      case ch
      when -1
        next 
      when ?0.getbyte(0)..?9.getbyte(0)
        _m *= 10 ; _m += (ch-48)
        $multiplier = _m
        $log.debug " inside UNIV MULT 1 #{$multiplier} "
      when ?\M-0.getbyte(0)..?\M-9.getbyte(0)
        _m *= 10 ; _m += (ch-?\M-0.getbyte(0))
        $multiplier = _m
        $log.debug " inside UNIV MULT 2 #{$multiplier} "
      else
        $log.debug " inside UNIV MULT else got #{ch} "
        # here is some other key that is the function key to be repeated. we must honor this
        # and ensure it goes to the right widget
        return ch
        #return :UNHANDLED
      end
    end
    return 0
  end
  ## forms handle keys
  # mainly traps tab and backtab to navigate between widgets.
  # I know some widgets will want to use tab, e.g edit boxes for entering a tab
  #  or for completion.
  def handle_key(ch)
        if ch ==  ?\C-u.getbyte(0)
          ret = universal_argument
          $log.debug " FORM set MULT to #{$multiplier}, ret = #{ret}  "
          return 0 if ret == 0
          ch = ret # unhandled char
        elsif ch >= ?\M-1.getbyte(0) && ch <= ?\M-9.getbyte(0)
          if $catch_alt_digits
            ret = digit_argument ch
            $log.debug " FORM set MULT DA to #{$multiplier}, ret = #{ret}  "
            return 0 if ret == 0 # don't see this happening
            ch = ret # unhandled char
          end
        end

        case ch
        when -1
          return
        else
          keycode = keycode_tos(ch)
          $log.debug " form HK #{ch} #{self}, #{@name}, #{keycode}  "
          field =  get_current_field
          handled = :UNHANDLED 
          handled = field.handle_key ch unless field.nil? # no field focussable
          # some widgets like textarea and list handle up and down
          if handled == :UNHANDLED or handled == -1 or field.nil?
            case ch
            when 9, ?\M-\C-i.getbyte(0)  # tab and M-tab in case widget eats tab (such as Table)
              ret = select_next_field
              return ret if ret == :NO_NEXT_FIELD
              # alt-shift-tab  or backtab (in case Table eats backtab)
            when 353, 481 ## backtab added 2008-12-14 18:41 
              ret = select_prev_field
              return ret if ret == :NO_PREV_FIELD
            when KEY_UP
              select_prev_field
            when KEY_DOWN
              select_next_field
            #when ?\M-L.getbyte(0)
              ### trying out these for fuun and testing splitpane 2010-01-10 20:32 
              #$log.debug " field #{field.name} was #{field.width} "
              #field.width += 1
              #$log.debug " field #{field.name} now #{field.width} "
              #field.repaint_all
            #when ?\M-H.getbyte(0), ?\M-<.getbyte(0)
              #field.width -= 1
              #$log.debug " field #{field.name} now #{field.width} "
              #field.repaint_all
            #when ?\M-J.getbyte(0)
              #field.height += 1
            #when ?\M-K.getbyte(0)
              #field.height -= 1
            else
              ret = process_key ch, self
              $log.debug " process_key #{ch} got ret #{ret} in #{self} "
              return :UNHANDLED if ret == :UNHANDLED
            end
          end
        end
       $log.debug " form before repaint #{self} , #{@name}, ret #{ret}"
       repaint
       #return handled # TRYNG 2010-03-01 23:30 since TP returns NO_NEXT_FIELD sometimes
       #$multiplier = 0
  end
  ##
  # test program to dump data onto log
  # The problem I face is that since widget array contains everything that should be displayed
  # I do not know what all the user wants - what are his data entry fields. 
  # A user could have disabled entry on some field after modification, so i can't use focusable 
  # or editable as filters. I just dump everything?
  # What's more, currently getvalue has been used by paint to return what needs to be displayed - 
  # at least by label and button.
  def dump_data
    $log.debug " DUMPING DATA "
    @widgets.each do |w|
      # we need checkbox and radio button values
      #next if w.is_a? RubyCurses::Button or w.is_a? RubyCurses::Label 
      next if w.is_a? RubyCurses::Label 
      next if !w.is_a? RubyCurses::Widget
      if w.respond_to? :getvalue
        $log.debug " #{w.name} #{w.getvalue}"
      else
        $log.debug " #{w.name} DOES NOT RESPOND TO getvalue"
      end
    end
    $log.debug " END DUMPING DATA "
  end
  ##
  # trying out for splitpane and others who have a sub-form
  def set_parent_buffer b
    @parent_buffer = b
  end
  # 2010-02-07 14:50 to aid in debugging and comparing log files.
  def to_s; @name || self; end

    ## ADD HERE FORM
  end
  ## Created and sent to all listeners whenever a property is changed
  # @see fire_property_change
  # @see fire_handler 
  # @since 1.0.5 added 2010-02-25 23:06 
  class PropertyChangeEvent
    attr_accessor :source, :property_name, :oldvalue, :newvalue
    def initialize source, property_name, oldvalue, newvalue
      set source, property_name, oldvalue, newvalue
    end
    def set source, property_name, oldvalue, newvalue
        @source, @property_name, @oldvalue, @newvalue =
        source, property_name, oldvalue, newvalue
    end
    def to_s
      "PROPERTY_CHANGE name: #{property_name}, oldval: #{@oldvalue}, newvalue: #{@newvalue}, source: #{@source}"
    end
    def inspect
      to_s
    end
  end

  ##
  # Text edit field
  # To get value use getvalue() 
  # TODO - test text_variable
  #  
  class Field < Widget
    dsl_accessor :maxlen             # maximum length allowed into field
    attr_reader :buffer              # actual buffer being used for storage
    dsl_accessor :label              # label of field
    dsl_accessor :default            # TODO use set_buffer for now
    dsl_accessor :values             # validate against provided list
    dsl_accessor :valid_regex        # validate against regular expression

    dsl_accessor :chars_allowed      # regex, what characters to allow, will ignore all else
    dsl_accessor :display_length     # how much to display
    dsl_accessor :bgcolor            # background color 'red' 'black' 'cyan' etc
    dsl_accessor :color              # foreground colors from Ncurses COLOR_xxxx
    dsl_accessor :show               # what charactr to show for each char entered (password field)
    dsl_accessor :null_allowed       # allow nulls, don't validate if null # added 2008-12-22 12:38 

    # any new widget that has editable should have modified also
    dsl_accessor :editable          # allow editing

    attr_reader :form
    attr_reader :handler             # event handler
    attr_reader :type                # datatype of field, currently only sets chars_allowed
    #attr_reader :curpos              # cursor position in buffer current, in WIDGET 
    attr_accessor :datatype              # crrently set during set_buffer
    attr_reader :original_value              # value on entering field
    attr_accessor :overwrite_mode              # true or false INSERT OVERWRITE MODE

    def initialize form, config={}, &block
      @form = form
      @buffer = String.new
      #@type=config.fetch("type", :varchar)
      @display_length = config.fetch("display_length", 20)
      @maxlen=config.fetch("maxlen", @display_length) 
      @row = config.fetch("row", 0)
      @col = config.fetch("col", 0)
      @bgcolor = config.fetch("bgcolor", $def_bg_color)
      @color = config.fetch("color", $def_fg_color)
      @name = config.fetch("name", nil)
      @editable = config.fetch("editable", true)
      @focusable = config.fetch("focusable", true)
      @handler = {}
      @event_args = {}             # arguments passed at time of binding, to use when firing event
      init_vars
      super
    end
    def init_vars
      @pcol = 0   # needed for horiz scrolling
      @curpos = 0                  # current cursor position in buffer
      @modified = false
    end
    def text_variable tv
      @text_variable = tv
      set_buffer tv.value
    end
    ##
    # define a datatype, currently only influences chars allowed
    # integer and float. what about allowing a minus sign? XXX
    def type dtype
      case dtype.to_s.downcase
      when 'integer'
        @chars_allowed = /\d/ if @chars_allowed.nil?
      when 'numeric'
        @chars_allowed = /[\d\.]/ if @chars_allowed.nil?
      when 'alpha'
        @chars_allowed = /[a-zA-Z]/ if @chars_allowed.nil?
      when 'alnum'
        @chars_allowed = /[a-zA-Z0-9]/ if @chars_allowed.nil?
      end
    end
    def putch char
      return -1 if !@editable 
      return -1 if !@overwrite_mode and @buffer.length >= @maxlen
      if @chars_allowed != nil
        return if char.match(@chars_allowed).nil?
      end
      # added insert or overwrite mode 2010-03-17 20:11 
      if @overwrite_mode
        @buffer[@curpos] = char
      else
        @buffer.insert(@curpos, char)
      end
      @curpos += 1 if @curpos < @maxlen
      @modified = true
      $log.debug " FIELD FIRING CHANGE: #{char} at new #{@curpos}: bl:#{@buffer.length} buff:[#{@buffer}]"
      fire_handler :CHANGE, self    # 2008-12-09 14:51 
      0
    end

    ##
    # TODO : sending c>=0 allows control chars to go. Should be >= ?A i think.
    def putc c
      if c >= 0 and c <= 127
        ret = putch c.chr
        if ret == 0
          if addcol(1) == -1  # if can't go forward, try scrolling
            # scroll if exceeding display len but less than max len
            if @curpos > @display_length and @curpos <= @maxlen
              @pcol += 1 if @pcol < @display_length 
            end
          end
          set_modified 
        end
      end
      return -1
    end
    def delete_at index=@curpos
      return -1 if !@editable 
      @buffer.slice!(index,1)
      $log.debug " delete at #{index}: #{@buffer.length}: #{@buffer}"
      @modified = true
      fire_handler :CHANGE, self    # 2008-12-09 14:51 
    end
    ## 
    # should this do a dup ??
    def set_buffer value
      @datatype = value.class
      #$log.debug " FIELD DATA #{@datatype}"
      @buffer = value.to_s
      @curpos = 0
    end
    # converts back into original type
    #  changed to convert on 2009-01-06 23:39 
    def getvalue
      dt = @datatype || String
      case dt.to_s
      when "String"
        return @buffer
      when "Fixnum"
        return @buffer.to_i
      when "Float"
        return @buffer.to_f
      else
        return @buffer.to_s
      end
    end
  
  def set_label label
    @label = label
    label.row  @row if label.row == -1
    label.col  @col-(label.name.length+1) if label.col == -1
    label.label_for(self)
  end

  ## Note that some older widgets like Field repaint every time the form.repaint
  ##+ is called, whether updated or not. I can't remember why this is, but
  ##+ currently I've not implemented events with these widgets. 2010-01-03 15:00 

  def repaint
    $log.debug("repaint FIELD: #{id}, #{name},  #{focusable}")
    #return if display_length <= 0 # added 2009-02-17 00:17 sometimes editor comp has 0 and that
    # becomes negative below, no because editing still happens
    @display_length = 1 if display_length == 0
    printval = getvalue_for_paint().to_s # added 2009-01-06 23:27 
    printval = show()*printval.length unless @show.nil?
    if !printval.nil? 
      if printval.length > display_length # only show maxlen
        printval = printval[@pcol..@pcol+display_length-1] 
      else
        printval = printval[@pcol..-1]
      end
    end
    #printval = printval[0..display_length-1] if printval.length > display_length
    if @bgcolor.is_a? String and @color.is_a? String
      acolor = ColorMap.get_color(@color, @bgcolor)
    else
      acolor = $datacolor
    end
    @graphic = @form.window if @graphic.nil? ## cell editor listbox hack XXX fix in correct place
    $log.debug " Field g:#{@graphic}. r,c,displen:#{@row}, #{@col}, #{@display_length} "
    @graphic.printstring  row, col, sprintf("%-*s", display_length, printval), acolor, @attr
  end
  def set_focusable(tf)
    @focusable = tf
  end

  # field
  def handle_key ch
    case ch
    when KEY_LEFT
      cursor_backward
    when KEY_RIGHT
      cursor_forward
    when KEY_BACKSPACE, 127
      delete_prev_char if @editable
    #when KEY_UP
    #  $log.debug " FIELD GOT KEY_UP, NOW IGNORING 2009-01-16 17:52 "
      #@form.select_prev_field # in a table this should not happen 2009-01-16 17:47 
    #  return :UNHANDLED
    #when KEY_DOWN
    #  $log.debug " FIELD GOT KEY_DOWN, NOW IGNORING 2009-01-16 17:52 "
      #@form.select_next_field # in a table this should not happen 2009-01-16 17:47 
    #  return :UNHANDLED
    when KEY_ENTER, 10, 13
      if respond_to? :fire
        fire
      end
    when 330
      delete_curr_char if @editable
    when ?\C-a.getbyte(0)
      cursor_home 
    when ?\C-e.getbyte(0)
      cursor_end 
    when ?\C-k.getbyte(0)
      delete_eol if @editable
    when ?\C-_.getbyte(0) # changed on 2010-02-26 14:44 so C-u can be used as numeric arg
      @buffer.insert @curpos, @delete_buffer unless @delete_buffer.nil?
    when 32..126
      #$log.debug("FIELD: ch #{ch} ,at #{@curpos}, buffer:[#{@buffer}] bl: #{@buffer.to_s.length}")
      putc ch
    when 27 # escape
      $log.debug " ADDED FIELD ESCAPE on 2009-01-18 12:27 XXX #{@original_value}"
      set_buffer @original_value 
    else
      ret = super
      return ret
    end
    0 # 2008-12-16 23:05 without this -1 was going back so no repaint
  end
  ## 
  # position cursor at start of field
  def cursor_home
    set_form_col 0
    @pcol = 0
  end
  ##
  # goto end of field, "end" is a keyword so could not use it.
  def cursor_end
        blen = @buffer.rstrip.length
        if blen < @display_length
          set_form_col blen
        else
          @pcol = blen-@display_length
          set_form_col @display_length-1
        end
        @curpos = blen # HACK XXX
  #  $log.debug " crusor END cp:#{@curpos} pcol:#{@pcol} b.l:#{@buffer.length} d_l:#{@display_length} fc:#{@form.col}"
    #set_form_col @buffer.length
  end
  def delete_eol
    return -1 unless @editable
    pos = @curpos-1
    @delete_buffer = @buffer[@curpos..-1]
    # if pos is 0, pos-1 becomes -1, end of line!
    @buffer = pos == -1 ? "" : @buffer[0..pos]
    fire_handler :CHANGE, self    # 2008-12-09 14:51 
    return @delete_buffer
  end
  def cursor_forward
    if @curpos < @buffer.length 
      if addcol(1)==-1  # go forward if you can, else scroll
        @pcol += 1 if @pcol < @display_length 
      end
      @curpos += 1
    end
   # $log.debug " crusor FORWARD cp:#{@curpos} pcol:#{@pcol} b.l:#{@buffer.length} d_l:#{@display_length} fc:#{@form.col}"
  end
  def cursor_backward
    if @curpos > 0
      @curpos -= 1
      if @pcol > 0 and @form.col == @col + @col_offset
        @pcol -= 1
      end
      addcol -1
    elsif @pcol > 0 #  added 2008-11-26 23:05 
      @pcol -= 1   
    end
 #   $log.debug " crusor back cp:#{@curpos} pcol:#{@pcol} b.l:#{@buffer.length} d_l:#{@display_length} fc:#{@form.col}"
=begin
# this is perfect if not scrolling, but now needs changes
    if @curpos > 0
      @curpos -= 1
      addcol -1
    end
=end
  end
    def delete_curr_char
      return -1 unless @editable
      delete_at
      set_modified 
    end
    def delete_prev_char
      return -1 if !@editable 
      return if @curpos <= 0
      @curpos -= 1 if @curpos > 0
      delete_at
      set_modified 
      addcol -1
    end
    ## add a column to cursor position. Field
    def addcol num
      if num < 0
        if @form.col <= @col + @col_offset
         # $log.debug " error trying to cursor back #{@form.col}"
          return -1
        end
      elsif num > 0
        if @form.col >= @col + @col_offset + @display_length
      #    $log.debug " error trying to cursor forward #{@form.col}"
          return -1
        end
      end
      @form.addcol num
    end
    # upon leaving a field
    # returns false if value not valid as per values or valid_regex
    # 2008-12-22 12:40 if null_allowed, don't validate, but do fire_handlers
    def on_leave
      val = getvalue
      #$log.debug " FIELD ON LEAVE:#{val}. #{@values.inspect}"
      valid = true
      if val.to_s.empty? and @null_allowed
        $log.debug " empty and null allowed"
      else
        if !@values.nil?
          valid = @values.include? val
          raise FieldValidationException, "Field value (#{val}) not in values: #{@values.join(',')}" unless valid
        end
        if !@valid_regex.nil?
          valid = @valid_regex.match(val.to_s)
          raise FieldValidationException, "Field not matching regex #{@valid_regex}" unless valid
        end
      end
      # here is where we should set the forms modified to true - 2009-01-18 12:36 XXX
      if modified?
        set_modified true
      end
      super
      #return valid
    end
    ## save original value on enter, so we can check for modified.
    #  2009-01-18 12:25 
    def on_enter
      @original_value = getvalue.dup rescue getvalue
      super
    end
    ##
    # overriding widget, check for value change
    #  2009-01-18 12:25 
    def modified?
      getvalue() != @original_value
    end
  # ADD HERE FIELD
  end
        
  ##
  # Like Tk's TkVariable, a simple proxy that can be passed to a widget. The widget 
  # will update the Variable. A variable can be used to link a field with a label or 
  # some other widget.
  # This is the new version of Variable. Deleting old version on 2009-01-17 12:04 
  class Variable
  
    def initialize value=""
      @update_command = []
      @args = []
      @value = value
      @klass = value.class.to_s
    end
    def add_dependent obj
      $log.debug " ADDING DEPENDE #{obj}"
      @dependents ||= []
      @dependents << obj
    end
    ##
    # install trigger to call whenever a value is updated
    def update_command *args, &block
      $log.debug "Variable: update command set " # #{args}"
      @update_command << block
      @args << args
    end
    ##
    # value of the variable
    def get_value val=nil
      if @klass == 'String'
        return @value
      elsif @klass == 'Hash'
        return @value[val]
      elsif @klass == 'Array'
        return @value[val]
      else
        return @value
      end
    end
    ##
    # update the value of this variable.
    # 2008-12-31 18:35 Added source so one can identify multiple sources that are updating.
    # Idea is that mutiple fields (e.g. checkboxes) can share one var and update a hash through it.
    # Source would contain some code or key relatin to each field.
    def set_value val, key=""
      oldval = @value
      if @klass == 'String'
        @value = val
      elsif @klass == 'Hash'
        $log.debug " Variable setting hash #{key} to #{val}"
        oldval = @value[key]
        @value[key]=val
      elsif @klass == 'Array'
        $log.debug " Variable setting array #{key} to #{val}"
        oldval = @value[key]
        @value[key]=val
      else
        oldval = @value
        @value = val
      end
      return if @update_command.nil?
      @update_command.each_with_index do |comm, ix|
        comm.call(self, *@args[ix]) unless comm.nil?
      end
      @dependents.each {|d| d.fire_property_change(d, oldval, val) } unless @dependents.nil?
    end
    ##
    def value= (val)
      raise "Please use set_value for hash/array" if @klass=='Hash' or @klass=='Array'
      oldval = @value
      @value=val
      return if @update_command.nil?
      @update_command.each_with_index do |comm, ix|
        comm.call(self, *@args[ix]) unless comm.nil?
      end
      @dependents.each {|d| d.fire_property_change(d, oldval, val) } unless @dependents.nil?
    end
    def value
      raise "Please use set_value for hash/array: #{@klass}" if @klass=='Hash' #or @klass=='Array'
      @value
    end
    def inspect
      @value.inspect
    end
    def [](key)
      @value[key]
    end
    ## 
    # in order to run some method we don't yet support
    def source
      @value
    end
    def to_s
      inspect
    end
  end
  ##
  # the preferred way of printing text on screen, esp if you want to modify it at run time.
  # Use display_length to ensure no spillage.
  class Label < Widget
    #dsl_accessor :label_for   # related field or buddy
    dsl_accessor :mnemonic    # keyboard focus is passed to buddy based on this key (ALT mask)
    # justify required a display length, esp if center.
    #dsl_accessor :justify     # :right, :left, :center  # added 2008-12-22 19:02 
    dsl_property :justify     # :right, :left, :center  # added 2008-12-22 19:02 
    dsl_property :display_length     #  please give this to ensure the we only print this much
    dsl_property :height    # if you want a multiline label.

    def initialize form, config={}, &block
  
      @row = config.fetch("row",-1) 
      @col = config.fetch("col",-1) 
      @bgcolor = config.fetch("bgcolor", $def_bg_color)
      @color = config.fetch("color", $def_fg_color)
      @text = config.fetch("text", "NOTFOUND")
      @editable = false
      @focusable = false
      super
      @justify ||= :left
      @name ||= @text
      @repaint_required = true
    end
    def getvalue
      @text_variable && @text_variable.value || @text
    end
    def label_for field
      @label_for = field
      #$log.debug " label for: #{@label_for}"
      bind_hotkey unless @form.nil?   # GRRR!
    end

    ##
    # for a button, fire it when label invoked without changing focus
    # for other widgets, attempt to change focus to that field
    def bind_hotkey
      if !@mnemonic.nil?
        ch = @mnemonic.downcase()[0].ord   ## FIXME 1.9 DONE 
        # meta key 
        mch = ?\M-a.getbyte(0) + (ch - ?a.getbyte(0))  ## FIXME 1.9
        if @label_for.is_a? RubyCurses::Button and @label_for.respond_to? :fire
          @form.bind_key(mch, @label_for) { |_form, _butt| _butt.fire }
        else
          $log.debug " bind_hotkey label for: #{@label_for}"
          @form.bind_key(mch, @label_for) { |_form, _field| _field.focus }
        end
      end
    end

    ##
    # XXX need to move wrapping etc up and done once. 
    def repaint
      return unless @repaint_required
        r,c = rowcol
        value = getvalue_for_paint
        lablist = []
        if @height && @height > 1
          lablist = wrap_text(value, @display_length).split("\n")
        else
          # ensure we do not exceed
          if !@display_length.nil?
            if value.length > @display_length
              value = value[0..@display_length-1]
            end
          end
          lablist << value
        end
        len = @display_length || value.length
        acolor = get_color $datacolor
        #$log.debug "label :#{@text}, #{value}, #{r}, #{c} col= #{@color}, #{@bgcolor} acolor  #{acolor} j:#{@justify} dlL: #{@display_length} "
        firstrow = r
        _height = @height || 1
        str = @justify.to_sym == :right ? "%*s" : "%-*s"  # added 2008-12-22 19:05 
        # loop added for labels that are wrapped.
        # TODO clear separately since value can change in status like labels
        $log.debug " RWID 1595 #{self.class} value: #{value} form:  #{form} "
        @graphic = @form.window if @graphic.nil? ## HACK messagebox givig this in repaint, 423 not working ??
        0.upto(_height-1) { |i| 
          @graphic.printstring r+i, c, " " * len , acolor,@attr
        }
        lablist.each_with_index do |_value, ix|
          break if ix >= _height
          if @justify.to_sym == :center
            padding = (@display_length - _value.length)/2
            _value = " "*padding + _value + " "*padding # so its cleared if we change it midway
          end
          @graphic.printstring r, c, str % [len, _value], acolor,@attr
          r += 1
        end
        if !@mnemonic.nil?
          ulindex = value.index(@mnemonic) || value.index(@mnemonic.swapcase)
          @graphic.mvchgat(y=firstrow, x=c+ulindex, max=1, Ncurses::A_BOLD|Ncurses::A_UNDERLINE, acolor, nil)
        end
        #@form.window.mvchgat(y=r, x=c, max=len, Ncurses::A_NORMAL, color, nil)
        @repaint_required = false
    end
  # ADD HERE LABEL
  end
  ##
  # action buttons
  # TODO: phasing out underline, and giving mnemonic and ampersand preference
  #  - Action: may have to listen to Action property changes so enabled, name etc change can be reflected
  class Button < Widget
    dsl_accessor :surround_chars   # characters to use to surround the button, def is square brackets
    dsl_accessor :mnemonic
    def initialize form, config={}, &block
      @focusable = true
      @editable = false
      @handler={} # event handler
      @event_args ||= {}
      super
      @bgcolor ||= $datacolor 
      @color ||= $datacolor 
      @surround_chars ||= ['[ ', ' ]'] 
      @col_offset = @surround_chars[0].length 
    end
    ##
    # set button based on Action
    #  2009-01-21 19:59 
    def action a
      text a.name
      mnemonic a.mnemonic unless a.mnemonic.nil?
      command { a.call }
    end
    ##
    # sets text, checking for ampersand, uses that for hotkey and underlines
    def text(*val)
      if val.empty?
        return @text
      else
        s = val[0].dup
        s = s.to_s if !s.is_a? String  # 2009-01-15 17:32 
        if (( ix = s.index('&')) != nil)
          s.slice!(ix,1)
          @underline = ix unless @form.nil? # this setting a fake underline in messageboxes
          mnemonic s[ix,1]
        end
        @text = s
      end
    end
    ## 
    # FIXME this will not work in messageboxes since no form available
    # if already set mnemonic, then unbind_key, ??

    def mnemonic char
      $log.error " #{self} COULD NOT SET MNEMONIC since form NIL" if @form.nil?
      return if @form.nil?
      @mnemonic = char
      ch = char.downcase()[0].ord ## XXX 1.9 
      # meta key 
      mch = ?\M-a.getbyte(0) + (ch - ?a.getbyte(0))
      $log.debug " #{self} setting MNEMO to #{char} #{mch}"
      @form.bind_key(mch, self) { |_form, _butt| _butt.fire }
    end
    ##
    # which index to use as underline.
    # Instead of using this to make a hotkey, I am thinking of giving this a new usage.
    # If you wish to override the underline?
    # @deprecated . use mnemonic or an ampersand in text.
    def OLDunderline ix
      _value = @text || getvalue # hack for Togglebutton FIXME
      raise "#{self}: underline requires text to be set " if _value.nil?
      mnemonic _value[ix]
    end
    # bind hotkey to form keys. added 2008-12-15 20:19 
    # use ampersand in name or underline
    def bind_hotkey
      return if @underline.nil? or @form.nil?
      _value = @text || getvalue # hack for Togglebutton FIXME
      #_value = getvalue
      $log.debug " bind hot #{_value} #{@underline}"
      ch = _value[@underline,1].downcase()[0].ord ## XXX 1.9  2009-10-05 18:55  TOTEST
      @mnemonic = _value[@underline,1]
      # meta key 
      mch = ?\M-a.getbyte(0) + (ch - ?a.getbyte(0))
      @form.bind_key(mch, self) { |_form, _butt| _butt.fire }
    end
    #    2009-01-17 01:48 removed so widgets can be called
#    def on_enter
#      $log.debug "ONENTER : #{@bgcolor} "
#    end
#    def on_leave
#      $log.debug "ONLEAVE : #{@bgcolor} "
#    end
    def getvalue
      @text_variable.nil? ? @text : @text_variable.get_value(@name)
    end

    # ensure text has been passed or action
    def getvalue_for_paint
      ret = getvalue
      @text_offset = @surround_chars[0].length
      @surround_chars[0] + ret + @surround_chars[1]
    end
    def repaint  # button
        #$log.debug("BUTTon repaint : #{self}  r:#{@row} c:#{@col} #{getvalue_for_paint}" )
        r,c = @row, @col #rowcol include offset for putting cursor
        @highlight_foreground ||= $reversecolor
        @highlight_background ||= 0
        bgcolor = @state==:HIGHLIGHTED ? @highlight_background : @bgcolor
        color = @state==:HIGHLIGHTED ? @highlight_foreground : @color
        if bgcolor.is_a? String and color.is_a? String
          color = ColorMap.get_color(color, bgcolor)
        end
        value = getvalue_for_paint
        #$log.debug("button repaint :#{self} r:#{r} c:#{c} col:#{color} bg #{bgcolor} v: #{value} ul #{@underline} mnem #{@mnemonic}")
        len = @display_length || value.length
        @graphic = @form.window if @graphic.nil? ## cell editor listbox hack XXX fix in correct place
        @graphic.printstring r, c, "%-*s" % [len, value], color, @attr
#       @form.window.mvchgat(y=r, x=c, max=len, Ncurses::A_NORMAL, bgcolor, nil)
        # in toggle buttons the underline can change as the text toggles
        if !@underline.nil? or !@mnemonic.nil?
          uline = @underline && (@underline + @text_offset) ||  value.index(@mnemonic) || value.index(@mnemonic.swapcase)
          $log.debug " mvchgat UNDERLI r= #{r} - #{@graphic.top} c #{c} c+x #{c+uline}- #{@graphic.left} #{@graphic} "
          #$log.debug " XXX HACK in next line related to UNDERLINES -graphic.top"
          y=r #-@graphic.top
          x=c+uline #-@graphic.left
          if @graphic.window_type == :PAD
            x -= @graphic.left
            y -= @graphic.top
          end
          raise "button underline location error #{x} , #{y} " if x < 0 or c < 0
          @graphic.mvchgat(y, x, max=1, Ncurses::A_BOLD|Ncurses::A_UNDERLINE, color, nil)
        end
    end
    ## command of button (invoked on press, hotkey, space)
    # added args 2008-12-20 19:22 
    def command *args, &block
      bind :PRESS, *args, &block
      $log.debug "#{text} bound PRESS"
    end
    ## fires PRESS event of button
    def fire
      $log.debug "firing PRESS #{text}"
      fire_handler :PRESS, @form
    end
    # Button
    def handle_key ch
      case ch
      when KEY_LEFT, KEY_UP
        return :UNHANDLED
        #  @form.select_prev_field
      when KEY_RIGHT, KEY_DOWN
        return :UNHANDLED
        #  @form.select_next_field
      when KEY_ENTER, 10, 13, 32  # added space bar also
        if respond_to? :fire
          fire
        end
      else
        return :UNHANDLED
      end
    end
    # temporary method, shoud be a proper class
    def self.button_layout buttons, row, startcol=0, cols=Ncurses.COLS-1, gap=5
      col = startcol
      buttons.each_with_index do |b, ix|
        $log.debug " BUTTON #{b}: #{b.col} "
        b.row = row
        b.col col
        $log.debug " after BUTTON #{b}: #{b.col} "
        len = b.text.length + gap
        col += len
      end
    end
  end #BUTTON
  
  ##
  # an event fired when an item that can be selected is toggled/selected
  class ItemEvent 
    # http://java.sun.com/javase/6/docs/api/java/awt/event/ItemEvent.html
    attr_reader :state   # :SELECTED :DESELECTED
    attr_reader :item   # the item pressed such as toggle button
    attr_reader :item_selectable   # item originating event such as list or collection
    attr_reader :item_first   # if from a list
    attr_reader :item_last   # 
    attr_reader :param_string   #  for debugging etc
=begin
    def initialize item, item_selectable, state, item_first=-1, item_last=-1, paramstring=nil
      @item, @item_selectable, @state, @item_first, @item_last =
        item, item_selectable, state, item_first, item_last 
      @param_string = "Item event fired: #{item}, #{state}"
    end
=end
    # i think only one is needed per object, so create once only
    def initialize item, item_selectable
      @item, @item_selectable =
        item, item_selectable
    end
    def set state, item_first=-1, item_last=-1, param_string=nil
      @state, @item_first, @item_last, @param_string =
        state, item_first, item_last, param_string 
      @param_string = "Item event fired: #{item}, #{state}" if param_string.nil?
    end
  end
  ##
  # A button that may be switched off an on. 
  # To be extended by RadioButton and checkbox.
  # TODO: add editable here nd prevent toggling if not so.
  class ToggleButton < Button
    dsl_accessor :onvalue, :offvalue
    dsl_accessor :value
    dsl_accessor :surround_chars 
    dsl_accessor :variable    # value linked to this variable which is a boolean
    dsl_accessor :display_length    #  2009-01-06 00:10 

    # item_event
    def initialize form, config={}, &block
      super
      # no longer linked to text_variable, that was a misunderstanding
      @value ||= (@variable.nil? ? false : @variable.get_value(@name)==true)
    end
    def getvalue
      @value ? @onvalue : @offvalue
    end
    ##
    # is the button on or off
    # added 2008-12-09 19:05 
    def checked?
      @value
    end
    alias :selected? :checked?

    def getvalue_for_paint
      buttontext = getvalue()
      @text_offset = @surround_chars[0].length
      @surround_chars[0] + buttontext + @surround_chars[1]
    end
    def handle_key ch
      if ch == 32
        toggle
      else
        super
      end
    end
    ##
    # toggle the button value
    def toggle
      fire
    end
    def fire
      checked(!@value)
      # added ItemEvent on 2008-12-31 13:44 
      @item_event = ItemEvent.new self, self if @item_event.nil?
      @item_event.set(@value ? :SELECTED : :DESELECTED)
      fire_handler :PRESS, @item_event # should the event itself be ITEM_EVENT
    #  fire_handler :PRESS, @form
    #  super
    end
    ##
    # set the value to true or false
    # user may programmatically want to check or uncheck
    def checked tf
      @value = tf
      if !@variable.nil?
        if @value 
          @variable.set_value((@onvalue || 1), @name)
        else
          @variable.set_value((@offvalue || 0), @name)
        end
      end
      # call fire of button class 2008-12-09 17:49 
    end
  end # class
  ##
  # A checkbox, may be selected or unselected
  # TODO hotkey should work here too.
  class CheckBox < ToggleButton
    dsl_accessor :align_right    # the button will be on the right 2008-12-09 23:41 
    # if a variable has been defined, off and on value will be set in it (default 0,1)
    def initialize form, config={}, &block
      @surround_chars = ['[', ']']    # 2008-12-23 23:16 added space in Button so overriding
      super
    end
    def getvalue
      @value 
    end
      
    def getvalue_for_paint
      buttontext = getvalue() ? "X" : " "
      dtext = @display_length.nil? ? @text : "%-*s" % [@display_length, @text]
      dtext = "" if @text.nil?  # added 2009-01-13 00:41 since cbcellrenderer prints no text
      if @align_right
        @text_offset = 0
        @col_offset = dtext.length + @surround_chars[0].length + 1
        return "#{dtext} " + @surround_chars[0] + buttontext + @surround_chars[1] 
      else
        pretext = @surround_chars[0] + buttontext + @surround_chars[1] 
        @text_offset = pretext.length + 1
        @col_offset = @surround_chars[0].length
        #@surround_chars[0] + buttontext + @surround_chars[1] + " #{@text}"
        return pretext + " #{dtext}"
      end
    end
  end # class
  ##
  # A selectable button that has a text value. It is based on a Variable that
  # is shared by other radio buttons. Only one is selected at a time, unlike checkbox
  # 2008-11-27 18:45 just made this inherited from Checkbox
  class RadioButton < ToggleButton
    dsl_accessor :align_right    # the button will be on the right 2008-12-09 23:41 
    # if a variable has been defined, off and on value will be set in it (default 0,1)
    def initialize form, config={}, &block
      @surround_chars = ['(', ')'] if @surround_chars.nil?
      super
    end
    # all radio buttons will return the value of the selected value, not the offered value
    def getvalue
      #@text_variable.value
      @variable.get_value @name
    end
    def getvalue_for_paint
      buttontext = getvalue() == @value ? "o" : " "
      dtext = @display_length.nil? ? text : "%-*s" % [@display_length, text]
      if @align_right
        @text_offset = 0
        @col_offset = dtext.length + @surround_chars[0].length + 1
        return "#{dtext} " + @surround_chars[0] + buttontext + @surround_chars[1] 
      else
        pretext = @surround_chars[0] + buttontext + @surround_chars[1] 
        @text_offset = pretext.length + 1
        @col_offset = @surround_chars[0].length
        return pretext + " #{dtext}"
      end
    end
    def toggle
      @variable.set_value @value, @name
      # call fire of button class 2008-12-09 17:49 
      fire
    end
    # added for bindkeys since that calls fire, not toggle - XXX i don't like this
    def fire
      @variable.set_value  @value,@name
      super
    end
    ##
    # ideally this should not be used. But implemented for completeness.
    # it is recommended to toggle some other radio button than to uncheck this.
    def checked tf
      if tf
        toggle
      elsif !@variable.nil? and getvalue() != @value # XXX ???
        @variable.set_value "",""
      end
    end
  end # class radio

  def self.startup
    VER::start_ncurses
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG
  end

end # module
