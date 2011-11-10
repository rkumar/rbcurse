=begin
  * Name: PadReader.rb
  * Description : This is an independent file viewer that uses a Pad and traps keys
  * Author: rkumar (http://github.com/rkumar/rbcurse/)
  * Date: 22.10.11 - 20:35
  * License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
  * Last update:  2011-11-09 - 13:01

  == CHANGES
  == TODO 
     make the window configurable so we can move to a textview that is pad based, later even list ?
     Note that cursor does not move, in real life applicatino cursor must move to bottom row
     and only then scrolling should start.
=end
require 'rbcurse'

include RubyCurses
class PadReader

  # You may pass height, width, row and col for creating a window otherwise a fullscreen window
  # will be created. If you pass a window from caller then that window will be used.
  # Some keys are trapped, jkhl space, pgup, pgdown, end, home, t b
  # This is currently very minimal and was created to get me started to integrating
  # pads into other classes such as textview.
  def initialize config={}, &block

    @config = config
    @rows = FFI::NCurses.LINES-1
    @cols = FFI::NCurses.COLS-1
    @prow = @pcol = 0
    @startrow = 0
    @startcol = 0
    
    h = config.fetch(:height, 0)
    w = config.fetch(:width, 0)
    t = config.fetch(:row, 0)
    l = config.fetch(:col, 0)
    @rows = h unless h == 0
    @cols = w unless w == 0
    @startrow = t unless t == 0
    @startcol = l unless l == 0
    @suppress_border = config[:suppress_border]
    unless @suppress_border
      @startrow += 1
      @startcol += 1
      @rows -=3  # 3 is since print_border_only reduces one from width, to check whether this is correct
      @cols -=3
    end
    @top = t
    @left = l
    view_file config[:filename]
    @window = config[:window] || VER::Window.new(:height => h, :width => w, :top => t, :left => l)
    # print border reduces on from width for some historical reason
    @window.print_border_only @top, @left, h-1, w, $datacolor
    @ph = @content_rows
    @pw = @content_cols # get max col
    @pad = FFI::NCurses.newpad(@ph, @pw)

    Ncurses::Panel.update_panels
    @content.each_index { |ix|

      FFI::NCurses.mvwaddstr(@pad,ix, 0, @content[ix])
    }
    @window.wrefresh
    padrefresh
    #FFI::NCurses.prefresh(@pad, 0,0, @startrow ,@startcol, @rows,@cols);

    @window.bkgd(Ncurses.COLOR_PAIR(5));
    FFI::NCurses.keypad(@pad, true);
    #@form = Form.new @window
    config[:row] = config[:col] = 0 # ??? XXX
  end

  private
  def view_file(filename)
    @file = filename
    @content = File.open(filename,"r").readlines
    @content_rows = @content.count
    @content_cols = content_cols()
    #run()
  end
  # write pad onto window
  private
  def padrefresh
    FFI::NCurses.prefresh(@pad,@prow,@pcol, @startrow,@startcol, @rows + @startrow,@cols+@startcol);
  end
  # returns button index
  # Call this after instantiating the window
  public
  def run
    #@form.repaint
    #@window.wrefresh
    return handle_keys
  end

  # convenience method
  private
  def key x
    x.getbyte(0)
  end
  def content_cols
    longest = @content.max_by(&:length)
    longest.length
  end

  # returns button index
  private
  def handle_keys
    buttonindex = catch(:close) do 
      @maxrow = @content_rows - @rows
      @maxcol = @content_cols - @cols 
      while((ch = @window.getchar()) != FFI::NCurses::KEY_F10 )
        #while((ch = FFI::NCurses.wgetch(@pad)) != FFI::NCurses::KEY_F10 )
        break if ch == ?\C-q.getbyte(0) 
        begin
          case ch
          when key(?t), 279
            @prow = 0
          when key(?b), 277
            @prow = @maxrow-1
          when key(?j)
            @prow += 1
          when key(?k)
            @prow -= 1
          when 32, 338
            @prow += 10
          when 339
            @prow -= 10
          when key(?l)
            @pcol += 1
          when key(?$)
            @pcol = @maxcol - 1
          when key(?h)
            @pcol -= 1
          when key(?0)
            @pcol = 0
          when key(?q)
            throw :close
          else 
            alert " #{ch} not mapped "
          end
          @prow = 0 if @prow < 0
          @pcol = 0 if @pcol < 0
          if @prow > @maxrow-1
            @prow = @maxrow-1
          end
          if @pcol > @maxcol-1
            @pcol = @maxcol-1
          end
          #@window.wclear
          #FFI::NCurses.prefresh(@pad,@prow,@pcol, @startrow,0, @rows,@cols);
          padrefresh
          Ncurses::Panel.update_panels
          #@form.handle_key(ch)
          #@window.wrefresh
        rescue => err
          $log.debug( err) if err
          $log.debug(err.backtrace.join("\n")) if err
          alert "Got an exception in PadReader: #{err}. Check log"
          $error_message.value = ""
        ensure
        end

      end # while loop
    end # close
    $log.debug "XXX: CALLER GOT #{buttonindex} "
    @window.destroy unless @config[:window]
    FFI::NCurses.delwin(@pad)
    return buttonindex 
  end
end
if __FILE__ == $PROGRAM_NAME
  require 'rbcurse/app'
  App.new do
    status_line
    @form.repaint
    p = PadReader.new :filename => "padreader.rb", :height => 20, :width => 60, :row => 4, :col => 4, :window => @window, :suppress_border => true
    p.run
    throw :close
  end
end
