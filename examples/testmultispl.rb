$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/lib"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rmultisplit'
require 'rbcurse/rlistbox'
#
## this sample creates a multisplitpane with n objects
##+ and move divider around using - + and =.
#
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
      r = 3; c = 7; ht = 18
      # filler just to see that we are covering correct space and not wasting lines or cols
      filler = "*" * 88
      (ht+2).times(){|i| @form.window.printstring(i,r, filler, $datacolor) }


      @help = "q to quit. v h - + =        : #{$0}                              . Check logger too"
      RubyCurses::Label.new @form, {'text' => @help, "row" => ht+r, "col" => 2, "color" => "yellow"}

      $message = Variable.new
      $message.value = "Message Comes Here"
      message_label = RubyCurses::Label.new @form, {'text_variable' => $message, "name"=>"message_label","row" => ht+r+2, "col" => 1, "display_length" => 60,  "height" => 2, 'color' => 'cyan'}
      $message.update_command() { message_label.repaint } # why ?

      splitp = MultiSplit.new @form do
          name   "mypane" 
          row  r 
          col  c
          width 70
          height ht
          split_count 3
          unlimited true
  #        focusable false
          orientation :VERTICAL_SPLIT
        end
      splitp.bind(:PROPERTY_CHANGE){|e| $message.value = e.to_s }

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      counter = 0
      while((ch = @window.getchar()) != ?q.getbyte(0) )
        str = keycode_tos ch
        case ch
        when ?a.getbyte(0)
          r = 0
        mylist = []
        counter.upto(counter+100) { |v| mylist << "#{v} scrollable data" }
        counter+=100;
        $listdata = Variable.new mylist
        listb = Listbox.new @form do
          name   "mylist" 
          #row  r 
          #col  0 
          #width 40
          #height 11
#         list mylist
          list_variable $listdata
          selection_mode :SINGLE
          #show_selector true
          #row_selected_symbol "[X] "
          #row_unselected_symbol "[ ] "
          title "A long list"
          title_attrib 'reverse'
          #cell_editing_allowed true
        end
        #listb.insert 55, "hello ruby", "so long python", "farewell java", "RIP .Net"
        #$listdata.value.insert 55, "hello ruby", "so long python", "farewell java", "RIP .Net"
        #listb.list_data_model.insert 55, "hello ruby", "so long python", "farewell java", "RIP .Net", "hi lisp", "hi clojure"
        splitp.add listb
        when ?v.getbyte(0)
          splitp.orientation(:VERTICAL_SPLIT)
          splitp.reset_to_preferred_sizes
        when ?h.getbyte(0)
          splitp.orientation(:HORIZONTAL_SPLIT)
          splitp.reset_to_preferred_sizes
        when ?-.getbyte(0)
          splitp.set_divider_location(splitp.divider_location-1)
        when ?+.getbyte(0)
          splitp.set_divider_location(splitp.divider_location+1)
        when ?=.getbyte(0)
          splitp.set_resize_weight(0.50)
        end
        #splitp.get_buffer().wclear
        #splitp << "#{ch} got (#{str})"
        splitp.repaint # since the above keys are not being handled inside
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
