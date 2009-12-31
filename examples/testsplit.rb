#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rsplitpane'
#require 'rbcurse/rtestwidget'
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
      r = 1; c = 3; ht = 18
      # filler just to see that we are covering correct space and not wasting lines or cols
      filler = "*" * 88
      (ht+2).times(){|i| @form.window.printstring(i,r, filler, $datacolor) }


      @help = "q to quit. v h - + =                                          . Check logger too"
      RubyCurses::Label.new @form, {'text' => @help, "row" => ht+r, "col" => 2, "color" => "yellow"}

      splitp = SplitPane.new @form do
          name   "mypane" 
          row  r 
          col  c
          width 70
          height ht
          #editable false
          focusable false
          #orientation :VERTICAL_SPLIT
        end

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != ?q.getbyte(0) )
        str = keycode_tos ch
        case ch
        when ?v.getbyte(0)
          splitp.orientation(:VERTICAL_SPLIT)
        when ?h.getbyte(0)
          splitp.orientation(:HORIZONTAL_SPLIT)
        when ?-.getbyte(0)
          splitp.set_divider_location(splitp.divider_location-1)
        when ?+.getbyte(0)
          splitp.set_divider_location(splitp.divider_location+1)
        when ?=.getbyte(0)
          splitp.set_resize_weight(0.50)
        end
        #splitp.get_buffer().wclear
        #splitp << "#{ch} got (#{str})"
        splitp.repaint
        splitp.buffer_to_screen
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
