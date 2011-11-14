# ----------------------------------------------------------------------------- #
#         File: textpad.rb
#  Description: A class that displays text using a pad.
#         The motivation for this is to put formatted text and not care about truncating and 
#         stuff. Also, there will be only one write, not each time scrolling happens.
#         I found textview code for repaint being more complex than required.
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2011-11-09 - 16:59
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2011-11-10 - 12:39
#
#  == CHANGES
#  == TODO 
#     when moving right, also don't pan straight away
#     x add mappings and process key in handle_keys and other widget things
#     - user can put text or list
#     - handle putting data again and overwriting existing
#     - formatted text
#     - search and other features
#     - can pad movement and other ops be abstracted into module for reuse
#     / get scrolling like in vim (C-f e y b d)
#     - alert issue of leaving a blank is poss due to using prefresh i/o copywin
#
# ----------------------------------------------------------------------------- #
#
require 'rbcurse'
require 'rbcurse/common/bordertitle'

include RubyCurses
module RubyCurses
  extend self
  class TextPad < Widget
    include BorderTitle

    dsl_accessor :suppress_border
    # You may pass height, width, row and col for creating a window otherwise a fullscreen window
    # will be created. If you pass a window from caller then that window will be used.
    # Some keys are trapped, jkhl space, pgup, pgdown, end, home, t b
    # This is currently very minimal and was created to get me started to integrating
    # pads into other classes such as textview.
    def initialize form=nil, config={}, &block

      @editable = false
      @focusable = true
      @config = config
      #@rows = FFI::NCurses.LINES-1
      #@cols = FFI::NCurses.COLS-1
      @prow = @pcol = 0
      @startrow = 0
      @startcol = 0
      @list = []
      super

      # FIXME 0 as height craps out. need to make it LINES

      @height = @height.ifzero(FFI::NCurses.LINES)
      @width = @width.ifzero(FFI::NCurses.COLS)
      @rows = @height
      @cols = @width
      @startrow = @row
      @startcol = @col
      #@suppress_border = config[:suppress_border]
      @row_offset = @col_offset = 1
      unless @suppress_border
        @startrow += 1
        @startcol += 1
        @rows -=3  # 3 is since print_border_only reduces one from width, to check whether this is correct
        @cols -=3
      end
      @row_offset = @col_offset = 0 if @suppress_borders
      @top = @row
      @left = @col
      init_vars
    end
    def init_vars
      @scrollatrows = @height - 3
      @oldindex = @current_index = 0
      @repaint_required = true
    end
    def rowcol #:nodoc:
      return @row+@row_offset, @col+@col_offset
    end

    private
    def create_pad
      destroy if @pad
      #@pad = FFI::NCurses.newpad(@content_rows, @content_cols)
      @pad = @window.get_pad(@content_rows, @content_cols)
    end

    private
    # create and populate pad
    def populate_pad
      @_populate_needed = false
      # how can we make this more sensible ? FIXME
      @renderer ||= DefaultRubyRenderer.new if ".rb" == @filetype
      @content_rows = @content.count
      @content_cols = content_cols()

      create_pad

      Ncurses::Panel.update_panels
      @content.each_index { |ix|
        #FFI::NCurses.mvwaddstr(@pad,ix, 0, @content[ix])
        render @pad, ix, @content[ix]
      }

    end

    public
    # supply a custom renderer that implements +render()+
    # @see render
    def renderer r
      @renderer = r
    end
    #
    # default method for rendering a line
    #
    def render pad, lineno, text
      if text.is_a? Chunks::ChunkLine
        FFI::NCurses.wmove @pad, lineno, 0
        a = get_attrib @attrib
      
        show_colored_chunks text, nil, a
        return
      end
      if @renderer
        @renderer.render @pad, lineno, text
      else
        FFI::NCurses.mvwaddstr(@pad,lineno, 0, @content[lineno])
      end
    end

    # supply a filename as source for textpad
    # Reads up file into @content

    def filename(filename)
      @file = filename
      @filetype = File.extname filename
      @content = File.open(filename,"r").readlines
      @_populate_needed = true
    end

    # Supply an array of string to be displayed
    # This will replace existing text

    def text lines
      @content = lines
      @_populate_needed = true
    end

    ## ---- the next 2 methods deal with printing chunks
    # we should put it int a common module and include it
    # in Window and Pad stuff and perhaps include it conditionally.

    def print(string, width = width)
      #return unless visible?
      w = width == 0? Ncurses.COLS : width
      FFI::NCurses.waddnstr(@pad,string.to_s, w) # changed 2011 dts  
    end

    def show_colored_chunks(chunks, defcolor = nil, defattr = nil)
      #return unless visible?
      chunks.each do |chunk| #|color, chunk, attrib|
        case chunk
        when Chunks::Chunk
          color = chunk.color
          attrib = chunk.attrib
          text = chunk.text
        when Array
          # for earlier demos that used an array
          color = chunk[0]
          attrib = chunk[2]
          text = chunk[1]
        end

        color ||= defcolor
        attrib ||= defattr || NORMAL

        #cc, bg = ColorMap.get_colors_for_pair color
        #$log.debug "XXX: CHUNK textpad #{text}, cp #{color} ,  attrib #{attrib}. #{cc}, #{bg} "
        FFI::NCurses.wcolor_set(@pad, color,nil) if color
        FFI::NCurses.wattron(@pad, attrib) if attrib
        print(text)
        FFI::NCurses.wattroff(@pad, attrib) if attrib
      end
    end

    def formatted_text text, fmt
      require 'rbcurse/common/chunk'
      @formatted_text = text
      @color_parser = fmt
      #remove_all
    end

    # write pad onto window
    private
    def padrefresh
      FFI::NCurses.prefresh(@pad,@prow,@pcol, @startrow,@startcol, @rows + @startrow,@cols+@startcol);
    end

    # convenience method to return byte
    private
    def key x
      x.getbyte(0)
    end

    # length of longest string in array
    def content_cols
      longest = @content.max_by(&:length)
      longest.length
    end

    public
    def repaint
      return unless @repaint_required
      if @formatted_text
        $log.debug "XXX:  INSIDE FORMATTED TEXT "

        l = RubyCurses::Utils.parse_formatted_text(@color_parser,
                                               @formatted_text)

        text(l)
        @formatted_text = nil
      end

      populate_pad if @_populate_needed
      #HERE we need to populate once so user can pass a renderer
      @window ||= @graphic
      unless @suppress_border
        if @repaint_all
          @window.print_border_only @top, @left, @height-1, @width, $datacolor
          print_title
          @window.wrefresh
        end
      end

      padrefresh
      @repaint_required = false
      @repaint_all = false
    end

    #
    # key mappings
    #
    def map_keys
      @mapped_keys = true
      bind_key([?g,?g]){ goto_start } # mapping double keys like vim
      bind_key(279){ goto_start } 
      bind_keys([?G,277]){ goto_end } 
      bind_keys([?k,KEY_UP]){ up } 
      bind_keys([?j,KEY_DOWN]){ down } 
      bind_key(?\C-e){ scroll_window_down } 
      bind_key(?\C-y){ scroll_window_up } 
      bind_keys([32,338]){ scroll_forward } 
      bind_keys([?\C-b,339]){ scroll_backward } 
      bind_key([?',?']){ goto_last_position } # vim , goto last row position (not column)
      #bind_key(?/, :ask_search)
      #bind_key(?n, :find_more)
      bind_key([?\C-x, ?>], :scroll_right)
      bind_key([?\C-x, ?<], :scroll_left)
      bind_key(?\M-l, :scroll_right)
      bind_key(?\M-h, :scroll_left)
      bind_key([?\C-x, ?\C-s], :saveas)
      #bind_key(?r) { getstr("Enter a word: ") }
      bind_key(?m, :disp_menu)
    end

    # goto first line of file
    def goto_start
      @oldindex = @current_index
      @current_index = 0
      @prow = 0
    end

    # goto last line of file
    def goto_end
      @oldindex = @current_index
      @current_index = @content_rows-1
      @prow = @current_index - @scrollatrows
    end

    # move down a line mimicking vim's j key
    # @param [int] multiplier entered prior to invoking key
    def down num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
      @oldindex = @current_index if num > 10
      @current_index += num
      unless is_visible? @current_index
        if @current_index > @scrollatrows
          @prow += 1
        end
      end
      $multiplier = 0
    end

    # move up a line mimicking vim's k key
    # @param [int] multiplier entered prior to invoking key
    def up num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
      @oldindex = @current_index if num > 10
      @current_index -= num
      unless is_visible? @current_index
        if @prow > @current_index
          $status_message.value = "1 #{@prow} > #{@current_index} "
          @prow -= 1
        else
        end
      end
      $multiplier = 0
    end

    # scrolls window down mimicking vim C-e
    # @param [int] multiplier entered prior to invoking key
    def scroll_window_down num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
      @prow += num
        if @prow > @current_index
          @current_index += 1
        end
      #check_prow
      $multiplier = 0
    end

    # scrolls window up mimicking vim C-y
    # @param [int] multiplier entered prior to invoking key
    def scroll_window_up num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
      @prow -= num
      unless is_visible? @current_index
        # one more check may be needed here TODO
        @current_index -= num
      end
      $multiplier = 0
    end

    # scrolls lines a window full at a time, on pressing ENTER or C-d or pagedown
    def scroll_forward
      @oldindex = @current_index
      @current_index += @scrollatrows
      @prow = @current_index - @scrollatrows
    end

    # scrolls lines backward a window full at a time, on pressing pageup 
    # C-u may not work since it is trapped by form earlier. Need to fix
    def scroll_backward
      @oldindex = @current_index
      @current_index -= @scrollatrows
      @prow = @current_index - @scrollatrows
    end
    def goto_last_position
      return unless @oldindex
      tmp = @current_index
      @current_index = @oldindex
      @oldindex = tmp
      bounds_check
    end
    def handle_key ch
      return :UNHANDLED unless @content
      map_keys unless @mapped_keys

      @maxrow = @content_rows - @rows
      @maxcol = @content_cols - @cols 
      @oldrow = @prow
      @oldcol = @pcol
      $log.debug "XXX: PAD got #{ch} "
      begin
        case ch
        when key(?l)
          @pcol += 1
        when key(?$)
          @pcol = @maxcol - 1
        when key(?h)
          if @pcol > 0
            @pcol -= 1
          end
        when key(?q)
          #throw :close
      when ?0.getbyte(0)..?9.getbyte(0)
        if ch == ?0.getbyte(0) && $multiplier == 0
          # copy of C-a - start of line
          @repaint_required = true if @pcol > 0 # tried other things but did not work
          @pcol = 0
          return 0
        end
        # storing digits entered so we can multiply motion actions
        $multiplier *= 10 ; $multiplier += (ch-48)
        return 0
        when ?\C-c.getbyte(0)
          $multiplier = 0
          return 0
        else
          # check for bindings, these cannot override above keys since placed at end
          begin
            ret = process_key ch, self
          rescue => err
            $log.error " TEXTPAD ERROR #{err} "
            $log.debug(err.backtrace.join("\n"))
            alert err.to_s
            # FIXME why does this result in a blank spot on screen till its refreshed again
            # should not happen if its deleting its panel and doing an update panel
          end
          return :UNHANDLED if ret == :UNHANDLED
        end
        bounds_check
      rescue => err
        $log.debug( err) if err
        $log.debug(err.backtrace.join("\n")) if err
        alert "Got an exception in PadReader: #{err}. Check log"
        $error_message.value = ""
      ensure
      end
      return 0
    end # while loop

    # destroy the pad, this needs to be called from somewhere, like when the app
    # closes or the current window closes , or else we could have a seg fault
    # or some ugliness on the screen below this one (if nested).

    # Now since we use get_pad from window, upon the window being destroyed,
    # it will call this. Else it will destroy pad
    def destroy
      FFI::NCurses.delwin(@pad) if @pad # when do i do this ? FIXME
      @pad = nil
    end
    def is_visible? index
      j = index - @prow #@toprow
      j >= 0 && j <= @scrollatrows
    end

    private
    
    # check that current_index and prow are within correct ranges
    # sets row (and someday col too)
    # sets repaint_required

    def bounds_check
      r,c = rowcol
      @current_index = 0 if @current_index < 0
      @current_index = @content_rows-1 if @current_index > @content_rows-1
      $status_message.value = "visible #{@prow} , #{@current_index} "
      unless is_visible? @current_index
        if @prow > @current_index
          $status_message.value = "1 #{@prow} > #{@current_index} "
          @prow -= 1
        else
        end
      end
      #end
      check_prow
      $log.debug "XXX: PAD BOUNDS ci:#{@current_index} , old #{@oldrow},pr #{@prow}, max #{@maxrow} "
      @crow = @current_index + r - @prow
      @crow = r if @crow < r
      # 2 depends on whetehr suppressborders
      @crow = @row + @height -2 if @crow >= r + @height -2
      setrowcol @crow, nil
      if @oldrow != @prow || @oldcol != @pcol
        @repaint_required = true
      end
    end
  end

  # check that prow and pcol are within bounds

  def check_prow
    @prow = 0 if @prow < 0
    @pcol = 0 if @pcol < 0
    if @prow > @maxrow-1
      @prow = @maxrow-1
    end
    if @pcol > @maxcol-1
      @pcol = @maxcol-1
    end
  end
  # a test renderer to see how things go
  class DefaultRubyRenderer
    def render pad, lineno, text
      bg = :black
      fg = :white
      att = NORMAL
      cp = $datacolor
      if text =~ /^\s*# /
        fg = :red
        cp = get_color($datacolor, fg, bg)
      elsif text =~ /^\s*#/
        fg = :blue
        cp = get_color($datacolor, fg, bg)
      elsif text =~ /^\s*class /
        fg = :magenta
        cp = get_color($datacolor, fg, bg)
      elsif text =~ /^\s*def /
        fg = :yellow
        att = BOLD
        cp = get_color($datacolor, fg, bg)
      elsif text =~ /^\s*(begin|rescue|ensure|end)/
        fg = :magenta
        att = BOLD
        cp = get_color($datacolor, fg, bg)
      end
      FFI::NCurses.wattron(pad,FFI::NCurses.COLOR_PAIR(cp) | att)
      FFI::NCurses.mvwaddstr(pad, lineno, 0, text)
      FFI::NCurses.wattroff(pad,FFI::NCurses.COLOR_PAIR(cp) | att)

    end
  end
end
if __FILE__ == $PROGRAM_NAME
  require 'rbcurse/app'
  App.new do
    w = 50
    w2 = FFI::NCurses.COLS-w-1
    p = RubyCurses::TextPad.new @form, :height => FFI::NCurses.LINES, :width => w, :row => 0, :col => 0 , :title => " ansi "
    fn = "../../../examples/color.2"
    text = File.open(fn,"r").readlines
    p.formatted_text(text, :ansi)
    RubyCurses::TextPad.new @form, :filename => "textpad.rb", :height => FFI::NCurses.LINES, :width => w2, :row => 0, :col => w+1 , :title => " ruby "
    #throw :close
    #status_line
  end
end
