#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
# Creates a scrollpane with a TextView (which is a modified TextView class)
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
#require 'rbcurse/rtextview'
require 'rbcurse/rmultitextview'
require 'rbcurse/rscrollpane'
require 'rbcurse/undomanager'
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new("v#{$0}.log")
    $log.level = Logger::DEBUG

    @window = VER::Window.root_window

    catch(:close) do
      colors = Ncurses.COLORS
      @form = Form.new @window
      @form.name = "Form::MAINFORM"
      r = 3; c = 5; w = 80
      ht = 20
      # print filler stars
      #filler = "*" * (w+2)
      #(ht+3).times(){|i| @form.window.printstring(i,c-1, filler, $datacolor) }


        @scroll = ScrollPane.new @form do
          name   "myScroller" 
          row r
          col  c 
          width w
          height ht
        end
        @textview = MultiTextView.new do
        #@textview = TextView.new do
          name   "myView" 
          row 0
          col  0 
          width w 
          height ht +20
          title "README.txt"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
          #suppress_borders true
        end
        #@textview.should_create_buffer true # can be moved to scrollpane
        #@textview.set_buffering(:target_window => @form.window, :bottom => @scroll.height-1, :right => @scroll.width-1 )
        #content = File.open("../README.markdown","r").readlines
        #@textview.set_content content #, :WRAP_WORD
        @textview.add "../README.markdown", "Readme"
       
        @textview.load_module "vieditable", "ViEditable"
        @scroll.child(@textview)
        undom = SimpleUndo.new @textview
        #@textview.show_caret=true

      @help = "F1 to quit. #{$0} TextView inside scrollpane. M-n M-p M-h M-l M-< M->, e to open file, : for menu""
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
