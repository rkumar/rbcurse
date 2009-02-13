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
require 'rbcurse/mapper'
require 'rbcurse/colormap'
#require 'rbcurse/rdialogs'
#require 'rbcurse/listcellrenderer'

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

include Ncurses
module RubyCurses
  extend self
  include ColorMap
    class FieldValidationException < RuntimeError
    end
    module Utils
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
        when ?\C-a .. ?\C-z
          return "C-" + (keycode + ?a -1).chr 
        when ?\M-A..?\M-z
          return "M-"+ (keycode - 128).chr
        when ?\M-\C-A..?\M-\C-Z
          return "M-C-"+ (keycode - 32).chr
        when ?\M-0..?\M-9
          return "M-"+ (keycode-?\M-0).to_s
        when 32:
          return "Space"
        when 27:
          return "Esc"
        when ?\C-]
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
        else
          others=[?\M--,?\M-+,?\M-=,?\M-',?\M-",?\M-;,?\M-:,?\M-\,, ?\M-.,?\M-<,?\M->]
          s_others=%w[M-- M-+ M-= M-' M-"   M-;   M-:   M-\, M-. M-<]
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
        #$log.debug " def fire_handler evt:#{event}, o: #{object}, #{self}, hdnler:#{@handler}"
        if !@handler.nil?
        #blk = @handler[event]
          ablk = @handler[event]
          if !ablk.nil?
            aeve = @event_args[event]
            ablk.each_with_index do |blk, ix|
              #$log.debug "#{self} called EventHandler firehander #{@name}, #{event}, obj: #{object},args: #{aeve[ix]}"
              blk.call object,  *aeve[ix]
            end
          end # if
        end # if
      end
      ## added on 2009-01-08 00:33 
      # goes with dsl_property
      # Need to inform listeners
    def fire_property_change text, oldvalue, newvalue
      #$log.debug " FPC #{self}: #{text} #{oldvalue}, #{newvalue}"
      @repaint_required = true
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
    dsl_property :text
    #dsl_accessor :text_variable
    #dsl_accessor :underline                        # offset of text to underline DEPRECATED
    dsl_property :width                # desired width of text
    #dsl_accessor :wrap_length                      # wrap length of text, if applic UNUSED

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
    attr_accessor :curpos              # cursor position inside object
    attr_reader  :config             # COULD GET AXED SOON NOTE
    attr_accessor  :form              # made accessor 2008-11-27 22:32 so menu can set
    attr_accessor :state              # normal, selected, highlighted
    attr_reader  :row_offset, :col_offset # where should the cursor be placed to start with
    dsl_property :visible # boolean     # 2008-12-09 11:29 
    #attr_accessor :modified          # boolean, value modified or not (moved from field 2009-01-18 00:14 )
    dsl_accessor :help_text          # added 2009-01-22 17:41 can be used for status/tooltips
    
    def initialize form, aconfig={}, &block
      @form = form
      @bgcolor ||=  "black" # 0
      @row_offset = @col_offset = 0
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
        @form.window.printstring r, c, "%-*s" % [len, value], acolor, @attr
        # next line should be in same color but only have @att so we can change att is nec
        #@form.window.mvchgat(y=r, x=c, max=len, Ncurses::A_NORMAL, @bgcolor, nil)
    end

    def destroy
      $log.debug "DESTROY : widget"
      panel = @window.panel
      Ncurses::Panel.del_panel(panel) if !panel.nil?   
      @window.delwin if !@window.nil?
    end
    # @ deprecated pls call windows method
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
    end
    # puts cursor on correct row.
    def set_form_row
      raise "empty todo widget"
    #  @form.row = @row + 1 + @winrow
      @form.row = @row + 1 
    end
    # set cursor on correct column, widget
    def set_form_col col=@curpos
      @curpos = col
      @form.col = @col + @col_offset + @curpos
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
    def bind_key keycode, *args, &blk
      $log.debug "called bind_key BIND #{keycode} #{keycode_tos(keycode)} #{args} "
      @key_handler ||= {}
      @key_args ||= {}
      @key_handler[keycode] = blk
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
    def process_key keycode, object
      return :UNHANDLED if @key_handler.nil?
      blk = @key_handler[keycode]
      return :UNHANDLED if blk.nil?
      #$log.debug "called process_key #{object}, #{@key_args[keycode]}"
      return blk.call object,  *@key_args[keycode]
      #0
    end
    ## 
    # to be added at end of handle_key of widgets so instlalled actions can be checked
    def handle_key(ch)
      ret = process_key ch, self
      return :UNHANDLED if ret == :UNHANDLED
    end
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
    def initialize win, &block
      @window = win
      @widgets = []
      @by_name = {}
      @active_index = -1
      @padx = @pady = 0
      @row = @col = -1
      @handler = {}
      @modified = false
      @focusable = true
      @navigation_policy ||= :CYCLICAL
      instance_eval &block if block_given?
      @firsttime = true # internal, don't touch
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

      @widgets << widget
      return @widgets.length-1
   end
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
      @widgets.each do |f|
        next if f.visible == false # added 2008-12-09 12:17 
        f.repaint
      end
      @window.clear_error
      @window.print_status_message $status_message unless $status_message.nil?
      @window.print_error_message $error_message unless $error_message.nil?
      $error_message = $status_message = nil
      #  this can bomb if someone sets row. We need a better way!
      if @row == -1 #or @firsttime == true
        #set_field_cursor 0
       $log.debug "form repaint calling select field 0"
        #select_field 0
        req_first_field
        #@firsttime = false
      end
       setpos 
       @window.wrefresh
    end
    ## 
    # move cursor to where the fields row and col are
    # private
    def setpos r=@row, c=@col
     # $log.debug "setpos : #{r} #{c}"
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
    ##
    # puts focus on the given field/widget index
    # XXX if called externally will not run a on_leave of previous field
    def select_field ix0
      return if @widgets.nil? or @widgets.empty? or !@widgets[ix0].focusable
#     $log.debug "insdie select  field :  #{ix0} ai #{@active_index}" 
      f = @widgets[ix0]
      if f.focusable
        @active_index = ix0
        @row, @col = f.rowcol
#       $log.debug "insdie sele nxt field : ROW #{@row} COL #{@col} " 
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
      #$log.debug "insdie sele nxt field :  #{@active_index} WL:#{@widgets.length}" 
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
        if f.focusable
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
          if f.focusable
            select_field i
            return
          end
        end
      end
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
        if f.focusable
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
          if f.focusable
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
    # move cursor by num columns
    def addcol num
      return if @col.nil? or @col == -1
      @col += num
      @window.wmove @row, @col
    end
    ##
    # move cursor by given rows and columns, can be negative.
    def addrowcol row,col
      return if @col.nil? or @col == -1
      return if @row.nil? or @row == -1
      @col += col
      @row += row
      @window.wmove @row, @col
    end
  ##
  # bind an action to a key, required if you create a button which has a hotkey
  # or a field to be focussed on a key, or any other user defined action based on key
  # e.g. bind_key ?\C-x, object, block
  def bind_key keycode, *args, &blk
    $log.debug "called bind_key BIND #{keycode} #{keycode_tos(keycode)} #{args} "
    @key_handler ||= {}
    @key_args ||= {}
    @key_handler[keycode] = blk
    @key_args[keycode] = args
  end

  # e.g. process_key ch, self
  # returns UNHANDLED if no block for it
  # after form handles basic keys, it gives unhandled key to current field, if current field returns
  # unhandled, then it checks this map.
  def process_key keycode, object
    return :UNHANDLED if @key_handler.nil?
    blk = @key_handler[keycode]
    return :UNHANDLED if blk.nil?
    $log.debug "called process_key #{object}, #{@key_args[keycode]}"
    blk.call object,  *@key_args[keycode]
    0
  end
  ## forms handle keys
  # mainly traps tab and backtab to navigate between widgets.
  # I know some widgets will want to use tab, e.g edit boxes for entering a tab
  #  or for completion.
  def handle_key(ch)
        case ch
        when -1
          return
        else
          field =  get_current_field
          handled = :UNHANDLED 
          handled = field.handle_key ch unless field.nil? # no field focussable
          # some widgets like textarea and list handle up and down
          if handled == :UNHANDLED or handled == -1 or field.nil?
            case ch
            when 9, ?\M-\C-i  # tab and M-tab in case widget eats tab (such as Table)
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
            else
              ret = process_key ch, self
              return :UNHANDLED if ret == :UNHANDLED
            end
          end
        end
       $log.debug " form before repaint"
       repaint
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

    ## ADD HERE FORM
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
    attr_reader :curpos              # cursor position in buffer current
    attr_accessor :datatype              # crrently set during set_buffer
    attr_reader :original_value              # value on entering field

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
      return -1 if !@editable or @buffer.length >= @maxlen
      if @chars_allowed != nil
        return if char.match(@chars_allowed).nil?
      end
      @buffer.insert(@curpos, char)
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
  def repaint
#    $log.debug("FIELD: #{id}, #{zorder}, #{focusable}")
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
    @form.window.printstring  row, col, sprintf("%-*s", display_length, printval), acolor, @attr
  end
  def set_focusable(tf)
    @focusable = tf
 #   @form.regenerate_focusables
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
    when ?\C-a
      cursor_home 
    when ?\C-e
      cursor_end 
    when ?\C-k
      delete_eol if @editable
    when ?\C-u
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
      $log.debug "Variable: update command set #{args}"
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
        ch = @mnemonic.downcase()[0]   ## FIXME 1.9
        # meta key 
        mch = ?\M-a + (ch - ?a)
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
        0.upto(_height-1) { |i| 
          @form.window.printstring r+i, c, " " * len , acolor,@attr
        }
        lablist.each_with_index do |_value, ix|
          break if ix >= _height
          if @justify.to_sym == :center
            padding = (@display_length - _value.length)/2
            _value = " "*padding + _value + " "*padding # so its cleared if we change it midway
          end
          @form.window.printstring r, c, str % [len, _value], acolor,@attr
          r += 1
        end
        if !@mnemonic.nil?
          ulindex = value.index(@mnemonic) || value.index(@mnemonic.swapcase)
          @form.window.mvchgat(y=firstrow, x=c+ulindex, max=1, Ncurses::A_BOLD|Ncurses::A_UNDERLINE, acolor, nil)
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
      #@command_block = nil
      @handler={} # event handler
      @event_args ||= {}
      super
      @bgcolor ||= $datacolor 
      @color ||= $datacolor 
      @surround_chars ||= ['[ ', ' ]'] 
      @col_offset = @surround_chars[0].length 
      #@text = @name if @text.nil?
      #bind_hotkey # 2008-12-23 22:41 remarked
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
    def mnemonic char
      $log.error " #{self} COULD NOT SET MNEMONIC since form NIL" if @form.nil?
      return if @form.nil?
      @mnemonic = char
      ch = char.downcase()[0] ## XXX 1.9 
      # meta key 
      mch = ?\M-a + (ch - ?a)
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
      ch = _value[@underline,1].downcase()[0] ## XXX 1.9 
      @mnemonic = _value[@underline,1]
      # meta key 
      mch = ?\M-a + (ch - ?a)
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
        @form.window.printstring r, c, "%-*s" % [len, value], color, @attr
#       @form.window.mvchgat(y=r, x=c, max=len, Ncurses::A_NORMAL, bgcolor, nil)
        # in toggle buttons the underline can change as the text toggles
        if !@underline.nil? or !@mnemonic.nil?
          uline = @underline && (@underline + @text_offset) ||  value.index(@mnemonic) || value.index(@mnemonic.swapcase)
          @form.window.mvchgat(y=r, x=c+uline, max=1, Ncurses::A_BOLD|Ncurses::A_UNDERLINE, color, nil)
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
        $log.debug " from 2009-01-16 18:18 buttons return UNHANDLED on UP DOWN LEFT RIGHT"
        return :UNHANDLED
        #  @form.select_prev_field
      when KEY_RIGHT, KEY_DOWN
        $log.debug " from 2009-01-16 18:18 buttons return UNHANDLED on UP DOWN LEFT RIGHT"
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
