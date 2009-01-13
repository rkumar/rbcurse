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
require 'lib/ver/ncurses'
require 'lib/ver/window'
require 'lib/rbcurse/mapper'
require 'lib/rbcurse/colormap'
require 'lib/rbcurse/rdialogs'
#require 'lib/rbcurse/listcellrenderer'

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
        else
          others=[?\M--,?\M-+,?\M-=]
          s_others=%w[M-- M-+ M-=]
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
        $log.debug "called EventHandler BIND #{event}, args:#{xargs} "
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
    
      ##
      # Fire all bindings for given event
      # e.g. fire_handler :ENTER, self
      # currently object usually contains self which is perhaps a bit of a waste,
      # could contain an event object with source, and some relevant methods or values
      def fire_handler event, object
        if !@handler.nil?
        #blk = @handler[event]
          ablk = @handler[event]
          if !ablk.nil?
            aeve = @event_args[event]
            ablk.each_with_index do |blk, ix|
              $log.debug "called EventHandler firehander #{@name}, #{event}, obj: #{object},args: #{aeve[ix]}"
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
  class Widget
    include DSL
    include EventHandler
    include ConfigSetup
    include RubyCurses::Utils
    dsl_property :text
    #dsl_accessor :text_variable
    dsl_accessor :underline                        # offset of text to underline DEPRECATED
    dsl_property :width                # desired width of text
    dsl_accessor :wrap_length                      # wrap length of text, if applic UNUSED

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
    attr_accessor :id, :zorder
    attr_accessor :curpos              # cursor position inside object
    attr_reader  :config
    attr_accessor  :form              # made accessor 2008-11-27 22:32 so menu can set
    attr_accessor :state              # normal, selected, highlighted
    attr_reader  :row_offset, :col_offset # where should the cursor be placed to start with
    dsl_property :visible # boolean     # 2008-12-09 11:29 
    
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

    # e.g. process_key ch, self
    # returns UNHANDLED if no block for it
    # after form handles basic keys, it gives unhandled key to current field, if current field returns
    # unhandled, then it checks this map.
    # added 2009-01-06 19:13 since widgets need to handle keys properly
    def process_key keycode, object
      return :UNHANDLED if @key_handler.nil?
      blk = @key_handler[keycode]
      return :UNHANDLED if blk.nil?
      $log.debug "called process_key #{object}, #{@key_args[keycode]}"
      blk.call object,  *@key_args[keycode]
      0
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
    def on_leave f
      return if f.nil?
      f.state = :NORMAL
      # on leaving update text_variable if defined. Should happen on modified only
      # should this not be f.text_var ... f.buffer ? XXX 2008-11-25 18:58 
      #f.text_variable.value = f.buffer if !f.text_variable.nil? # 2008-12-20 23:36 
      f.on_leave if f.respond_to? :on_leave
      fire_handler :LEAVE, f 
      ## to test XXX in combo boxes the box may not be editable by be modified by selection.
      if f.respond_to? :editable and f.modified
        $log.debug " Form about to fire CHANGED for #{f} "
        f.fire_handler(:CHANGED, f) 
      end
    end
    def on_enter f
      return if f.nil?
      f.state = :HIGHLIGHTED
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
        when 9
          ret = select_next_field
          return ret if ret == :NO_NEXT_FIELD
        when 353 ## backtab added 2008-12-14 18:41 
          ret = select_prev_field
          return ret if ret == :NO_PREV_FIELD
        else
          field =  get_current_field
          handled = field.handle_key ch unless field.nil? # no field focussable
          # some widgets like textarea and list handle up and down
          if handled == :UNHANDLED or handled == -1 or field.nil?
            case ch
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
  # TODO wrapping message
  # dimensions of window should be derived on content
  #
  class MessageBox
    include DSL
    include RubyCurses::Utils
    dsl_accessor :title
    dsl_accessor :message
    dsl_accessor :type               # :ok, :ok_cancel :yes_no :yes_no_cancel :custom
    dsl_accessor :default_button     # TODO - currently first
    dsl_accessor :layout
    dsl_accessor :buttons           # used if type :custom
    dsl_accessor :underlines           # offsets of each button to underline
    attr_reader :config
    attr_reader :selected_index     # button index selected by user
    attr_reader :window     # required for keyboard
    dsl_accessor :list_selection_mode  # true or false allow multiple selection
    dsl_accessor :list  # 2009-01-05 23:59 
    dsl_accessor :button_type      # ok, ok_cancel, yes_no
    dsl_accessor :default_value     # 
    dsl_accessor :default_values     # #  2009-01-06 00:05 after removing meth missing 
    dsl_accessor :height, :width, :top, :left  #  2009-01-06 00:05 after removing meth missing

    dsl_accessor :message_height


    def initialize form=nil, aconfig={}, &block
      @form = form
      @config = aconfig
      @buttons = []
      #@keys = {}
      @bcol = 5
      @selected_index = -1
      @config.each_pair { |k,v| instance_variable_set("@#{k}",v) }
      instance_eval &block if block_given?
      if @layout.nil? 
        case @type.to_s
        when "input"
          layout(10,60, 10, 20) 
        when "list"
          height = [5, @list.length].min 
          layout(10+height, 60, 5, 20)
        when "field_list"
          height = @field_list.length
          layout(10+height, 60, 5, 20)
        when "override"
          $log.debug " override: #{@height},#{@width}, #{@top}, #{@left} "
          layout(@height,@width, @top, @left) 
          $log.debug " override: #{@layout.inspect}"
        else
          height = @form && @form.widgets.length ## quick fix. FIXME
          height ||= 0
          layout(10+height,60, 10, 20) 
        end
      end
      @window = VER::Window.new(@layout)
      if @form.nil?
        @form = RubyCurses::Form.new @window
      else
        @form.window = @window
      end
      acolor = get_color $reversecolor
      $log.debug " MESSAGE BOX #{@bgcolor} , #{@color} , #{acolor}"
      @window.bkgd(Ncurses.COLOR_PAIR(acolor));
      @window.wrefresh
      @panel = @window.panel
      Ncurses::Panel.update_panels
      process_field_list
      print_borders
      print_title
      print_message unless @message.nil?
      print_input
      create_buttons
      @form.repaint
      @window.wrefresh
      handle_keys
    end
    ##
    # takes care of a field list sent in
    def process_field_list
      return if @field_list.nil? or @field_list.length == 0
      @field_list.each do |f|
        f.set_form @form
      end
    end
    def default_button offset0
      @selected_index = offset0
    end
    ##
    # value entered by user if type = input
    def input_value
      return @input.buffer if !@input.nil?
      return @listbox.getvalue if !@listbox.nil?
    end
    def create_buttons
      case @button_type.to_s.downcase
      when "ok"
        make_buttons ["&OK"]
      when "ok_cancel" #, "input", "list", "field_list"
        make_buttons %w[&OK &Cancel]
      when "yes_no"
        make_buttons %w[&Yes &No]
      when "yes_no_cancel"
        make_buttons ["&Yes", "&No", "&Cancel"]
      when "custom"
        make_buttons @buttons
      else
        $log.debug "No type passed for creating messagebox. Using default (OK)"
        make_buttons ["&OK"]
      end
    end
    def make_buttons names
      total = names.inject(0) {|total, item| total + item.length + 4}
      bcol = center_column total

      brow = @layout[:height]-3
      button_ct=0
      names.each_with_index do |bname, ix|
        text = bname
        #underline = @underlines[ix] if !@underlines.nil?

        button = Button.new @form do
          text text
          name bname
          row brow
          col bcol
          #underline underline
          highlight_background $datacolor 
          color $reversecolor
          bgcolor $reversecolor
        end
        index = button_ct
        button.command { |form| @selected_index = index; @stop = true; $log.debug "Pressed Button #{bname}";}
        button_ct += 1
        bcol += text.length+6
      end
    end
    ## message box
    def stopping?
      @stop
    end
    def handle_keys
      begin
        while((ch = @window.getchar()) != 999 )
          case ch
          when -1
            next
          else
            press ch
            break if @stop
          end
        end
      ensure
        destroy  
      end
      return @selected_index
    end
    def press ch
       #$log.debug "message box handle_keys :  #{ch}"  if ch != -1
        case ch
        when -1
          return
        when KEY_F1, 27, ?\C-q   
          @stop = true
          return
        when KEY_ENTER, 10, 13
          field =  @form.get_current_field
          if field.respond_to? :fire
            field.fire
          end
          $log.debug "popup ENTER : #{@selected_index} "
          $log.debug "popup ENTER :  #{field.name}" if !field.nil?
          @stop = true
          return
        when 9
          @form.select_next_field
        else
          # fields must return unhandled else we will miss hotkeys. 
          # On messageboxes, often if no edit field, then O and C are hot.
          field =  @form.get_current_field
          handled = field.handle_key ch

          if handled == :UNHANDLED
            ret = @form.process_key ch, self ## trying out trigger button
          end
        end
        @form.repaint
        Ncurses::Panel.update_panels();
        Ncurses.doupdate();
        @window.wrefresh
    end
    def print_borders
      width = @layout[:width]
      height = @layout[:height]
      @window.print_border_mb 1,2, height, width, $normalcolor, A_REVERSE
=begin
      start = 2
      hline = "+%s+" % [ "-"*(width-((start+1)*2)) ]
      hline2 = "|%s|" % [ " "*(width-((start+1)*2)) ]
      @window.printstring(row=1, col=start, hline, color=$reversecolor)
      (start).upto(height-2) do |row|
        @window.printstring row, col=start, hline2, color=$normalcolor, A_REVERSE
      end
      @window.printstring(height-2, col=start, hline, color=$reversecolor)
=end
    end
    def print_title title=@title
      width = @layout[:width]
      title = " "+title+" "
      @window.printstring(row=1,col=(width-title.length)/2,title, color=$normalcolor)
    end
    def center_column textlen
      width = @layout[:width]
      return (width-textlen)/2
    end
    def print_message message=@message, row=nil
      @message_row = @message_col = 2
      display_length = @layout[:width]-8
      # XXX this needs to go up and decide height of window
      if @message_height.nil?
        @message_height = (message.length/display_length)+1
        $log.debug " print_message: mh:#{@message_height}"
      end
      @message_height ||= 1
      width = @layout[:width]
      return if message.nil?
      case @type.to_s
      when "input" 
        row=(@layout[:height]/3) if row.nil?
        @message_col = 4
      when "list" 
        row=3
        @message_col = 4 
      else
        row=(@layout[:height]/3) if row.nil?
        @message_col = (width-message.length)/2
      end
      @message_row = row
      #@window.printstring( row, @message_col , message, color=$reversecolor)
      # 2008-12-30 19:45 experimenting with label so we can get justify and wrapping.
      #@window.printstring( row, @message_col , message, color=$reversecolor)
      message_label = RubyCurses::Label.new @form, {'text' => message, "name"=>"message_label","row" => row, "col" => @message_col, "display_length" => display_length,  "height" => @message_height, "attr"=>"reverse"}

    end
    def print_input
      #return if @type.to_s != "input"
      @message_height ||= 0
      @message_row ||= 2
      @message_col ||= 2
      r = @message_row + @message_height + 1
      c = @message_col
      defaultvalue = @default_value || ""
      input_config = @config["input_config"] || {}
      case @type.to_s 
      when "input"
        @input = RubyCurses::Field.new @form, input_config do
          name   "input" 
          row  r 
          col  c 
          display_length  30
          set_buffer defaultvalue
        end
      when "list"
        list = @list
        selection_mode = @list_selection_mode 
        default_values = @default_values
        $log.debug " value of select_mode #{selection_mode}"
        @listbox = RubyCurses::Listbox.new @form do
          name   "input" 
          row  r 
          col  c 
#         attr 'reverse'
          color 'black'
          bgcolor 'white'
          width 30
          height 6
          list  list
          # ?? display_length  30
          #set_buffer defaultvalue
          selection_mode selection_mode
          default_values default_values
          is_popup false
        end
      end
    end
    def configure(*val , &block)
      case val.size
      when 1
        return @config[val[0]]
      when 2
        @config[val[0]] = val[1]
        instance_variable_set("@#{val[0]}", val[1]) 
      end
      instance_eval &block if block_given?
    end
    def cget param
      @config[param]
    end

    def layout(height=0, width=0, top=0, left=0)
      @layout = { :height => height, :width => width, :top => top, :left => left } 
    end
    def destroy
      $log.debug "DESTROY : widget"
      panel = @window.panel
      Ncurses::Panel.del_panel(panel) if !panel.nil?   
      @window.delwin if !@window.nil?
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
    attr_accessor :modified          # boolean, value modified or not

    attr_reader :form
    attr_reader :handler             # event handler
    attr_reader :type                # datatype of field, currently only sets chars_allowed
    attr_reader :curpos              # cursor position in buffer current
    attr_accessor :datatype              # crrently set during set_buffer

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
      @curpos = 0                  # current cursor position in buffer
      @handler = {}
      @event_args = {}             # arguments passed at time of binding, to use when firing event
      @modified = false
      @pcol = 0   # needed for horiz scrolling
      super
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
    when KEY_UP
      @form.select_prev_field
    when KEY_DOWN
      @form.select_next_field
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
      $log.debug("FIELD: ch #{ch} ,at #{@curpos}, buffer:[#{@buffer}] bl: #{@buffer.to_s.length}")
      putc ch
    else
      return :UNHANDLED
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
    def set_modified tf=true
      @modified = tf
      @form.modified = true if tf
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
      super
      #return valid
    end
  # ADD HERE FIELD
  end
        ##
        # Like Tk's TkVariable, a simple proxy that can be passed to a widget. The widget 
        # will update the Variable. A variable can be used to link a field with a label or 
        # some other widget.
        # TODO: Currently it maintains a String, but it needs to be able to use a Hash or
        # Array at least.
        
  class Variable
    attr_reader :source  # optional source of updater passed in value= method
    def initialize value=""
      @update_command = []
      @args = []
      @value = value
    end
    ##
    # install trigger to call whenever a value is updated
    def update_command *args, &block
      $log.debug "Variable: update command set #{args}"
      @update_command << block
      @args << args
    end
#   def read_command &block
#     @read_command = block
#   end
    ##
    # value of the variable
    #def value
#     $log.debug "variable value called : #{@value} "
    #  @value
    #end
    ##
    # update the value of this variable.
    # 2008-12-31 18:35 Added source so one can identify multiple sources that are updating.
    # Idea is that mutiple fields (e.g. checkboxes) can share one var and update a hash through it.
    # Source would contain some code or key relatin to each field.
    def value (*val)
      return @value if val.empty?
      if val.size == 1
        @value,@source = val
      end
      $log.debug "variable value= called : #{val}, source=#{source} "
      return if @update_command.nil?
      @update_command.each_with_index do |comm, ix|
        comm.call(self, *@args[ix]) unless comm.nil?
      end
    end
    def value= (val)
      value val
    end
    ##
    # since we could put a hash or array in as @value
    def method_missing(sym, *args)
      if @value.respond_to? sym
        $log.debug("MISSING calling Variable  #{sym} called #{args[0]}")
        @value.send(sym, args)
      else
        $log.error("ERROR VARIABLE MISSING #{sym} called by #{self}")
        raise "ERROR VARIABLE MISSING #{sym} called by #{self}"
      end
    end
  end
  class RVariable
  
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
      $log.debug "RVariable: update command set #{args}"
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
        $log.debug " RVariable setting hash #{key} to #{val}"
        oldval = @value[key]
        @value[key]=val
      elsif @klass == 'Array'
        $log.debug " RVariable setting array #{key} to #{val}"
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
    # sets text, checking for ampersand, uses that for hotkey and underlines
    def text(*val)
      if val.empty?
        return @text
      else
        s = val[0]
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
    def on_enter
#      $log.debug "ONENTER : #{@bgcolor} "
    end
    def on_leave
#      $log.debug "ONLEAVE : #{@bgcolor} "
    end
    def getvalue
      @text_variable.nil? ? @text : @text_variable.get_value(@name)
    end

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
          @form.select_prev_field
      when KEY_RIGHT, KEY_DOWN
          @form.select_next_field
      when KEY_ENTER, 10, 13, 32  # added space bar also
        if respond_to? :fire
          fire
        end
      else
        return :UNHANDLED
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
  ##
  # When an event is fired by Listbox, contents are changed, then this object will be passed 
  # to trigger
  # shamelessly plugged from a legacy language best unnamed
  # type is CONTENTS_CHANGED, INTERVAL_ADDED, INTERVAL_REMOVED
  class ListDataEvent
    attr_accessor :index0, :index1, :source, :type
    def initialize index0, index1, source, type
      @index0 = index0
      @index1 = index1
      @source = source
      @type = type
    end
    def to_s
      "#{@type.to_s}, #{@source}, #{@index0}, #{@index1}"
    end
    def inspect
      "#{@type.to_s}, #{@source}, #{@index0}, #{@index1}"
    end
  end
  # http://www.java2s.com/Code/JavaAPI/javax.swing.event/ListDataEventCONTENTSCHANGED.htm
  # should we extend array of will that open us to misuse
  class ListDataModel
    include Enumerable
    include RubyCurses::EventHandler
    attr_accessor :selected_index

    def initialize anarray
      @list = anarray.dup
    end
    # not sure how to do this XXX 
    def each 
      @list.each { |item| yield item }
    end
    # not sure how to do this XXX 
    def <=>(other)
      @list <=> other
    end
    def index obj
      @list.index(obj)
    end
    def length ; @list.length; end

    def insert off0, *data
      @list.insert off0, *data
      lde = ListDataEvent.new(off0, off0+data.length-1, self, :INTERVAL_ADDED)
      fire_handler :LIST_DATA_EVENT, lde
    end
    def append data
      @list << data
      lde = ListDataEvent.new(@list.length-1, @list.length-1, self, :INTERVAL_ADDED)
      fire_handler :LIST_DATA_EVENT, lde
    end
    def update off0, data
      @list[off0] = data
      lde = ListDataEvent.new(off0, off0, self, :CONTENTS_CHANGED)
      fire_handler :LIST_DATA_EVENT, lde
    end
    def []=(off0, data)
      update off0, data
    end
    def [](off0)
      @list[off0]
    end
    def delete_at off0
      @list.delete off0
      lde = ListDataEvent.new(off0, off0, self, :INTERVAL_REMOVED)
      fire_handler :LIST_DATA_EVENT, lde
    end
    def remove_all
      @list = []
      lde = ListDataEvent.new(0, 0, self, :INTERVAL_REMOVED)
      fire_handler :LIST_DATA_EVENT, lde
    end
    def delete obj
      off0 = @list.index obj
      return if off0.nil?
      @list.delete off0
      lde = ListDataEvent.new(off0, off0, self, :INTERVAL_REMOVED)
      fire_handler :LIST_DATA_EVENT, lde
    end
    def include?(obj)
      return @list.include?(obj)
    end
    def values
      @list.dup
    end
    def on_enter_row object
      $log.debug " XXX on_enter_row of list_data"
      fire_handler :ENTER_ROW, object
    end
    alias :to_array :values
  end # class ListDataModel
  ## 
  # scrollable, selectable list of items
  # TODO Add events for item add/remove and selection change
  #  added event LIST_COMBO_SELECT fired whenever a select/deselect is done.
  #    - I do not know how this works in Tk so only the name is copied..
  #    - @selected contains indices of selected objects.
  #    - currently the first argument of event is row (the row selected/deselected). Should it
  #    be the object.
  #    - this event could change when range selection is allowed.
  #  
  # PLEASE USE NEWLISTBOX being deprecated
  class OldListbox < Widget
    require 'lib/rbcurse/scrollable'
    require 'lib/rbcurse/selectable'
    include Scrollable
    include Selectable
    dsl_accessor :height
    dsl_accessor :title
    dsl_accessor :title_attrib   # bold, reverse, normal
#   dsl_accessor :list    # the array of data to be sent by user
    attr_reader :toprow
    attr_reader :prow
    attr_reader :winrow
    dsl_accessor :selection_mode # allow multiple select or not
#   dsl_accessor :list_variable   # a variable values are shown from this
    dsl_accessor :default_values  # array of default values
    dsl_accessor :is_popup       # if it is in a popup and single select, selection closes

    def initialize form, config={}, &block
      @focusable = true
      @editable = false
      @row = 0
      @col = 0
      # data of listbox
      @list = []
      # any special attribs such as status to be printed in col1, or color (selection)
      @list_attribs = {}
      super
      @row_offset = @col_offset = 1
      @scrollatrow = @height -2
      @content_rows = @list.length
      @selection_mode ||= 'multiple'
      @win = @form.window
 #     @list = @list_variable.value unless @list_variable.nil?
      init_scrollable
      print_borders unless @win.nil?   # in messagebox we don;t have window as yet!
      # next 2 lines carry a redundancy
      select_default_values   
      # when the combo box has a certain row in focus, the popup should have the same row in focus
      set_focus_on (@list.selected_index || 0)
    end
    def list alist=nil
      return @list if alist.nil?
      @list = RubyCurses::ListDataModel.new(alist)
    end
    def list_variable alist=nil
      return @list if alist.nil?
      @list = RubyCurses::ListDataModel.new(alist.value)
    end
    def list_data_model ldm=nil
      return @list if ldm.nil?
      raise "Expecting list_data_model" unless ldm.is_a? RubyCurses::ListDataModel
      @list = ldm
    end

    def select_default_values
      return if @default_values.nil?
      @default_values.each do |val|
        row = @list.index val
        do_select(row) unless row.nil?
      end
    end
    def print_borders
      width = @width
      height = @height
      window = @form.window
      startcol = @col 
      startrow = @row 
      @color_pair = get_color($datacolor)
      window.print_border startrow, startcol, height, width, @color_pair, @attr
      print_title
=begin
      hline = "+%s+" % [ "-"*(width-((1)*2)) ]
      hline2 = "|%s|" % [ " "*(width-((1)*2)) ]
      window.printstring( row=startrow, col=startcol, hline, acolor)
      (startrow+1).upto(startrow+height-1) do |row|
        window.printstring( row, col=startcol, hline2, acolor)
      end
      window.printstring( startrow+height, col=startcol, hline, acolor)
=end 
     # @derwin = @form.window.derwin(@height, @width, @row, @col)
     # repaint
    end
    def print_title
      printstring(@form.window, @row, @col+(@width-@title.length)/2, @title, @color_pair, @title_attrib) unless @title.nil?
    end
    ### START FOR scrollable ###
    def get_content
      #@list 2008-12-01 23:13 
      @list_variable && @list_variable.value || @list 
    end
    def get_window
      @form.window
    end
    ### END FOR scrollable ###
    def repaint
      print_borders
      paint
    end
    # override widgets text
    def getvalue
      get_selected_data
    end
    # Listbox
    # [ ] scroll left right
    # if selectable is on, then spacebar will select, as will 'x'
    # otherwise spacebar pages, as does C-n
    def handle_key ch
      ret = selectable_handle_key ch
      if ret == :UNHANDLED
        ret = scrollable_handle_key ch
        if ret == :UNHANDLED
        end
      end
      return ret
    end # handle_k listb
    def on_enter_row arow
      $log.debug " Listbox #{self} FIRING ENTER_ROW with #{arow} H: #{@handler.keys}"
      #fire_handler :ENTER_ROW, arow
      fire_handler :ENTER_ROW, self
      @list.on_enter_row self
    end
    def on_leave_row arow
      $log.debug " Listbox #{self} FIRING leave with #{arow}"
      #fire_handler :LEAVE_ROW, arow
      fire_handler :LEAVE_ROW, self
    end
    # override widget so cursor is on focussed row. 2008-12-25 18:44 
    def set_form_row
      @form.row = @winrow + @row + 1
    end
  end # class listb

  ##
  # pops up a list of values for selection
  # 2008-12-10
  class PopupList
    include DSL
    include RubyCurses::EventHandler
    dsl_accessor :title
    dsl_accessor :row, :col, :height, :width
    dsl_accessor :layout
    attr_reader :config
    attr_reader :selected_index     # button index selected by user
    attr_reader :window     # required for keyboard
    dsl_accessor :list_selection_mode  # true or false allow multiple selection
    dsl_accessor :relative_to   # a widget, if given row and col are relative to widgets windows 
                                # layout
    dsl_accessor :max_visible_items   # how many to display
    dsl_accessor :list_config       # hash with values for the list to use 
    dsl_accessor :valign
    attr_reader :listbox

    def initialize aconfig={}, &block
      @config = aconfig
      @selected_index = -1
      @list_config ||= {}
      @config.each_pair { |k,v| instance_variable_set("@#{k}",v) }
      instance_eval &block if block_given?
      @list_config.each_pair { |k,v|  instance_variable_set("@#{k}",v) }
      @height ||= [@max_visible_items || 10, @list.length].min 
      #$log.debug " POPUP XXX #{@max_visible_items} ll:#{@list.length} h:#{@height}"
      # get widgets absolute coords
      if !@relative_to.nil?
        layout = @relative_to.form.window.layout
        @row = @row + layout[:top]
        @col = @col + layout[:left]
      end
      if !@valign.nil?
        case @valign.to_sym
        when :BELOW
          @row += 1
        when :ABOVE
          @row -= @height+1
          @row = 0 if @row < 0
        when :CENTER
          @row -= @height/2
          @row = 0 if @row < 0
        else
        end
      end

      layout(1+height, @width+4, @row, @col) # changed 2 to 1, 2008-12-17 13:48 
      @window = VER::Window.new(@layout)
      @form = RubyCurses::Form.new @window
      @window.bkgd(Ncurses.COLOR_PAIR($reversecolor));
      #@window.attron(Ncurses.COLOR_PAIR($reversecolor));
      #@window.wclear
      #@window.attroff(Ncurses.COLOR_PAIR($reversecolor));
      @window.wrefresh
      @panel = @window.panel
      Ncurses::Panel.update_panels
#     @message_row = @message_col = 2
#     print_borders
#     print_title
      print_input # creates the listbox
      @form.repaint
      @window.wrefresh
      handle_keys
    end
    def list alist=nil
      return @list if alist.nil?
      @list = ListDataModel.new(alist)
    end
    def list_data_model ldm
      raise "Expecting list_data_model" unless ldm.is_a? RubyCurses::ListDataModel
      @list = ldm
    end
    ##
    def input_value
      #return @listbox.getvalue if !@listbox.nil?
      return @listbox.focussed_index if !@listbox.nil?
    end
    ## popuplist
    def stopping?
      @stop
    end
    def handle_keys
      begin
        while((ch = @window.getchar()) != 999 )
          case ch
          when -1
            next
          else
            press ch
            break if @stop
          end
        end
      ensure
        destroy  
      end
      return 0 #@selected_index
    end
    ##
    # TODO get next match for key
    def press ch
       $log.debug "popup handle_keys :  #{ch}"  if ch != -1
        case ch
        when -1
          return
        when KEY_F1, 27, ?\C-q   # 27/ESC does not come here since gobbled by keyboard.rb
          @stop = true
          return
        when KEY_ENTER, 10, 13
          fire_handler :PRESS, @listbox.focussed_index
          # since Listbox is handling enter, COMBO_SELECT will not be fired
        # $log.debug "popup ENTER : #{@selected_index} "
        # $log.debug "popup ENTER :  #{field.name}" if !field.nil?
          @stop = true
          return
        when 9
          @form.select_next_field 
        else
          # fields must return unhandled else we will miss hotkeys. 
          # On messageboxes, often if no edit field, then O and C are hot.
          field =  @form.get_current_field
          handled = field.handle_key ch

          if handled == :UNHANDLED
              @stop = true
              return
          end
        end
        @form.repaint
        Ncurses::Panel.update_panels();
        Ncurses.doupdate();
        @window.wrefresh
    end
    def print_input
      r = c = 0
      width = @layout[:width]
      height = @layout[:height]
      height = @height
      parent = @relative_to
      defaultvalue = @default_value || ""
      list = @list
      selection_mode = @list_selection_mode 
      default_values = @default_values
      @list_config['color'] ||= 'black'
      @list_config['bgcolor'] ||= 'cyan'
        @listbox = RubyCurses::Listbox.new @form, @list_config do
          name   "input" 
          row  r 
          col  c 
#         attr 'reverse'
          width width
          height height
          list_data_model  list
# ?? XXX          display_length  30
#         set_buffer defaultvalue
          selection_mode selection_mode
          default_values default_values
          is_popup true
          #add_observer parent
          
        end
    end
    # may need to be upgraded to new one XXX FIXME
    def configure(*val , &block)
      case val.size
      when 1
        return @config[val[0]]
      when 2
        @config[val[0]] = val[1]
        instance_variable_set("@#{val[0]}", val[1]) 
      end
      instance_eval &block if block_given?
    end
    def cget param
      @config[param]
    end

    def layout(height=0, width=0, top=0, left=0)
      @layout = { :height => height, :width => width, :top => top, :left => left } 
    end
    def destroy
      #$log.debug "DESTROY : popuplist "
      @window.destroy if !@window.nil?
    end
  end # class PopupList
  ##
  # this is the new Listbox, based on new scrollable.
  #
  class Listbox < Widget
    require 'lib/rbcurse/listscrollable'
    require 'lib/rbcurse/listselectable'
    require 'lib/rbcurse/defaultlistselectionmodel'
    require 'lib/rbcurse/celleditor'
    include ListScrollable
    include ListSelectable
    dsl_accessor :height
    dsl_accessor :title
    dsl_accessor :title_attrib   # bold, reverse, normal
#   dsl_accessor :list    # the array of data to be sent by user
    attr_reader :toprow
  #  attr_reader :prow
  #  attr_reader :winrow
  #  dsl_accessor :selection_mode # allow multiple select or not
#   dsl_accessor :list_variable   # a variable values are shown from this
    dsl_accessor :default_values  # array of default values
    dsl_accessor :is_popup       # if it is in a popup and single select, selection closes
    attr_accessor :current_index
    #dsl_accessor :cell_renderer
    dsl_accessor :selected_color, :selected_bgcolor, :selected_attr
    dsl_accessor :max_visible_items   # how many to display 2009-01-11 16:15 
    dsl_accessor :cell_editing_allowed
    dsl_property :show_selector
    dsl_property :row_selected_symbol # 2009-01-12 12:01 changed from selector to selected
    dsl_property :row_unselected_symbol # added 2009-01-12 12:00 
    dsl_property :left_margin
    dsl_accessor :KEY_ROW_SELECTOR
    dsl_accessor :KEY_GOTO_TOP
    dsl_accessor :KEY_GOTO_BOTTOM
    dsl_accessor :KEY_CLEAR_SELECTION
    dsl_accessor :KEY_NEXT_SELECTION
    dsl_accessor :KEY_PREV_SELECTION

    def initialize form, config={}, &block
      @focusable = true
      @editable = false
      @row = 0
      @col = 0
      # data of listbox
      @list = []
      # any special attribs such as status to be printed in col1, or color (selection)
      @list_attribs = {}
      super
      @current_index ||= 0
      @row_offset = @col_offset = 1
      @content_rows = @list.length
      @selection_mode ||= 'multiple'
      @win = @form.window
      print_borders unless @win.nil?   # in messagebox we don;t have window as yet!
      # next 2 lines carry a redundancy
      select_default_values   
      # when the combo box has a certain row in focus, the popup should have the same row in focus
      set_focus_on (@list.selected_index || 0)
      init_vars
    end
    def init_vars
      @to_print_borders ||= 1
      @repaint_required = true
      @toprow = @pcol = 0
      @KEY_ROW_SELECTOR ||= ?\C-x
      @KEY_GOTO_TOP ||= ?\M-0
      @KEY_GOTO_BOTTOM ||= ?\M-9
      @KEY_CLEAR_SELECTION ||= ?\M-e
      if @show_selector
        @row_selected_symbol ||= '>'
        @row_unselected_symbol ||= ' '
        @left_margin ||= @row_selected_symbol.length
      end
      @left_margin ||= 0
    end

    ##
    # getter and setter for selection_mode
    # Must be called after creating model, so no duplicate. Since one may set in model directly.
    def selection_mode(*val)
      raise "ListSelectionModel not yet created!" if @list_selection_model.nil?
      if val.empty?
        @list_selection_model.selection_mode
      else
        @list_selection_model.selection_mode = val[0] 
      end
    end
    def row_count
      @list.length
    end
    # added 2009-01-07 13:05 so new scrollable can use
    def scrollatrow
      @height - 2
    end
    def list alist=nil
      return @list if alist.nil?
      @list = RubyCurses::ListDataModel.new(alist)
      create_default_list_selection_model
    end
    def list_variable alist=nil
      return @list if alist.nil?
      @list = RubyCurses::ListDataModel.new(alist.value)
      create_default_list_selection_model
    end
    def list_data_model ldm=nil
      return @list if ldm.nil?
      raise "Expecting list_data_model" unless ldm.is_a? RubyCurses::ListDataModel
      @list = ldm
      create_default_list_selection_model
    end

    def select_default_values
      return if @default_values.nil?
      @default_values.each do |val|
        row = @list.index val
        #do_select(row) unless row.nil?
        add_row_selection_interval row, row unless row.nil?
      end
    end
    def print_borders
      width = @width
      height = @height
      window = @form.window
      startcol = @col 
      startrow = @row 
      @color_pair = get_color($datacolor)
      window.print_border startrow, startcol, height, width, @color_pair, @attr
      print_title
    end
    def print_title
      printstring(@form.window, @row, @col+(@width-@title.length)/2, @title, @color_pair, @title_attrib) unless @title.nil?
    end
    ### START FOR scrollable ###
    def get_content
      #@list 2008-12-01 23:13 
      @list_variable && @list_variable.value || @list 
    end
    def get_window
      @form.window
    end
    ### END FOR scrollable ###
    # override widgets text
    def getvalue
      selected_rows
    end
    # Listbox
    def handle_key(ch)
      @current_index ||= 0
      @toprow ||= 0
      h = scrollatrow()
      rc = row_count
      case ch
      when KEY_UP  # show previous value
        previous_row
    #    @toprow = @current_index
      when KEY_DOWN  # show previous value
        next_row
      when @KEY_ROW_SELECTOR # 32:
        return if is_popup and @selection_mode == 'single' # not allowing select this way since there will be a difference 
        toggle_row_selection @current_index #, @current_index
        @repaint_required = true
      when ?\C-n:
        scroll_forward
      when ?\C-p:
        scroll_backward
      when @KEY_GOTO_TOP # 48, ?\C-[:
        # please note that C-[ gives 27, same as esc so will respond after ages
        goto_top
      when ?\C-]:
        goto_bottom
      when @KEY_NEXT_SELECTION # ?'
        $log.debug "insdie next selection"
        @oldrow = @current_index
        do_next_selection #if @select_mode == 'multiple'
        bounds_check
      when @KEY_PREV_SELECTION # ?"
        @oldrow = @current_index
        $log.debug "insdie prev selection"
        do_prev_selection #if @select_mode == 'multiple'
        bounds_check
      when @KEY_CLEAR_SELECTION
        clear_selection #if @select_mode == 'multiple'
        @repaint_required = true
      when 27, ?\C-c:
        editing_canceled @current_index
      else
        # this has to be fixed, if compo does not handle key it has to continue into next part FIXME
        if @cell_editing_allowed
          @repaint_required = true
          # hack - on_enter_row should fire when this widget gets focus. first row that is DONE
          begin
            @cell_editor.component.handle_key(ch)
          rescue
            on_enter_row @current_index
            @cell_editor.component.handle_key(ch)
          end
        else
          case ch
          when ?A..?Z, ?a..?z
            ret = set_selection_for_char ch.chr
          else
            ret = process_key ch, self
            return :UNHANDLED if ret == :UNHANDLED
          end
        end
      end
    end
    def on_enter
      on_enter_row @current_index
      set_form_row # added 2009-01-11 23:41 
      $log.debug " ONE ENTER LIST #{@current_index}, #{@form.row}"
      @repaint_required
      fire_handler :ENTER, self
    end
    def on_enter_row arow
      $log.debug " Listbox #{self} ENTER_ROW with curr #{@current_index}. row: #{arow} H: #{@handler.keys}"
      #fire_handler :ENTER_ROW, arow
      fire_handler :ENTER_ROW, self
      @list.on_enter_row self
      edit_row_at arow
      @repaint_required = true
    end
    def edit_row_at arow
      if @cell_editing_allowed
        #$log.debug " cell editor on enter #{arow} val of list[row]: #{@list[arow]}"
        editor = cell_editor
        prepare_editor editor, arow
      end
    end
    ## 
    def prepare_editor editor, row
      r,c = rowcol
      value =  @list[row] # .chomp
      value = value.dup rescue value # so we can cancel
      row = r + (row - @toprow) #  @form.row
      col = c+@left_margin # @form.col
      # unfortunately 2009-01-11 19:47 combo boxes editable allows changing value
      editor.prepare_editor self, row, col, value
      set_form_col @left_margin

      # set original value so we can cancel
      # set row and col,
      # set value and other things, color and bgcolor
    end
    def on_leave_row arow
      $log.debug " Listbox #{self} leave with (cr: #{@current_index}) #{arow}: list[row]:#{@list[arow]}"
      #fire_handler :LEAVE_ROW, arow
      fire_handler :LEAVE_ROW, self
      editing_completed arow
    end
    def editing_completed arow
      if @cell_editing_allowed
        if !@cell_editor.nil?
      #    $log.debug " cell editor (leave) setting value row: #{arow} val: #{@cell_editor.getvalue}"
          @list[arow] = @cell_editor.getvalue #.dup 2009-01-10 21:42 boolean can't duplicate
        else
          $log.debug "CELL EDITOR WAS NIL, #{arow} "
        end
      end
      @repaint_required = true
    end
    def editing_canceled arow
      prepare_editor @cell_editor, arow
      @repaint_required = true
    end

    ##
    # getter and setter for cell_editor
    def cell_editor(*val)
      if val.empty?
        @cell_editor ||= create_default_cell_editor
      else
        @cell_editor = val[0] 
      end
    end
    def create_default_cell_editor
      return RubyCurses::CellEditor.new RubyCurses::Field.new nil, {"focusable"=>false, "visible"=>false, "display_length"=> @width-2-@left_margin}
    end
    ##
    # getter and setter for cell_renderer
    def cell_renderer(*val)
      if val.empty?
        @cell_renderer ||= create_default_cell_renderer
      else
        @cell_renderer = val[0] 
      end
    end
    def create_default_cell_renderer
      return RubyCurses::ListCellRenderer.new "", {"color"=>@color, "bgcolor"=>@bgcolor, "parent" => self, "display_length"=> @width-2-@left_margin}
    end
    def repaint
      return unless @repaint_required
      print_borders if @to_print_borders == 1 # do this once only, unless everything changes
      rc = row_count
      maxlen = @maxlen ||= @width-2
      tm = @list
      tr = @toprow
      acolor = get_color $datacolor
      h = scrollatrow()
      r,c = rowcol
      0.upto(h) do |hh|
        crow = tr+hh
        if crow < rc
            focussed = @current_index == crow ? true : false 
            selected = is_row_selected crow
            content = tm[crow]
            if content.is_a? String
              content.chomp!
              content.gsub!(/\t/, '  ') # don't display tab
              content.gsub!(/[^[:print:]]/, '')  # don't display non print characters
              if !content.nil? 
                if content.length > maxlen # only show maxlen
                  content = content[@pcol..@pcol+maxlen-1] 
                else
                  content = content[@pcol..-1]
                end
              end
            elsif content.is_a? TrueClass or content.is_a? FalseClass
            else
              content = content.to_s
            end
            ## set the selector symbol if requested
            selection_symbol = ''
            if @show_selector
              if selected
                selection_symbol = @row_selected_symbol
              else
                selection_symbol =  @row_unselected_symbol
              end
              @form.window.printstring r+hh, c, selection_symbol, acolor,@attr
            end
            #renderer = get_default_cell_renderer_for_class content.class.to_s
            renderer = cell_renderer()
            #renderer.show_selector @show_selector
            #renderer.row_selected_symbol @row_selected_symbol
            #renderer.left_margin @left_margin
            #renderer.repaint @form.window, r+hh, c+(colix*11), content, focussed, selected
            renderer.repaint @form.window, r+hh, c+@left_margin, content, focussed, selected
        else
          # clear rows
          @form.window.printstring r+hh, c, " " * (@width-2), acolor,@attr
        end
      end
      if @cell_editing_allowed
        @cell_editor.component.repaint unless @cell_editor.nil? or @cell_editor.component.form.nil?
      end
      @table_changed = false
      @repaint_required = false
    end

  end # class listb

  def self.startup
    VER::start_ncurses
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG
  end

end # module
