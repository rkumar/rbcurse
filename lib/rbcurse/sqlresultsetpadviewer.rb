#!/usr/bin/ruby

require 'rubygems'
require 'ncurses'
require 'logger'
require 'sqlite3'

include Ncurses
include Ncurses::Form

class SqlResultsetPadViewer

  attr_accessor :header_left   # will print on left what you give

  def initialize(rows=Ncurses.LINES-1, cols=Ncurses.COLS-1)
    @rows = rows
    @cols = cols
    @startrow = 1
    @header_row = 0
    @lastrow = Ncurses.LINES-1 # @rows-1

    @rowid = 0
    @page = 0
    @max_rows = 50
    @more = false
    @maxlen = 0 # length of longest column name
    @promptcolor = 4 # as in alpine
    @barcolor = 2
    @barrow = @lastrow
  end
  def print_data rowid=@rowid, page = 0
    return if rowid< 0 or rowid >= @content.length
    @prow = 0
    data = @content[rowid]
    r = 1
    lc = 1
    dc = @maxlen + 2
    labelcolor = 6
    datacolor = 5
    startfield = page*@max_rows
    @pad.clear
    #range=(startfield..@columns.length).to_a 

    @more = false
    ## LOOP PRINT
    @columns.each_index do |ix|
      printstr(@pad,r, lc, "%s" % @columns[ix], labelcolor);
      printstr(@pad, r, dc, "%s" % data[ix] , datacolor);
      r += 1
    end
    printstr(@win, @barrow, 1, "row %d of %d (N-Next P-Prev Q-Quit, G-Goto, [, ]) " % [rowid+1, @content.length], @barcolor);
    @win.refresh
  end
  def sql(command)
    db = SQLite3::Database.new('../../out/testd.db')
#    db.results_as_hash = true
    #command = %Q{select * from #{tablename} limit 1}
    @columns, *@datarows = db.execute2(command)
    @datatypes = @datarows[0].types
    @content = @datarows
    @content_rows = @columns.length
    $log.debug("sql: #{command}")
#    $log.debug("cols: #{@columns.inspect}")
#    $log.debug("dt: #{@datatypes.inspect}")
#    $log.debug("row0: #{@datarows[0].inspect}")
#    $log.debug("rows: #{@datarows.inspect}")
    db.close
    t=@columns.inject(0) do |t, curr| t>curr.length ? t : curr.length; end
    @maxlen = t
  end

  def run
    begin
    @win = WINDOW.new(0,0,0,0)
      # the next line will not obscure footer and header win of prev screen
    @panel = @win.new_panel
    @pad = Ncurses.newpad([@columns.length+4, @lastrow+1].max,@cols)
    @padpanel = @pad.new_panel
    Ncurses::Panel.update_panels

    print_data
    @win.bkgd(Ncurses.COLOR_PAIR(5));
    @pad.keypad(TRUE);

#    Ncurses.refresh();

    @prow = 0; @pcol = 0;
    print_header_left( sprintf("%*s", @cols, " "))
    print_header_left(@header_left) if !@header_left.nil?
    print_header_right(sprintf("Row 1 of %d ", @content.length))
    @win.wrefresh
    @pad.prefresh(0,0, @startrow ,0, @rows-2,Ncurses.COLS-1);


    # Loop through to get user requests
    # # XXX Need to clear pad so earlier data in last line does not still remain
    while((ch = @pad.getch()) != KEY_F1 )
      print_header_left( sprintf("%*s", @cols, " "))
      print_header_left(@header_left) if !@header_left.nil?
      @win.wrefresh
      case ch
      when ?n:
        next_row
      when ?p:
        @page = 0
        #@win.wscrl(-1)
        @rowid -=1 if @rowid > 0
        print_data @rowid
      when ?[:
        @page = 0
        @rowid =0
        print_data @rowid
      when ?]:
        @page = 0
        @rowid = @content.length() - 1
        print_data @rowid,0
      when KEY_DOWN
        #next
        # disallow
        if @prow > @content_rows
          Ncurses.beep
          next
        end
        @prow += 1 
      when KEY_UP
        #next
        # disallow
        if @prow <= 0
          Ncurses.beep
          @prow = 0
          #next
        else
        @prow -= 1 
        end
      when 32
        if @prow + @rows > @content_rows
          #@prow = @content_rows - @rows
          next_row
          #next
        else
          @prow += @rows-2
        end
      when ?-
        if @prow <= 0
          Ncurses.beep
          #@prow = 0
          #next
        else
          @prow -= (@rows-2)
        end
      when KEY_ENTER, 10
        # selection
      when ?q, ?\,
        break
      when ?g
        line = getstring "Enter row to go to:"
        oldrow = @rowid
        @rowid = line.to_i
        @rowid -= 1 if @rowid > 0
        if @rowid > @content.length
          @rowid = oldrow
          Ncurses.beep
          next
        end
        print_data @rowid,0
      end
      #@win.wclear
      @win.werase # gives less flicker since wclear sems to refresh immed
      print_header_left(@header_left) if !@header_left.nil?
      print_header_right(sprintf("Row %d of %d ", @rowid+1, @content.length))
      printstr(@win, @barrow, 1, "row %d of %d (N-Next P-Prev Q-Quit, G-Goto, [, ]) " % [@rowid+1, @content.length], @barcolor);
      @win.refresh
      @pad.prefresh(@prow,@pcol, @startrow,0, @rows-2,Ncurses.COLS-1);
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
  def next_row
    @prow = 0
    @page = 0
    #@win.wscrl(1)
    @rowid +=1 if @rowid < @content.length - 1 
    print_data @rowid, 0
  end
  def getstring prompt, r=@lastrow-1, c=1, maxlen = 10, color = @promptcolor
    clear_error @win, r, color
    printstr(@win,r, c, prompt, color);
    ret = ''
    Ncurses.echo();
    @win.attron(Ncurses.COLOR_PAIR(color))
    @win.mvwgetnstr(r,c+prompt.length+1,ret,maxlen)
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
    tp = SqlResultsetPadViewer.new
    tp.header_left = "Contracts"
    tp.sql("select * from contracts ")
    tp.run
 #   pv.view_file("test.t")

  ensure
    Ncurses.endwin();
  end
 end
