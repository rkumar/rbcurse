#!/usr/bin/ruby

require 'rubygems'
require 'ncurses'

include Ncurses
include Ncurses::Form

class PadReader

  def initialize(rows=Ncurses.LINES-3, cols=Ncurses.COLS-1)
    @rows = rows
    @cols = cols
    @startrow = 1
    @header_row = 0
  end
  def view_file(filename)
    @file = filename
    @content = File.open(filename,"r").readlines
    @content_rows = @content.count
    run()
  end

  def run
    begin
    @win = WINDOW.new(0,0,0,0)
      # the next line will not obscure footer and header win of prev screen
    #@win = WINDOW.new(@rows,@cols,1,0)
    @panel = @win.new_panel
    @pad = Ncurses.newpad(@content_rows,@cols)
    @padpanel = @pad.new_panel
    Ncurses::Panel.update_panels
    @content.each_index { |ix|
      @pad.mvaddstr(ix, 0, @content[ix])
    }

    @win.bkgd(Ncurses.COLOR_PAIR(5));
    @pad.keypad(TRUE);

    Ncurses.refresh();


    # Print field types

    @prow = 0; @pcol = 0;
    print_header_left( sprintf("%*s", @cols, " "))
    print_header_left(@file) if !@file.nil?
    print_header_right(sprintf("  %d rows", @content_rows))
    @win.wrefresh
    @pad.prefresh(0,0, @startrow ,0, @rows,Ncurses.COLS-1);


    # Loop through to get user requests
    # # XXX Need to clear pad so earlier data in last line does not still remain
    while((ch = @pad.getch()) != KEY_F1 )
      print_header_left( sprintf("%*s", @cols, " "))
      print_header_left(@file) if !@file.nil?
      print_header_right(sprintf("  %d rows", @content_rows))
      @win.wrefresh
      case ch
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
          Ncurses.beep
          #next
        else
          @prow += @rows
        end
      when ?-
        if @prow <= 0
          Ncurses.beep
          #@prow = 0
          #next
        else
          @prow -= @rows
        end
      when KEY_ENTER, 10
        # selection
      when ?q, ?\,
        break
      end
      @win.wclear
      @pad.prefresh(@prow,@pcol, @startrow,0, @rows,Ncurses.COLS-1);
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
    pv = PadReader.new
    pv.view_file("../../README.txt")

  ensure
    Ncurses.endwin();
  end
 end
