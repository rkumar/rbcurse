$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
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
      $log.debug "called widget BIND #{event} #{args} "
      @handler[event] = blk
      @event_args[event] = args
    end
    ## got left out by mistake 2008-11-26 20:20 
    def fire_handler event, object
      $log.debug "called widget firehander #{object}, #{@event_args[event]}"
      blk = @handler[event]
      return if blk.nil?
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
    attr_reader :by_name   # hash containing widgets by name for retrieval
    attr_reader :menu_bar
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
      instance_eval &block if block_given?
    end
    def set_menu_bar mb
      @menu_bar = mb
      add_widget mb
    end
   def add_widget widget
      if widget.respond_to? :name and !widget.name.nil?
        $log.debug "adding to byname: #{widget.name} " 
        @by_name[widget.name] = widget
      end
      $log.debug "adding to widgets: #{widget.class} " 
     @widgets << widget
     if widget.focusable
#      $log.debug "adding widget to focusabe: #{widget.name}" 
     end
     return @widgets.length-1
   end
   # form
    def repaint
      @widgets.each do |f|
        f.repaint
      end
      if @row == -1
        #set_field_cursor 0
       $log.debug "repaint calling select field 0"
        #select_field 0
        req_first_field
      end
       setpos 
      @window.wrefresh
    end
    def setpos r=@row, c=@col
      $log.debug "setpos : #{r} #{c}"
     @window.wmove r,c
    end
    def get_current_field
      @widgets[@active_index]
    end
    def req_first_field
      @active_field = -1 # FIXME HACK
      select_next_field
    end
    def req_last_field
      @active_field = -1 # FIXME HACK
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
    def select_field ix0
      return if @widgets.nil? or @widgets.empty?
      $log.debug "insdie select  field :  #{ix0} ai #{@active_index}" 
      @active_index = ix0
      f = @widgets[@active_index]
      if f.focusable
        on_enter f
        @row, @col = f.rowcol
        $log.debug "insdie sele nxt field : ROW #{@row} COL #{@col} " 
        @window.wmove @row, @col
        f.curpos = 0
        repaint
        @window.refresh
      else
        $log.debug "insdie sele nxt field ENABLED FALSE : prev #{previtem} act #{@active_index}  #{ix0}" 
      end
    end
    def select_next_field
      return if @widgets.nil? or @widgets.empty?
       $log.debug "insdie sele nxt field :  #{@active_index} WL:#{@widgets.length}" 
      if @active_index.nil?
        @active_index = -1 
      else
        f = @widgets[@active_index]
        on_leave f
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
       $log.debug "insdie sele nxt field FAILED:  #{@active_index} WL:#{@widgets.length}" 
        @active_index = nil
        select_next_field
    end
    def select_prev_field
      return if @widgets.nil? or @widgets.empty?
       $log.debug "insdie sele prev field :  #{@active_index} WL:#{@widgets.length}" 
      if @active_index.nil?
        @active_index = @widgets.length 
      else
        f = @widgets[@active_index]
        on_leave f
      end
      #@active_index -= 1
      index = @active_index - 1
      (index).downto(0) do |i|
        f = @widgets[i]
        if f.focusable
          select_field i
          return
        end
      end
       $log.debug "insdie sele prev field FAILED:  #{@active_index} WL:#{@widgets.length}" 
        @active_index = nil # HACK !!!
        select_prev_field
      #req_last_field
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
    @handler[event] = blk
  end
  def fire_handler event, object
#   $log.debug "called form firehander #{object}"
    blk = @handler[event]
    return if blk.nil?
    blk.call object
  end
  ## forms handle keys
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
          select_next_field
=begin
        # lists use up and down key for navigation internally
        when KEY_UP
          select_prev_field
        when KEY_DOWN
          select_next_field
=end
        else
          field =  get_current_field
          handled = field.handle_key ch
          if handled == :UNHANDLED or handled == -1
            case ch
            when KEY_UP
              select_prev_field
            when KEY_DOWN
              select_next_field
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

    def initialize aconfig={}, &block
      @config = aconfig
      @buttons = []
      @keys = {}
      @bcol = 5
      @selected_index = -1
      @config.each_pair { |k,v| instance_variable_set("@#{var}",v) }
      instance_eval &block if block_given?
      layout(10,60, 10, 20) if @layout.nil? 
      @window = VER::Window.new(@layout)
      @form = RubyCurses::Form.new @window
      @window.bkgd(Ncurses.COLOR_PAIR(@bgcolor || $reversecolor));
      @panel = @window.panel
      Ncurses::Panel.update_panels
      print_borders
      print_title
      print_message
      print_input
      create_buttons
      @form.repaint
      @window.wrefresh
      handle_keys
    end
    def default_button offset0
      @selected_index = offset0
    end
    ##
    # value entered by user if type = input
    def input_value
      @input.buffer if !@input.nil?
    end
    def create_buttons
      case @type.to_s.downcase
      when "ok"
        @underlines = [0]
        make_buttons ["OK"]
      when "ok_cancel", "input"
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
        VER::Keyboard2.focus = self
      ensure
        destroy  # XXX
      end
      return @selected_index
    end
    def press ch
       $log.debug "message box handle_keys :  #{ch}"  if ch != -1
        case ch
        when -1
          return
        when KEY_F1
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
          if @keys.include? ch
           $log.debug "KEY #{ch} caught"
            @selected_index = @keys[ch]
            @stop = true
            return
          end
          field =  @form.get_current_field
          handled = field.handle_key ch
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
        printstr(@window, row, col=start, hline2, color=$reversecolor)
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
      row=(@layout[:height]/3) if row.nil?
      @message_row = row
      width = @layout[:width]
      @message_col = (width-message.length)/2
      @message_col = 4 if @type.to_s == "input"
      printstr(@window, row, @message_col , message, color=$reversecolor)
    end
    def print_input
      return if @type.to_s != "input"
      r = @message_row + 1
      c = @message_col
      defaultvalue = @default_value || ""
        @input = RubyCurses::Field.new @form do
          name   "input" 
          row  r 
          col  c 
          display_length  30
          set_buffer defaultvalue
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
    dsl_accessor :values             # TODO
    dsl_accessor :valid_regex        # TODO

    dsl_accessor :chars_allowed      # regex, what characters to allow, will ignore all else
    dsl_accessor :display_length     # how much to display
    dsl_accessor :bgcolor            # cannot be used currently
    dsl_accessor :color
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
      ar = @buffer.split(//)
      ar.delete_at index
      @buffer = ar.join
      @modified = true
    end
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
      req_prev_char
    when KEY_RIGHT
      req_next_char
    when KEY_BACKSPACE, 127
      delete_prev_char
    when KEY_ENTER, 10, 13
      if respond_to? :fire
        fire
      end
    when 330
      delete_curr_char
    else
      $log.debug("ch #{ch}")
      putc ch
    end

  end
  def req_next_char
    if @curpos < display_length
      @curpos += 1
      addcol 1
    end
  end
  def req_prev_char
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
    def update_command *args, &block
      $log.debug "update command set #{args}"
      @update_command = block
      @args = args
    end
    def read_command &block
      @read_command = block
    end
    def value
#     $log.debug "variable value called : #{@value} "
      @value
    end
    def value= val
      $log.debug "variable value= called : #{val} "
      @value = val
      @update_command.call(self, *@args) if !@update_command.nil?
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
     $log.debug "label :#{@text}, #{value}, #{r}, #{c} col= #{@color}, #{@bgcolor} acolor  #{acolor} "
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
      @handler={}
      super
      @bgcolor ||= $datacolor 
      @color ||= $datacolor 
      @surround_chars ||= ['[', ']'] 
      @text = @name if @text.nil?
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
        $log.debug("BUTTon repaint : #{self.class()}  r:#{@row} c:#{@col} #{getvalue_for_paint}" )
        r,c = rowcol
        @highlight_foreground ||= $reversecolor
        @highlight_background ||= 0
        bgcolor = @state==:HIGHLIGHTED ? @highlight_background : @bgcolor
        color = @state==:HIGHLIGHTED ? @highlight_foreground : @color
        if bgcolor.is_a? String and color.is_a? String
          color = ColorMap.get_color(color, bgcolor)
        end
        value = getvalue_for_paint
        $log.debug("button repaint : r:#{r} c:#{c} col:#{color} bg #{bgcolor} v: #{value} ")
        len = @display_length || value.length
        @form.window.printstring r, c, "%-*s" % [len, value], color, @attrs
#       @form.window.mvchgat(y=r, x=c, max=len, Ncurses::A_NORMAL, bgcolor, nil)
        if @underline != nil
        #printstring @form.window, r, c+@underline+1, "%-*s" % [1, value[@underline+1,1]], color, 'bold'
        #  @form.window.mvprintw(r, c+@underline+1, "\e[4m %s \e[0m", value[@underline+1,1]);
       # underline not working here using Ncurses. Works with highline. \e[4m
          @form.window.mvchgat(y=r, x=c+@underline+1, max=1, Ncurses::A_BOLD, color, nil)
        end
    end
    def command &block
      #@command_block = block
      bind :PRESS, &block
      $log.debug "#{text} bound PRESS"
      #instance_eval &block if block_given?
    end
    def fire
      #@form.instance_eval(&@command_block) if !@command_block.nil?
      #@command_block.call @form  if !@command_block.nil?
      $log.debug "firing PRESS #{text}"
      fire_handler :PRESS, @form
    end
    def bind event, &blk
      @handler[event] = blk
    end
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
        return -1
      end
    end
  end #BUTTON
  ##
  # A button that may be switched off an on. Does not fire.
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
    def toggle
      @value = !@value
      if !@text_variable.nil?
        if @value 
          @text_variable.value = (@onvalue || 1)
        else
          @text_variable.value = (@offvalue || 0)
        end
      end
    end
  end # class
  ##
  # A checkbox, may be selected or unselected
  class CheckBox < ToggleButton
    include CommonIO
    # if a variable has been defined, off and on value will be set in it (default 0,1)
    def initialize form, config={}, &block
      super
      @surround_chars ||= ['[', ']']
      @value ||= false
    end
    def getvalue
      $log.debug " iside CHECKBOX getvalue"
      @value 
    end
    def getvalue_for_paint
      $log.debug " iside CHECKBOX getvalue for paint"
      buttontext = getvalue() ? "X" : " "
      @surround_chars[0] + buttontext + @surround_chars[1] + " #{@text}"
    end
  end # class
  ##
  # A selectable button that has a text value. It is based on a Variable that
  # is shared by other radio buttons. Only one is selected at a time, unlike checkbox
  # 2008-11-27 18:45 just made this inherited from Checkbox
  class RadioButton < ToggleButton
    include CommonIO
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
      @surround_chars[0] + buttontext + @surround_chars[1] + " #{@text}"
    end
    def toggle
      @text_variable.value = @value
    end
  end # class
  def self.startup
    VER::start_ncurses
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG
    Colormap.setup
  end

end # module



if $0 == __FILE__
  # Initialize curses
  begin
    VER::start_ncurses
    Ncurses.start_color();
    # Initialize few color pairs 
    Ncurses.init_pair(1, COLOR_RED, COLOR_BLACK);
    Ncurses.init_pair(2, COLOR_BLACK, COLOR_WHITE);
    Ncurses.init_pair(3, COLOR_BLACK, COLOR_BLUE);
    Ncurses.init_pair(4, COLOR_YELLOW, COLOR_RED); # for selected item
    Ncurses.init_pair(5, COLOR_WHITE, COLOR_BLACK); # for unselected menu items
    Ncurses.init_pair(6, COLOR_WHITE, COLOR_BLUE); # for bottom/top bar
    Ncurses.init_pair(7, COLOR_WHITE, COLOR_RED); # for error messages
    $reversecolor = 2
    $errorcolor = 7
    $promptcolor = $selectedcolor = 4
    $normalcolor = $datacolor = 5
    $bottomcolor = $topcolor = 6

    # Create the window to be associated with the form 
    # Un post form and free the memory
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG

    catch(:close) do
      @layout = { :height => 0, :width => 0, :top => 0, :left => 0 } 
      @win = VER::Window.new(@layout)
      @window = @win
      @win.bkgd(Ncurses.COLOR_PAIR(5));
      @panel = @win.panel
      @win.wrefresh
      Ncurses::Panel.update_panels
      $labelcolor = 2
      $datacolor = 5
      $log.debug "START  ---------"
      # need to pass a form, not window.
      @mb = RubyCurses::MessageBox.new do
        #title "Color selector"
        title "Enter your name"
        message "Enter your name"
        type :custom
        buttons %w[red green blue yellow]
        underlines [0,0,0,0]
        type :input
        default_value "rahul"
        default_button 0
      end
      
     $log.debug "MBOX : #{@mb.selected_index} "
     $log.debug "MBOX : #{@mb.input_value} "
      $log.debug "AFTER CREATE : #{@form.inspect} "
#     $log.debug "row : #{@form.row} "
#     $log.debug "col : #{@form.col} "
#     $log.debug "Config : #{@form.config.inspect} "
#     @form.configure "row", 23
#     @form.configure "col", 83
#     $log.debug "row : #{@form.row} "
#     x = @form.row
#    @form.depth   21
#    @form.depth = 22
#    @form.depth   24
#    @form.depth = 25
#     $log.debug "col : #{@form.col} "
#     $log.debug "config : #{@form.config.inspect} "
#     $log.debug "row : #{@form.configure('row')} "
      #$log.debug "mrgods : #{@form.public_methods.sort.inspect}"
      while((ch = @win.getch()) != KEY_F1 )
        @win.wrefresh
      end
      #     VER::Keyboard.focus = tp
    end
  rescue => ex
  ensure
      Ncurses::Panel.del_panel(@panel) if !@panel.nil?   
      @win.delwin if !@win.nil?
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
