#!/usr/bin/ruby

require 'rubygems'
require 'ncurses'

include Ncurses
include Ncurses::Form


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

  # Create the window to be associated with the form 
  @screenrows = Ncurses.LINES-3
  @startrow = 1
  my_form_win = WINDOW.new(0,0,0,0)
  my_panel = my_form_win.new_panel
  textary = File.open("TODO","r").readlines
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
  
  #my_pad.prefresh(0,0, 0,0, Ncurses.LINES,Ncurses.COLS);
  #my_form_win.wrefresh();
  @prow = 0; @pcol = 0;
  my_pad.prefresh(0,0, @startrow ,0, @screenrows,Ncurses.COLS-1);


  # Loop through to get user requests
  # # XXX Need to clear pad so earlier data in last line does not still remain
  while((ch = my_pad.getch()) != KEY_F1 )
    case ch
    when KEY_DOWN
      #next
      # disallow
      if @prow > textary.count
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
        next
      end
     @prow -= 1 
    when 32
      if @prow > textary.count
        @prow = textary.count
        Ncurses.beep
        next
      end
     @prow += @screenrows
    when ?-
      if @prow <= 0
        Ncurses.beep
        @prow = 0
        next
      end
     @prow -= @screenrows
    when KEY_ENTER, 10
      # selection
    when ?q, ?\,
      break
    end
    my_form_win.wclear
    my_pad.prefresh(@prow,@pcol, @startrow,0, @screenrows,Ncurses.COLS-1);
    #my_form_win.wrefresh # if i don't put this then upon return the other screen is still shown
                         # till i press a key
  Ncurses::Panel.update_panels
  end
  # Un post form and free the memory


ensure
  Ncurses.endwin();
end
