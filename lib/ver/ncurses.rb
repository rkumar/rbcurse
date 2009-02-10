require 'rbcurse/colormap'
module VER
include ColorMap
  module_function

  # Setup ncurses, nicely documented by the curses manpages
  def start_ncurses
    # The initscr code determines the terminal type and initializes all curses
    # data structures.
    # initscr also causes the first call to refresh to clear the screen.
    # If errors occur, initscr writes an appropriate error message to standard
    # error and exits; otherwise, a pointer is returned to stdscr.
    stdscr = Ncurses.initscr

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
    Ncurses.keypad(stdscr, bf = true)

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

  def stop_ncurses
    Ncurses.echo
    Ncurses.nocbreak
    Ncurses.nl
    Ncurses.endwin
  ensure
    return unless error = @last_error
    log = Config[:logfile].value

    Kernel.warn "There may have been fatal errors logged to: #{log}."
    Kernel.warn "The most recent was:"

    $stderr.puts ''
    $stderr.puts @last_error_message if @last_error_message
    $stderr.puts @last_error, *@last_error.backtrace
  end
end
