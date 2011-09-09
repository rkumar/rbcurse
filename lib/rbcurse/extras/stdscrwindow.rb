require 'ver/ncurses'
module RubyCurses
  #
  # an attempt to make a window based on stdscr for bottom line printing so the entire 
  # application can have one pointer, regardless of whether through App
  # or otherwise. This still provides the full getchar operation, copied from
  # Window class which is the main purpose of this. So as to provide ask, agree and say.
  #
  # We should be able to pass this window to bottomline and have one global bottomline
  # created once (by window class ?)
  #
  class StdscrWindow 
    attr_reader :width, :height, :top, :left

    def initialize

      @window_pointer = FFI::NCurses.initscr
      $log.debug "STDSCR window pointer is #{@window_pointer.class}"
      $log.debug "STDSCR window pointer mehtods #{@window_pointer.public_methods}"
      $error_message_row ||= Ncurses.LINES-1
      $error_message_col ||= 1
      init_vars


    end
    def init_vars
      Ncurses::keypad(@window_pointer, true)
      @stack = []
    end
    ##

    # Ncurses


    # taken from Window
    def method_missing(name, *args)
      name = name.to_s
      if (name[0,2] == "mv")
        test_name = name.dup
        test_name[2,0] = "w" # insert "w" after"mv"
        if (FFI::NCurses.respond_to?(test_name))
          return FFI::NCurses.send(test_name, @window_pointer, *args)
        end
      end
      test_name = "w" + name
      # FFI responds but the pointer does not !!! bottomline 1045
      if (FFI::NCurses.respond_to?(test_name))
        return FFI::NCurses.send(test_name, @window_pointer, *args)
      end
      FFI::NCurses.send(name, window_pointer, *args)
    end
    def respond_to?(name)
      name = name.to_s
      if (name[0,2] == "mv" && FFI::NCurses.respond_to?("mvw" + name[2..-1]))
        return true
      end
      FFI::NCurses.respond_to?("w" + name) || FFI::NCurses.respond_to?(name)
    end
      #@window.send(meth, *args)

    def print(string, width = width)
      return unless visible?
      @window_pointer.waddnstr(string.to_s, width)
    end

    def print_yx(string, y = 0, x = 0)
      @window_pointer.mvwaddnstr(y, x, string, width)
    end

    def print_empty_line
      return unless visible?
      @window_pointer.printw(' ' * width)
    end

    def print_line(string)
      print(string.ljust(width))
    end

    def puts(*strings)
      print(strings.join("\n") << "\n")
    end

    def XXXrefresh
      @window_pointer.refresh
    end


    def color=(color)
      @color = color
      @window_pointer.color_set(color, nil)
    end

    def highlight_line(color, y, x, max)
      @window_pointer.mvchgat(y, x, max, FFI::NCurses::A_NORMAL, color, nil)
    end

    def ungetch(ch)
      FFI::NCurses.ungetch(ch)
    end

    def getch
      #c = @window_pointer.getch # FFI NW stdscr must get key not some window
      raise "Ncurses.stdscr does not have getch" if !Ncurses.stdscr.respond_to? :getch
      $log.debug " XXXX before calling getch"
      c = Ncurses.stdscr.getch
      $log.debug " XXXX after calling getch #{c}"
      #c = FFI::NCurses.getch # causes an endless loop since other comp gets key
      #if c == FFI::NCurses::KEY_RESIZE
    rescue Interrupt => ex
      3 # is C-c
    end

    # returns control, alt, alt+ctrl, alt+control+shift, F1 .. etc
    # ALT combinations also send a 27 before the actual key
    # Please test with above combinations before using on your terminal
    # added by rkumar 2008-12-12 23:07 
    def getchar 
      while 1 
        ch = getch 
        #$log.debug "window getchar() GOT: #{ch}" if ch != -1
        if ch == -1
          # the returns escape 27 if no key followed it, so its SLOW if you want only esc
          if @stack.first == 27
            #$log.debug " -1 stack sizze #{@stack.size}: #{@stack.inspect}, ch #{ch}"
            case @stack.size
            when 1
              @stack.clear
              return 27
            when 2 # basically a ALT-O, this will be really slow since it waits for -1
              ch = 128 + @stack.last
              @stack.clear
              return ch
            when 3
              $log.debug " SHOULD NOT COME HERE getchar()"
            end
          end
          @stack.clear
          next
        end
        # this is the ALT combination
        if @stack.first == 27
          # experimental. 2 escapes in quick succession to make exit faster
          if ch == 27
            @stack.clear
            return ch
          end
          # possible F1..F3 on xterm-color
          if ch == 79 or ch == 91
            #$log.debug " got 27, #{ch}, waiting for one more"
            @stack << ch
            next
          end
          #$log.debug "stack SIZE  #{@stack.size}, #{@stack.inspect}, ch: #{ch}"
          if @stack == [27,79]
            # xterm-color
            case ch
            when 80
              ch = KEY_F1
            when 81
              ch = KEY_F2
            when 82
              ch = KEY_F3
            when 83
              ch = KEY_F4
            end
            @stack.clear
            return ch
          elsif @stack == [27, 91]
            if ch == 90
              @stack.clear
              return KEY_BTAB # backtab
            end
          end
          # the usual Meta combos. (alt)
          ch = 128 + ch
          @stack.clear
          return ch
        end
        # append a 27 to stack, actually one can use a flag too
        if ch == 27
          @stack << 27
          next
        end
        return ch
      end
    end

    def clear
      # return unless visible?
      move 0, 0
      puts *Array.new(height){ ' ' * (width - 1) }
    end


    def visible?
      @visible
    end
    ## 
    # added by rk 2008-11-29 19:01 
    # I usually use this, not the others ones here
    # @param  r - row
    # @param  c - col
    # @param string - text to print
    # @param color - color pair
    # @ param att - ncurses attribute: normal, bold, reverse, blink,
    # underline
    def printstring(r,c,string, color, att = FFI::NCurses::A_NORMAL)
        prv_printstring(r,c,string, color, att )
    end

    ## name changed from printstring to prv_prinstring
    def prv_printstring(r,c,string, color, att = FFI::NCurses::A_NORMAL)

      #$log.debug " #{@name} inside window printstring r #{r} c #{c} #{string} "
      att = FFI::NCurses::A_NORMAL if att.nil? 
      case att.to_s.downcase
      when 'normal'
        att = FFI::NCurses::A_NORMAL
      when 'underline'
        att = FFI::NCurses::A_UNDERLINE
      when 'bold'
        att = FFI::NCurses::A_BOLD
      when 'blink'
        att = FFI::NCurses::A_BLINK    # unlikely to work
      when 'reverse'
        att = FFI::NCurses::A_REVERSE    
      end

      attron(Ncurses.COLOR_PAIR(color) | att)
      # we should not print beyond window coordinates
      # trying out on 2009-01-03 19:29 
      width = Ncurses.COLS
      # the next line won't ensure we don't write outside some bounds like table
      #string = string[0..(width-c)] if c + string.length > width
      #$log.debug "PRINT len:#{string.length}, #{Ncurses.COLS}, #{r}, #{c} w: #{@window} "
      mvprintw(r, c, "%s", string);
      attroff(Ncurses.COLOR_PAIR(color) | att)
    end
    # added by rk 2008-11-29 19:01 
    # Since these methods write directly to window they are not advised
    # since clearing previous message we don't know how much to clear.
    # Best to map error_message to a label.
    #  2010-09-13 00:22 WE should not use these any longer.
    #  Application should create a label and map a Variable named
    #  $errormessage to it. We should only update the Variable
    def print_error_message text=$error_message
      r = $error_message_row || Ncurses.LINES-1
      c = $error_message_col || (Ncurses.COLS-text.length)/2 

      $log.debug "got ERROR MESSAGE #{text} row #{r} "
      clear_error r, $datacolor
      printstring r, c, text, color = $promptcolor
      $error_message_clear_pending = true
    end
    # added by rk 2008-11-29 19:01 
    def print_status_message text=$status_message
      r = $status_message_row || Ncurses.LINES-1
      clear_error r, $datacolor
      # print it in centre
      printstring r, (Ncurses.COLS-text.length)/2, text, color = $promptcolor
    end
    # Clear error message printed
    # I am not only clearing if something was printed. This is since
    # certain small forms like TabbedForm top form throw an error on printstring.
    # 
    def clear_error r = $error_message_row, color = $datacolor
      return unless $error_message_clear_pending
      c = $error_message_col || (Ncurses.COLS-text.length)/2 
      sz = $error_message_size || Ncurses.COLS
      printstring(r, c, "%-*s" % [sz, " "], color)
      $error_message_clear_pending = false
    end
    ##
    def get_window; @window_pointer; end
    def to_s; @name || self; end
  end
end
