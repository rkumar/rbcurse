$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
=begin
  * Name: rform: our own ruby form and field. Hoping to make it simpler to create forms and labels.
  * $Id$
  * Description   Our own form with own simple field to make life easier. Ncurses forms are great, but
  *         honestly the sequence sucks and is a pain after a while for larger scale work.
  *         We need something less restrictive.
  * Author: rkumar
TODO 
  * integrate with our mapper
  * read only field
  * justified, int real charonly
  * Date: 2008-11-14 23:43 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'rubygems'
require 'ncurses'
require 'logger'
require 'lib/ver/ncurses'
require 'lib/ver/keyboard'
require 'lib/ver/window'
require 'lib/rbcurse/mapper'
require 'lib/rbcurse/keylabelprinter'
require 'lib/rbcurse/commonio'

## form needs to know order of fields esp they can be changed.
#include Curses
include Ncurses
module RubyCurses
  class Form
  include CommonIO
    attr_reader :value
    attr_reader :fields
    attr_reader :widgets
    attr_reader :focusables
    attr_reader :fieldnames
    attr_reader :current_index
    attr_accessor :window
    attr_accessor :row, :col
#   attr_accessor :color
#   attr_accessor :bgcolor
    attr_reader :field_id_incr
    attr_accessor :padx
    attr_accessor :pady
    attr_accessor :modified
    attr_reader :by_name
    def initialize win, &block
      @window = win
      @fields = []
      @widgets = []
      @by_name = {}
      @fieldnames = []
      @active_index = -1
      @field_id_incr = 0
      @padx = @pady = 0
      @row = @col = -1
      @handler = {}
      @modified = false
      @focusables = []
      instance_eval &block if block_given?
    end
    def add_field field
      id = @field_id_incr
      @fields << field
      @field_id_incr += 1 
      if !field.name.nil?
        @by_name[field.name] = field
      end
      add_widget field
      return id
    end
   def add_widget widget
     @widgets << widget
     if widget.focusable
       $log.debug "adding widget to focusabe: #{widget.name}" 
       @focusables << widget 
       widget.order = @focusables.length-1
     end
     return @widgets.length-1
   end
    def repaint
      @widgets.each do |f|
        f.repaint
      end
      if @row == -1
        set_field_cursor 0
      end
      setpos
      @window.wrefresh
    end
    def setpos r=@row, c=@col
     @window.wmove r,c
    end
    def get_current_field
      #@fields[@active_index]
      @focusables[@active_index]
    end
    def set_current_field index
      raise "RRRER" if index > @fields.length
      set_field_cursor index
    end
    def req_first_field
      set_field_cursor 0
    end
    def req_last_field
      #id = prev_focusable_field @fields.length-1
      set_field_cursor @focusables.length-1
    end
    def req_next_field
      if @active_index == @focusables.length-1
        req_first_field
      else
        set_field_cursor @active_index+1
      end
    end
    def req_prev_field
      if @active_index == 0
        req_last_field
      else
        set_field_cursor @active_index-1
      end
      #set_field_cursor @active_index-1
    end
    def handle_key key
    end
    def set_field_cursor index
      return if @active_index == index or index.nil?
      f = get_current_field

      fire_handler :LEAVE, f if !f.nil?
      @active_index = index
      f = get_current_field
      fire_handler :ENTER, f
     @row, @col = f.rowcol
     @window.wmove @row, @col
     f.curpos = 0
    end
    # char is fed to the current field
    def putch char
      ret = get_current_field.putch char
      return if ret != 0
      addcol 1
      @modified = true
    end
    def delete_curr_char
      get_current_field.delete_at
      @modified = true
    end
    def delete_prev_char
      return if get_current_field.curpos <= 0
      get_current_field.delete_prev_char
      addcol -1
      @modified = true
    end
    def putc c
      f = get_current_field
      return if !f.editable
      ret = f.putc c
      if ret == 0
        addcol 1 
        @modified = true
      end
    end
    def addcol num
      return if @col.nil? or @col == -1
      @col += num
      @window.wmove @row, @col
    end
    def req_next_char
      if get_current_field.curpos < get_current_field.display_length
        get_current_field.curpos += 1
        addcol 1
      end
    end
    def req_prev_char
      if get_current_field.curpos > 0
        get_current_field.curpos -= 1
        addcol -1
      end
    end
  def bind event, &blk
    @handler[event] = blk
  end
  def fire_handler event, object
#   $log.debug "called firehander #{object}"
    blk = @handler[event]
    return if blk.nil?
    blk.call object
  end
  # pls optimize this, see we could make a field focusable when program is running
  def next_focusable_field index=@active_index
    #f = @fields.find{ |f| f.focusable and f.order >= index }
    #f.order rescue nil
   $log.debug "FOCUSA #{@focusables.length } " 
    if index < @focusables.length-1
      index += 1 
    else
      index = 0
    end
    return @focusables[index].order
  end
  def prev_focusable_field index=@active_index
    #f = @fields.sort{|a,b| b.order <=> a.order}.find(lambda { index }){ |f| f.focusable and f.order <= index }
    #f.order  rescue nil
    if index > 0
      index -= 1 
    else
      index = @focusables.length-1
    end
    return @focusables[index].order
  end
  def regenerate_focusables
    @focusables = []
    @widgets.each do |w|
      @focusables << w if w.focusable
    end
  end

    ## ADD HERE FORM
  end

  class Field
    include CommonIO
    attr_accessor :order
    attr_accessor :name
    attr_accessor :id
    attr_accessor :maxlen
    attr_accessor :curpos
    attr_accessor :row
    attr_accessor :col
    attr_reader :buffer
    attr_accessor :label
    attr_accessor :default
    attr_accessor :config
    attr_accessor :values
    attr_accessor :valid_regex
    attr_accessor :display_length
    attr_accessor :bgcolor
    attr_accessor :color
    attr_reader :form
    attr_accessor :editable
    attr_reader :focusable
    attr_accessor :modified
    attr_reader :handler

    #def initialize name, r,c, type=:varchar, display_length=10, maxlen=-1
    def initialize form, config={}, &block
      @form = form
      @buffer = String.new
      @type=config.fetch("type", :varchar)
      @display_length = config.fetch("display_length", 20)
      @maxlen=config.fetch("maxlen", @display_length) 
      @row = config.fetch("row", 0)
      @col = config.fetch("col", 0)
      @bgcolor = config.fetch("bgcolor", 0)
      @color = config.fetch("color", $datacolor)
      @name = config.fetch("name", nil)
      @editable = config.fetch("editable", true)
      @focusable = config.fetch("focusable", true)
      @curpos = 0
      @handler = {}
      @modified = false
      instance_eval &block if block_given?
      @id = @order = form.add_field(self)
    end
    def putch char
      return -1 if !@editable or @buffer.length >= @maxlen
      @buffer.insert(@curpos, char)
      @curpos += 1 if @curpos < @maxlen
      @modified = true
      0
    end

    def putc c
      if c >= 0 and c <= 127
        return putch c.chr
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
    def delete_prev_char
      return -1 if !@editable 
      @curpos -= 1 if @curpos > 0
      delete_at
      @modified = true
    end
    def rowcol
      return @row, @col
    end
    def set_buffer value
      @buffer = value
    end
    def getvalue
      @buffer
    end
  #def set_label name, row=-1, col=-1, color=$datacolor, bgcolor=2
  def set_label label
    @label = label
    label.row = @row if label.row == -1
    label.col = @col-(name.length+1) if label.col == -1
  end
  def repaint
#    $log.debug("FIELD: #{id}, #{order}, #{focusable}")
    printval = getvalue
    printval = printval[0..display_length-1] if printval.length > display_length
    printstr @form.window, row, col, sprintf("%-*s", display_length, printval), color
    @form.window.mvchgat(y=row, x=col, max=display_length, Ncurses::A_NORMAL, bgcolor, nil)
  end
  def bind event, &blk
    @handler[event] = blk
  end
  def fire_handler event
    blk = @handler[event]
    return if blk.nil?
    blk.call self
  end
  def set_focusable(tf)
    @focusable = tf
    @form.regenerate_focusables
  end
  # ADD HERE FIELD
  end
  class Label
    include CommonIO
    attr_accessor :text
    attr_accessor :id
    attr_accessor :row
    attr_accessor :col
    attr_accessor :config
    attr_accessor :color
    attr_accessor :bgcolor
    attr_reader :form
    attr_reader :editable
    attr_reader :focusable
    attr_accessor :name


    def initialize form, config={}, &block
      @form = form
      @row = config.fetch("row",-1) 
      @col = config.fetch("col",-1) 
      @bgcolor = config.fetch("bgcolor", 0)
      @color = config.fetch("bgcolor", $datacolor)
      @text = config.fetch("text", "NOTFOUND")
      @name = config.fetch("name", "NOTFOUN")
      @editable = config.fetch("editable", false)
      @focusable =  config.fetch("focusable", false)
      instance_eval &block if block_given?
      @id = form.add_widget(self)
    end
    def rowcol
      return @row, @col
    end
    def getvalue
      @text
    end
  def repaint
        r,c = rowcol
        printstr @form.window, r, c, getvalue, color
#        $log.debug "label : #{getvalue}, #{r}, #{c} "
        @form.window.mvchgat(y=r, x=c, max=@text.length, Ncurses::A_NORMAL, bgcolor, nil)
  end
  # ADD HERE LABEL
  end
  class Button < Field
  include CommonIO
    def initialize form, config={}, &block
      super
      @focusable = true
      @editable = false
      @command_block = nil
      @buffer = @name if @buffer.nil?
      @display_length = @buffer.length
    end
    def command &block
      #@command_block = block
      bind :PRESS, &block
      $log.debug "#{name} bound PRESS"
      #instance_eval &block if block_given?
    end
    def fire
      #@form.instance_eval(&@command_block) if !@command_block.nil?
      #@command_block.call @form  if !@command_block.nil?
      $log.debug "firing PRESS #{name}"
      fire_handler :PRESS
    end
  end #BUTTON
  class LButton < Label
  include CommonIO
  attr_accessor :order  # focusable
  attr_accessor :curpos  # focusable
    def initialize form, config={}, &block
     config.merge!("focusable"=>true)
      super
      @focusable = true
      @editable = false
      #@command_block = nil
      @text = @name if @text.nil?
      @display_length = @text.length
      @handler={}
    end
#   def focusable
#     true
#   end
    def command &block
      #@command_block = block
      bind :PRESS, &block
      $log.debug "#{name} bound PRESS"
      #instance_eval &block if block_given?
    end
    def fire
      #@form.instance_eval(&@command_block) if !@command_block.nil?
      #@command_block.call @form  if !@command_block.nil?
      $log.debug "firing PRESS #{name}"
      fire_handler :PRESS, @form
    end
    def bind event, &blk
      @handler[event] = blk
    end
    def fire_handler event, object
      #   $log.debug "called firehander #{object}"
      blk = @handler[event]
      return if blk.nil?
      blk.call object
    end
  end #LBUTTON
end # modul

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
    @bottomcolor = $topcolor = 6

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
      @form = RubyCurses::Form.new @win
      r = 1; c = 22;
      %w[ name age company].each do |w|
        field = RubyCurses::Field.new @form do
          @name=w 
          @row=r 
          @col=c 
          @display_length=30
          set_buffer "abcd #{w}" 
          set_label RubyCurses::Label.new @form, {'text' => w}
        end
        r += 1
      end
#     $log.debug("byname: #{@form.by_name.inspect}")
      @form.by_name["age"].display_length = 3
      @form.by_name["age"].maxlen = 3
     @form.by_name["name"].set_focusable(false)
      @form.bind(:ENTER) { |f|   f.label.bgcolor = $promptcolor if f.instance_of? RubyCurses::Field}
      @form.bind(:LEAVE) { |f|$log.debug "485:#{f.name} ";  f.label.bgcolor = $datacolor  if f.instance_of? RubyCurses::Field}
      ok_button = RubyCurses::LButton.new @form do
        @text="[ OK ]"
        @name="OK"
        @row=10
        @col=22
      end
      ok_button.command { |form| form.printstr(@window, 23,45, "OK CALLED") }
      cancel_button = RubyCurses::Button.new @form do
        @buffer="[ Cancel ]"
        @row=10
        @col=28
      end
      cancel_button.command { |form| form.printstr(@window, 23,45, "Cancel CALLED"); throw(:close); }
      @form.repaint
      @form.req_first_field
      @win.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @win.getch()) != KEY_F1 )
        case ch
        when -1
          next
        when 9
          @form.req_next_field
        when KEY_UP
          @form.req_prev_field
        when KEY_DOWN
          @form.req_next_field
        when KEY_LEFT
          @form.req_prev_char
        when KEY_RIGHT
          @form.req_next_char
        when KEY_BACKSPACE, 127
          @form.delete_prev_char
        when KEY_ENTER, 10, 13
          f = @form.get_current_field
          if f.respond_to? :fire
            f.fire
          end

        when 330
          @form.delete_curr_char
        else
          $log.debug("ch #{ch}")
          @form.putc ch
        end
        @form.repaint
      @win.wrefresh
      end
      #     VER::Keyboard.focus = tp
    end
  rescue => ex
  ensure
      Ncurses::Panel.del_panel(@panel) if !@panel.nil?   
      Ncurses::Panel.del_panel(@padpanel) if !@padpanel.nil?   
      @win.delwin if !@win.nil?
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
