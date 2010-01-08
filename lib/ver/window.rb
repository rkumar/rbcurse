require 'ver/ncurses'
module VER
  class Window 
    attr_reader :width, :height, :top, :left
    attr_accessor :layout
    attr_reader   :panel   # reader requires so he can del it in end
    attr_reader   :window_type   # window or pad to distinguish 2009-11-02 23:11 

    def initialize(layout)
      @visible = true
      reset_layout(layout)

      @window = Ncurses::WINDOW.new(height, width, top, left)
      @panel = Ncurses::Panel.new_panel(@window)
      init_vars
      ## eeks XXX next line will wreak havoc when multiple windows opened like a mb or popup
      $error_message_row = $status_message_row = Ncurses.LINES-1

    end
    def init_vars
      @window_type = :WINDOW
      Ncurses::keypad(@window, true)
      @stack = []
    end
    ##
    # this is an alternative constructor
    def self.root_window(layout = { :height => 0, :width => 0, :top => 0, :left => 0 })
      #VER::start_ncurses
      @layout = layout
      @window = Window.new(@layout)
      @window.wrefresh
      Ncurses::Panel.update_panels
      return @window
    end
    # 2009-10-13 12:24 
    # not used as yet
    # this is an alternative constructor
    # created if you don't want to create a hash first
    def self.create_window(h=0, w=0, t=0, l=0)
      layout = { :height => 0, :width => 0, :top => 0, :left => 0 }
      @window = Window.new(layout)
      return @window
    end

    def resize_with(layout)
      reset_layout(layout)
      @window.wresize(height, width)
      @window.mvwin(top, left)
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

    def move(y, x)
      return unless @visible
#       Log.debug([y, x] => caller[0,4])
      @window.move(y, x)
    end

    def method_missing(meth, *args)
      @window.send(meth, *args)
    end

    def print(string, width = width)
      return unless visible?
      @window.waddnstr(string.to_s, width)
    end

    def print_yx(string, y = 0, x = 0)
      @window.mvwaddnstr(y, x, string, width)
    end

    def print_empty_line
      return unless visible?
      @window.printw(' ' * width)
    end

    def print_line(string)
      print(string.ljust(width))
    end

    def show_colored_chunks(chunks)
      return unless visible?
      chunks.each do |color, chunk|
        color_set(color)
        print_line(chunk)
      end
    end

    def puts(*strings)
      print(strings.join("\n") << "\n")
    end

    def refresh
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

    def getch
      @window.getch
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
              return 353 # backtab
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

    # setup and reset

    def reset_layout(layout)
      @layout = layout

      [:height, :width, :top, :left].each do |name|
        instance_variable_set("@#{name}", layout_value(name))
      end
    end

    def layout_value(name)
      value = @layout[name]
      default = default_for(name)

      value = value.call(default) if value.respond_to?(:call)
      return (value || default).to_i
    end

    def default_for(name)
      case name
      when :height, :top
        Ncurses.stdscr.getmaxy
      when :width, :left
        Ncurses.stdscr.getmaxx
      else
        0
      end
    end

    # Ncurses panel

    def hide
      Ncurses::Panel.hide_panel @panel
      Ncurses.refresh # wnoutrefresh
      @visible = false
    end

    def show
      Ncurses::Panel.show_panel @panel
      Ncurses.refresh # wnoutrefresh
      @visible = true
    end

    def on_top
      Ncurses::Panel.top_panel @panel
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
      $log.debug "win destroy"

      #@panel = @window.panel if @window
      Ncurses::Panel.del_panel(@panel) if !@panel.nil?   
      @window.delwin if !@window.nil?
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

      att = Ncurses::A_NORMAL if att.nil?
      case att.to_s.downcase
      when 'underline'
        att = Ncurses::A_UNDERLINE
      when 'bold'
        att = Ncurses::A_BOLD
      when 'blink'
        att = Ncurses::A_BLINK    # unlikely to work
      when 'reverse'
        att = Ncurses::A_REVERSE    
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
    def print_error_message text=$error_message
      r = $error_message_row || Ncurses.LINES-1
      $log.debug "got ERROR MEASSAGE #{text} row #{r} "
      clear_error r, $datacolor
      # print it in centre
      printstring r, (Ncurses.COLS-text.length)/2, text, color = $promptcolor
    end
    # added by rk 2008-11-29 19:01 
    def print_status_message text=$status_message
      r = $status_message_row || Ncurses.LINES-1
      clear_error r, $datacolor
      # print it in centre
      printstring r, (Ncurses.COLS-text.length)/2, text, color = $promptcolor
    end
    # added by rk 2008-11-29 19:01 
    def clear_error r = $error_message_row, color = $datacolor
      printstring(r, 0, "%-*s" % [Ncurses.COLS," "], color)
    end
    ##
    # CAUTION : FOR MESSAGEBOXES ONLY !!!! XXX
    def print_border_mb row, col, height, width, color, attr
      mvwaddch row, col, ACS_ULCORNER
      mvwhline( row, col+1, ACS_HLINE, width-6)
      mvwaddch row, col+width-5, Ncurses::ACS_URCORNER
      mvwvline( row+1, col, ACS_VLINE, height-4)

      mvwaddch row+height-3, col, Ncurses::ACS_LLCORNER
      mvwhline(row+height-3, col+1, ACS_HLINE, width-6)
      mvwaddch row+height-3, col+width-5, Ncurses::ACS_LRCORNER
      mvwvline( row+1, col+width-5, ACS_VLINE, height-4)
    end
    ##
    # prints a border around a widget, CLEARING the area.
    #  If calling with a pad, you would typically use 0,0, h-1, w-1.
    def print_border row, col, height, width, color, att=Ncurses::A_NORMAL
      att ||= Ncurses::A_NORMAL

      $log.debug " inside print_border r #{row} c #{col} h #{height} w #{width} "

      # 2009-11-02 00:45 made att nil for blanking out
      (row+1).upto(row+height-1) do |r|
        printstring( r, col+1," "*(width-2) , $datacolor, nil)
      end
      attron(Ncurses.COLOR_PAIR(color) | att)


      mvwaddch row, col, ACS_ULCORNER
      mvwhline( row, col+1, ACS_HLINE, width-2)
      mvwaddch row, col+width-1, Ncurses::ACS_URCORNER
      mvwvline( row+1, col, ACS_VLINE, height-1)

      mvwaddch row+height-0, col, Ncurses::ACS_LLCORNER
      mvwhline(row+height-0, col+1, ACS_HLINE, width-2)
      mvwaddch row+height-0, col+width-1, Ncurses::ACS_LRCORNER
      mvwvline( row+1, col+width-1, ACS_VLINE, height-1)
      attroff(Ncurses.COLOR_PAIR(color) | att)
    end
  # added RK 2009-10-08 23:57 for tabbedpanes
  # THIS IS EXPERIMENTAL - 
    def derwin(layout)
      return VER::SubWindow.new(self, layout)
    end
    def get_window; @window; end
  end
  ##
  # added RK 2009-10-08 23:57 for tabbedpanes
  # THIS IS EXPERIMENTAL - 
  # I have not called super in the initializer so any methods you try on subwin
  # that exist in the superclass which use @window will bomb
  # @since 0.1.3
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
      @subwin = @parent.get_window().derwin(@height, @width, @top, @left)
      $log.debug "SUBWIN init #{@height} #{@width} #{@top} #{@left} "
      $log.debug "SUBWIN init #{@subwin.getbegx} #{@subwin.getbegy} #{@top} #{@left} "
      @panel = Ncurses::Panel.new_panel(@subwin)

      @window = @subwin # makes more mthods available
      init_vars

    end
    # no need really now 
    def reset_layout layout
      @height = layout[:height]
      @width = layout[:width]
      @top = layout[:top]
      @left = layout[:left]
    end
    def _destroy
      # typically the ensure block should have this
      # or should window do it for all subwins, or would we want to wait that long ?
      $log.debug "subwin destroy"

      Ncurses::Panel.del_panel(@panel) if !@panel.nil?   
      @window.delwin if !@window.nil?
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
      @window = Ncurses.newpad(@padheight, @padwidth)
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
    ## added user setting screens max row and col (e.g splitpanes first component)
    def set_screen_max_row_col mr, mc
      @screen_maxrow = mr unless mr.nil?
      @screen_maxcol = mc unless mc.nil?
    end
    # start row and col correspond to pad's top and left which will change if scrolling
    # However, if we use this as a backing store for subwindows it could remain the same
    def set_pad_top_left top, left=-1
      $log.debug "   inside set_pad_top_left to #{top} #{left} earlier #{@pminrow}, #{@pmincol}"
      @pminrow = top unless top < 0
      @pmincol = left unless left < 0
    end
    # return screen max row which will be used for writing to window
    # XXX what if user sets/overrides sheight
    def smaxrow
      #$log.debug "    ... niside smaxrow #{@sheight} + #{@top} -1 "
      #@sheight + @top -1 
#      $log.debug "    ... niside smaxrow #{@sheight} + #{@top} -1 - #{@pminrow}"
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
    def set_backing_window win
      @otherwin = win
      # XX should we  extract the coordinates and use for printing ??
      # or for setting maxrow and maxcol
    end
    # trying to make things as easy as possible
    # returns -1 if error in prefresh
    def wrefresh
      $log.debug " inside pad's wrefresh #{@window}.  #{@pminrow}, #{@pmincol}, #{@top} #{@left} #{smaxrow()} #{smaxcol()} "

      # caution, prefresh uses maxrow and maxcol not height and width
      # so we have to add top and less one since we are zero based
      ret = @window.prefresh(@pminrow, @pmincol, @top, @left, smaxrow(), smaxcol())
      $log.debug " WREFRESH returns -1 ERROR " if ret == -1
      return ret
    end
    ##
    # copy the window to the pad (assumes we are writing onto win and keeping
    # pad as backup
    # also assuming only one win so, window not passed as param
    # @return return value of copywin which should be 0 (-1 is ERR)
    def copy_pad_to_win
      # check that we don't exceed other windows height/maxrow
      smr = smaxrow()
      osmr = @otherwin.smaxrow()
      osmc = @otherwin.smaxcol()
      osw = @otherwin.width
      osh = @otherwin.height
      if smr >= osmr
        smr = osmr-1 # XXX causing issues in viewport, wont print footer with this
      end
      smc = smaxcol()
      if smc >= osmc
        smc = osmc-1
        smc = @width # XXX ??? THIS WAS WORKING< but throwing error in viewport case
        smc = [osmc-1, @width].min # yet another hack
        $log.debug " SMC o-1 #{osmc-1} wdth #{@width}, smc #{smc}  "
      end
      smc = osw -1 if smc >= osw; # added 2009-11-02 17:01 for tabbedpanes
      @pminrow = 0 if @pminrow < 0
      @pmincol = 0 if @pmincol < 0
      $log.debug " calling copy pad #{@pminrow} #{@pmincol}, #{@top} #{@left}, #{smr} #{smc} "
      $log.debug "  calling copy pad H: #{@height} W: #{@width}"
      ret = @window.copywin(@otherwin.get_window,@pminrow,@pmincol, @top, @left, smr, smc, 0)
      #if ret == -1
        $log.debug "  #{ret} otherwin copy pad #{@otherwin.pminrow} #{@otherwin.pmincol}, #{@otherwin.top} #{@otherwin.left}, #{osmr} #{osmc} "
        $log.debug "  #{ret} otherwin copy pad H: #{@otherwin.height} W: #{@otherwin.width}"
        if @top >= @otherwin.height
          $log.debug "  #{ret} ERROR top exceeds other ht #{@top}   H: #{@otherwin.height} "
        end
        if @left >= @otherwin.width
          $log.debug "  #{ret} ERROR left exceeds other wt #{@left}   W: #{@otherwin.width} "
        end
        if smr >= @otherwin.height
          $log.debug "  #{ret} ERROR smrow exceeds other ht #{smr}   H: #{@otherwin.height} "
        end
        if smc >= @otherwin.width
          $log.debug "  #{ret} ERROR smcol exceeds other wt #{smc}   W: #{@otherwin.width} "
        end
      #end
      return ret
    end
    def copy_win_to_pad
      smr = smaxrow()
      if smr >= @window.smaxrow()
        smr = @window.smaxrow()-1
      end
      ret = @otherwin.copywin(@window.get_window,@pminrow,@pmincol, @top, @left, smr, smaxcol(), 1)
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

    def printstring(row,col,value,color,attrib=Ncurses::A_NORMAL)
      #$log.debug " pad printstring #{row} - #{@top} , #{col} - #{@left} "
      super(row - @top, col - @left, value, color, attrib)
    end # printstring
    #  convenience method so that pad can use print_border but remove screen's row and col
    #  Please note that this requires that buffer have latest top and left.
    def print_border row, col, height, width, color, att=Ncurses::A_NORMAL
      $log.debug " pad printborder #{row} - #{@top} , #{col} - #{@left}, #{height} , #{width}  "
      super(row - @top, col - @left, height, width,  color, att)
    end
  end # class Pad
end
