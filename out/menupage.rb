#!/usr/bin/ruby
# Copyright (c) 2004 by Simon Kaczor <skaczor@cox.net>

require 'rubygems'
require 'ncurses'

include Ncurses
include Ncurses::Form

def print_this(win, text, color, x, y)
    if(win == nil)
      win = stdscr;
    end
    color=Ncurses.COLOR_PAIR(color);
    win.attron(color);
    #win.mvprintw(x, y, "%-40s" % text);
    win.mvprintw(x, y, "%s" % text);
    win.attroff(color);
    Ncurses.refresh
end

def print_in_middle(win, starty, startx, width, string, color)

  if(win == nil)
    win = stdscr;
  end
  x = Array.new
  y = Array.new
  Ncurses.getyx(win, y, x);
  if(startx != 0)
    x[0] = startx;
  end
  if(starty != 0)
    y[0] = starty;
  end
  if(width == 0)
    width = 80;
  end
  length = string.length;
  temp = (width - length)/ 2;
  x[0] = startx + temp.floor;
  win.attron(color);
  win.mvprintw(y[0], x[0], "%s", string);
  win.attroff(color);
  Ncurses.refresh();
end

fields = Array.new


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
  Ncurses.init_pair(6, COLOR_WHITE, COLOR_BLUE); # for stdscr and bottom/top bar
  Ncurses.init_pair(7, COLOR_WHITE, COLOR_RED); # for error messages
  stdscr.bkgd(Ncurses.COLOR_PAIR(6));

  menuarr = []
  menuitem = {}
  menuitem["short"] = "COMPOSE"
  menuitem["long"] = "Compose a mail"
  menuitem["key"] = "C"
  menuitem["action"] = "ruby emailcli.rb"
  menuarr << menuitem
  menuitem = {}
  menuitem["short"] = "LIST"
  menuitem["long"] = "List folders"
  menuitem["key"] = "L"
  menuitem["action"] = "ruby gen3.rb"
  menuarr << menuitem
  menuitem = {}
  menuitem["short"] = "INBOX"
  menuitem["long"] = "Read Inbox"
  menuitem["key"] = "I"
  menuitem["action"] = "ruby gen1.rb"
  menuarr << menuitem
  menuitem = {}
  menuitem["short"] = "QUIT"
  menuitem["long"] = "Quit Application"
  menuitem["key"] = "Q"
  menuitem["action"] = ":exit"
  menuarr << menuitem

  keyhash = {}
  # Initialize the fields
  menuarr.each_index { |i|
    field = FIELD.new(1, 70, i*2+4, 1, 0, 0)
    menuitem = menuarr[i]
    field.user_object = menuitem
    field.set_field_buffer(0, sprintf("%3s    %10s  - %30s", menuitem["key"], menuitem["short"],menuitem["long"]))
#    field.set_field_back(A_UNDERLINE)
    field.field_opts_off(O_EDIT)
    field.field_opts_off(O_STATIC)
    fields.push(field)
    keyhash[menuitem["key"].upcase]=menuitem["action"]
    keyhash[menuitem["key"].downcase]=menuitem["action"]
  }



  # Create the form and post it
  my_form = FORM.new(fields);

  my_form.user_object = "My identifier"

  # Calculate the area required for the form
  rows = Array.new()
  cols = Array.new()
  my_form.scale_form(rows, cols);

  # Create the window to be associated with the form 
  my_form_win = WINDOW.new(0,0,0,0)
  my_panel = my_form_win.new_panel
  Ncurses::Panel.update_panels

  my_form_win.bkgd(Ncurses.COLOR_PAIR(5));
  my_form_win.keypad(TRUE);

  # Set main window and sub window
  my_form.set_form_win(my_form_win);
  my_form.set_form_sub(my_form_win.derwin(rows[0], cols[0], 2, 12));

  # Print a border around the main window and print a title */
  #my_form_win.box(0, 0);
  #print_in_middle(my_form_win, 1, 0, cols[0] + 14, "Main Menu", Ncurses.COLOR_PAIR(6));
  Ncurses.refresh();

  my_form.post_form();

  # Print field types
  
  my_form_win.wrefresh();

  stdscr.mvprintw(0, 0, "%-80s" % "My Application V 100.0.0.1    MAIN MENU         " );
  stdscr.mvprintw(Ncurses.LINES - 2, 28, "Use UP, DOWN arrow keys to switch between fields");
  stdscr.mvprintw(Ncurses.LINES - 1, 28, "Press F1 to quit");
  stdscr.refresh();

  field_init_proc = proc {
    x = my_form.current_field
    ix = fields.index(x)
    item = menuarr[ix]
    act = item["action"]
    fields[ix].set_field_back(Ncurses.COLOR_PAIR(4))
    print_this(nil, act.to_s, 6, Ncurses.LINES-1, 58)
  }
  field_term_proc = proc {
    x = my_form.current_field
    ix = fields.index(x)
    fields[ix].set_field_back(A_NORMAL)
  }

  my_form.set_field_init(field_init_proc)
  my_form.set_field_term(field_term_proc)
      my_form.form_driver(REQ_FIRST_FIELD);
  # Loop through to get user requests
  while((ch = my_form_win.getch()) != KEY_F1 )
    case ch
    when KEY_DOWN
      # Go to next field */
      my_form.form_driver(REQ_NEXT_FIELD);
      
    when KEY_UP
      # Go to previous field
      my_form.form_driver(REQ_PREV_FIELD);

    when KEY_ENTER, 10
      # selection
      x = my_form.current_field
      ix = fields.index(x)
      item = menuarr[ix]
      act = item["action"]
        #system(act)
    else
      c = sprintf("%c", ch);
      if keyhash.include?c
        print_this(nil, keyhash[c].to_s, 6, Ncurses.LINES-1, 58)
        #system(c)
      else
        print_this(nil, sprintf("[Command %c is not defined for this screen]", ch), 7, Ncurses.LINES-3, 28)
      end
  end
  end
  # Un post form and free the memory
  my_form.unpost_form();
  my_form.free_form();
  fields.each {|f| f.free_field()}


ensure
  Ncurses.endwin();
end

