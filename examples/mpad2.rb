#!/usr/bin/env ruby

# REQUIRES A FILE NAMED "TODO" in current folder, to display and page
# a basic file pager to check out ncurses ruby pad
# working in 1.8.7 but not showing anything when i hit a key in 1.9.1
require 'rubygems'
require 'ncurses'
require 'logger'

include Ncurses
include Ncurses::Form

class Fixnum
   def ord
     self
   end
## mostly for control and meta characters
   def getbyte(n)
     self
   end
end unless "a"[0] == "a"


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
  #stdscr.bkgd(Ncurses.COLOR_PAIR(6)); ## DO NOT TOUCH stdscr please

  $log = Logger.new("view.log")
  $log.level = Logger::DEBUG
  # Create the window to be associated with the form 
  @screenrows = Ncurses.LINES-3
  screencols = 80
  @startrow = 1
  my_form_win = WINDOW.new(0,0,0,0)
  x = Array.new
  y = Array.new
  Ncurses.getmaxyx(my_form_win, y, x)
  $log.debug " x = #{x[0]}, y = #{y[0]}"
  screencols = 99; x[0]-15
  my_panel = my_form_win.new_panel
  textary = File.open("../TODO","r").readlines
  my_pad = Ncurses.newpad(textary.count,100)
  pad = my_pad.new_panel
  Ncurses::Panel.update_panels

  my_form_win.bkgd(Ncurses.COLOR_PAIR(5));
  my_pad.keypad(TRUE);

  # Set main window and sub window

  # Print a border around the main window and print a title */
  #my_form_win.box(0, 0);
  #print_in_middle(my_form_win, 1, 0, cols[0] + 14, "Main Menu", Ncurses.COLOR_PAIR(6));
  Ncurses.refresh();

  textary.each_index { |ix|
    my_pad.mvaddstr(ix, 0, textary[ix])
  }

  # Print field types
  
  #my_pad.prefresh(0,0, 0,0, Ncurses.LINES,Ncurses.COLS-1);
  #my_form_win.wrefresh();
  @prow = 0; @pcol = 0;
  #my_pad.prefresh(0,0, @startrow ,0, @screenrows,Ncurses.COLS-1);
  # trying out overwrite since copywin retuns ERR -1
  #ret = Ncurses.copywin(my_pad, my_form_win, 0,0,@startrow,0, @screenrows, Ncurses.COLS-1, 0)
  ### ret = Ncurses.overwrite(my_pad, my_form_win) # worked
  ### $log.debug("overwrite #{ret}")
#  ret = Ncurses.overwrite(my_form_win, my_pad)
  #my_form_win.wrefresh(); << this line clears what pad has put, but needed by copywin etc i think


  # Loop through to get user requests
  # # XXX Need to clear pad so earlier data in last line does not still remain
  while((ch = my_pad.getch()) != KEY_F1 )
    case ch
    when ?j.getbyte(0)
     @prow += 1 
      #next
      # disallow
      if @prow > textary.count
        @prow = textary.count
        Ncurses.beep
        next
      end
    #when KEY_UP
    when ?k.getbyte(0)
     @prow -= 1 
      #next
      # disallow
      if @prow <= 0
        Ncurses.beep
        @prow = 0
        next
      end
    when 32
      @prow += @screenrows
      if @prow > textary.count
        @prow = textary.count
        Ncurses.beep
        next
      end
    when ?-.getbyte(0)
      if @prow <= 0
        Ncurses.beep
        @prow = 0
        next
      end
     @prow -= @screenrows
    when ?t.getbyte(0)
        @pcol = @prow = 0
    when ?h.getbyte(0)
      @pcol += 1
    when ?l.getbyte(0)
      @pcol -= 1
    when ?r.getbyte(0)
      my_form_win.wclear # 2009-10-10 17:46 
    when KEY_ENTER, 10
      # selection
    when ?q.getbyte(0), ?\,
      break
    end
    @pcol = 0 if @pcol < 0
    # clear is required but in 1.9.1 there is no prefresh after a clear. screen blanks out totally
    #my_form_win.wclear # 2009-10-10 17:46 
    #my_form_win.werase # 2009-10-10 17:46 
  #  my_pad.prefresh(@prow,@pcol, @startrow,0, @screenrows,Ncurses.COLS-1);
  #ret = Ncurses.copywin(my_pad, my_form_win, @prow,@pcol,@startrow,0, @screenrows, Ncurses.COLS-1, 0)
  #ret = my_pad.copywin( my_form_win, @prow,@pcol,@startrow,0, @screenrows, Ncurses.COLS-1, 0)
  ret = my_pad.copywin( my_form_win, @prow,@pcol,0,0, @screenrows, screencols, 0)
  $log.debug("copywin #{ret} : cols:#{screencols}")
   my_form_win.wrefresh # if i don't put this then upon return the other screen is still shown
                         # till i press a key
  Ncurses::Panel.update_panels
  end
  # Un post form and free the memory


ensure
  Ncurses.endwin();
end
