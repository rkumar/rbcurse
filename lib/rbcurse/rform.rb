$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
=begin
  * Name: rform: our own ruby form and field. Hoping to make it simpler to create forms and labels.
  * $Id$
  * Description   Our own form with own simple field to make life easier. Ncurses forms are great, but
  *         honestly the sequence sucks and is a pain after a while for larger scale work.
  *         We need something less restrictive.
  * Author: rkumar
TODO 
    - menu bar : what to do if adding a menu, or option later.
      we dnt show disabld options in a way that user can know its disabled
  * do we need widgets in our thign at all, why am i managing ?
  * Field/entry
    - show (what char to show when entry done : show '*'
    - textvariable - bding field to a var so the var is updated
  * Button remove inheritance fom Label
    - width int : desiredwidth
    - underline index
    - foreground, bgcolor 
    - surroundchars
  * Label
    - desired width
    - textvariable , foreground, bgcolor
  * POPUP
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
require 'lib/rbcurse/rwidget'
require 'lib/rbcurse/scrollable'

## form needs to know order of fields esp they can be changed.
#include Curses
include Ncurses
module RubyCurses
  extend self


  class MenuSeparator
    include CommonIO
    attr_accessor :enabled
    attr_accessor :parent
#   attr_accessor :window
    attr_accessor :row
    attr_accessor :col
    attr_accessor :width
    def initialize 
      @enable = false
    end
    def repaint
      printstr(@parent.window, @row, 0, "|%s|" % ("-"*@width), $reversecolor)
    end
    def destroy
    end
    def on_enter
    end
    def on_leave
    end
    def to_s
      ""
    end
  end
  class MenuItem
    include CommonIO
    attr_accessor :parent
#    attr_accessor :window
    attr_accessor :row
    attr_accessor :col
    attr_accessor :width
    attr_accessor :accelerator
    attr_accessor :enabled
    attr_reader :text, :mnemonic
    def initialize text, mnemonic=nil, &block
      @text = text
      @enabled = true
      @mnemonic = mnemonic
      instance_eval &block if block_given?
    end
    def to_s
      "#{@text} #{@accelerator}"
    end
    def command *args, &block 
      $log.debug ">>>command : #{@text} "
      @command = block if block_given?
      @args = args
    end
    def on_enter
      $log.debug ">>>on enter menuitem : #{@text} #{@row} #{@width} "
      highlight
    end
    def on_leave
      $log.debug ">>>on leave menuitem : #{@text} "
      highlight false
    end
    ## XXX it could be a menu again
    def fire
      $log.debug ">>>fire menuitem : #{@text} #{@command} "
      @command.call *@args if !@command.nil?
    end
    def highlight tf=true
      if tf
        color = $datacolor
        @parent.window.mvchgat(y=@row, x=1, @width, Ncurses::A_NORMAL, color, nil)
      else
        repaint
      end
      @parent.window.wrefresh
    end
    def repaint # menuitem.repaint
      r = @row
      printstr(@parent.window, @row, 0, "|%-*s|" % [@width, text], $reversecolor)
      if !@accelerator.nil?
        printstr(@parent.window, r, (@width+1)-@accelerator.length, @accelerator, $reversecolor)
      elsif !@mnemonic.nil?
        m = @mnemonic
        ix = text.index(m) || text.index(m.swapcase)
        charm = text[ix,1]
        printstr(@parent.window, r, ix+1, charm, $datacolor) if !ix.nil?
      end
    end
    def destroy
     $log.debug "DESTRY menuitem #{@text}"
    end
  end
  class Menu
    include CommonIO
    attr_accessor :parent
    attr_accessor :row
    attr_accessor :col
    attr_accessor :width
    attr_accessor :enabled
    attr_reader :text
    attr_reader :items
    attr_reader :window
    attr_reader :panel
    attr_reader :current_menu

    def initialize text, &block
      @text = text
      @items = []
      @enabled = true
      @current_menu = []
      instance_eval &block if block_given?
    end
    def to_s
      @text
    end
    # item could be menuitem or another menu
    def add menuitem
      @items << menuitem
      return self
    end
    def insert_separator ix
      @items.insert ix, MenuSeparator.new
    end
    def add_separator 
      @items << MenuSeparator.new
    end
    # menu - 
    def fire
      $log.debug "menu fire called: #{text}  " 
      if @window.nil?
        #repaint
        create_window
        if !@parent.is_a? RubyCurses::MenuBar 
          @parent.current_menu << self
        end
      else
        ### shouod this not just show ?
      $log.debug "menu fire called: #{text} ELSE XXX WHEN IS THIS CALLED ? 658  " 
        @items[@active_index].fire # this should happen if selected. else selected()
      end
      #@action.call if !@action.nil?
    end
    # user has clicked down, we shoud display items
    # DRAW menuitems
    def repaint # menu.repaint
      return if @items.nil? or @items.empty?
      $log.debug "menu repaint: #{text} row #{@row} col #{@col}  " 
      if !@parent.is_a? RubyCurses::MenuBar 
        printstr(@parent.window, @row, 0, "|%-*s>|" % [@width-1, text], $reversecolor)
        @parent.window.refresh
      end
      if @window.nil?
        #create_window
      else
        @window.show
        select_item 0
        @window.refresh
      end
    end
    ##
    # recursive if given one not enabled goes to next enabled
    def select_item ix0
      return if @items.nil? or @items.empty?
       $log.debug "insdie select  item :  #{ix0}" 
      if !@active_index.nil?
        @items[@active_index].on_leave 
      end
      previtem = @active_index
      @active_index = ix0
      if @items[ix0].enabled
        @items[ix0].on_enter
      else
        $log.debug "insdie sele nxt item ENABLED FALSE :  #{ix0}" 
        if @active_index > previtem
          select_next_item
        else
          select_prev_item
        end
      end
      @window.refresh
    end
    def select_next_item
      return if @items.nil? or @items.empty?
       $log.debug "insdie sele nxt item :  #{@active_index}" 
      @active_index = -1 if @active_index.nil?
      if @active_index < @items.length-1
        select_item @active_index + 1
      else
      #  select_item 0
      end
    end
    def select_prev_item
      return if @items.nil? or @items.empty?
       $log.debug "insdie sele prv item :  #{@active_index}" 
      if @active_index > 0
        select_item @active_index - 1
      else
      #select_item @items.length-1
      end
    end
    def on_enter # menu.on_enter
      $log.debug "menu onenter: #{text} #{@row} #{@col}  " 
      # call parent method. XXX
        if @parent.is_a? RubyCurses::MenuBar 
          printstr(@parent.window, @row, @col, " %s " % text, $datacolor)
        else
          highlight
        end
        if !@window.nil? #and @parent.selected
          $log.debug "menu onenter: #{text} calling window,show"
          @window.show
          select_item 0
        elsif @parent.is_a? RubyCurses::MenuBar and  @parent.selected
          # only on the top level do we open a window if a previous one was opened
          $log.debug "menu onenter: #{text} calling repaint CLASS: #{@parent.class}"
        #  repaint
          create_window
        end
    end
    def on_leave # menu.on_leave
      $log.debug "menu onleave: #{text} #{@row} #{@col}  " 
      # call parent method. XXX
        if @parent.is_a? RubyCurses::MenuBar 
          printstr(@parent.window, @row, @col, " %s " % text, $reversecolor)
          @window.hide if !@window.nil?
        else
          $log.debug "MENU SUBMEN. menu onleave: #{text} #{@row} #{@col}  " 
          # parent is a menu
          highlight false
          @parent.current_menu.pop
          destroy
        end
    end
    def highlight tf=true # menu
          $log.debug "MENU SUBMENU menu highlight: #{text} #{@row} #{@col}, PW #{@parent.width}  " 
      color = tf ? $datacolor : $reversecolor
      #@parent.window.mvchgat(y=@row, x=1, @width, Ncurses::A_NORMAL, color, nil)
      @parent.window.mvchgat(y=@row, x=1, @parent.width, Ncurses::A_NORMAL, color, nil)
      @parent.window.wrefresh
    end
    def create_window # menu
      margin = 3
      @width = array_width @items
      $log.debug "create window menu #{@text}: #{@row} ,#{@col},wd #{@width}   " 
      @layout = { :height => @items.length+3, :width => @width+margin, :top => @row+1, :left => @col } 
      @win = VER::Window.new(@layout)
      @window = @win
      @win.bkgd(Ncurses.COLOR_PAIR(5));
      @panel = @win.panel
        printstr(@window, 0, 0, "+%s+" % ("-"*@width), $reversecolor)
        r = 1
        @items.each do |item|
          #if item == :SEPARATOR
          #  printstr(@window, r, 0, "|%s|" % ("-"*@width), $reversecolor)
          #else
            item.row = r
            item.col = 0
            item.col = @col+@width+margin # margins???
 #         $log.debug "create window menu loop passing col : #{item.col} " 
            item.width = @width
            #item.window = @window
            item.parent = self
            item.repaint
          #end
          r+=1
        end
        printstr(@window, r, 0, "+%s+" % ("-"*@width), $reversecolor)
      select_item 0
      @window.refresh
      return @window
    end
    def array_width a
      longest = a.max {|a,b| a.to_s.length <=> b.to_s.length }
      $log.debug "array width #{longest}"
      longest.to_s.length
    end
    def destroy
      $log.debug "DESTRY menu #{@text}"
      return if @window.nil?
      @visible = false
      panel = @window.panel
      Ncurses::Panel.del_panel(panel) if !panel.nil?   
      @window.delwin if !@window.nil?
      @items.each do |item|
        #next if item == :SEPARATOR
        item.destroy
      end
      @window = nil
    end
    # menu LEFT, RIGHT, DOWN, UP, ENTER
    # item could be menuitem or another menu
    #
    def handle_key ch
      if !@current_menu.empty?
        cmenu = @current_menu.last
      else 
        cmenu = self
      end
      case ch
      when KEY_DOWN
          cmenu.select_next_item
      when KEY_UP
        cmenu.select_prev_item
      when KEY_ENTER, 10, 13
        cmenu.fire
      when KEY_LEFT
        if cmenu.parent.is_a? RubyCurses::Menu 
       $log.debug "LEFT IN MENU : #{cmenu.parent.class} len: #{cmenu.parent.current_menu.length}"
       $log.debug "left IN MENU : #{cmenu.parent.class} len: #{cmenu.current_menu.length}"
        end
        if cmenu.parent.is_a? RubyCurses::Menu and !cmenu.parent.current_menu.empty?
       $log.debug " ABOU TO DESTROY DUE TO LEFT"
          cmenu.parent.current_menu.pop
          cmenu.destroy
        else
          return :UNHANDLED
        end
      when KEY_RIGHT
       $log.debug "RIGHTIN MENU : "
        if cmenu.parent.is_a? RubyCurses::Menu 
       $log.debug "right IN MENU : #{cmenu.parent.class} len: #{cmenu.parent.current_menu.length}"
       $log.debug "right IN MENU : #{cmenu.parent.class} len: #{cmenu.current_menu.length}"
        end
        if cmenu.parent.is_a? RubyCurses::Menu and !cmenu.parent.current_menu.empty?
       $log.debug " ABOU TO DESTROY DUE TO RIGHT"
          cmenu.parent.current_menu.pop
          cmenu.destroy
        end
        return :UNHANDLED
      else
        return :UNHANDLED
      end
    end
    ## menu 
    def show # menu.show
      $log.debug "show (menu) : #{@text} "
      if @window.nil?
        create_window
      end
        @window.show 
        select_item 0
    end
  end
  class MenuBar
    include CommonIO
    attr_reader :items
    attr_reader :window
    attr_reader :panel
    attr_reader :selected
    attr_accessor :visible
    attr_accessor :active_index
    attr_accessor :state              # normal, selected, highlighted
    def initialize &block
      @window = nil
      @active_index = 0
      @items = []
      @visible = false
      @cols = Ncurses.COLS-1
      instance_eval &block if block_given?
    end
    def focusable
      false
    end
    def add menu
      @items << menu
      return self
    end
    def next_menu
      $log.debug "next meu: #{@active_index}  " 
      if @active_index < @items.length-1
        set_menu @active_index + 1
      else
        set_menu 0
      end
    end
    def prev_menu
      $log.debug "prev meu: #{@active_index} " 
      if @active_index > 0
        set_menu @active_index-1
      else
        set_menu @items.length-1
      end
    end
    def set_menu index
      $log.debug "set meu: #{@active_index} #{index}" 
      menu = @items[@active_index]
      menu.on_leave # hide its window, if open
      @active_index = index
      menu = @items[@active_index]
      menu.on_enter #display window, if previous was displayed
      @window.wmove menu.row, menu.col
#     menu.show
#     menu.window.wrefresh # XXX we need this
    end
    # menubar LEFT, RIGHT, DOWN 
    def handle_keys
      @selected = false
      set_menu 0
      while((ch = @window.getch()) != KEY_F2 )
       $log.debug "insdie handle_keys :  #{ch}"  if ch != -1
        case ch
        when -1
          next
        when KEY_DOWN
          $log.debug "insdie keyDOWN :  #{ch}" 
          if !@selected
            current_menu.fire
          else
            current_menu.handle_key ch
          end
            
          @selected = true
        when KEY_ENTER, 10, 13
          @selected = true
            $log.debug "insdie ENTER :  #{current_menu}" 
            current_menu.handle_key ch
        when KEY_UP
          $log.debug "insdie keyUPP :  #{ch}" 
          current_menu.handle_key ch
        when KEY_LEFT
          $log.debug "insdie KEYLEFT :  #{ch}" 
          ret = current_menu.handle_key ch
          prev_menu if ret == :UNHANDLED
          #display_items if @selected
        when KEY_RIGHT
       $log.debug "insdie KEYRIGHT :  #{ch}" 
          ret = current_menu.handle_key ch
          next_menu if ret == :UNHANDLED
        else
          next
        end
        Ncurses::Panel.update_panels();
        Ncurses.doupdate();

        @window.wrefresh
      end
      destroy  # XXX
    end
    def current_menu
      @items[@active_index]
    end
    def toggle
      @visible = !@visible
      if !@visible
        hide
      else
        show
      end
    end
    def hide
      @visible = false
      @window.hide if !@window.nil?
    end
    def show
      @visible = true
      if @window.nil?
        repaint  # XXX FIXME
      else
        @window.show 
      end
    end
    ## menubar
    def repaint
      return if !@visible
      @window ||= create_window
      printstr(@window, 0, 0, "%-*s" % [@cols," "], $reversecolor)
      c = 1; r = 0;
      @items.each do |item|
        item.row = r; item.col = c; item.parent = self
        printstr(@window, r, c, " %s " % item.text, $reversecolor)
        c += (item.text.length + 2)
      end
      @window.wrefresh
    end
    def create_window
      @layout = { :height => 1, :width => 0, :top => 0, :left => 0 } 
      @win = VER::Window.new(@layout)
      @window = @win
      @win.bkgd(Ncurses.COLOR_PAIR(5));
      @panel = @win.panel
      return @window
    end
    def destroy
      $log.debug "DESTRY menubar "
      @visible = false
      panel = @window.panel
      Ncurses::Panel.del_panel(panel) if !panel.nil?   
      @window.delwin if !@window.nil?
      @items.each do |item|
        item.destroy
      end
      @window = nil
    end
  end # menubar

  ## allow selection multi and single
  #  use selection color for selected row.
  class Listbox < Widget
    include Scrollable
    dsl_accessor :height
    dsl_accessor :title
    dsl_accessor :list    # the array of data to be sent by user
    attr_reader :toprow
    attr_reader :prow
    attr_reader :winrow

    def initialize form, config={}, &block
      @focusable = true
      @editable = false
      @row = 0
      @col = 0
      @list = []
      super
      @scrollatrow = @height-2
      @content_rows = @list.length
      @win = @form.window
      init_scrollable
      print_borders
    end
    def insert off0, *data
      @list.insert off0, *data
    end
    def print_borders
      width = @width
      height = @height
      window = @form.window
      startcol = @col 
      startrow = @row 
      color = $datacolor
      hline = "+%s+" % [ "-"*(width-((1)*2)) ]
      hline2 = "|%s|" % [ " "*(width-((1)*2)) ]
      printstr(window, row=startrow, col=startcol, hline, color)
      (startrow+1).upto(startrow+height-1) do |row|
        printstr(window, row, col=startcol, hline2, color)
      end
      printstr(window, startrow+height, col=startcol, hline, color)
  
     # @derwin = @form.window.derwin(@height, @width, @row, @col)
     # repaint
    end
    ### FOR scrollable ###
    def get_content
      @list
    end
    def get_window
      @form.window
    end
    ### FOR scrollable ###
    def repaint
      paint
    end
    # Listbox
    # ^P ^N scroll up down
    # [ ] scroll left right
    def handle_key ch
      scrollable_handle_key ch
    end # handle_k listb
  end # class listb
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
          name   w 
          row  r 
          col  c 
          display_length  30
          set_buffer "abcd #{w}" 
          set_label RubyCurses::Label.new @form, {'text' => w}
        end
        r += 1
      end
      $results = RubyCurses::Variable.new
      $results.value = "Hello there"
      var = RubyCurses::Label.new @form, {'text_variable' => $results, "row" => r, "col" => 22}
        r += 1
#     $log.debug("byname: #{@form.by_name.inspect}")
        mylist = []
        0.upto(100) { |v| mylist << "#{v} data" }
        field = RubyCurses::Listbox.new @form do
          name   "mylist" 
          row  r 
          col  c 
          width 40
          height 10
          list mylist
        end
      @form.by_name["age"].display_length = 3
      @form.by_name["age"].maxlen = 3
      @form.by_name["age"].set_buffer  "24"
      @form.by_name["name"].set_buffer  "Not focusable"
      @form.by_name["age"].chars_allowed = /\d/
      @form.by_name["company"].type(:ALPHA)
     @form.by_name["name"].set_focusable(false)
      @form.bind(:ENTER) { |f|   f.label.bgcolor = $promptcolor if f.instance_of? RubyCurses::Field}
      @form.bind(:LEAVE) { |f|  f.label.bgcolor = $datacolor  if f.instance_of? RubyCurses::Field}
      ok_button = RubyCurses::Button.new @form do
        text "OK"
        name "OK"
        row 18
        col 22
      end
      ok_button.command { |form| $results.value = "OK PRESS:";form.printstr(@window, 23,45, "OK CALLED") }
        #text "Cancel"
      cancel_button = RubyCurses::Button.new @form do
        text_variable $results
        row 18
        col 28
      end
      cancel_button.command { |form| form.printstr(@window, 23,45, "Cancel CALLED"); throw(:close); }
      @mb = RubyCurses::MenuBar.new
      filemenu = RubyCurses::Menu.new "File"
      filemenu.add(item = RubyCurses::MenuItem.new("Open",'O'))
      item.command(@form) {|form|  form.printstr(@window, 23,45, "Open CALLED"); }

      filemenu.insert_separator 1
      filemenu.add(RubyCurses::MenuItem.new "New",'N')
      filemenu.add(RubyCurses::MenuItem.new "Save",'S')
      filemenu.add(RubyCurses::MenuItem.new "Exit",'X')
      @mb.add(filemenu)
      editmenu = RubyCurses::Menu.new "Edit"
      item = RubyCurses::MenuItem.new "Cut"
      editmenu.add(item)
      item.accelerator = "Ctrl-X"
      item=RubyCurses::MenuItem.new "Copy"
      editmenu.add(item)
      item.accelerator = "Ctrl-C"
      item=RubyCurses::MenuItem.new "Paste"
      editmenu.add(item)
      item.accelerator = "Ctrl-V"
      @mb.add(editmenu)
      @mb.add(menu=RubyCurses::Menu.new("Others"))
      #item=RubyCurses::MenuItem.new "Save","S"
      item = RubyCurses::MenuItem.new "Options"
      menu.add(item)
      item = RubyCurses::MenuItem.new "Config"
      menu.add(item)
      item = RubyCurses::MenuItem.new "Tables"
      menu.add(item)
      savemenu = RubyCurses::Menu.new "EditM"
      item = RubyCurses::MenuItem.new "CutM"
      savemenu.add(item)
      item = RubyCurses::MenuItem.new "DeleteM"
      savemenu.add(item)
      item = RubyCurses::MenuItem.new "PasteM"
      savemenu.add(item)
      menu.add(savemenu)
      @form.set_menu_bar  @mb
      # END
      @form.repaint
      @win.wrefresh
      Ncurses::Panel.update_panels
      #@form.req_first_field
      #@form.select_field 0
      while((ch = @win.getch()) != KEY_F1 )
        @form.handle_key(ch)
       # @form.repaint
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
