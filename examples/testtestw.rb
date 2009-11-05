#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
#require 'lib/ver/keyboard'
require 'rbcurse'
require 'rbcurse/rtestwidget'
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
      r = 1; c = 30; w = 40
      ht = 10
      # print filler stars
      filler = "*" * (w+2)
      (ht+3).times(){|i| @form.window.printstring(i,c-1, filler, $datacolor) }

      # strangely, first displays textview, then puts the fillers over it.
      # then after a keypress, again refreshes textview.


        @textview = TestWidget.new @form do
          name   "myView" 
          row r
          col  c 
          width w
          height ht
          title "README.txt"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
        end
        content = File.open("../README.txt","r").readlines
        @textview.set_content content #, :WRAP_WORD

      @help = "q to quit. This is a test of testWidget which uses a pad/buffer."
      RubyCurses::Label.new @form, {'text' => @help, "row" => 21, "col" => 2, "color" => "yellow"}

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != ?q.getbyte(0) )
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
