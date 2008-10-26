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
  my_form_win = WINDOW.new(20,0,2,0)
  my_panel = my_form_win.new_panel
  my_pad = Ncurses.newpad(100,100)
  pad = my_pad.new_panel
  Ncurses::Panel.update_panels

  my_form_win.bkgd(Ncurses.COLOR_PAIR(5));
  my_pad.keypad(TRUE);

  # Set main window and sub window
  my_form.set_form_win(my_form_win);
  #my_form.set_form_sub(my_form_win.derwin(rows[0], cols[0], 2, 12));

  # Print a border around the main window and print a title */
  #my_form_win.box(0, 0);
  #print_in_middle(my_form_win, 1, 0, cols[0] + 14, "Main Menu", Ncurses.COLOR_PAIR(6));
  Ncurses.refresh();

  my_form.post_form();

  # Print field types
  
  #my_pad.prefresh(0,0, 0,0, Ncurses.LINES,Ncurses.COLS);
  #my_form_win.wrefresh();
  my_pad.prefresh(0,0, 5,0, 10,Ncurses.COLS);

  @labelarr.each{ |lhash|
    posy = lhash["position"][0]
    posx = lhash["position"][1]
    if posy < 0
      posy = Ncurses.LINES + posy
    end
    if posx < 0
      posx = Ncurses.COLS + posy
    end
    text = lhash["text"]
    color_pair = lhash["color_pair"] || 6
    my_form_win.attron(Ncurses.COLOR_PAIR(color_pair))
    my_form_win.mvprintw(posy, posx, "%-s" % text );
    my_form_win.attroff(Ncurses.COLOR_PAIR(color_pair))
  }
  header = @form["header"]
  subheader = @form["subheader"]
  posy = 0
  posx = 0
  htext = "<APPLICATION NAME>  <VERSION>          MAIN MENU"
  if !header.nil?
    posy = header[0]
    posx = header[1]
    htext = header[2]
  end
    my_form_win.attron(Ncurses.COLOR_PAIR(6))
  my_form_win.mvprintw(posy, posx, "%-*s" % [Ncurses.COLS, htext] );
    my_form_win.attroff(Ncurses.COLOR_PAIR(6))
  if !subheader.nil?
    my_form_win.mvprintw(subheader[0],subheader[1], "%-*s" % [ Ncurses.COLS, subheader[2]]);
  end
  #stdscr.mvprintw(Ncurses.LINES - 2, 28, "Use UP, DOWN arrow keys to switch between fields");
  #stdscr.mvprintw(Ncurses.LINES - 1, 28, "Press F1 to quit");
  #stdscr.refresh();
  #my_form_win.wrefresh();
  #my_pad.prefresh(0,0, 0,0, Ncurses.LINES-1,Ncurses.COLS-1);
  my_pad.prefresh(0,0, 5,0, 10,Ncurses.COLS);

  field_init_proc = proc {
    x = my_form.current_field
    ix = fields.index(x)
    item = @menuarr[ix]
    act = item["message"]
    fields[ix].set_field_back(Ncurses.COLOR_PAIR(4))
    print_this(my_form_win, act.to_s, 6, Ncurses.LINES-1, 58)
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
  while((ch = my_pad.getch()) != KEY_F1 )
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
      item = @menuarr[ix]
      act = item["action"]
      break if act == "quit"  # bad hack, i really don't know what to do.
      menu_action(act)
    else
      c = sprintf("%c", ch);
      if keyhash.include?c
        print_this(my_form_win, keyhash[c].to_s, 6, Ncurses.LINES-1, 58)
        pos = keypos[c.downcase]
        x = my_form.current_field
        ix = fields.index(x)
        (pos-ix).times{ my_form.form_driver(REQ_NEXT_FIELD) } if pos > ix
        (ix-pos).times{ my_form.form_driver(REQ_PREV_FIELD) } if pos < ix
        break if keyhash[c] == "quit"  # bad hack, i really don't know what to do.
        menu_action(keyhash[c])
      else
        print_this(my_form_win, sprintf("[Command %c is not defined for this screen]   ", ch), 7, Ncurses.LINES-3, 28)
      end
    end
    my_form_win.wrefresh # if i don't put this then upon return the other screen is still shown
                         # till i press a key
  Ncurses::Panel.update_panels
  end
  # Un post form and free the memory
  my_form.unpost_form();
  my_form.free_form();
  fields.each {|f| f.free_field()}


ensure
  Ncurses.endwin();
end

