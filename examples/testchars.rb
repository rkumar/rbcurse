#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
#require 'lib/ver/keyboard'
require 'rbcurse'
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG

    @window = VER::Window.root_window

    catch(:close) do
      colors = Ncurses.COLORS
      @form = Form.new @window
      r = 1; c = 1;
      arr=[]; sarr=[]

sarr << "ACS_BBSS"
arr << ACS_BBSS
sarr << "ACS_BLOCK"
arr << ACS_BLOCK
sarr << "ACS_BOARD"
arr << ACS_BOARD
sarr << "ACS_BSBS"
arr << ACS_BSBS
sarr << "ACS_BSSB"
arr << ACS_BSSB
sarr << "ACS_BSSS"
arr << ACS_BSSS
sarr << "ACS_BTEE"
arr << ACS_BTEE
sarr << "ACS_BULLET"
arr << ACS_BULLET
sarr << "ACS_CKBOARD"
arr << ACS_CKBOARD
sarr << "ACS_DARROW"
arr << ACS_DARROW
sarr << "ACS_DEGREE"
arr << ACS_DEGREE
sarr << "ACS_DIAMOND"
arr << ACS_DIAMOND
sarr << "ACS_GEQUAL"
arr << ACS_GEQUAL
sarr << "ACS_HLINE"
arr << ACS_HLINE
sarr << "ACS_LANTERN"
arr << ACS_LANTERN
sarr << "ACS_LARROW"
arr << ACS_LARROW
sarr << "ACS_LEQUAL"
arr << ACS_LEQUAL
sarr << "ACS_LLCORNER"
arr << ACS_LLCORNER
sarr << "ACS_LRCORNER"
arr << ACS_LRCORNER
sarr << "ACS_LTEE"
arr << ACS_LTEE
sarr << "ACS_NEQUAL"
arr << ACS_NEQUAL
sarr << "ACS_PI"
arr << ACS_PI
sarr << "ACS_PLMINUS"
arr << ACS_PLMINUS
sarr << "ACS_PLUS"
arr << ACS_PLUS
sarr << "ACS_RARROW"
arr << ACS_RARROW
sarr << "ACS_RTEE"
arr << ACS_RTEE
sarr << "ACS_S1"
arr << ACS_S1
sarr << "ACS_S3"
arr << ACS_S3
sarr << "ACS_S7"
arr << ACS_S7
sarr << "ACS_S9"
arr << ACS_S9
sarr << "ACS_SBBS"
arr << ACS_SBBS
sarr << "ACS_SBSB"
arr << ACS_SBSB
sarr << "ACS_SBSS"
arr << ACS_SBSS
sarr << "ACS_SSBB"
arr << ACS_SSBB
sarr << "ACS_SSBS"
arr << ACS_SSBS
sarr << "ACS_SSSB"
arr << ACS_SSSB
sarr << "ACS_SSSS"
arr << ACS_SSSS
sarr << "ACS_STERLING"
arr << ACS_STERLING
sarr << "ACS_TTEE"
arr << ACS_TTEE
sarr << "ACS_UARROW"
arr << ACS_UARROW
sarr << "ACS_ULCORNER"
arr << ACS_ULCORNER
sarr << "ACS_URCORNER"
arr << ACS_URCORNER
sarr << "ACS_VLINE"
arr << ACS_VLINE

sarr.each_index { |i|
  @window.mvaddch r,c, arr[i]
  @window.mvprintw r,c+2,"%s", sarr[i]
  r+=1
  if r == 25
    r = 1
    c+=25
  end
}

      #@form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != ?q.getbyte(0) )
        str = keycode_tos ch
        @form.handle_key(ch)
        @window.wrefresh
      end
    end
  rescue => ex
  ensure
    @window.destroy if !@window.nil?
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
