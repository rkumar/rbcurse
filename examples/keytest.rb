$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
#require 'lib/ver/ncurses'
#require 'lib/ver/window'
require 'lib/rbcurse/rwidget'
require 'lib/ver/keyboard2'
#require 'lib/rbcurse/mapper'

# Using mapper with keyboard2 which gives numeric keys
# The error messages are not so pretty, otherwise its okay... error messages need a little work
# Use C-q or q to quit
## C-s starts a new mode :cx, 'i' gets back to normal 
#include Ncurses


def printstr(pad, r,c,string, color, att = Ncurses::A_NORMAL)

  #att = bold ? Ncurses::A_BLINK|Ncurses::A_BOLD : Ncurses::A_NORMAL
  #     att = bold ? Ncurses::A_BOLD : Ncurses::A_NORMAL
  pad.attrset(Ncurses.COLOR_PAIR(color) | att)
  #pad.mvprintw(r, c, "%s", string);
  pad.mvaddstr(r, c, "%s" % string);
  pad.attroff(Ncurses.COLOR_PAIR(color) | att)
end
class KeyTest
  attr_reader :window    # needed by keyboard to do getch
  attr_accessor :mode    # needed by handler
  def initialize win
    @window = win
    @color = $datacolor
    @mode = :normal
    map_keys
    VER::Keyboard2.focus = self
  end
  def down
    printstr(@window, 12,1,"GOT Down       ", @color, att = Ncurses::A_NORMAL)
  end
  def up
    printstr(@window, 12,1,"GOT Up        ", @color, att = Ncurses::A_REVERSE)
  end
  def do_select
    printstr(@window, 12,1,"GOT do_select", @color, att = Ncurses::A_BOLD)
  end

  def map_keys
    @mapper = Mapper.new(self)
    @keyhandler = @mapper     # i don't want a separate handler, this will do

    # view refers to the object passed to constrcutor of Mapper, here it is self
    @mapper.let :normal do
      map(?\C-x, ?\C-d){ view.down }
      map(?\C-x, ?\C-u){ view.up }
      map(?\C-x, ?q){ view.stop }
      map(?\C-x, ?\C-s){ view.do_search_ask }
      map(?\C-x, ?\C-x){ view.do_select }
      map(?q){ view.stop }
      map(?q){ view.stop }
      map(32){ view.space }
      map(?n){ view.space }
      map(?j){ :down }
      map(?k){ view.up }
      map(?p){ view.minus }
      map(?[) { view.goto_start }
      map(?]) { view.goto_end }
      map(?-) { view.minus }

      map('right') { view.right}
      map(?l) { view.right}
      map('left') {view.left}
      map(?h) {view.left}
      map(KEY_DOWN) { view.down }
      map(?j) { view.down }
      map(KEY_UP) { view.up }
      map(KEY_ENTER) { view.enter  }
      map(?g) { view.handle_goto_ask }
      map(?/) { view.do_search_ask }
      map(?\C-n) { view.do_search_next }
      map(?\C-p) { view.do_search_prev }
      map(?x) { view.do_select }
      map(?\') { view.do_next_selection }
      map(?") { view.do_prev_selection }
      map(?\C-e) { view.do_clear_selection }
      ## C-s starts a new mode, i gets back to normal 
      map(?\C-s){ view.mode = :cx }
      # all printable chars not trapped above are caught here
      map(/^([[:print:]])$/){ view.show("Got printable: #{@arg}              ") }


      map(?\C-q){ view.stop }
    end

    ## a mode, started by C-s, use i to go back, q to quit
    @mapper.let :cx do
      map(?c.getbyte(0)){ view.show(:c) }
      map(?a.getbyte(0)){ view.show(:a) }
      map(?r.getbyte(0)){ view.show(:r) }
      map(?q.getbyte(0)){ view.stop }
      map(?i.getbyte(0)){ view.mode = :normal }
    end
  end
  def press(key)
    # I can intercept printable keys here
    $log.debug("press key: %s" % key)
    begin
      @keyhandler.press(key)
      #break if stopping?
      return if stopping?
      if !@message.nil?
        printstr(@window, 18,1,"%40s" % @message, $promptcolor, att = Ncurses::A_NORMAL)
        @message = nil
      end

    rescue ::Exception => ex
      $log.debug ex
      show(ex.message)
    end
  end # press

  # from VER
  def stopping?
    @stop
  end
  def show string
    @message = string
  end

  # without this system hangs if unknown key presed
  def info(message)
    @message = message
  end

  def stop
    @stop = true
    throw(:close)
  end
end
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils
  begin
  # Initialize curses
    VER::start_ncurses
    $reversecolor = 2
    $errorcolor = 7
    $promptcolor = $selectedcolor = 4
    $normalcolor = $datacolor = 5
    $bottomcolor = $topcolor = 6

    # Create the window to be associated with the form 
    # Un post form and free the memory
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG

    catch(:close) do
      @layout = { :height => 0, :width => 0, :top => 0, :left => 0 } 
      @window = VER::Window.new(@layout)
      @window.bkgd(Ncurses.COLOR_PAIR(5));
      @panel = @window.panel
      @window.wrefresh
      Ncurses::Panel.update_panels
      $log.debug "START   ---------"
      kt = KeyTest.new @window
    end
  rescue => ex
  ensure
    Ncurses::Panel.del_panel(@panel) if !@panel.nil?   
    @window.delwin if !@window.nil?
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
