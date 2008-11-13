=begin
  * Name: rbeditform
  * $Id$
  * Description   Edit form object with its own key_handler
  * Author: rkumar
  * Date: 2008-11-13 13:33 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end

##
# dependencies
#   - @win  the window on which writing is happening
#   - @cols - how many columns on screen, usually Ncurses.COLS-1
#   - @lastrow - last row of screen, errors and message use -2
#   - $header_row - row on which to write - usually 1 should be global for an app
#   - $promptcolor - color used for prompting
#   - $datacolor - color used for prompting
module CommonIO

  ##
  # print a string on a given window/pad, row, col, string text and color pair
    def printstr(pad, r,c,string, color=$datacolor)
      pad.attron(Ncurses.COLOR_PAIR(color))
      pad.mvprintw(r, c, "%s", string);
      pad.attroff(Ncurses.COLOR_PAIR(color))
    end
    def print_message text
      putstring text, @lastrow-2, 1, color = $promptcolor
    end
    def putstring prompt, r=@lastrow-2, c=1, color = $promptcolor
      clear_error @win, r, color
      printstr(@win,r, c, prompt, color);
    end
    def getstring prompt, r=@lastrow-2, c=1, maxlen = 10, color = $promptcolor
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
    def clear_error win, r = @lastrow-2, color = $promptcolor
      printstr(win, r, 0, "%-*s" % [Ncurses.COLS," "], color)
    end
    def print_header_left(string)
      @win.attron(Ncurses.COLOR_PAIR(6))
      @win.mvprintw($header_row, 0, "%s", string);
      @win.attroff(Ncurses.COLOR_PAIR(6))
    end
    def print_header_right(string)
      @win.attron(Ncurses.COLOR_PAIR(6))
      @win.mvprintw($header_row, @cols-string.length, "%s", string);
      @win.attroff(Ncurses.COLOR_PAIR(6))
    end
  def print_this(win, text, color, x, y)
    if(win == nil)
      raise "win nil in printthis"
    end
    color=Ncurses.COLOR_PAIR(color);
    win.attron(color);
    win.mvprintw(x, y, "%s" % text);
    win.attroff(color);
    win.refresh
  end

  # the old historical program which prints a string in middle of whereever
  # thanks to this i was using stdscr which must never be used

  def print_in_middle(win, starty, startx, width, string, color)
    if(win == nil)
       raise "window is nil"
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
    win.refresh();
  end
 
end
