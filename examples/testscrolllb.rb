#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
# Creates a scrollpane with a Testwidget (which is a modified TextView class)
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rlistbox'
require 'rbcurse/rscrollpane'
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
      r = 1; c = 10; w = 40
      ht = 10
      # print filler stars
      filler = "*" * (w+2)
      #(ht+3).times(){|i| @form.window.printstring(i,c-1, filler, $datacolor) }


        @scroll = ScrollPane.new @form do
          name   "myScroller" 
          row r+ht+1
          col  c 
          width w
          height ht
        end
        mylist = []
        0.upto(100) { |v| mylist << "#{v} scrollable data" }
        $listdata = Variable.new mylist
        # NOTE that embedded object is not passed form, since it doesn't update form
        listb = Listbox.new nil do
          name   "mylist" 
          row 0
          col  0 
          width w+10
          height ht+10
          list_variable $listdata
          #selection_mode :SINGLE
          show_selector true
          row_selected_symbol "[X] "
          row_unselected_symbol "[ ] "
          title "A long list"
          title_attrib 'reverse'
          cell_editing_allowed true
        end
        ## The next 2 are not advised since they don't trigger events
        #listb.insert 55, "hello ruby", "so long python", "farewell java", "RIP .Net"
        #$listdata.value.insert 55, "hello ruby", "so long python", "farewell java", "RIP .Net"
        listb.list_data_model.insert 55, "hello ruby", "so long python", "farewell java", "RIP .Net", "hi lisp", "hi clojure", "hiya erlang"
        @scroll.child(listb)


      @help = "q to quit. This is a test of Listbox which uses a pad/buffer.: #{$0}"
      #RubyCurses::Label.new @form, {'text' => @help, "row" => 21, "col" => 2, "color" => "yellow"}

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
