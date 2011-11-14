require 'ffi-ncurses'
#include FFI::NCurses # this pollutes many objects and invalidates method_missing
module VER
  module_function

  # Setup ncurses, nicely documented by the curses manpages
  def start_ncurses
    return if $ncurses_started
    $ncurses_started = true
    # The initscr code determines the terminal type and initializes all curses
    # data structures.
    # initscr also causes the first call to refresh to clear the screen.
    # If errors occur, initscr writes an appropriate error message to standard
    # error and exits; otherwise, a pointer is returned to stdscr.
    stdscr = Ncurses.initscr  ## FFI

#    Color.start if Ncurses.has_colors?
      Ncurses.start_color();
      ColorMap.setup # added by RK 2008-11-30 00:48 
    # The keypad option enables the keypad of the user's terminal.
    # If enabled (bf is TRUE), the user can press a function key (such as an
    # arrow key) and wgetch returns a single value representing the function
    # key, as in KEY_LEFT.
    # If disabled (bf is FALSE), curses does not treat function keys specially
    # and the program has to interpret the escape sequences itself.
    # If the keypad in the terminal can be turned on (made to transmit) and off
    # (made to work locally), turning on this option causes the terminal keypad
    # to be turned on when wgetch is called.
    # The default value for keypad is false.
    Ncurses.keypad(stdscr.pointer, bf = true) # FFIWINDOW
    #Ncurses.keypad(stdscr, bf = true)
      #Ncurses.stdscr.keypad(true)     # turn on keypad mode FFI
    #Ncurses.keypad(stdscr, bf = 1)

    # The nl and nonl routines control whether the underlying display device
    # translates the return key into newline on input, and whether it
    # translates newline into return and line-feed on output (in either case,
    # the call addch('\n') does the equivalent of return and line feed on the
    # virtual screen).
    # Initially, these translations do occur.
    # If you disable them using nonl, curses will be able to make better use of
    # the line-feed capability, resulting in faster cursor motion.
    # Also, curses will then be able to detect the return key.
    Ncurses.nonl

    # The raw and noraw routines place the terminal into or out of raw mode.
    # Raw mode is similar to cbreak mode, in that characters typed are
    # immediately passed through to the user program.
    # The differences are that in raw mode, the interrupt, quit, suspend, and
    # flow control characters are all passed through uninterpreted, instead of
    # generating a signal.
    # The behavior of the BREAK key depends on other bits in the tty driver
    # that are not set by curses.
    Ncurses.raw

    # Normally, the tty driver buffers typed characters until a newline or
    # carriage return is typed.
    # The cbreak routine disables line buffering and
    # erase/kill character-processing (interrupt and flow control characters
    # are unaffected), making characters typed by the user immediately
    # available to the program.
    Ncurses.cbreak

    # The echo and noecho routines control whether characters typed by the user
    # are echoed by getch as they are typed.
    # Echoing by the tty driver is always disabled, but initially getch is in
    # echo mode, so characters typed are echoed.
    Ncurses.noecho

    # The curs_set routine sets the cursor state is set to invisible, normal,
    # or very visible for visibility equal to 0, 1, or 2 respectively.
    # If the terminal supports the visibility requested, the previous cursor
    # state is returned; otherwise, ERR is returned.
    Ncurses.curs_set(1)

    # The halfdelay routine is used for half-delay mode, which is similar to
    # cbreak mode in that characters typed by the user are immediately
    # available to the  program.
    # However, after blocking for tenths tenths of seconds, ERR is returned if
    # nothing has been typed.
    # The value of tenths must be a number between 1 and 255.
    # Use nocbreak to leave half-delay mode.
    Ncurses::halfdelay(tenths = 10)

    # The nodelay option causes getch to be a non-blocking call. If no input is
    # ready, getch returns ERR. If disabled (bf is FALSE), getch waits until a
    # key is pressed.
    # Ncurses::nodelay(Ncurses::stdscr, bf = true)
  end

  # this should happen only in outermost program that started ncurses
  # if a called program does this, the calling program can have a display freeze
  def stop_ncurses
    Ncurses.echo
    Ncurses.nocbreak
    Ncurses.nl
    Ncurses.endwin
    $ncurses_started = false
    #puts "curses over"
  ensure
    return unless error = @last_error
    log = Config[:logfile].value

    Kernel.warn "There may have been fatal errors logged to: #{log}."
    Kernel.warn "The most recent was:"

    $stderr.puts ''
    $stderr.puts @last_error_message if @last_error_message
    $stderr.puts @last_error, *@last_error.backtrace
  end
require 'rbcurse/colormap'
include ColorMap
end
module Ncurses
  extend self
  FALSE = 0
  TRUE = 1
  module NCX
    def COLS
      FFI::NCurses.getmaxx(FFI::NCurses.stdscr)
    end
    def LINES
#      #FFI::NCurses.getmaxy(FFI::NCurses.stdscr)
      FFI::NCurses.LINES
    end
#    # supposed to be picked up at runtime
    def COLORS
      FFI::NCurses.COLORS
    end

    # jsut trying this so i can do Ncurses.stdscr.getmax
    def _stdscr
      FFI::NCurses.stdscr
    end
    # this allows me to refer to them as Ncurses::A_REVERSE as is the case everywhere
    A_REVERSE = FFI::NCurses::A_REVERSE
    A_STANDOUT = FFI::NCurses::A_STANDOUT
    A_BOLD = FFI::NCurses::A_BOLD
    A_UNDERLINE = FFI::NCurses::A_UNDERLINE
    A_BLINK = FFI::NCurses::A_BLINK
    A_NORMAL = FFI::NCurses::A_NORMAL
    KEY_F1 = FFI::NCurses::KEY_F1
  end
  include NCX
  extend NCX
  # i think we can knock this off
  def method_missing meth, *args
    if (FFI::NCurses.respond_to?(meth))
      FFI::NCurses.send meth, *args
    end
  end
  # FFINC.constants.each { |e| Ncurses.const_set(e, FFINC.const_get(e) )  }
  def const_missing name
    val = FFI::NCurses.const_get(name)
    const_set(name, val)
    return val
  end

  # This is a window pointer wrapper, to be used for stdscr and others.
  # Ideally ffi-ncurses should do this, if it returns a pointer, I'll do this.
  class FFIWINDOW
    attr_accessor :pointer
    def initialize(*args, &block)
      if block_given?
        @pointer = args.first
      else
        @pointer = FFI::NCurses.newwin(*args)
      end
    end
    def method_missing(name, *args)
      name = name.to_s
      if (name[0,2] == "mv")
        test_name = name.dup
        test_name[2,0] = "w" # insert "w" after"mv"
        if (FFI::NCurses.respond_to?(test_name))
          return FFI::NCurses.send(test_name, @pointer, *args)
        end
      end
      test_name = "w" + name
      if (FFI::NCurses.respond_to?(test_name))
        return FFI::NCurses.send(test_name, @pointer, *args)
      end
      FFI::NCurses.send(name, @pointer, *args)
    end
    def respond_to?(name)
      name = name.to_s
      if (name[0,2] == "mv" && FFI::NCurses.respond_to?("mvw" + name[2..-1]))
        return true
      end
      FFI::NCurses.respond_to?("w" + name) || FFI::NCurses.respond_to?(name)
    end
    def del
      FFI::NCurses.delwin(@pointer)
    end
    alias delete del
  end
  # if ffi-ncurses returns a pointer wrap it.
  # or we can check for whether it responds_to? refresh and getch
  def self.initscr
    #@stdscr = Ncurses::FFIWINDOW.new(FFI::NCurses.initscr) { }
    stdscr = FFI::NCurses.initscr
    if stdscr.is_a? FFI::Pointer
      @stdscr = Ncurses::FFIWINDOW.new(stdscr) { }
    else
      @stdscr = stdscr
    end
  end
  def self.stdscr
    @stdscr
  end
  #  commented off on 2011-09-15 FFIWINDOW results in errors
#  class << self
#    def method_missing(method, *args, &block)
#      FFI::NCurses.send(method, *args, &block)
#    end
#  end
#  ---
end
