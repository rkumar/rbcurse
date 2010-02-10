#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
# Creates a scrollpane with a Testwidget (which is a modified TextView class)
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rtextarea'
require 'rbcurse/rscrollpane'
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
      $log.debug " MAIN FORM #{@form}   w #{@window}  "
      r = 1; c = 10; w = 40
      ht = 10
      # print filler stars
      #filler = "*" * (w+2)
      #(ht+3).times(){|i| @form.window.printstring(i,c-1, filler, $datacolor) }


        @scroll = ScrollPane.new @form do
          name   "myScroller" 
          row r+ht+1
          col  c 
          width w
          height ht
        end
        # XXX  we are passing nil as form, so its bound to bomb FIXME TODO
        @textview = TextArea.new @nil do
          name   "myText" 
          row 0
          col  0 
          width w+10
          height ht+10
          title "EditMe.txt"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
          should_create_buffer true
        end
        @scroll.child(@textview)
        @textview << "I expect to pass through this world but once." << "Any good therefore that I can do, or any kindness or abilities that I can show to any fellow creature, let me do it now."
        @textview << "Let me not defer it or neglect it, for I shall not pass this way again."
        @textview << " "
        @textview << "F1 to exit. M-n, M-p, M-h, M-l for scrolling."
        @textview << "Some more text going below scrollpane.. "
        @textview << "Try C-[ C-] for going to start and end "


      @help = "F1 to quit. This is a test of TextArea inside a Scrollpane (it uses a pad/buffer).: #{$0} "
      RubyCurses::Label.new @form, {'text' => @help, "row" => 23, "col" => 2, "color" => "yellow"}

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != KEY_F1)
        str = keycode_tos ch
        @form.handle_key(ch)
        @form.repaint
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
