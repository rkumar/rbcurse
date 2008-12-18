=begin
  * Name: rwidget: base class and then popup and other derived widgets
  * $Id$
  * Description   
    Some simple light widgets for creating ncurses applications. No reliance on ncurses
    forms and fields.
        I expect to pass through this world but once. Any good therefore that I can do, 
        or any kindness or ablities that I can show to any fellow creature, let me do it now. 
        Let me not defer it or neglect it, for I shall not pass this way again.  
  * Author: rkumar
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
require 'lib/ver/keyboard2'
require 'lib/ver/window'
require 'lib/rbcurse/mapper'
require 'lib/rbcurse/keylabelprinter'
require 'lib/rbcurse/commonio'
require 'lib/rbcurse/colormap'
#require 'lib/rbcurse/rform'

module DSL
## others may not want this, if = sent, it creates DSL and sets
  def method_missing(sym, *args)
    $log.debug "METHOD MISSING : #{sym} "
#   raise "METH MISSING #{sym}"
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

end

include Ncurses
module RubyCurses
  extend self
  include ColorMap
    class FieldValidationException < RuntimeError
    end

    module EventHandler
      ##
      # bind an event to a block, optional args will also be passed when calling
      def bind event, *xargs, &blk
        $log.debug "called EventHandler BIND #{event}, args:#{xargs} "
        @handler ||= {}
        @event_args ||= {}
        @handler[event] = blk
        @event_args[event] = xargs
      end
    
      # e.g. fire_handler :ENTER, self
      def fire_handler event, object
        return if @handler.nil?
        blk = @handler[event]
        return if blk.nil?
        $log.debug "called EventHandler firehander #{@name}, #{event}, obj: #{object},args: #{@event_args[event]}"
        blk.call object,  *@event_args[event]
      end
    end
  class Widget
    include CommonIO
    include DSL
    dsl_accessor :text, :text_variable
    dsl_accessor :underline                        # offset of text to underline
    dsl_accessor :width                # desired width of text
    dsl_accessor :wrap_length                      # wrap length of text, if applic
    dsl_accessor :select_foreground, :select_background  # color init_pair
    dsl_accessor :highlight_foreground, :highlight_background  # color init_pair
    dsl_accessor :disabled_foreground, :disabled_background  # color init_pair
    dsl_accessor :focusable, :enabled # boolean
    dsl_accessor :row, :col            # location of object
    dsl_accessor :color, :bgcolor      # normal foreground and background
    dsl_accessor :attr                 # attribute bold, normal, reverse
    dsl_accessor :name                 # name to refr to or recall object by_name
    attr_accessor :id, :zorder
    attr_accessor :curpos              # cursor position inside object
    attr_reader  :config
    attr_accessor  :form              # made accessor 2008-11-27 22:32 so menu can set
    attr_accessor :state              # normal, selected, highlighted
    attr_reader  :row_offset, :col_offset # where should the cursor be placed to start with
    dsl_accessor :visible # boolean     # 2008-12-09 11:29 
    
    def initialize form, aconfig={}, &block
      @form = form
      @bgcolor ||=  "black" # 0
      @row_offset = @col_offset = 0
      @state = :NORMAL
      @color ||= "white" # $datacolor
      @attr = nil
      @handler = {}
      @event_args = {}
      @config = aconfig
      @config.each_pair { |k,v| variable_set(k,v) }
      instance_eval &block if block_given?
      @id = form.add_widget(self) if !form.nil? and form.respond_to? :add_widget
    end
    ## got left out by mistake 2008-11-26 20:20 
    def bind event, *args, &blk
      $log.debug "called widget #{id} BIND #{event} #{args} "
      @handler[event] = blk
      @event_args[event] = args
    end
    ## got left out by mistake 2008-11-26 20:20 
    def fire_handler event, object
      blk = @handler[event]
      return if blk.nil?
      $log.debug "called widget firehander #{object}, #{@event_args[event]}"
      blk.call object,  *@event_args[event]
    end
    ## got left out by mistake 2008-11-26 20:20 
    def on_enter
      fire_handler :ENTER, self
    end
    ## got left out by mistake 2008-11-26 20:20 
    def on_leave
      fire_handler :LEAVE, self
    end
    # private
    def variable_set var, val
        var = "@#{var}"
        instance_variable_set(var, val) 
    end
    # private
    def rowcol
    # $log.debug "widgte rowcol : #{@row+@row_offset}, #{@col+@col_offset}"
      return @row+@row_offset, @col+@col_offset
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
      $log.debug "att #{att}"

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
    # set cursor on correct column
    def set_form_col col=@cursor
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
      @form.select_field @id
    end
    ## ADD HERE WIDGET
  end

  class Form
  include CommonIO
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
    end
    def set_menu_bar mb
      @menu_bar = mb
      add_widget mb
    end
    def add_widget widget
      if widget.respond_to? :name and !widget.name.nil?
        #       $log.debug "adding to byname: #{widget.name} " 
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
      if @row == -1
        #set_field_cursor 0
       $log.debug "form repaint calling select field 0"
        #select_field 0
        req_first_field
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
    def on_leave f
      return if f.nil?
      f.state = :NORMAL
      # on leaving update text_variable if defined. Should happen on modified only
      # should this not be f.text_var ... f.buffer ? XXX 2008-11-25 18:58 
      @text_variable.value = @buffer if !@text_variable.nil?
      f.on_leave if f.respond_to? :on_leave
      fire_handler :LEAVE, f 
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
      return if @widgets.nil? or @widgets.empty?
#     $log.debug "insdie select  field :  #{ix0} ai #{@active_index}" 
      @active_index = ix0
      f = @widgets[@active_index]
      if f.focusable
        on_enter f
        @row, @col = f.rowcol
#       $log.debug "insdie sele nxt field : ROW #{@row} COL #{@col} " 
        @window.wmove @row, @col
        f.curpos = 0
        repaint
        @window.refresh
      else
        $log.debug "insdie sele nxt field ENABLED FALSE : prev #{previtem} act #{@active_index}  #{ix0}" 
      end
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
         $log.debug " caught EXCEPTION #{err}"
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
        select_next_field
      else
        return :NO_NEXT_FIELD
      end
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
      if @navigation_policy == :CYCLICAL
        @active_index = nil # HACK !!!
        select_prev_field
      else
        return :NO_PREV_FIELD
      end
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
  def bind event, &blk
   $log.debug "called form bind #{event} PLEASE ADD args here"
    @handler[event] = blk
  end
  def fire_handler event, object
#   $log.debug "called form firehander #{object}"
    blk = @handler[event]
    return if blk.nil?
    blk.call object
  end
  ##
  # bind an action to a key, required if you create a button which has a hotkey
  # or a field to be focussed on a key, or any other user defined action based on key
  # e.g. bind_key ?\C-x, object, block
  def bind_key keycode, *args, &blk
    $log.debug "called bind_key BIND #{keycode} #{args} "
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
          # user should degine what key he wants to map menu bar to XXX
        when KEY_F2
          if !@menu_bar.nil?
            @menu_bar.toggle
            @menu_bar.handle_keys
          end
        when 9
          ret = select_next_field
          return ret if ret == :NO_NEXT_FIELD
        when 353 ## backtab added 2008-12-14 18:41 
          ret = select_prev_field
          return ret if ret == :NO_PREV_FIELD
        else
          field =  get_current_field
          handled = field.handle_key ch
          # some widgets like textarea and list handle up and down
          if handled == :UNHANDLED or handled == -1
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
    include CommonIO
    include DSL
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
    dsl_accessor :list_select_mode  # true or false allow multiple selection

    def initialize aconfig={}, &block
      @config = aconfig
      @buttons = []
      @keys = {}
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
        else
          layout(10,60, 10, 20) 
        end
      end
      @window = VER::Window.new(@layout)
      @form = RubyCurses::Form.new @window
      #@window.bkgd(Ncurses.COLOR_PAIR(@bgcolor || $reversecolor));
      @window.bkgd(Ncurses.COLOR_PAIR($reversecolor));
      @window.wrefresh
      @panel = @window.panel
      Ncurses::Panel.update_panels
      process_field_list
      print_borders
      print_title
      print_message
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
      case @type.to_s.downcase
      when "ok"
        @underlines = [0]
        make_buttons ["OK"]
      when "ok_cancel", "input", "list", "field_list"
        @underlines = [0,0]
        make_buttons %w[OK Cancel]
      when "yes_no"
        @underlines = [0,0]
        make_buttons %w[Yes No]
      when "yes_no_cancel"
        @underlines = [0,0,0]
        make_buttons ["Yes", "No", "Cancel"]
      when "custom"
        make_buttons @buttons
      else
        $log.debug "No type passed for creating messagebox. Using default"
        @underlines = [0]
        make_buttons ["OK"]
      end
    end
    def make_buttons names
      total = names.inject(0) {|total, item| total + item.length + 4}
      bcol = center_column total

      brow = @layout[:height]-3
      button_ct=0
      names.each_with_index do |bname, ix|
        text = bname
        if !@underlines.nil?
          underline = @underlines[ix] if !@underlines.nil?
         ch = text[underline,1].downcase()[0]
        @keys[ch] = ix  # underlined key points to index of button
        $log.debug "text #{text} #{text[underline,1]}   "
        # trap the meta key also, since the box could have an input field
         mch = ?\M-a + (ch - ?a)
         $log.debug "mch meta : #{mch},  #{ch}"
         @keys[mch] = ix  # underlined key points to index of button
        end

        button = Button.new @form do
          text text
          name bname
          row brow
          col bcol
          underline underline
          highlight_background $datacolor 
          color $reversecolor
          bgcolor $reversecolor
        end
        index = button_ct
        button.command { |form| @selected_index = index; $log.debug "Pressed Button #{bname}";}
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
        $log.debug " keyhandler is now messagebox "
        VER::Keyboard2.focus = self
      ensure
        $log.debug " destroy of is now messagebox "
        destroy  # XXX
      end
      return @selected_index
    end
    def press ch
       $log.debug "message box handle_keys :  #{ch}"  if ch != -1
        case ch
        when -1
          return
        when KEY_F1, 27, ?\C-q   # 27/ESC does not come here since gobbled by keyboard.rb
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
            if @keys.include? ch
              ## XXX I should be firing the button also
              $log.debug "KEY #{ch} caught - PLS FIRE THE BUTTON"
              @selected_index = @keys[ch]
              @stop = true
              return
            end
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
      start = 2
      hline = "+%s+" % [ "-"*(width-((start+1)*2)) ]
      hline2 = "|%s|" % [ " "*(width-((start+1)*2)) ]
      printstr(@window, row=1, col=start, hline, color=$reversecolor)
      (start).upto(height-2) do |row|
        #printstr(@window, row, col=start, hline2, color=$reversecolor)
        @window.printstring row, col=start, hline2, color=$normalcolor, A_REVERSE
      end
      printstr(@window, height-2, col=start, hline, color=$reversecolor)
    end
    def print_title title=@title
      width = @layout[:width]
      title = " "+title+" "
      printstr(@window, row=1,col=(width-title.length)/2,title, color=$normalcolor)
    end
    def OLDcenter_column text
      width = @layout[:width]
      return (width-text.length)/2
    end
    def center_column textlen
      width = @layout[:width]
      return (width-textlen)/2
    end
    def print_message message=@message, row=nil
      @message_row = @message_col = 2
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
      width = @layout[:width]
      printstr(@window, row, @message_col , message, color=$reversecolor)
    end
    def print_input
      #return if @type.to_s != "input"
      r = @message_row + 1
      c = @message_col
      defaultvalue = @default_value || ""
      case @type.to_s 
      when "input"
        @input = RubyCurses::Field.new @form do
          name   "input" 
          row  r 
          col  c 
          display_length  30
          set_buffer defaultvalue
        end
      when "list"
        list = @list
        select_mode = @list_select_mode 
        default_values = @default_values
        $log.debug " value of select_mode #{select_mode}"
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
          display_length  30
          set_buffer defaultvalue
          select_mode select_mode
          default_values default_values
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
  # TODO - test text_variable
  class Field < Widget
    include CommonIO
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
    attr_reader :form
    attr_accessor :modified          # boolean, value modified or not
    attr_reader :handler             # event handler
    attr_reader :type                # datatype of field, currently only sets chars_allowed
    attr_reader :curpos              # cursor position in buffer current

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
      fire_handler :CHANGE, self    # 2008-12-09 14:51 
      0
    end

    def putc c
      if c >= 0 and c <= 127
        ret = putch c.chr
        if ret == 0
          addcol 1
          set_modified 
        end
      end
      return -1
    end
    def delete_at index=@curpos
      return -1 if !@editable 
      @buffer.slice!(index,1)
      @modified = true
      fire_handler :CHANGE, self    # 2008-12-09 14:51 
    end
    ## 
    # should this do a dup ??
    def set_buffer value
      @buffer = value
    end
    def getvalue
      @buffer
    end
  
  def set_label label
    @label = label
    label.row = @row if label.row == -1
    label.col = @col-(label.name.length+1) if label.col == -1
  end
  def repaint
#    $log.debug("FIELD: #{id}, #{zorder}, #{focusable}")
    printval = getvalue_for_paint
    printval = show()*printval.length unless @show.nil?
    printval = printval[0..display_length-1] if printval.length > display_length
        if @bgcolor.is_a? String and @color.is_a? String
          acolor = ColorMap.get_color(@color, @bgcolor)
        else
          acolor = $datacolor
        end
    #printstr @form.window, row, col, sprintf("%-*s", display_length, printval), color
    @form.window.printstring  row, col, sprintf("%-*s", display_length, printval), acolor, @attrs
    #@form.window.mvchgat(y=row, x=col, max=display_length, Ncurses::A_NORMAL, bgcolor, nil)
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
      delete_prev_char
    when KEY_UP
      @form.select_prev_field
    when KEY_DOWN
      @form.select_next_field
    when KEY_ENTER, 10, 13
      if respond_to? :fire
        fire
      end
    when 330
      delete_curr_char
    when ?\C-a
      cursor_home 
    when ?\C-e
      cursor_end 
    when ?\C-k
      delete_eol
    when ?\C-u
      @buffer.insert @curpos, @delete_buffer unless @delete_buffer.nil?
    when 32..126
      $log.debug("ch #{ch}")
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
  end
  ##
  # goto end of field, "end" is a keyword so could not use it.
  def cursor_end
    set_form_col @buffer.length
  end
  def delete_eol
    pos = @curpos-1
    @delete_buffer = @buffer[@curpos..-1]
    # if pos is 0, pos-1 becomes -1, end of line!
    @buffer = pos == -1 ? "" : @buffer[0..pos]
    fire_handler :CHANGE, self    # 2008-12-09 14:51 
    return @delete_buffer
  end
  def cursor_forward
    if @curpos < @buffer.length  # display_length -> prevent crashes if person tries entering
      @curpos += 1
      addcol 1
    end
  end
  def cursor_backward
    if @curpos > 0
      @curpos -= 1
      addcol -1
    end
  end
    def delete_curr_char
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
      @form.addcol num
    end
    # upon leaving a field
    # returns false if value not valid as per values or valid_regex
    def on_leave
      val = getvalue
      $log.debug " FIELD ON LEAVE:#{val}. #{@values.inspect}"
      valid = true
      if !@values.nil?
        valid = @values.include? val
        raise FieldValidationException, "Field value (#{val}) not in values: #{@values.join(',')}" unless valid
      end
      if !@valid_regex.nil?
        valid = @valid_regex.match(val)
        raise FieldValidationException, "Field not matching regex #{@valid_regex}" unless valid
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
    def initialize value=""
      @update_command = nil
      @args = nil
      @value = value
    end
    ##
    # trigger to call whenever a value is updated
    def update_command *args, &block
      $log.debug "update command set #{args}"
      @update_command = block
      @args = args
    end
#   def read_command &block
#     @read_command = block
#   end
    def value
#     $log.debug "variable value called : #{@value} "
      @value
    end
    def value= val
      $log.debug "variable value= called : #{val} "
      @value = val
      @update_command.call(self, *@args) if !@update_command.nil?
    end
    ##
    # since we could put a hash or array in as @value
    def method_missing(sym, *args)
      if @value.respond_to? sym
        $log.debug("MISSING calling variable  #{sym} called #{args[0]}")
        @value.send(sym, args)
      else
        $log.error("ERROR VARIABLE MISSING #{sym} called")
      end
    end
  end
  class Label < Widget
    include CommonIO

    def initialize form, config={}, &block
    # @form = form
      @row = config.fetch("row",-1) 
      @col = config.fetch("col",-1) 
      @bgcolor = config.fetch("bgcolor", $def_bg_color)
      @color = config.fetch("color", $def_fg_color)
      @text = config.fetch("text", "NOTFOUND")
      @name = config.fetch("name", @text)
      @editable = false
      @focusable = false
      super
    end
    def getvalue
      @text_variable && @text_variable.value || @text
    end
    def repaint
        r,c = rowcol
        value = getvalue_for_paint
        len = @display_length || value.length
        if @bgcolor.is_a? String and @color.is_a? String
          acolor = ColorMap.get_color(@color, @bgcolor)
        else
          acolor = $datacolor
        end
#    $log.debug "label :#{@text}, #{value}, #{r}, #{c} col= #{@color}, #{@bgcolor} acolor  #{acolor} "
        @form.window.printstring r, c, "%-*s" % [len, value], acolor,@attrs
        #@form.window.mvchgat(y=r, x=c, max=len, Ncurses::A_NORMAL, color, nil)
    end
  # ADD HERE LABEL
  end
  class Button < Widget
  include CommonIO
  dsl_accessor :surround_chars   # characters to use to surround the button, def is square brackets
    def initialize form, config={}, &block
      @focusable = true
      @editable = false
      #@command_block = nil
      @handler={} # event handler
      super
      @bgcolor ||= $datacolor 
      @color ||= $datacolor 
      @surround_chars ||= ['[', ']'] 
      @text = @name if @text.nil?
      bind_hotkey
    end
    # bind hotkey to form keys. added 2008-12-15 20:19 
    # use ampersand in name or underline
    def bind_hotkey
      return if @underline.nil? or @form.nil?
      _value = @text
      $log.debug " bind hot #{_value} #{@underline}"
      ch = _value[@underline,1].downcase()[0] ## XXX 1.9 
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
      @text_variable.nil? ? @text : @text_variable.value
    end

    def getvalue_for_paint
      ret = getvalue
      @surround_chars[0] + ret + @surround_chars[1]
    end
    def repaint  # button
#       $log.debug("BUTTon repaint : #{self.class()}  r:#{@row} c:#{@col} #{getvalue_for_paint}" )
        r,c = rowcol
        @highlight_foreground ||= $reversecolor
        @highlight_background ||= 0
        bgcolor = @state==:HIGHLIGHTED ? @highlight_background : @bgcolor
        color = @state==:HIGHLIGHTED ? @highlight_foreground : @color
        if bgcolor.is_a? String and color.is_a? String
          color = ColorMap.get_color(color, bgcolor)
        end
        value = getvalue_for_paint
#       $log.debug("button repaint : r:#{r} c:#{c} col:#{color} bg #{bgcolor} v: #{value} ")
        len = @display_length || value.length
        @form.window.printstring r, c, "%-*s" % [len, value], color, @attrs
#       @form.window.mvchgat(y=r, x=c, max=len, Ncurses::A_NORMAL, bgcolor, nil)
        if @underline != nil
        #printstring @form.window, r, c+@underline+1, "%-*s" % [1, value[@underline+1,1]], color, 'bold'
        #  @form.window.mvprintw(r, c+@underline+1, "\e[4m %s \e[0m", value[@underline+1,1]);
       # underline not working here using Ncurses. Works with highline. \e[4m
          @form.window.mvchgat(y=r, x=c+@underline+1, max=1, Ncurses::A_BOLD|Ncurses::A_UNDERLINE, color, nil)
        end
    end
    # XXX FIXME always store args also
    def command &block
      #@command_block = block
      bind :PRESS, &block
      $log.debug "#{text} bound PRESS"
      #instance_eval &block if block_given?
    end
    ## XXX FIXME
    # to return self and args when firing
    def fire
      #@form.instance_eval(&@command_block) if !@command_block.nil?
      #@command_block.call @form  if !@command_block.nil?
      $log.debug "firing PRESS #{text}"
      fire_handler :PRESS, @form
    end
    ## XXX bind args always
    def bind event, &blk
      @handler[event] = blk
    end
    ## XXX FIXME
    # to return self and args when firing
    def fire_handler event, object
      $log.debug "called firehander #{object}"
      blk = @handler[event]
      return if blk.nil?
      blk.call object
    end
    # Button
    def handle_key ch
      case ch
      when KEY_LEFT, KEY_UP
        #@form.req_prev_field
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
  # A button that may be switched off an on. 
  # To be extended by RadioButton and checkbox.
  class ToggleButton < Button
    include CommonIO
    dsl_accessor :onvalue, :offvalue
    dsl_accessor :value
    dsl_accessor :surround_chars 
    def initialize form, config={}, &block
      super
      @value ||= false
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
    def getvalue_for_paint
      buttontext = getvalue()
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
      checked(!@value)
    end
    ##
    # set the value to true or false
    # user may programmatically want to check or uncheck
    def checked tf
      @value = tf
      if !@text_variable.nil?
        if @value 
          @text_variable.value = (@onvalue || 1)
        else
          @text_variable.value = (@offvalue || 0)
        end
      end
      # call fire of button class 2008-12-09 17:49 
      fire
    end
  end # class
  ##
  # A checkbox, may be selected or unselected
  class CheckBox < ToggleButton
    include CommonIO
    dsl_accessor :align_right    # the button will be on the right 2008-12-09 23:41 
    # if a variable has been defined, off and on value will be set in it (default 0,1)
    def initialize form, config={}, &block
      super
      @surround_chars ||= ['[', ']']
      @value ||= false
    end
    def getvalue
#     $log.debug " iside CHECKBOX getvalue"
      @value 
    end
    def getvalue_for_paint
#     $log.debug " iside CHECKBOX getvalue for paint"
      buttontext = getvalue() ? "X" : " "
      if @align_right
        "#{@text} " + @surround_chars[0] + buttontext + @surround_chars[1] 
      else
        @surround_chars[0] + buttontext + @surround_chars[1] + " #{@text}"
      end
    end
  end # class
  ##
  # A selectable button that has a text value. It is based on a Variable that
  # is shared by other radio buttons. Only one is selected at a time, unlike checkbox
  # 2008-11-27 18:45 just made this inherited from Checkbox
  class RadioButton < ToggleButton
    include CommonIO
    dsl_accessor :align_right    # the button will be on the right 2008-12-09 23:41 
    # if a variable has been defined, off and on value will be set in it (default 0,1)
    def initialize form, config={}, &block
      @surround_chars = ['(', ')'] if @surround_chars.nil?
      super
    end
    # all radio buttons will return the value of the selected value, not the offered value
    def getvalue
      @text_variable.value
    end
    def getvalue_for_paint
      buttontext = @text_variable.value == @value ? "o" : " "
      if @align_right
        "#{@text} " + @surround_chars[0] + buttontext + @surround_chars[1] 
      else
        @surround_chars[0] + buttontext + @surround_chars[1] + " #{@text}"
      end
    end
    def toggle
      @text_variable.value = @value
      # call fire of button class 2008-12-09 17:49 
      fire
    end
    # added for bindkeys since that calls fire, not toggle - XXX i don't like this
    def fire
      @text_variable.value = @value
      super
    end
    ##
    # ideally this should not be used. But implemented for completeness.
    # it is recommended to toggle some other radio button than to uncheck this.
    def checked tf
      if tf
        toggle
      elsif !@text_variable.nil? and @text_variable == @value
        @text_variable = nil
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
    attr_accessor :selected_item

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
  class Listbox < Widget
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
    dsl_accessor :select_mode # allow multiple select or not
    dsl_accessor :list_variable   # a variable values are shown from this
    dsl_accessor :default_values  # array of default values

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
      @select_mode ||= 'multiple'
      @win = @form.window
      #     XXX have to deal with a list_variable too
 #     @list = @list_variable.value unless @list_variable.nil?
      init_scrollable
      print_borders
      # next 2 lines carry a redundancy
      select_default_values   
      # when the combo box has a certain row in focus, the popup should have the same row in focus
      set_focus_on @list.selected_item
    end
    def list alist=nil
      return @list if alist.nil?
      @list = RubyCurses::ListDataModel.new(alist)
    end
    def list_data_model ldm
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
      #color = $datacolor
      if @bgcolor.is_a? String and @color.is_a? String
        acolor = ColorMap.get_color(@color, @bgcolor)
      else
        acolor = $datacolor
      end
      @color_pair = acolor
      hline = "+%s+" % [ "-"*(width-((1)*2)) ]
      hline2 = "|%s|" % [ " "*(width-((1)*2)) ]
      printstr(window, row=startrow, col=startcol, hline, acolor)
      print_title
      (startrow+1).upto(startrow+height-1) do |row|
        printstr(window, row, col=startcol, hline2, acolor)
      end
      printstr(window, startrow+height, col=startcol, hline, acolor)
  
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
      fire_handler :ENTER_ROW, arow
    end
    def on_leave_row arow
      fire_handler :LEAVE_ROW, arow
    end
  end # class listb

  ##
  # pops up a list of values for selection
  # 2008-12-10
  class PopupList
#   include CommonIO
    include DSL
    include RubyCurses::EventHandler
    dsl_accessor :title
    dsl_accessor :row, :col, :height
    dsl_accessor :layout
    attr_reader :config
    attr_reader :selected_index     # button index selected by user
    attr_reader :window     # required for keyboard
    dsl_accessor :list_select_mode  # true or false allow multiple selection
    dsl_accessor :relative_to   # a widget, if given row and col are relative to widgets windows 
                                # layout
    dsl_accessor :max_visible_items   # how many to display
    dsl_accessor :list_config       # hash with values for the list to use 

    def initialize aconfig={}, &block
      @config = aconfig
      @selected_index = -1
      @list_config ||= {}
      @config.each_pair { |k,v| instance_variable_set("@#{k}",v) }
      instance_eval &block if block_given?
      @list_config.each_pair { |k,v|  instance_variable_set("@#{k}",v) }
      # get widgets absolute coords
      if !@relative_to.nil?
        layout = @relative_to.form.window.layout
        @row = @row + layout[:top]
        @col = @col + layout[:left]
      end
      @height = [@max_visible_items || 10, @list.length].min 
      layout(1+height, @width+4, @row, @col) # changed 2 to 1, 2008-12-17 13:48 
      @window = VER::Window.new(@layout)
      @form = RubyCurses::Form.new @window
      @window.bkgd(Ncurses.COLOR_PAIR($reversecolor));
      @window.wrefresh
      @panel = @window.panel
      Ncurses::Panel.update_panels
#     @message_row = @message_col = 2
#     print_borders
#     print_title
      print_input
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
        destroy  # XXX
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
        # $log.debug "popup ENTER : #{@selected_index} "
        # $log.debug "popup ENTER :  #{field.name}" if !field.nil?
          @stop = true
          return
        when 9
          @form.select_next_field ## XXX
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
      height = @height
      defaultvalue = @default_value || ""
        list = @list
        select_mode = @list_select_mode 
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
          display_length  30
#         set_buffer defaultvalue
          select_mode select_mode
          default_values default_values
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
      $log.debug "DESTROY : popuplist "
      panel = @window.panel
      Ncurses::Panel.del_panel(panel) if !panel.nil?   
      @window.delwin if !@window.nil?
    end
  end # class PopupList

  def self.startup
    VER::start_ncurses
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG
  end

end # module
