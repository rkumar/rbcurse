$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
=begin
  * Name: rwidget: base class and then popup and other derived widgets
  * $Id$
  * Description   
I expect to pass through this world but once. Any good therefore that I can do, or any kindness or ablities that I can show to any fellow creature, let me do it now. Let me not defer it or neglect it, for I shall not pass this way again.  
* Author: rkumar
TODO 
  * Date: 2008-11-19 12:49 
  * License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

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
require 'lib/rbcurse/rform'

module DSL
## others may not want this, if = sent, it creates DSL and sets
  def method_missing(sym, *args)
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
           #$log.debug "SETTING :   @#{sym}" 
           #$log.debug "getting :  @#{sym}" 

include Ncurses
module RubyCurses
  extend self
  class Widget
    include CommonIO
    include DSL
    dsl_accessor :text, :textvariable
    dsl_accessor :underline                        # offset of text to underline
    dsl_accessor :width                # desired width of text
    dsl_accessor :wrap_length                      # wrap length of text, if applic
    dsl_accessor :select_foreground, :select_background  # color init_pair
    dsl_accessor :highlight_foreground, :highlight_background  # color init_pair
    dsl_accessor :disabled_foreground, :disabled_background  # color init_pair
    dsl_accessor :focusable, :enabled # boolean
    dsl_accessor :row, :col
    dsl_accessor :color, :bgcolor      # normal foreground and background
    dsl_accessor :name                 # name to refr to or recall object by_name
    attr_accessor :id, :zorder
    attr_accessor :curpos              # cursor position inside object
    attr_reader  :config
    attr_reader  :form
    attr_accessor :state              # normal, selected, highlighted
    
    def initialize form, aconfig={}, &block
      @form = form
      @bgcolor = 0
      @state = :NORMAL
      @color = $datacolor
      @config = aconfig
      @config.each_pair { |k,v| variable_set(k,v) }
      instance_eval &block if block_given?
      @id = form.add_widget(self) if !form.nil? and form.respond_to? :add_widget
    end
    def variable_set var, val
        var = "@#{var}"
        instance_variable_set(var, val) 
    end
    def rowcol
      return @row, @col
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
    def cget param
      @config[param]
    end
    def getvalue
      @text
    end
    def repaint
        r,c = rowcol
        $log.debug("widget repaint : r:#{r} c:#{c} col:#{@color}" )
        printstr @form.window, r, c, getvalue, @color
        @form.window.mvchgat(y=r, x=c, max=@text.length, Ncurses::A_NORMAL, @bgcolor, nil)
#     raise "error please override repaint "
    end

    def destroy
      $log.debug "DESTROY : widget"
      panel = @window.panel
      Ncurses::Panel.del_panel(panel) if !panel.nil?   
      @window.delwin if !@window.nil?
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
        @window.wmove f.row, f.col
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
    def addcol num
      return if @col.nil? or @col == -1
      @col += num
      @window.wmove @row, @col
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
  ## forms handle keys
  def handle_key(ch)
        case ch
        when -1
          return
        when KEY_F2
          if !@menu_bar.nil?
            @menu_bar.toggle
            @menu_bar.handle_keys
          end
        when 9
          select_next_field
        when KEY_UP
          select_prev_field
        when KEY_DOWN
          select_next_field
        else
          field =  get_current_field
          handled = field.handle_key ch
        end
        repaint
  end

    ## ADD HERE FORM
  end
  class MessageBox
    include CommonIO
    include DSL
    dsl_accessor :title
    dsl_accessor :message
    dsl_accessor :type
    dsl_accessor :default_button
    dsl_accessor :layout
    attr_reader :config
    attr_reader :selected_index

    def initialize aconfig={}, &block
      @config = aconfig
      @buttons = []
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
      create_buttons
      @form.repaint
      @window.wrefresh
      handle_keys
      
    end
    def create_buttons
      case @type.to_s.downcase
      when "ok"
        make_button "OK"
      when "ok_cancel"
        @bcol = center_column "[ OK ] [ Cancel ]"
        make_button "OK"
        make_button "Cancel"
      when "yes_no"
        @bcol = center_column "[ Yes ] [ No ]"
        make_button "Yes"
        make_button "No"
      when "yes_no_cancel"
        @bcol = center_column "[ Yes ] [ No ] [Cancel]"
        make_button "Yes"
        make_button "No"
        make_button "Cancel"
      else
        @bcol = center_column "[ OK ]"
$log.debug "BCOL : #{@bcol} "
        make_button "OK"
      end
    end
    def make_button name
      $log.debug "insde make button : #{@bcol} #{name}"
      bcol = @bcol
      brow = @layout[:height]-3
      text = name
      button = RubyCurses::Button.new @form do
        text text
        name name
        row brow
        col bcol
        highlight_background $datacolor
        color $reversecolor
        bgcolor $reversecolor
      end
      index = @buttons.length
      button.command { |form| @selected_index = index; $log.debug "Pressed Button #{name}";}
      @buttons << button
      @bcol += text.length+6
    end
    # message box
    def handle_keys
      begin
      while((ch = @window.getch()) != KEY_F1 )
       $log.debug "message box handle_keys :  #{ch}"  if ch != -1
        case ch
        when -1
          next
        when KEY_ENTER, 10, 13
          field =  @form.get_current_field
          if field.respond_to? :fire
            field.fire
          end
          $log.debug "popup ENTER : #{@selected_index} "
          $log.debug "popup ENTER :  #{field.name}" if !field.nil?
          break
        when 9
          @form.select_next_field
        when KEY_UP, KEY_LEFT
          @form.select_prev_field
        when KEY_DOWN, KEY_RIGHT
          @form.select_next_field
        else
          field =  @form.get_current_field
          handled = field.handle_key ch
        end
        @form.repaint
        Ncurses::Panel.update_panels();
        Ncurses.doupdate();

        @window.wrefresh
      end
      ensure
        destroy  # XXX
      end
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
    def center_column text
      width = @layout[:width]
      return (width-text.length)/2
    end
    def print_message message=@message, row=nil
      row=(@layout[:height]/3) if row.nil?
      width = @layout[:width]
      printstr(@window, row,(width-message.length)/2,message, color=$reversecolor)
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
      # need to pass a form, not window.
      @mb = RubyCurses::MessageBox.new do
        title "hello world"
        message "How are you?"
        type :yes_no_cancel
      end
      
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
