#!/usr/bin/env ruby
# adapted from the C program at:
# http://tldp.org/HOWTO/NCURSES-Programming-HOWTO/panels.html
# a more complex example of creating 3 panels using ncurses-ruby
# use TAB to traverse.
require 'rubygems'
require 'ncurses'

include Ncurses
include Ncurses::Form
#NLINES=10
NCOLS = 40

class Threetest

  def initialize(stdscr)
    @stdscr = stdscr
    @my_wins = Array.new
    @my_panels = Array.new
    @top  = nil # a panel
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
  def win_show(win, label, label_color)
    starty = []; startx = []
    height = []; width = []
    win.getbegyx(starty, startx);
    win.getmaxyx( height, width);

    win.box( 0, 0);
    win.mvwaddch( 2, 0, ACS_LTEE); 
    win.mvwhline( 2, 1, ACS_HLINE, width[0] - 2); 
    win.mvwaddch( 2, width[0] - 1, ACS_RTEE); 

    print_in_middle(win, 1, 0, width[0], label, Ncurses.COLOR_PAIR(label_color));

  end
  def clear_wins()
    @my_panels.each { |p| Ncurses::Panel.del_panel(p) }
    @my_wins.each { |w| w.delwin }
  end
  def init_wins(wins, n)
    y =2; x=10
    label= ''
    0.upto(n-1) do |i|
      #wins << newwin(NLINES, NCOLS, y, x);
      w  = Ncurses::WINDOW.new(10,NCOLS, y , x)
      label =sprintf( "Window Number %d", i + 1);
      win_show(w, label, i + 1);
      wins << w
      y += 3;
      x += 7;

    end
  end
  def run
    init_wins(@my_wins, 3);
    @my_wins.each{ |w| @my_panels << w.new_panel }

#    Ncurses::Panel.set_panel_userptr(@my_panels[0], @my_panels[1]);
#    Ncurses::Panel.set_panel_userptr(@my_panels[1], @my_panels[2]);
#    Ncurses::Panel.set_panel_userptr(@my_panels[2], @my_panels[0]);
    @my_panels[0].set_panel_userptr( @my_panels[1]);
    @my_panels[1].set_panel_userptr( @my_panels[2]);
    @my_panels[2].set_panel_userptr( @my_panels[0]);
    Ncurses::Panel.update_panels
    Ncurses.doupdate()
    @stdscr.attron(Ncurses.COLOR_PAIR(4));
    @stdscr.mvprintw(Ncurses.LINES - 2, 0, "Use tab to browse through the windows (Alt-q to Exit)");
    @stdscr.attroff(Ncurses.COLOR_PAIR(4));
    Ncurses.doupdate();

    @top = @my_panels[2];
    ix = 2
    # just for fun we are writing into each window when you type, one row col for each window
    col = [1,1,1]
    row = [3,3,3]
    while((ch = @stdscr.getch()) != 147)
      case(ch)
      when 9:
        row[ix]+=1 # start a new row each time you enter a window
        col[ix] = 1 # start of on col 1 each time you tab in
        ix += 1 if ix < 3
        ix = 0 if ix == 3
        @top = Ncurses::Panel.panel_userptr(@top);
        #top = my_panels[ix]
        Ncurses::Panel.top_panel(@top);
        #break;

      else
        @my_wins[ix].mvprintw(row[ix], col[ix], "%c", ch);
        col[ix] += 1
      end
      Ncurses::Panel.update_panels();
      Ncurses.doupdate();
    end
    clear_wins

  end
end
if __FILE__ == $0
  begin

    stdscr=Ncurses.initscr
    Ncurses.start_color
    Ncurses.cbreak
    Ncurses.noecho
    Ncurses.keypad(stdscr, true)
    Ncurses.init_pair(1, COLOR_RED, COLOR_BLACK);
    Ncurses.init_pair(2, COLOR_GREEN, COLOR_BLACK);
    Ncurses.init_pair(3, COLOR_BLUE, COLOR_BLACK);
    Ncurses.init_pair(4, COLOR_CYAN, COLOR_BLACK);

    tp = Threetest.new(stdscr)
    tp.run
  ensure
    Ncurses.endwin();
  end
end
