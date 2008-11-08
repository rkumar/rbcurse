#!/usr/bin/ruby

require 'rubygems'
require 'ncurses'
require 'logger'
require 'sqlite3'

include Ncurses
include Ncurses::Form

class SqlPopup

  attr_accessor :header_left   # will print on left what you give
  attr_accessor :labelcolor   # colorpair of label
  attr_accessor :datacolor   # color pair of data
  attr_accessor :promptcolor   # color pair or prompt
  attr_accessor :barcolor   # color pair of bottom bar

  def initialize(rows=Ncurses.LINES-1, cols=Ncurses.COLS-1)
    @rows = rows
    @cols = cols
    @startrow = 1
    @header_row = 0
    @lastrow = Ncurses.LINES-1 # @rows-1

    @promptcolor = 4 # as in alpine
    @labelcolor = 6
    @datacolor = 5
    @barcolor = 2
    @selectioncolor = 4
    @barrow = @lastrow
    @padrows = Ncurses.LINES-1
    @message = ""
    @selected = []
  end
  def estimate_column_widths
    colwidths = {}
    @content.each_index do |cix|
      break if cix >= 20
      row = @content[cix]
      row.each_index do |ix|
        col = row[ix]
        colwidths[ix] ||= 0
        colwidths[ix] = [colwidths[ix], col.length].max
      end
    end
    total = 0
    colwidths.each_pair do |k,v|
      name = @columns[k.to_i]
      colwidths[name] = v
      total += v
    end
    colwidths["__TOTAL__"] = total
    return colwidths
  end
        

  def print_tabular_data #:yields pad, ix,  row, labelcol, datacol, column_name, column_value
    @prow = 0
    r = 1
    lc = 1
    @pad.clear

    ## LOOP PRINT
    printstr(@pad,r, lc, "#" , @labelcolor);
    lc += 3
    @columns.each do |name|
      printstr(@pad,r, lc, "%s" % name, @labelcolor);
      lc += @colwidths[name]+1
    end
    r += 1
    @content.each_with_index do |row, rowid|
      lc = 1
      printstr(@pad, r, lc, rowid+1 , @datacolor);
      lc += 3
      row.each_index do |ix|
        col = row[ix]
        if block_given?
          yield @pad, r, lc, col
        else
          printstr(@pad, r, lc, " "+col , @datacolor);
          lc += @colwidths[ix]+1
        end
      end
      r += 1
    end
    #printstr(@win, @barrow, 1, "row %d of %d (N-Next P-Prev Q-Quit, G-Goto, [, ]) " % [rowid+1, @content.length], @barcolor);
    @win.refresh
  end
  def sql(command)
    db = SQLite3::Database.new('../../out/testd.db')
#    db.results_as_hash = true
    #command = %Q{select * from #{tablename} limit 1}
    @columns, *@datarows = db.execute2(command)
    @datatypes = @datarows[0].types
    @content = @datarows
    $log.debug("sql: #{command}")
#    $log.debug("cols: #{@columns.inspect}")
#    $log.debug("dt: #{@datatypes.inspect}")
#    $log.debug("row0: #{@datarows[0].inspect}")
#    $log.debug("rows: #{@datarows.inspect}")
    db.close
  end
  def do_select
    if @selected[@prow].nil?
      @selected[@prow] = "X"
    else
     @selected[@prow] = nil
    end
  end

  def show_focus_on_row row0, tf=true
    @focussedrow = row0 if tf
    color = tf ? @selectioncolor : @datacolor
    lc = 1
    r = row0+2
    printstr(@pad, r, 0, "%-*s" % [Ncurses.COLS," "], color)
    printstr(@pad, r, lc, "#{@selected[row0]}%2d" % idx=row0+1 , color);
    lc += 3
    row = @content[row0]
    row.each_index do |ix|
      col = row[ix]
      if block_given?
        yield @pad, r, lc, col
      else
        printstr(@pad, r, lc, " "+col , color);
        lc += @colwidths[ix]+1
      end
    end
  end
  def run_tabular
    begin
    @win = WINDOW.new(0,0,0,0)
      # the next line will not obscure footer and header win of prev screen
    @panel = @win.new_panel
    @padrows = [(@content.length) +6, @lastrow+1].max
    @content_rows = @content.length
    @colwidths = estimate_column_widths
    @cols = @colwidths["__TOTAL__"]  +@columns.length
    $log.debug("cols: #{@cols} #{@columns.length}")
    @pad = Ncurses.newpad(@padrows,@cols)
    @padpanel = @pad.new_panel
    Ncurses::Panel.update_panels

    print_tabular_data
    @win.bkgd(Ncurses.COLOR_PAIR(5));
    @pad.keypad(TRUE);

#    Ncurses.refresh();

    @prow = 0; @pcol = 0;
    @toprow = 0
    ## CLEAR clear row
    print_header_left( sprintf("%*s", @cols, " "))
    print_header_left(@header_left) if !@header_left.nil?
    print_header_right(sprintf("Row 1 of %d ", @content.length))
    @win.wrefresh
    show_focus_on_row(0)
    @scrolling = false
    @winrow = 0
    @pad.prefresh(0,0, @startrow ,0, @rows-2,Ncurses.COLS-1);


    # Loop through to get user requests
    # # XXX Need to clear pad so earlier data in last line does not still remain
    while((ch = @pad.getch()) != KEY_F1 )
      print_header_left( sprintf("%*s", @cols, " "))
      print_header_left(@header_left) if !@header_left.nil?
      @win.wrefresh
      @oldprow = @prow
      @oldwinrow = @winrow
      c = ch.chr rescue 0
      $log.debug("ch: %d %s" % [ch, c])
      case ch
      when ?[:      # BEGINNING
        @prow = 0
        @toprow = @prow
      when ?]:       # GOTO END
        #@prow = @content_rows - (@rows-2)
        @prow = @content_rows-1 
        @toprow = @prow
        @winrow = 0     # not putting this was cause prow < toprow !!
      when KEY_RIGHT,?l
        @pcol += 20 if @pcol + 50 < @cols
        $log.debug("pcols = #{@pcol}")
      when KEY_LEFT, ?h
        @pcol -= 20 if @pcol > 0
        @pcol = 0 if @pcol < 0
      when KEY_DOWN, ?j
        if @prow >= @content_rows-1
          Ncurses.beep
          next
        end
        if @winrow < 20 # @lastrow-2
          @winrow += 1
        else
          @toprow += 1 
        end
        @prow += 1 
      when KEY_UP,?k
        #next
        # disallow
        if @prow <= 0
          Ncurses.beep
          @prow = 0
          #  next
        else
          @prow -= 1 
        end
        if @winrow > 0 
          @winrow -= 1
        else
          @toprow -= 1 if @toprow > 0
        end
        $log.error("ERR !!!! #{@winrow} pr #{@prow} tr #{@toprow}") if @prow < @toprow
        @toprow = @prow if @prow < @toprow
      when 32, ?n:
        if @prow + @rows > @content_rows
          next
        else
          @prow += @rows-2
          @toprow = @prow
        end
      when ?-,?p:
        if @prow <= 0
          Ncurses.beep
          @prow = 0
          #next
        else
          @prow -= (@rows-2)
          @prow = 0 if @prow < 0
        end
          @toprow = @prow
      when KEY_ENTER, 10
        # selection
      when ?q, ?\,
        break
      when ?g
        line = getstring "Enter row to go to:"
        oldrow = @prow
        @prow = line.to_i
        @prow -= 1 if @prow > 0
        if @prow > @content.length
          @prow = oldrow
          Ncurses.beep
          next
        end
      when ?/:
        do_search
      when ?\C-n:
        do_search_next
      when ?\C-p:
        do_search_prev
      when ?x:
        do_select
      end
      #@win.wclear
      @win.werase # gives less flicker since wclear sems to refresh immed
      print_header_left( sprintf("%*s", @cols, " "))
      print_header_left(@header_left) if !@header_left.nil?
      print_header_right(sprintf("Row %d of %d ", @prow+1, @content.length))
      printstr(@win, @barrow, 1, "row %d of %d (N-Next P-Prev Q-Quit, G-Goto, [, ]) %s" % [@prow+1, @content.length, @message], @barcolor);
      @win.refresh
      show_focus_on_row(@oldprow, false)
      show_focus_on_row(@prow)
      $log.debug("tr:wr:pr #{@toprow} #{@winrow} #{@prow}")
      @pad.prefresh(@toprow,@pcol, @startrow,0, @rows-2,Ncurses.COLS-1) 
      Ncurses::Panel.update_panels
      #win.wrefresh # if i don't put this then upon return the other screen is still shown
      # till i press a key
    end # while
    ensure
      Ncurses::Panel.del_panel(@panel) if !@panel.nil?   
      Ncurses::Panel.del_panel(@padpanel) if !@padpanel.nil?   
      @win.delwin if !@win.nil?
    end

  end # run

  def do_search
    regex = getstring "Enter regex to search for:"
    res = []
    @content.each_with_index do |row, ix| res << ix if row.grep(/#{regex}/) != [] end
    $log.debug("RES: "+ res.inspect)
    if res.length > 0
      @prow = res[0]
    end
    @message = "%d matches for %s (Use ^N ^P)" % [res.length, regex]
    @search_indices = res
    @search_index = 0
  end
  def do_search_next
    if @search_indices == []
      Ncurses.beep
    end
    @search_index += 1
    if @search_index >= @search_indices.length
      @search_index = 0
    end
    @prow = @search_indices[@search_index]
  end
  def do_search_prev
    if @search_indices == []
      Ncurses.beep
    end
    @search_index -= 1
    if @search_index < 0
      @search_index = @search_indices.length-1
    end
    @prow = @search_indices[@search_index]
  end

  def getstring prompt, r=@lastrow-1, c=1, maxlen = 10, color = @promptcolor
    clear_error @win, r, color
    printstr(@win,r, c, prompt, color);
    ret = ''
    Ncurses.echo();
    @win.attron(Ncurses.COLOR_PAIR(color))
    begin
    @win.mvwgetnstr(r,c+prompt.length+1,ret,maxlen)
    rescue Interrupt => err
      # C-c
      ret = ''
    end
    @win.attroff(Ncurses.COLOR_PAIR(color))
    Ncurses.noecho();
    return ret
  end
  def clear_error win, r = @lastrow, color = @promptcolor
    printstr(win, r, 0, "%-*s" % [Ncurses.COLS," "], color)
  end
  def print_header_left(string)
    @win.attron(Ncurses.COLOR_PAIR(6))
    @win.mvprintw(@header_row, 0, "%s", string);
    @win.attroff(Ncurses.COLOR_PAIR(6))
  end
  def print_header_right(string)
    @win.attron(Ncurses.COLOR_PAIR(6))
    @win.mvprintw(@header_row, @cols-string.length, "%s", string);
    @win.attroff(Ncurses.COLOR_PAIR(6))
  end
  def printstr(pad, r,c,string, color)
    pad.attron(Ncurses.COLOR_PAIR(color))
    pad.mvprintw(r, c, "%s", string);
    pad.attroff(Ncurses.COLOR_PAIR(color))
  end


  end # class PadReader

 if $0 == __FILE__
  # Initialize curses
  begin
    stdscr = Ncurses.initscr();
    Ncurses.start_color();
    Ncurses.cbreak();
    Ncurses.noecho();
    Ncurses.keypad(stdscr, true);

    # Initialize few color pairs 
    Ncurses.init_pair(1, COLOR_RED, COLOR_BLACK);
    Ncurses.init_pair(2, COLOR_BLACK, COLOR_WHITE);
    Ncurses.init_pair(3, COLOR_BLACK, COLOR_BLUE);
    Ncurses.init_pair(4, COLOR_YELLOW, COLOR_RED); # for selected item
    Ncurses.init_pair(5, COLOR_WHITE, COLOR_BLACK); # for unselected menu items
    Ncurses.init_pair(6, COLOR_WHITE, COLOR_BLUE); # for bottom/top bar
    Ncurses.init_pair(7, COLOR_WHITE, COLOR_RED); # for error messages

    # Create the window to be associated with the form 
    # Un post form and free the memory
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG
    tp = SqlPopup.new
    tp.header_left = "Contracts"
    tp.labelcolor = 5
    tp.datacolor = 2
    tp.sql("select * from contacts ")
      tp.labelcolor = 2
      tp.datacolor = 5
      tp.run_tabular

  ensure
    Ncurses.endwin();
  end
 end
