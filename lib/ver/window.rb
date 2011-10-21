require 'ver/ncurses'
require 'ver/panel'
# this is since often windows are declared with 0 height or width and this causes
# crashes in the most unlikely places. This prevceents me from having to write ternary
# e.g.
#     @layout[:width].ifzero(FFI::NCurses::LINES-2)
class Fixnum
  def ifzero v
    return self if self != 0
    return v
  end
end

module VER
  class Window 
    attr_reader :width, :height, :top, :left
    attr_accessor :layout # hash containing hwtl
    attr_reader   :panel   # reader requires so he can del it in end
    attr_reader   :window_type   # window or pad to distinguish 2009-11-02 23:11 
    attr_accessor :name  # more for debugging log files. 2010-02-02 19:58 
    attr_accessor :modified # has it been modified and may need a refresh
    attr_reader   :bottomline  # experimental here 2010-11-03 22:19 

    # @param [Array, Hash] window coordinates (ht, w, top, left)
    # or 
    # @param [int, int, int, int] window coordinates (ht, w, top, left)
    # 2011-09-21 allowing array, or 4 ints,  in addition to hash @since 1.3.1
    def initialize(*args)

      case args.size
      when 1
        case args[0]
        when Array, Hash
         layout = args[0]
        else
          raise ArgumentError, "Window expects 4 ints, array of 4 ints, or Hash in constructor"
        end
      when 4
        layout = { :height => args[0], :width => args[1], :top => args[2], :left => args[3] }
      end

      @visible = true
      reset_layout(layout)

      $log.debug "XXX:WINDOW got #{@height}, #{@width}, #{@top}, #{@left} "
      @window = FFI::NCurses.newwin(@height, @width, @top, @left) # added FFI 2011-09-6 
      @panel = Ncurses::Panel.new(@window) # added FFI 2011-09-6 
      #$error_message_row = $status_message_row = Ncurses.LINES-1
      $error_message_row ||= Ncurses.LINES-1
      $error_message_col ||= 1 # ask (bottomline) uses 0 as default so you can have mismatch. XXX
      $status_message ||= Variable.new # in case not an App
      init_vars


    end
    def init_vars
      @window_type = :WINDOW
      Ncurses::keypad(@window, true)
      @stack = []
      @name ||="#{self}"
      @modified = true
      $catch_alt_digits ||= false # is this where is should put globals ? 2010-03-14 14:00 XXX
      #init_bottomline # bottomline to creates its own window 2011-10-8 
    end
    ##
    # this is an alternative constructor
    def self.root_window(layout = { :height => 0, :width => 0, :top => 0, :left => 0 })
      #VER::start_ncurses
      @layout = layout
      @window = Window.new(@layout)
      @window.name = "Window::ROOTW"
      @window.wrefresh
      Ncurses::Panel.update_panels
      return @window
    end
    # 2009-10-13 12:24 
    # not used as yet
    # this is an alternative constructor
    # created if you don't want to create a hash first
    #  2011-09-21 V1.3.1 You can now send an array to Window constructor
    def self.create_window(h=0, w=0, t=0, l=0)
      layout = { :height => h, :width => w, :top => t, :left => l }
      @window = Window.new(layout)
      return @window
    end

    def resize_with(layout)
      $log.debug " DARN ! This awready duz a resize!! if h or w or even top or left changed!!! XXX"
      reset_layout(layout)
      #@window.wresize(height, width)
      wresize(height, width)
      #FFI::NCurses.wresize(@window,height, width)
      # this is dicey since we often change top and left in pads only for panning !! XXX
      #@window.mvwin(top, left)
      mvwin(top, left)
      #FFI::NCurses.mvwin(@window, top, left)
    end

    %w[width height top left].each do |side|
      eval(
      "def #{side}=(n)
         return if n == #{side}
         @layout[:#{side}] = n
         resize_with @layout
       end"
      )
    end
    # ADDED DUE TO FFI 
    def wrefresh
      Ncurses.wrefresh(@window)
    end
    def delwin # 2011-09-7 
      Ncurses.delwin(@window)
    end
    def attron *args
      FFI::NCurses.wattron @window, *args
    end
    def attroff *args
      FFI::NCurses.wattroff @window, *args
    end
    #
    # ## END FFI

    def resize
      resize_with(@layout)
    end

    # Ncurses

    def pos
      return y, x
    end

    def y
      Ncurses.getcury(@window)
    end

    def x
      Ncurses.getcurx(@window)
    end

    def x=(n) move(y, n) end
    def y=(n) move(n, x) end

    #def move(y, x)
      #return unless @visible
##       Log.debug([y, x] => caller[0,4])
      ##@window.wmove(y, x) # bombing since ffi-ncurses 0.4.0 (maybe it was never called
      ##earlier. was crashing in appemail.rb testchoose.
      #wmove y,x # can alias it
    #end
    # since include FFI is taking over, i need to force it here. not going into
    # method_missing
    def wmove y,x
      #Ncurses.wmove @window, y, x
      FFI::NCurses.wmove @window, y, x
    end
    alias :move :wmove

    # while moving from ncurses-ruby to FFI need to pass window pointer
    # for w methods as well as mvw - NOT COMING HERE due to include FFI
    def OLDmethod_missing(meth, *args)
      $log.debug " WWWW method missing #{meth} "
      if meth[0,1]=="w" || meth[0,3] == "mvw"
        $log.debug " WWWW method missing #{meth} adding window in call "
        #return @window.send(meth, @window, *args)
        return FFI::NCurses.send(meth, @window, *args)
      else
      end
      if @window
        if @window.respond_to? meth
          @window.send(meth, *args)
        else
          FFI::NCurses.send( meth, *args)
        end
      else
        FFI::NCurses.send( meth, *args)
      end
    end

    def method_missing(name, *args)
      name = name.to_s
      if (name[0,2] == "mv")
        test_name = name.dup
        test_name[2,0] = "w" # insert "w" after"mv"
        if (FFI::NCurses.respond_to?(test_name))
          return FFI::NCurses.send(test_name, @window, *args)
        end
      end
      test_name = "w" + name
      if (FFI::NCurses.respond_to?(test_name))
        return FFI::NCurses.send(test_name, @window, *args)
      end
      FFI::NCurses.send(name, @window, *args)
    end
    def respond_to?(name)
      name = name.to_s
      if (name[0,2] == "mv" && FFI::NCurses.respond_to?("mvw" + name[2..-1]))
        return true
      end
      FFI::NCurses.respond_to?("w" + name) || FFI::NCurses.respond_to?(name)
    end

    # NOTE: many of these methods using width will not work since root windows width 
    #  is 0
    def print(string, width = width)
      return unless visible?
      w = width == 0? Ncurses.COLS : width
      waddnstr(string.to_s, w) # changed 2011 dts  
    end

    # NOTE: many of these methods using width will not work since root windows width 
    #  is 0
    def print_yx(string, y = 0, x = 0)
      w = width == 0? Ncurses.COLS : width
      mvwaddnstr(y, x, string, w) # changed 2011 dts  
    end

    # NOTE: many of these methods using width will not work since root windows width 
    #  is 0
    def print_empty_line
      return unless visible?
      w = width == 0? Ncurses.COLS : width
      printw(' ' * w)
    end

    # NOTE: many of these methods using width will not work since root windows width 
    #  is 0
    def print_line(string)
      w = width == 0? Ncurses.COLS : width
      print(string.ljust(w))
    end

    
    # NOTE: many of these methods using width will not work since root windows width 
    #  is 0
    #  Previously this printed a chunk as a full line, I've modified it to print on 
    #  one line. This can be used for running text. 
    def show_colored_chunks(chunks, defcolor = nil, defattr = nil)
      return unless visible?
      chunks.each do |color, chunk, attrib|
        color ||= defcolor
        attrib ||= defattr
        #$log.debug "XXX: CHUNK #{chunk} "
        color_set(color,nil) if color
        wattron(attrib) if attrib
        print(chunk)
        wattroff(attrib) if attrib
      end
    end

    def puts(*strings)
      print(strings.join("\n") << "\n")
    end

    def _refresh
      return unless visible?
      @window.refresh
    end

    def wnoutrefresh
      return unless visible?
      @window.wnoutrefresh
    end

    def color=(color)
      @color = color
      @window.color_set(color, nil)
    end

    def highlight_line(color, y, x, max)
      @window.mvchgat(y, x, max, Ncurses::A_NORMAL, color, nil)
    end

    def ungetch(ch)
      Ncurses.ungetch(ch)
    end

    def getch
      #c = @window.getch
      c = Ncurses.getch
      #if c == Ncurses::KEY_RESIZE

    rescue Interrupt => ex
      3 # is C-c
    end

    #  2011-09-23 @since 1.3.1
    # Added more combinations here. These 2 are just indicative
    SPECIAL_KEYS = {
      [27, 79, 50, 81]              => 20014, #  'F14',
      [27, 79, 50, 82]              => 20015 # 'F15',
    }

    # returns control, alt, alt+ctrl, alt+control+shift, F1 .. etc
    # ALT combinations also send a 27 before the actual key
    # Please test with above combinations before using on your terminal
    # added by rkumar 2008-12-12 23:07 
    #  2011-09-23 Redone Control-left, right, and Shift-F5..F10.
    #  Checking for quick press of Alt-Sh-O followed by Alt or printable char
    #  Checking for quick press of Alt-[ followed by Alt or printable char
    #  I attempted keeping a hash of combination arrays but it fails in the above
    #  2 cases, so abandoned.
    def getchar 
      while 1 
        ch = getch
        $log.debug "window getchar() GOT: #{ch}" if ch != -1
        sf = @stack.first
        if ch == -1
          # the returns escape 27 if no key followed it, so its SLOW if you want only esc
          if @stack.first == 27
            #$log.debug " -1 stack sizze #{@stack.size}: #{@stack.inspect}, ch #{ch}"
            case @stack.size
            when 1
              @stack.clear
              return 27
            when 2 # basically a ALT-O, or alt-[ (79 or 91) this will be really slow since it waits for -1
              ch = 128 + @stack.last
              @stack.clear
              return ch
            else
              # check up a hash of special keys
              ret = SPECIAL_KEYS(@stack)
              return ret if ret
              $log.warn "INVALID UNKNOWN KEY: SHOULD NOT COME HERE getchar():#{@stack}" 
            end
          end
          # possibly a 49 left over from M3-1
          unless @stack.empty?
            if @stack.size == 1
              @stack.clear
              return sf
            end
            $log.warn "something on stack getchar(): #{@stack} "
          end
          # comemnt after testing keys since this will be called a lot, even stack.clear is called a lot
          $log.warn "ERROR CLEARING STACK WITH STUFF ON IT getchar():#{@stack}"  if ($log.debug? && !@stack.empty?)
          @stack.clear
          next
        end #  -1
        # this is the ALT combination
        if @stack.first == 27
          # experimental. 2 escapes in quick succession to make exit faster
          if @stack.size == 1 && ch == 27
            @stack.clear
            return ch
          end
          # possible F1..F3 on xterm-color
          if ch == 79 || ch == 91
            #$log.debug " got 27, #{ch}, waiting for one more"
            @stack << ch
            next
          end
          #$log.debug "stack SIZE  #{@stack.size}, #{@stack.inspect}, ch: #{ch}"
          if @stack == [27,79]
            # xterm-color
            case ch
            when 80
              ch = FFI::NCurses::KEY_F1
            when 81
              ch = FFI::NCurses::KEY_F2
            when 82
              ch = FFI::NCurses::KEY_F3
            when 83
              ch = FFI::NCurses::KEY_F4
            #when 27 # another alt-char following Alt-Sh-O
            else
              @stack.clear
              @stack << ch
              return 128 + 79

            end
            @stack.clear
            return ch
          elsif @stack == [27, 91]
            # XXX 27, 91 also is Alt-[
            if ch == 90
              @stack.clear
              return KEY_BTAB # backtab
            elsif ch == 53 || ch == 50 || ch == 51
              # control left, right and shift function
              @stack << ch
              next
            elsif ch == 27 # another alt-char immediately after Alt-[
              $log.debug "getchar in 27, will return 128+91 " if $log.debug? 
              @stack.clear
              @stack << ch
              return 128 + 91
            else
              $log.debug "getchar in other, will return 128+91: #{ch} " if $log.debug? 
              # other cases Alt-[ followed by some char or key - merge with previous
              @stack.clear
              @stack << ch
              return 128 + 91
            end
          elsif @stack == [27, 91, 53]
            if ch == 68
              @stack.clear
              return C_LEFT  # control-left
            elsif ch == 67
              @stack.clear
              return C_RIGHT  # -control-rt
            end
          elsif @stack == [27, 91, 51]
            if ch == 49 && getch()== 126
              @stack.clear
              return 20009  # sh_f9
            end
          elsif @stack == [27, 91, 50]
            if ch == 50 && getch()== 126
              @stack.clear
              return 20010  # sh-F10
            end
            if ch == 57 && getch()== 126
              @stack.clear
              return 20008  # sh-F8
            elsif ch == 56 && getch()== 126
              @stack.clear
              return 20007  # sh-F7
            elsif ch == 54 && getch()== 126
              @stack.clear
              return 20006  # sh-F6
            elsif ch == 53 && getch()== 126
              @stack.clear
              return 20005  # sh-F5
            end
          end
          # the usual Meta combos. (alt) - this is screwing it up, just return it in some way
          ch = 128 + ch
          @stack.clear
          return ch
        end # stack.first == 27
        # append a 27 to stack, actually one can use a flag too
        if ch == 27
          @stack << 27
          next
        end
        return ch
      end # while
    end # def

    # doesn't seem to work, clears first line, not both
    def clear
      # return unless visible?
      move 0, 0
      puts *Array.new(height){ ' ' * (width - 1) }
    end

    # setup and reset

    ## allow user to send an array
    # I am tired of the hash layout (taken from ver).
    def reset_layout(layout)
      case layout
      when Array
        $log.error  "NIL in window constructor" if layout.include? nil
        raise ArgumentError, "Nil in window constructor" if layout.include? nil
        @height, @width, @top, @left = *layout
        raise ArgumentError, "Nil in window constructor" if @top.nil? || @left.nil?

        @layout = { :height => @height, :width => @width, :top => @top, :left => @top }
      when Hash
        @layout = layout

        [:height, :width, :top, :left].each do |name|
          instance_variable_set("@#{name}", layout_value(name))
        end
      end
    end

    # removed ref to default_for since giving error in FFI 2011-09-8 
    def layout_value(name)
      value = @layout[name]
      default = default_for(name)

      value = value.call(default) if value.respond_to?(:call)
      return (value || default).to_i
    end

    # this gives error since stdscr is only a pointer at this time
    def default_for(name)
      case name
      when :height, :top
        #Ncurses.stdscr.getmaxy(stdscr)
        FFI::NCurses.LINES
      when :width, :left
        #Ncurses.stdscr.getmaxx(stdscr)
        FFI::NCurses.COLS
      else
        0
      end
    end

    # Ncurses panel

    def hide
      #return unless visible? # added 2011-10-14 these 2 are not behaving properly
      Ncurses::Panel.hide_panel @panel.pointer
      #Ncurses.refresh # wnoutrefresh
      Ncurses::Panel.update_panels # added so below window does not need to do this 2011-10-1 
      @visible = false
    end

    def show
      #return if visible? # added 2011-10-14 these 2 are not behaving properly
      Ncurses::Panel.show_panel @panel.pointer
      #Ncurses.refresh # wnoutrefresh
      Ncurses::Panel.update_panels # added so below window does not need to do this 2011-10-1 
      @visible = true
    end

    def on_top
      Ncurses::Panel.top_panel @panel.pointer
      wnoutrefresh
    end

    def visible?
      @visible
    end
    ##
    #added by rk 2008-11-29 18:48 
    #to see if we can clean up from within
    def destroy
      # typically the ensure block should have this
      # @panel = @window.panel if @window
      #Ncurses::Panel.del_panel(@panel) if !@panel.nil?   
      #@window.delwin if !@window.nil?
      $log.debug "win destroy start"

      #@panel = @window.panel if @window
      # changed Ncurses::Panel to Ncurses::Panel on 2011-09-8 when moved to FFI
      Ncurses::Panel.del_panel(@panel.pointer) if !@panel.nil?    # ADDED FFI pointer 2011-09-7 
      #@window.delwin(@window) if !@window.nil? # added FFI 2011-09-7 
      delwin() if !@window.nil? # added FFI 2011-09-7 
      Ncurses::Panel.update_panels # added so below window does not need to do this 2011-10-1 
      $log.debug "win destroy end"
    end
    def printstring_or_chunks(r,c,content, color, att = Ncurses::A_NORMAL)
      if content.is_a? String
        printstring(r,c,content, color, att)
      elsif content.is_a? Array
                # several chunks in one row - NOTE Very experimental may change
        if content[0].is_a? Array
          wmove r, c
          # either we have to loop through and put in default color and attr
          # or pass it to show_col
          a = get_attrib att
          show_colored_chunks content, color, a
        else
          # a single row chunk - NOTE Very experimental may change
          text = content[1].dup
          printstring r, c, text, content[0] || color, content[2] || att
        end
      end
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
    def printstring(r,c,string, color, att = Ncurses::A_NORMAL)
      raise "Nil passed to peintstring row:#{r}, col:#{c}, #{color} " if r.nil? || c.nil? || color.nil?
      raise "Zero or less passed to printstring row:#{r}, col:#{c} " if $log.debug? && (r <=0 || c <=0)
      prv_printstring(r,c,string, color, att )
    end

    ## name changed from printstring to prv_prinstring
    def prv_printstring(r,c,string, color, att = Ncurses::A_NORMAL)

      #$log.debug " #{@name} inside window printstring r #{r} c #{c} #{string} "
      att = Ncurses::A_NORMAL if att.nil? 
      case att.to_s.downcase
      when 'normal'
        att = Ncurses::A_NORMAL
      when 'underline'
        att = Ncurses::A_UNDERLINE
      when 'bold'
        att = Ncurses::A_BOLD
      when 'blink'
        att = Ncurses::A_BLINK    # unlikely to work
      when 'reverse'
        att = Ncurses::A_REVERSE    
      end

      wattron(Ncurses.COLOR_PAIR(color) | att)
      mvwprintw(r, c, "%s", :string, string);
      wattroff(Ncurses.COLOR_PAIR(color) | att)
    end
    # @deprecated
    def print_error_message text=$error_message.get_value
      alert text
    end
    # added by rk 2008-11-29 19:01 
    # @deprecated. use global method of same name in rdialog
    def print_status_message text=$status_message
      #VER::print_status_message text
      alert text
    end
    # added by rk 2008-11-29 19:01 
    # Since these methods write directly to window they are not advised
    # since clearing previous message we don't know how much to clear.
    # Best to map error_message to a label.
    #  2010-09-13 00:22 WE should not use these any longer.
    #  Application should create a label and map a Variable named
    #  $errormessage to it. We should only update the Variable
    def DEPRECATED_print_error_message text=$error_message.get_value
      r = $error_message_row || Ncurses.LINES-1
      c = $error_message_col || (Ncurses.COLS-text.length)/2 

      $log.debug "got ERROR MESSAGE #{text} row #{r} "
      clear_error r, $datacolor
      printstring r, c, text, color = $promptcolor
      $error_message_clear_pending = true
    end
    # added by rk 2008-11-29 19:01 
    # @deprecated. use global method of same name
    def DEPRECATED_print_status_message text=$status_message
      r = $status_message_row || Ncurses.LINES-1
      clear_error r, $datacolor
      # print it in centre
      printstring r, (Ncurses.COLS-text.length)/2, text, color = $promptcolor
    end
    # Clear error message printed
    # I am not only clearing if something was printed. This is since
    # certain small forms like TabbedForm top form throw an error on printstring.
    # @deprecated 
    def clear_error r = $error_message_row, color = $datacolor
      return unless $error_message_clear_pending
      c = $error_message_col || (Ncurses.COLS-text.length)/2 
      sz = $error_message_size || Ncurses.COLS
      printstring(r, c, "%-*s" % [sz, " "], color)
      $error_message_clear_pending = false
    end
    ##
    # NOTE : FOR MESSAGEBOXES ONLY !!!! 
    def print_border_mb row, col, height, width, color, attr
      mvwaddch row, col, Ncurses::ACS_ULCORNER
      mvwhline( row, col+1, Ncurses::ACS_HLINE, width-6)
      mvwaddch row, col+width-5, Ncurses::ACS_URCORNER
      mvwvline( row+1, col, Ncurses::ACS_VLINE, height-4)

      mvwaddch row+height-3, col, Ncurses::ACS_LLCORNER
      mvwhline(row+height-3, col+1, Ncurses::ACS_HLINE, width-6)
      mvwaddch row+height-3, col+width-5, Ncurses::ACS_LRCORNER
      mvwvline( row+1, col+width-5, Ncurses::ACS_VLINE, height-4)
    end
    ##
    # prints a border around a widget, CLEARING the area.
    #  If calling with a pad, you would typically use 0,0, h-1, w-1.
    def print_border row, col, height, width, color, att=Ncurses::A_NORMAL
      raise "height needs to be supplied." if height.nil?
      raise "width needs to be supplied." if width.nil?
      att ||= Ncurses::A_NORMAL

      $log.debug " inside window print_border r #{row} c #{col} h #{height} w #{width} "

      # 2009-11-02 00:45 made att nil for blanking out
      # FIXME - in tabbedpanes this clears one previous line ??? XXX when using a textarea/view
      # when using a pad this calls pads printstring which again reduces top and left !!! 2010-01-26 23:53 
      (row+1).upto(row+height-1) do |r|
        #printstring( r, col+1," "*(width-2) , $datacolor, nil)
        prv_printstring( r, col+1," "*(width-2) , $datacolor, nil)
      end
      prv_print_border_only row, col, height, width, color, att
    end
    def print_border_only row, col, height, width, color, att=Ncurses::A_NORMAL
      prv_print_border_only row, col, height, width, color, att
    end


    ## print just the border, no cleanup
    #+ Earlier, we would clean up. Now in some cases, i'd like
    #+ to print border over what's been done. 
    # XXX this reduces 1 from width but not height !!! FIXME 
    def prv_print_border_only row, col, height, width, color, att=Ncurses::A_NORMAL
      att ||= Ncurses::A_NORMAL
      case att.to_s.downcase
      when 'normal'
        att = Ncurses::A_NORMAL
      when 'underline'
        att = Ncurses::A_UNDERLINE
      when 'bold'
        att = Ncurses::A_BOLD
      when 'blink'
        att = Ncurses::A_BLINK    # unlikely to work
      when 'reverse'
        att = Ncurses::A_REVERSE    
      end
      wattron(Ncurses.COLOR_PAIR(color) | att)
      mvwaddch  row, col, Ncurses::ACS_ULCORNER
      mvwhline( row, col+1, Ncurses::ACS_HLINE, width-2)
      mvwaddch row, col+width-1, Ncurses::ACS_URCORNER
      mvwvline( row+1, col, Ncurses::ACS_VLINE, height-1)

      mvwaddch row+height-0, col, Ncurses::ACS_LLCORNER
      mvwhline(row+height-0, col+1, Ncurses::ACS_HLINE, width-2)
      mvwaddch row+height-0, col+width-1, Ncurses::ACS_LRCORNER
      mvwvline( row+1, col+width-1, Ncurses::ACS_VLINE, height-1)
      wattroff(Ncurses.COLOR_PAIR(color) | att)
    end
    # added RK 2009-10-08 23:57 for tabbedpanes
    # THIS IS EXPERIMENTAL -  XXX CLEANUP REMOVE
    # Acco to most sources, derwin and subwin are not thoroughly tested, avoid usage
    # subwin moving and resizing not functioning.
    def derwin(layout)
      $log.debug " #{self} EXP: returning a subwin in derwin"
      v = VER::SubWindow.new(self, layout)
      $log.debug " #{self} EXP: returning a subwin in derwin: #{v} "
      return v
    end
    ## REMOVE CLEANUP UNUSED
    def _subwin(layout)
      t = @layout[:top]
      l = @layout[:left]
      layout[:top] = layout[:top] + t
      layout[:left] = layout[:left] + l
      $log.debug " #{self} EXP: returning a subwin in derwin. Adding #{t} and #{l} "
      v = VER::SubWindow.new(self, layout)
      $log.debug " #{self} EXP: returning a subwin in derwin: #{v} "
      return v
    end
    # This used to return an Ncurses window object, and you could call methods on it
    # Now it returns a FFI::NCurses.window pointer which you cannot call methods on.
    # You have to pass it to FFI::NCurses.<method>
    def get_window; @window; end
    def to_s; @name || self; end
    # use in place of mvwhline if your widget could be using a pad or window
    def rb_mvwhline row, col, char, width
      mvwhline row, col, char, width
    end
    # use in place of mvwvline if your widget could be using a pad or window
    def rb_mvwvline row, col, char, width
      mvwvline row, col, char, width
    end
    # use in place of mvaddch if your widget could be using a pad or window
    def rb_mvaddch row, col, char
      mvaddch row, col, char
    end
    # experimentally
    # Add a bottomline to window when creating root_window
    # this way its available even when App is not used.
    def init_bottomline
      unless @bottomline
        require 'forwardable'
        require 'rbcurse/extras/bottomline'
        @bottomline = RubyCurses::Bottomline.new self, $error_message_row
        @bottomline.name = "window.rb"
        extend Forwardable
        def_delegators :@bottomline, :ask, :say, :agree, :choose
      end
    end
  end
  #-------------------------------- deprecated stuff ------------------ #
  ##
  # added RK 2009-10-08 23:57 for tabbedpanes
  # THIS IS EXPERIMENTAL - 
  # I have not called super in the initializer so any methods you try on subwin
  # that exist in the superclass which use @window will bomb
  # @since 0.1.3 REMOVE UNUSED.
  # @deprecated
  class SubWindow  < VER::Window
    attr_reader :width, :height, :top, :left
    attr_accessor :layout
    attr_reader   :panel   # XXX reader requires so he can del it in end
    attr_reader   :subwin   # 
    attr_reader   :parent   # 

    def initialize(parent, layout)
      @visible = true
      reset_layout(layout)

      @parent = parent
      #@subwin = @parent.get_window().derwin(@height, @width, @top, @left)
      @subwin = @parent.get_window().subwin(@height, @width, @top, @left)
      $log.debug "SUBWIN init #{@height} #{@width} #{@top} #{@left} "
      #$log.debug "SUBWIN init #{@subwin.getbegx} #{@subwin.getbegy} #{@top} #{@left} "
      @panel = Ncurses::Panel.new_panel(@subwin)

      @window = @subwin # makes more mthods available
      init_vars

    end
    # no need really now 
    def reset_layout layout
      @layout = layout # 2010-02-13 22:23 
      @height = layout[:height]
      @width = layout[:width]
      @top = layout[:top]
      @left = layout[:left]
    end
    def _destroy
      # typically the ensure block should have this
      # or should window do it for all subwins, or would we want to wait that long ?
      $log.debug "subwin destroy"

      Ncurses::Panel.del_panel(panel.pointer) if !panel.nil?    # FFI
      #@window.delwin(@window) if !@window.nil? # added FFI 2011-09-7 
      delwin if !@window.nil? # added FFI 2011-09-7 
    end
  end

  ##
  # Pad
  # This is EXPERIMENTAL
  # A pad cannot be used interchangeable since some application functions such as wrefresh
  # are illegal. Cannot expect the application to take care.
  # Internally we can make it easier. Mostly a pad is used to map to one portion of the screen.
  # So we allow that to be defined once. Then only start row and col of pad change.
  # Maybe we should check pad coordinates so no errors
  # Also check screen coordinates (if we know)
  # We need padheight and padwidth only to ensure we don't keep recreating.
  # Howevre, when comp's height increases, then decreases, pad height remains larger
  # but we keep printing an extra row in copywin. so Pad needs to maintain comp height
  # and padheight.
  # @since 0.1.3
  # NOTE used only by TabbedPane. If we rewrite without using it in 1.3.1 then scrap.
  class Pad  < VER::Window
    # top and left correspond to screen's top and left wich will mostly be fixed
    attr_accessor :top, :left
    # start row and col correspond to pad's top and left which will change if scrolling
    attr_accessor :pminrow, :pmincol
    # screen's height and width, now it reflects components height and width
    attr_accessor :sheight, :swidth
    attr_reader :otherwin
    # dimensions the pad was created with, used so we don't keep recreating pad, only if increase.
    attr_reader :padheight, :padwidth
    #attr_accessor :name  # more for debugging log files. 2010-02-02 19:58 
    def initialize(height, width)
      @visible = true
      # do we set height and width ?? XXX
      @window = Ncurses.newpad(height, width)
      @padheight = height
      @padwidth = width
      @height = height
      @width = width
      @sheight = height
      @swidth = width
      init_vars
    end
    def init_vars
      super
      @top ||= 0; @left ||= 0
      @pmincol ||= 0 # pad will print from this col
      @pminrow ||= 0 # pad will print from this row
      @window_type = :PAD
      @name ||="#{self}"
      $log.debug "        PAD constructor #{self} , #{@window} "
    end
    #
    # @param layout is a hash (@see Window.initialize)
    def self.create_with_layout(layout)
      @window = Pad.new(layout[:height], layout[:width])
      @window.reset_layout(layout)
      return @window
    end
    ##
    # increases the pad size, since the widget may have been resized
    # checks that one of ht or width has been increased
    # destroys earlier pad and returns new one
    # Updates sheight and swidth even if reduced so copywin works fine.
    # @param [Fixnum] height to resize to
    # @param [Fixnum] width to resize to
    # @return [Pad]
    #  2009-10-29 23:18 
    def resize(ht = 0, w = 0)
      # update sheight and swidth even if reduced, so that pad doesn't overwrite.
      @sheight = ht if ht > 0
      @swidth = w if w > 0
      return if ht < @padheight and w < @padwidth
      @padheight = ht if ht > @padheight
      @padwidth = w if w > @padwidth
      destroy
      $log.debug " L502 resize, creating newpad with #{@padheight} and #{@padwidth} "
      @window = Ncurses.newpad(@padheight, @padwidth)
      $log.debug " L502 resize created #{@window} "
      return @window
    end
    ## used if pad and window are same size only
    # creates a similar sized window
    # assumes window is backed by this pad
    # @param object of Window class
    def self.create_for_window(win)
      # get coordinates for win
      @otherwin = win
      smaxx = win.getmaxx()
      smaxy = win.getmaxy()
      top = win.getminx()
      left = win.getminy()
      sheight = win.height
      swidth = win.width
      # make pad based on size of window
      window = Pad.create_with_layout(layout = { :height => sheight, :width => swidth, :top => top, :left => sleft })
      window.sheight = sheight
      window.swidth = swidth
      return window

    end
    # top and left correspond to screen's top and left wich will mostly be fixed.
    # In cases where the component may float around, as in Splitpanes second component
    # this would be set using component's row and col.
    def set_screen_row_col top, left=-1
      @top = top
      @left = left unless left < 0
    end
    alias :set_screen_pad_left :set_screen_row_col

    ## added user setting screens max row and col (e.g splitpanes first component)
    def set_screen_max_row_col mr, mc
      $log.debug "#{@name} set_screen_max_row_col #{mr},#{mc}. earlier #{@screen_maxrow}, #{@screen_maxcol}  "
      # added || check on 2010-01-09 18:39 since crashing if mr > sh + top ..
      # I removed the check, since it results in a blank area on screen since the 
      # widget has not expanded itself. Without the check it will  crash on copywin so you
      # should increase widget size or disallow  calling this in this situation.
      if mr > (@sheight + @top -1 -@pminrow)
        $log.warn " ->>> ** set_screen_max_row_col #{mr} > #{@sheight} + #{@top} -1 - #{@pminrow} ** "
        $log.warn " ->>> can result in error in copy_win or in some rows not displaying"
        return # some situations actually require this ...
      end unless mr.nil?
      @screen_maxrow = mr unless mr.nil? # || mr > (@sheight + @top -1 -@pminrow)
      @screen_maxcol = mc unless mc.nil?
    end
    # start row and col correspond to pad's top and left which will change if scrolling
    # However, if we use this as a backing store for subwindows it could remain the same
    def set_pad_top_left top, left=-1
      $log.debug "#{@name} inside set_pad_top_left to #{top} #{left} earlier #{@pminrow}, #{@pmincol}"
      @pminrow = top unless top < 0
      @pmincol = left unless left < 0
    end
    # return screen max row which will be used for writing to window
    # XXX what if user sets/overrides sheight
    def smaxrow
      #$log.debug "    ... niside smaxrow #{@sheight} + #{@top} -1 "
      #@sheight + @top -1 
      $log.debug "smr: #{@screen_maxrow}   ... niside smaxrow #{@sheight} + #{@top} -1 - #{@pminrow}"
      @screen_maxrow || @sheight + @top -1 -@pminrow
    end
    ##
    # return screen max col which will be used for writing to window
    def smaxcol
      #$log.debug "    ... niside smaxcol #{@swidth} + #{@left} -1 "
      #@swidth + @left -1
      #      $log.debug "    ... niside smaxcol #{@swidth} + #{@left} -1 - #{@pmincol} "
      @screen_maxcol || @swidth + @left -1 - @pmincol
    end
    ##
    # specify the window or subwin that the pad is writing to
    # 2010-02-20 22:45 - actually since there are pad methods smaxrow used on otherwin
    # therefor it can only be a Pad !! NOTE
    def set_backing_window win
      @otherwin = win
      # XX should we  extract the coordinates and use for printing ??
      # or for setting maxrow and maxcol
    end
    # trying to make things as easy as possible
    # returns -1 if error in prefresh
    def wrefresh
      $log.debug " inside pad's wrefresh #{@window}. minr,minc,top,left,smaxr,c: #{@pminrow}, #{@pmincol}, #{@top} #{@left} #{smaxrow()} #{smaxcol()} self: #{self.name} "

      # caution, prefresh uses maxrow and maxcol not height and width
      # so we have to add top and less one since we are zero based
      ret = @window.prefresh(@pminrow, @pmincol, @top, @left, smaxrow(), smaxcol())
      $log.warn " WREFRESH returns -1 ERROR - width or height must be exceeding " if ret == -1
      @modified = false
      return ret
    end
    ##
    # copy the window to the pad (assumes we are writing onto win and keeping
    # pad as backup
    # also assuming only one win so, window not passed as param
    # @return return value of copywin which should be 0 (-1 is ERR)
    def copy_pad_to_win
      $log.warn " DEPRECATED copy_pad_to_win" # CLEANUP
      raise "DEPREC copy_pad_to_win deprecated. Will be removed. Let me know if it is needed"
      # check that we don't exceed other windows height/maxrow
      smr = smaxrow()
      # SHIT, this means the otherwin has to be a Pad, cannot be a window
      osw = @otherwin.width
      osh = @otherwin.height
      osh = @height if osh == 0 # root window has 0
      osw = @width if osw == 0 # root window has 0
      osmr = @otherwin.smaxrow() rescue osh # TRYING for windows
      osmc = @otherwin.smaxcol() rescue osw
      if smr >= osmr
        $log.debug " adjusted smr from #{smr} to #{osmr} -1 causing issues in viewfooter"
        smr = osmr-1 # XXX causing issues in viewport, wont print footer with this
      end
      if smr > @sheight + @top -1 -@pminrow # 2010-01-17 13:27 
        smr = @sheight + @top -1 -@pminrow 
        $log.debug " adjusted smr to #{smr} to prevent crash "
      end
      smc = smaxcol()
      $log.debug " SMC original = #{smc} "
      if smc >= osmc
        smc = osmc-1
        smc = @width # XXX ??? THIS WAS WORKING< but throwing error in viewport case
        smc = [osmc-1, @width].min # yet another hack
        $log.debug " SMC o-1 #{osmc-1} wdth #{@width}, smc #{smc}  "
      end
      ### XXX commented out since it doesn't let a comp print fully if widget expanded (splitpane)
      #smc = osw -1 if smc >= osw; # added 2009-11-02 17:01 for tabbedpanes

      # dang, this is coming up a lot. 2010-01-16 20:34 
      # the second scrollpane was one row too large in testsplit3a.rb
      if smr - @top > @padheight
        $log.debug " fixing smr to padheight  2010-01-16 20:35 HOPE THIS DOESNT BREAK ANYTHING"
        smr = @padheight
      end
      @pminrow = 0 if @pminrow < 0
      @pmincol = 0 if @pmincol < 0
      $log.debug " COPYING #{self.name} to #{@otherwin.name} "
      $log.debug " calling copy pad #{@pminrow} #{@pmincol}, #{@top} #{@left}, #{smr} #{smc} self #{self.name} "
      $log.debug "  calling copy pad H: #{@height} W: #{@width}, PH #{@padheight} PW #{@padwidth} WIN:#{@window} "
      #      $log.debug "  -otherwin target copy pad #{@otherwin.pminrow} #{@otherwin.pmincol}, #{@otherwin.top} #{@otherwin.left}, #{osmr} #{osmc} OTHERWIN:#{@otherwin.name} "
      ret="-"
      #if ret == -1
      #x XXX        $log.debug "  #{ret} otherwin copy pad #{@otherwin.pminrow} #{@otherwin.pmincol}, #{@otherwin.top} #{@otherwin.left}, #{osmr} #{osmc} "
      $log.debug "  #{ret} otherwin copy pad H: #{osh} W: #{osw}"
      if @top >= osh
        $log.debug "  #{ret} ERROR top exceeds other ht #{@top}   H: #{osh} "
      end
      if @left >= osw
        $log.debug "  #{ret} ERROR left exceeds other wt #{@left}   W: #{osw} "
      end
      if smr >= osh
        $log.debug "  #{ret} ERROR smrow exceeds other ht #{smr}   H: #{osh} "
        smr = osh() -1 # testing 2010-01-31 21:47  , again 2010-02-05 20:22 
      end
      if smc >= osw
        $log.debug "  #{ret} ERROR smcol exceeds other wt #{smc}   W: #{osw} "
      end
      if smc - @left > @padwidth
        $log.debug "  #{ret} ERROR smcol - left  exceeds padwidth   #{smc}- #{@left}   PW: #{@padwidth} "
      end
      if smr - @top > @padheight
        $log.debug "  #{ret} ERROR smr  - top  exceeds padheight   #{smr}- #{@top}   PH: #{@padheight} "
      end
      ret = @window.copywin(@otherwin.get_window,@pminrow,@pmincol, @top, @left, smr, smc, 0)
      $log.debug " copywin ret #{ret} "
      # 2010-01-11 19:42 one more cause of -1 coming is that padheight (actual height which never
      # changes unless pad increases) or padwidth is smaller than area being printed. Solution: increase 
      # buffer by increasing widgets w or h. smc - left should not exceed padwidth. smr-top should not
      # exceed padheight
      #end
      @modified = false
      return ret
    end
    # @deprecated
    def copy_win_to_pad
      $log.warn " DEPRECATED copy_win_to_pad" # CLEANUP 2011-09-29 
      raise "DEPREC copy_win_to_pad deprecated. Will be removed. Let me know if it is needed"
      smr = smaxrow()
      if smr >= @window.smaxrow()
        smr = @window.smaxrow()-1
      end
      $log.debug " copy_win_to_pad #{@otherwin.name}, #{@window.name}, pminr:#{@pminrow} pminc:#{@pmincol} top:#{@top} left:#{@left} smr:#{smr} "
      ret = @otherwin.copywin(@window.get_window,@pminrow,@pmincol, @top, @left, smr, smaxcol(), 1)
      @modified = false
      return ret
    end
    ## 
    #Used to overwrite the pad onto the screen window
    # A window should have been specified as window to back (@see set_backing_window) or (@see create_with_window)
    def overwrite_window
      return @window.overwrite(@otherwin.get_window)
    end

    ## 
    #  convenience method so that pad can use printstring but remove screen's row and col
    #  The absolute row and col will be taken into consideration when printing on screen.
    #  
    # @param [Fixnum] row row to print on
    # @param [Fixnum] col column to print on
    # @param [String] value to print
    # @param [Fixnum] color - color combination
    # @param [Fixnum, nil] attrib defaults to NORMAL

    # Pls remove the raise once the program is working, extra line can slow things down
    # Keep it on when testing.
    # If the raise is thrown, it means your object could be positioned higher than it should be,
    # or at some point you have increased top, without increasing the objects row.
    def printstring(row,col,value,color,attrib=Ncurses::A_NORMAL)
      #$log.debug " pad printstring #{row} - #{@top} , #{col} - #{@left} "
      raise "printstring row < top, pls correct code #{row} #{@top}, #{col} #{@left} " if row < @top or col < @left
      #$log.warn "printstring row < top, pls correct code #{row} #{@top} " if row < @top
      super(row - @top, col - @left, value, color, attrib)
    end # printstring
    #  convenience method so that pad can use print_border but remove screen's row and col
    #  Please note that this requires that buffer have latest top and left.
    def print_border row, col, height, width, color, att=Ncurses::A_NORMAL
      $log.debug " pad printborder #{row} - #{@top} , #{col} - #{@left}, #{height} , #{width}  "
      raise "print_border: row < top, pls correct code #{row} #{@top},  #{col} #{@left} " if row < @top or col < @left
      #$log.warn   "print_border: row < top, pls correct code #{row} #{@top} " if row < @top
      super(row - @top, col - @left, height, width,  color, att)
    end
    def print_border_only row, col, height, width, color, att=Ncurses::A_NORMAL
      $log.debug " pad printborder_only #{row} - #{@top} , #{col} - #{@left}, #{height} , #{width}  "
      raise "print_border row < top, pls correct code #{row} #{@top},  #{col} #{@left} " if row < @top or col < @left
      super(row - @top, col - @left, height, width,  color, att)
    end
    # use in place of mvwhline if your widget could be using a pad or window
    def rb_mvwhline row, col, char, width
      super(row-@top, col-@left, char, width)
    end
    # use in place of mvwvline if your widget could be using a pad or window
    def rb_mvwvline row, col, char, width
      super(row-@top, col-@left, char, width)
    end
    # use in place of mvaddch if your widget could be using a pad or window
    def rb_mvaddch row, col, char
      super(row-@top, col-@left, char)
    end
  end # class Pad
end
