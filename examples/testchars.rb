#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
#require 'ncurses' # FFI
require 'logger'
#require 'lib/ver/keyboard'
require 'rbcurse'
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new((File.join(ENV["LOGDIR"] || "./" ,"rbc13.log")))
    $log.level = Logger::DEBUG

    @window = VER::Window.root_window

    catch(:close) do
      colors = Ncurses.COLORS
      @form = Form.new @window
      r = 1; c = 1;
      arr=[]; sarr=[]

sarr << "ACS_BBSS"
arr << FFI::NCurses::ACS_BBSS
sarr << "ACS_BLOCK"
arr << FFI::NCurses::ACS_BLOCK
sarr << "ACS_BOARD"
arr << FFI::NCurses::ACS_BOARD
sarr << "ACS_BSBS"
arr << FFI::NCurses::ACS_BSBS
sarr << "ACS_BSSB"
arr << FFI::NCurses::ACS_BSSB
sarr << "ACS_BSSS"
arr << FFI::NCurses::ACS_BSSS
sarr << "ACS_BTEE"
arr << FFI::NCurses::ACS_BTEE
sarr << "ACS_BULLET"
arr << FFI::NCurses::ACS_BULLET
sarr << "ACS_CKBOARD"
arr << FFI::NCurses::ACS_CKBOARD
sarr << "ACS_DARROW"
arr << FFI::NCurses::ACS_DARROW
sarr << "ACS_DEGREE"
arr << FFI::NCurses::ACS_DEGREE
sarr << "ACS_DIAMOND"
arr << FFI::NCurses::ACS_DIAMOND
sarr << "ACS_GEQUAL"
arr << FFI::NCurses::ACS_GEQUAL
sarr << "ACS_HLINE"
arr << FFI::NCurses::ACS_HLINE
sarr << "ACS_LANTERN"
arr << FFI::NCurses::ACS_LANTERN
sarr << "ACS_LARROW"
arr << FFI::NCurses::ACS_LARROW
sarr << "ACS_LEQUAL"
arr << FFI::NCurses::ACS_LEQUAL
sarr << "ACS_LLCORNER"
arr << FFI::NCurses::ACS_LLCORNER
sarr << "ACS_LRCORNER"
arr << FFI::NCurses::ACS_LRCORNER
sarr << "ACS_LTEE"
arr << FFI::NCurses::ACS_LTEE
sarr << "ACS_NEQUAL"
arr << FFI::NCurses::ACS_NEQUAL
sarr << "ACS_PI"
arr << FFI::NCurses::ACS_PI
sarr << "ACS_PLMINUS"
arr << FFI::NCurses::ACS_PLMINUS
sarr << "ACS_PLUS"
arr << FFI::NCurses::ACS_PLUS
sarr << "ACS_RARROW"
arr << FFI::NCurses::ACS_RARROW
sarr << "ACS_RTEE"
arr << FFI::NCurses::ACS_RTEE
sarr << "ACS_S1"
arr << FFI::NCurses::ACS_S1
sarr << "ACS_S3"
arr << FFI::NCurses::ACS_S3
sarr << "ACS_S7"
arr << FFI::NCurses::ACS_S7
sarr << "ACS_S9"
arr << FFI::NCurses::ACS_S9
sarr << "ACS_SBBS"
arr << FFI::NCurses::ACS_SBBS
sarr << "ACS_SBSB"
arr << FFI::NCurses::ACS_SBSB
sarr << "ACS_SBSS"
arr << FFI::NCurses::ACS_SBSS
sarr << "ACS_SSBB"
arr << FFI::NCurses::ACS_SSBB
sarr << "ACS_SSBS"
arr << FFI::NCurses::ACS_SSBS
sarr << "ACS_SSSB"
arr << FFI::NCurses::ACS_SSSB
sarr << "ACS_SSSS"
arr << FFI::NCurses::ACS_SSSS
sarr << "ACS_STERLING"
arr << FFI::NCurses::ACS_STERLING
sarr << "ACS_TTEE"
arr << FFI::NCurses::ACS_TTEE
sarr << "ACS_UARROW"
arr << FFI::NCurses::ACS_UARROW
sarr << "ACS_ULCORNER"
arr << FFI::NCurses::ACS_ULCORNER
sarr << "ACS_URCORNER"
arr << FFI::NCurses::ACS_URCORNER
sarr << "ACS_VLINE"
arr << FFI::NCurses::ACS_VLINE

sarr.each_index { |i|
  @window.mvaddch r,c, arr[i]
  @window.mvprintw r,c+2,"%s", :string, sarr[i]
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
