#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
# Creates a scrollpane with a TextView (which is a modified TextView class)
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
#require 'rbcurse/rtestwidget'
require 'rbcurse/rtextview'
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
      r = 1; c = 5; w = 80
      ht = 20
      # print filler stars
      filler = "*" * (w+2)
      #(ht+3).times(){|i| @form.window.printstring(i,c-1, filler, $datacolor) }


        @scroll = ScrollPane.new @form do
          name   "myScroller" 
          row r
          col  c 
          width w
          height ht
        end
        @textview = TextView.new nil do
          name   "myView" 
          row 0
          col  0 
          width w+10
          height ht+20
          title "README.txt"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
          should_create_buffer true
        end
        content = File.open("../README.markdown","r").readlines
        @textview.set_content content #, :WRAP_WORD
        @scroll.child(@textview)

      @help = "F1 to quit. This is a test of TextView inside a scrollpane. M-n M-p M-h M-l M-< M-> "
      RubyCurses::Label.new @form, {'text' => @help, "row" => ht+r+1, "col" => 2, "color" => "yellow"}

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != KEY_F1 ) # ?q.getbyte(0) )
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
