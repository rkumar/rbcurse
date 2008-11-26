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
  * Field/entry
    - textvariable - bding field to a var so the var is updated
    - int and float - range
  * Button 
    - width int : desiredwidth
  * Label
    - desired width
  * 
  * integrate with our mapper TODO
  * justified
  * use a global $message, and maybe a header message too.
  * Make a root window/form that creates the logger colors and other things.
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
require 'lib/rbcurse/selectable'

## form needs to know order of fields esp they can be changed.
#include Curses
include Ncurses
include RubyCurses
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
  ##
  # TODO : underlining and key capture 
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

  ## TODO allow selection multi and single
  #  use selection color for selected row.
  class Listbox < Widget
    include Scrollable
    include Selectable
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
      # data of listbox
      @list = []
      # any special attribs such as status to be printed in col1, or color (selection)
      @list_attribs = {}
      super
      @row_offset = @col_offset = 1
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
    ### START FOR scrollable ###
    def get_content
      @list
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
    def handle_key ch
      ret = scrollable_handle_key ch
      if ret == :UNHANDLED
        ret = selectable_handle_key ch
      end
    end # handle_k listb
    def on_enter_row arow
      fire_handler :ENTER_ROW, arow
    end
    def on_leave_row arow
      fire_handler :LEAVE_ROW, arow
    end
  end # class listb
  ## a multiline text editing widget
  # TODO - giving data to user - adding newlines, and withog adding.
  #  - respect newlines for incoming data
  #   add C-u undo cut at position
  class TextArea < Widget
    include Scrollable
    dsl_accessor :height
    dsl_accessor :title
    dsl_accessor :list    # the array of data to be sent by user
    dsl_accessor :maxlen    # the array of data to be sent by user
    attr_reader :toprow
    attr_reader :prow
    attr_reader :winrow

    def initialize form, config={}, &block
      @focusable = true
      @editable = true
      @left_margin = 1
      @row = 0
      @col = 0
      @show_focus = false
      @list = []
      super
      @row_offset = @col_offset = 1
      @orig_col = @col
      # this does result in a blank line if we insert after creating. That's required at 
      # present if we wish to only insert
      if @list.empty?
        @list << String.new 
      end
      @scrollatrow = @height-2
      @content_rows = @list.length
      @win = @form.window
      init_scrollable
      print_borders
      @maxlen ||= @width-2
    end
    def rowcol
      $log.debug "textarea rowcol : #{@row+@row_offset+@winrow}, #{@col+@col_offset}"
      return @row+@row_offset+@winrow, @col+@col_offset
    end
    def insert off0, *data
      @list.insert off0, *data
    end
    def wrap_text(txt, col = @maxlen)
      $log.debug "inside wrap text for :#{txt}"
      txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,
               "\\1\\3\n") 
    end
    def << data
      if data.length > @maxlen
        $log.debug "wrapped append for #{data}"
        data = wrap_text data
        $log.debug "after wrap text for :#{data}"
        data = data.split(/\n/)
        # we need a soft return
        data.each {|line| @list << line+"\n"}
        @list[-1][-1] = "\r"
      else
        $log.debug "normal append for #{data}"
        data << "\r" if data[-1,1] != "\r"
        @list << data
      end
      self
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
    def repaint # textarea
      paint
    end
    def getvalue
      @list
    end
    # textarea
    # [ ] scroll left right
    def handle_key ch
      @buffer = @list[@prow]
      if @buffer.nil? and @list.length == 0
        @list << ""
        @buffer = @list[@prow]
      end
      return if @buffer.nil?
      $log.debug " before: curpos #{@curpos} blen: #{@buffer.length}"
      if @curpos > @buffer.length
        addcol(@buffer.length-@curpos)+1
        @curpos = @buffer.length
      end
      $log.debug " after loop : curpos #{@curpos} blen: #{@buffer.length}"
      pre_key
      case ch
      when ?\C-n
        space
      when ?\C-p
        minus
      when ?\C-[
        goto_start
      when ?\C-]
        goto_end
      when KEY_UP
        #select_prev_row
        ret = up
        #addrowcol -1,0 if ret != -1 or @winrow != @oldwinrow                 # positions the cursor up 
        @form.row = @row + 1 + @winrow
      when KEY_DOWN
        ret = down
        #addrowcol 1,0 if ret != -1   or @winrow != @oldwinrow                  # positions the cursor down
        @form.row = @row + 1 + @winrow

        $log.debug "KEYDOWN : cp #{@curpos} #{@buffer.length} "
        # select_next_row
      when KEY_ENTER, 10, 13
        # insert a blank row and append rest of this line to cursor
        @delete_buffer = (delete_eol || "")
        @list[@prow] << "\r"
        $log.debug "DELETE BUFFER #{@delete_buffer}" 
        @list.insert @prow+1, @delete_buffer 
        @curpos = 0
        down
        @form.col = @orig_col + @col_offset
        #addrowcol 1,0
        @form.row = @row + 1 + @winrow
      when KEY_LEFT
        req_prev_char
      when KEY_RIGHT
        req_next_char
      when KEY_BACKSPACE, 127
        delete_prev_char
      when 330
        delete_curr_char
      when ?\C-k
        if @buffer == ""
          delete_line
        else
          delete_eol
        end
      when ?\C-a
        set_form_col 0
      when ?\C-e
        set_form_col @buffer.length
      else
        $log.debug("ch #{ch}")
        putc ch
      end
      post_key
    end
    # puts cursor on correct row.
    def set_form_row
      @form.row = @row + 1 + @winrow
    end
    # set cursor on correct column
    def set_form_col col=@cursor
      @curpos = col
      @form.col = @orig_col + @col_offset + @curpos
    end
    def do_current_row # :yields current row
      yield @list[@prow]
      @buffer = @list[@prow]
    end
    def delete_eol
      pos = @curpos-1
      @delete_buffer = @buffer[@curpos..-1]
      # if pos is 0, pos-1 becomes -1, end of line!
      @list[@prow] = pos == -1 ? "" : @buffer[0..pos]
      $log.debug "delete EOL :pos=#{pos}, #{@delete_buffer}: row: #{@list[@prow]}:"
      @buffer = @list[@prow]
      req_prev_char
      return @delete_buffer
    end
    def req_next_char
      $log.debug "next char cp #{@curpos} wi: #{@width}"
      if @curpos < @width and @curpos < @maxlen-1 # else it will do out of box
        @curpos += 1
        addcol 1
      end
    end
    def addcol num
      @form.addcol num
    end
    def addrowcol row,col
    @form.addrowcol row, col
  end
  def req_prev_char
    if @curpos > 0
      @curpos -= 1
      addcol -1
    end
  end
  def delete_line line=@prow
    $log.debug "called delete line"
    @list.delete_at line
    @buffer = @list[@prow]
    if @buffer.nil?
      up
      @form.row = @row + 1 + @winrow
    end
  end
    def delete_curr_char
      delete_at
      set_modified 
    end
    def delete_prev_char
      return -1 if !@editable 
      if @curpos <= 0
        join_to_prev_line
        return
      end
      @curpos -= 1 if @curpos > 0
      delete_at
      set_modified 
      addcol -1
    end
    def join_to_prev_line
      return if @prow == 0
      prev = @list[@prow-1].chomp
      prevlen = prev.length
      space_left = @maxlen - prev.length
      carry_up = @buffer[0..space_left]
      @list[@prow-1]=prev + carry_up
      space_left2 = @buffer[(space_left+1)..-1]
      @list[@prow]=space_left2 #if !space_left2.nil?
      @list[@prow] ||= ""
      up
      addrowcol -1,0
      @curpos = prevlen
      @form.col = @orig_col + @col_offset + @curpos
#     $log.debug "carry up: nil" if carry_up.nil?
#     $log.debug "listrow nil " if @list[@prow].nil?
#     $log.debug "carry up: #{carry_up} prow:#{@list[@prow]}"
    end
    def putch char
      return -1 if !@editable #or @buffer.length >= @maxlen
      if @chars_allowed != nil
        return if char.match(@chars_allowed).nil?
      end
      $log.debug "putch : pr:#{@prow} bu:#{@buffer} cp:#{@curpos}"
      if @curpos >= @maxlen
        $log.debug "INSIDE 1 putch : pr:#{@prow} bu:#{@buffer} CP:#{@curpos}"
        ## wrap on word
        lastchars = ""
        lastspace = @buffer.rindex(" ")
        if !lastspace.nil?
          lastchars = @buffer[lastspace+1..-1]
          @list[@prow] = @buffer[0..lastspace]
        else
          lastchars = ""
        end
        $log.debug "last sapce #{lastspace}, #{lastchars}, #{@list[@prow]} "
        ## wrap on word
        ret = down 
        (append_row(lastchars) && down) if ret == -1
        @curpos = lastchars.length # 0
        @form.col = @orig_col + @col_offset + @curpos
        #addrowcol 1,0                  # positions the cursor down
        set_form_row
        @buffer = @list[@prow]
        $log.debug "INSIDE putch2: pr:#{@prow} bu:#{@buffer} CP:#{@curpos}"
      elsif @buffer.length >= @maxlen
        $log.debug "INELSE 2 putch : pr:#{@prow} bu:#{@buffer} CP:#{@curpos}"
        if @list[@prow+1].nil? or @list[@prow+1].length >= @maxlen
          @list.insert @prow+1, ""
          $log.debug "created new row #{@list.length}"
        end
        lastchars = ""
        lastspace = @buffer.rindex(" ")
        if !lastspace.nil?
          lastchars = @buffer[lastspace..-1]
          @list[@prow] = @buffer[0..lastspace-1]
        end
        $log.debug "last sapce #{lastspace},#{@buffer.length},#{lastchars}, #{@list[@prow]} "
        ## wrap on word XXX some strange behaviour stiill over here.
        newbuff = @list[@prow+1]
        newbuff.insert(0, lastchars) # @buffer[-1,1])
        $log.debug "beforelast char to new row. buffer:#{@buffer}"
        #@list[@prow] = @buffer[0..-2]
        @buffer = @list[@prow]
        $log.debug "moved last char to new row. buffer:#{@buffer}"
        $log.debug "buffer len:#{@buffer.length} curpos #{@curpos} maxlen #{@maxlen} " 
        # sometimme cursor is on a space and we;ve pushed it to next line
        # so cursor > buffer length
      end
      @curpos = @buffer.length if @curpos > @buffer.length
      @buffer.insert(@curpos, char)
      @curpos += 1 
      addcol 1
      @modified = true
      0
    end
    def append_row chars=""
        $log.debug "append row sapce:#{chars}."
      @list.insert @prow+1, chars
    end

    def putc c
      if c >= 0 and c <= 127
        ret = putch c.chr
        if ret == 0
        # addcol 1
          set_modified 
        end
      end
      return -1
    end
    # DELETE func
    def delete_at index=@curpos
      return -1 if !@editable 
      $log.debug "dele : #{@prow} #{@buffer} #{index}"
      @buffer.slice!(@curpos)
      # if no newline at end of this then bring up prev character/s till maxlen
      if @buffer[-1,1]!="\r"
        @buffer[-1]=" " if @buffer[-1,1]=="\n"
        if !next_line.nil? and next_line.length > 0
          move_chars_up
        end
      end
      @modified = true
    end
    # move up one char from next row to current, used when deleting in a line
    # should not be called if line ends in "\r"
    def move_char_up
      @list[@prow] << @list[@prow+1].slice!(0)
      delete_line(@prow+1) if next_line().length==0
    end
    # tries to move up as many as possible
    # should not be called if line ends in "\r"
    def move_chars_up
      space_left = @maxlen - @buffer.length
      can_move = [space_left, next_line.length].min
      @list[@prow] << @list[@prow+1].slice!(0, can_move)
      delete_line(@prow+1) if next_line().length==0
    end
    def next_line
      @list[@prow+1]
    end
    def do_relative_row num
      yield @list[@prow+num] 
    end
    def set_modified tf=true
      @modified = tf
      @form.modified = true if tf
    end
  end # class textarea
  ##
  # A viewable read only box. Can scroll. 
  # Intention is to be able to change content dynamically - the entire list.
  # Use set_content to set content, or just update the list attrib
  # TODO - horizontal scrolling,
  #      - searching, goto line
  class TextView < Widget
    include Scrollable
    dsl_accessor :height
    dsl_accessor :title
    dsl_accessor :list    # the array of data to be sent by user
    dsl_accessor :maxlen    # the array of data to be sent by user
    attr_reader :toprow
    attr_reader :prow
    attr_reader :winrow

    def initialize form, config={}, &block
      @focusable = true
      @editable = false
      @left_margin = 1
      @row = 0
      @col = 0
      @show_focus = false  # don't highlight row under focus
      @list = []
      super
      @row_offset = @col_offset = 1
      @orig_col = @col
      # this does result in a blank line if we insert after creating. That's required at 
      # present if we wish to only insert
      @scrollatrow = @height-2
      @content_rows = @list.length
      @win = @form.window
      init_scrollable
      print_borders
      @maxlen ||= @width-2
    end
    def set_content list
      @list = list
    end
    ## display this row on top
    def top_row(*val)
      if val.empty?
        @toprow
      else
        @toprow = val[0] || 0
        @prow = val[0] || 0
      end
    end
    ##
    # returns row of first match of given regex (or nil if not found)
    def find_first_match regex
      @list.each_with_index do |row, ix|
        return ix if !row.match(regex).nil?
      end
      return nil
    end
    def rowcol
      $log.debug "textarea rowcol : #{@row+@row_offset+@winrow}, #{@col+@col_offset}"
      return @row+@row_offset+@winrow, @col+@col_offset
    end
    def wrap_text(txt, col = @maxlen)
      $log.debug "inside wrap text for :#{txt}"
      txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,
               "\\1\\3\n") 
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
    def repaint # textarea
      paint
    end
    def getvalue
      @list
    end
    # textarea
    # [ ] scroll left right
    def handle_key ch
      @buffer = @list[@prow]
      if @buffer.nil? and @list.length == 0
        @list << ""
        @buffer = @list[@prow]
      end
      return if @buffer.nil?
      $log.debug " before: curpos #{@curpos} blen: #{@buffer.length}"
      if @curpos > @buffer.length
        addcol(@buffer.length-@curpos)+1
        @curpos = @buffer.length
      end
      $log.debug " after loop : curpos #{@curpos} blen: #{@buffer.length}"
      pre_key
      case ch
      when ?\C-n
        space
      when ?\C-p
        minus
      when ?\C-[
        goto_start
      when ?\C-]
        goto_end
      when KEY_UP
        #select_prev_row
        ret = up
        #addrowcol -1,0 if ret != -1 or @winrow != @oldwinrow                 # positions the cursor up 
        @form.row = @row + 1 + @winrow
      when KEY_DOWN
        ret = down
        @form.row = @row + 1 + @winrow
      when KEY_LEFT
        req_prev_char
      when KEY_RIGHT
        req_next_char
      when KEY_BACKSPACE, 127
        req_prev_char
      when 330
        req_prev_char
      when ?\C-a
        set_form_col 0
      when ?\C-e
        set_form_col @buffer.length
      else
        $log.debug("ch #{ch}")
      end
      post_key
    end
    # puts cursor on correct row.
    def set_form_row
      @form.row = @row + 1 + @winrow
    end
    # set cursor on correct column
    def set_form_col col=@cursor
      @curpos = col
      @form.col = @orig_col + @col_offset + @curpos
    end
    def req_next_char
      if @curpos < @width and @curpos < @maxlen-1 # else it will do out of box
        @curpos += 1
        addcol 1
      end
    end
    def addcol num
      @form.addcol num
    end
    def addrowcol row,col
    @form.addrowcol row, col
  end
  def req_prev_char
    if @curpos > 0
      @curpos -= 1
      addcol -1
    end
  end
    def next_line
      @list[@prow+1]
    end
    def do_relative_row num
      yield @list[@prow+num] 
    end
  end # class textview
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
      colors = Ncurses.COLORS
      $log.debug "START #{colors} colors  ---------"
      @form = Form.new @win
      r = 1; c = 22;
      %w[ name line regex password].each do |w|
        field = Field.new @form do
          name   w 
          row  r 
          col  c 
          display_length  30
          set_buffer "abcd " 
          set_label Label.new @form, {'text' => w}
        end
        r += 1
      end
      $results = Variable.new
      $results.value = "A variable"
      var = RubyCurses::Label.new @form, {'text_variable' => $results, "row" => r, "col" => 22}
        r += 1
        mylist = []
        0.upto(100) { |v| mylist << "#{v} scrollable data" }
        listb = Listbox.new @form do
          name   "mylist" 
          row  r 
          col  1 
          width 40
          height 10
          list mylist
        end
        listb.insert 55, "hello ruby", "so long python", "farewell java", "RIP .Net"
        texta = TextArea.new @form do
          name   "mytext" 
          row  1 
          col  52 
          width 40
          height 15
        end
        texta << "I expect to pass through this world but once." << "Any good therefore that I can do, or any kindness or abilities that I can show to any fellow creature, let me do it now. "
        texta << "Let me not defer it or neglect it, for I shall not pass this way again."
        #texta << "hello there" << "we are testing deletes in this application"
        #texta << "HELLO there" << "WE ARE testing deletes in this application"
        texta << " "
        texta << " F1 to exit. or click second button"

        @textview = TextView.new @form do
          name   "myView" 
          row  16 
          col  52 
          width 40
          height 7
        end
        content = File.open("../../README.txt","r").readlines
        @textview.set_content content
        @textview.top_row 21

        # just for demo, lets scroll the text view as we scroll this.
        listb.bind(:ENTER_ROW, @textview) { |arow, tview| tview.top_row arow }
        
        # just for demo, lets scroll the text view to the line you enter
        @form.by_name["line"].bind(:LEAVE, @textview) { |fld, tv| tv.top_row(fld.getvalue.to_i) }
        @form.by_name["regex"].bind(:LEAVE, @textview) { |fld, tv| tv.top_row(tv.find_first_match(fld.getvalue)) }

      checkbutton = CheckBox.new @form do
        text_variable $results
        #value = true
        onvalue "selected cb"
        offvalue "UNselected cb"
        text "Please click me"
        row 17
        col 22
      end

      @form.by_name["line"].display_length = 3
      @form.by_name["line"].maxlen = 3
      @form.by_name["line"].set_buffer  "24"
      @form.by_name["name"].set_buffer  "Not focusable"
      @form.by_name["line"].chars_allowed = /\d/
      @form.by_name["regex"].type(:ALPHA)
      @form.by_name["name"].set_focusable(false)
      @form.by_name["password"].set_buffer ""
      @form.by_name["password"].show '*'
      @form.bind(:ENTER) { |f|   f.label.bgcolor = $promptcolor if f.instance_of? RubyCurses::Field}
      @form.bind(:LEAVE) { |f|  f.label.bgcolor = $datacolor  if f.instance_of? RubyCurses::Field}
      ok_button = Button.new @form do
        text "OK"
        name "OK"
        row 18
        col 22
      end
      ok_button.command { |form| form.dump_data;form.printstr(@window, 23,45, "Dumped data to log") }
        #text "Cancel"
      cancel_button = Button.new @form do
        text_variable $results
        row 18
        col 28
        surround_chars ['{','}']
      end
      cancel_button.command { |form| form.printstr(@window, 23,45, "Cancel CALLED"); throw(:close); }

      Label.new @form, {'text' => "Select a language:", "row" => 20, "col" => 22}
      $radio = Variable.new
      radio1 = RadioButton.new @form do
        text_variable $radio
        text "ruby"
        value "ruby"
        row 21
        col 22
      end
      radio2 = RadioButton.new @form do
        text_variable $radio
        text  "java"
        value  "java"
        row 22
        col 22
      end

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
