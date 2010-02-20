#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
#*******************************************************#
#                     testsplit3b.rb                    #
#                 written by Rahul Kumar                #
#                    January 17, 2010                   #
#                                                       #
#  Test textview, split and textarea inside splitpane   #
#  This wraps a textview inside a scrollpane, and       #
#  puts the SCRP inside a SPLP                          #
#  Adds a listbox to the menagerie of objects.          #
#
#  /----+---------------\
#  |   V|              V|
#  | 1 V|              V|
#  | >>V|              V|
#  +----+       3      V|
#  |   V|              V|
#  | 2 V|              V|
#  |>>>V|>>>>>>         |
#  \----+---------------/
# 
#
#
#            Released under ruby license. See           #
#         http://www.ruby-lang.org/en/LICENSE.txt       #
#               Copyright 2010, Rahul Kumar             #
#*******************************************************#
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rsplitpane'
require 'rbcurse/rscrollpane'
require 'rbcurse/rtextarea'
require 'rbcurse/rtextview'
require 'rbcurse/rlistbox'
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new("v#{$0}.log")
    $log.level = Logger::DEBUG
    show_caret_flag = false #true

    @window = VER::Window.root_window

    catch(:close) do
      colors = Ncurses.COLORS
      @form = Form.new @window
      $log.debug " MAIN FORM #{@form}  "
      r = 1; c = 3; ht = 18; w = 70
      r = 3; c = 7; ht = 24; w = 100


      @help = "F1 to quit. To resize split: M-, M+, M=. TAB, M-w, M-n, M-p, M-l, M-h, C-n/p  : #{$0}"
      RubyCurses::Label.new @form, {'text' => @help, "row" => ht+r, "col" => 2, "color" => "yellow"}

        outer = SplitPane.new @form do
          name   "mainpane" 
          row  r 
          col  c
          width w
          height ht
          orientation :VERTICAL_SPLIT
        end
        # note that splitleft has no form. so focus has to be managed XXX
        splitleft = SplitPane.new nil do
          name   "splitleft" 
          
          #width w/3 # 30
          #height ht-0 #/2-1

          orientation :HORIZONTAL_SPLIT
          border_color $promptcolor
          border_attrib Ncurses::A_NORMAL
        end
        ta1 = TextArea.new nil do
          name   "myTextArea" 
          #row 0
          #col  0 
          width w # this is ofcourse large, full width
          #height (ht/2)-1
          height ht
          title "README.md"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
        end
        ta1.show_caret = show_caret_flag

        t1 = TextView.new nil do
          name   "myView" 
          #row 0
          #col  0 
          #width w-2
          height ht
          #height (ht/2)-1
          width w/2-1
          title "README.md"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
        end
        t1.show_caret = show_caret_flag
        content = File.open("../README.markdown","r").readlines
        t1.set_content content #, :WRAP_WORD

        mylist = []
        0.upto(50) { |v| mylist << "#{v} scrollable data" }
        $listdata = Variable.new mylist
        listb = Listbox.new nil do
          name   "mylist" 
          row 0
          col  0 
          width w/2
          height ht/2+5
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
        listb.list_data_model.insert 25, "hello ruby", "so long python", "farewell java", "RIP .Net", "hi lisp", "hi cloJure", "git Go"
        # to see lower border i need to set height to ht/2 -2 in both cases, but that
        # crashes ruby when i reduce height by 1.
        #t2 = TextView.new nil do
          #name   "myView2" 
          ##row 0
          ##col  0 
          #width w/2-1
          ##height ht
          #height (ht/2)-1
          #title "NOTES"
          #title_attrib 'bold'
          #print_footer true
          #footer_attrib 'bold'
        #end
        #content = File.open("../NOTES","r").readlines
        #t2.set_content content #, :WRAP_WORD

        scroll1 = ScrollPane.new nil do
          name   "myScroll1" 
        end
        scroll2 = ScrollPane.new nil do
          name   "myScroll2" 
        end
        scroll3 = ScrollPane.new nil do
          name   "myScroll3" 
          #width 46
        end
        #scroll1.preferred_width w/2 #/2  ## should pertain more to horizontal orientation
        scroll1.preferred_height (ht/2)-4 ## this messes things up when we change orientation
        # the outer compo needs child set first else cursor does not reach up from
        # lower levels. Is the connection broken ?
        outer.first_component(splitleft)
        outer.second_component(scroll3)
        #scroll2.preferred_height ht/2-2
        scroll3.child(ta1)
        splitleft.first_component(scroll1)
        scroll1.child(t1)
        splitleft.second_component(scroll2)
        scroll2.child(listb)
        #scroll2.cascade_changes = true
        #t1.preferred_width w/2 #/2  ## should pertain more to horizontal orientation
        #t1.preferred_height (ht/2)-1 ## this messes things up when we change orientation
        #t1.set_resize_weight 0.50
        ret = splitleft.reset_to_preferred_sizes
        splitleft.set_resize_weight(0.50) if ret == :ERROR

        splitleft.preferred_width w/2 #w/3
        splitleft.preferred_height ht/2-2
        #splitleft.set_resize_weight 0.50
        #ta1.min_width 10
        #ta1.min_height 5
        #splitleft.min_width 12
        #splitleft.min_height 6
        ret = outer.reset_to_preferred_sizes
        outer.set_resize_weight(0.50) if ret == :ERROR

        File.open("../README.markdown","r") do |file|
           while (line = file.gets)
              ta1 << line.chomp
           end
        end

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != KEY_F1 )
        str = keycode_tos ch
        case ch
        #when ?v.getbyte(0)
          #$log.debug " ORIENTATION VERTICAL"
          #outer.orientation(:VERTICAL_SPLIT)
          #outer.reset_to_preferred_sizes
        #when ?h.getbyte(0)
          #$log.debug " ORIENTATION HORIZ"
          #outer.orientation(:HORIZONTAL_SPLIT)
          #outer.reset_to_preferred_sizes
        when ?-.getbyte(0)
          $log.debug " KEY PRESS -"
          outer.set_divider_location(outer.divider_location-1)
        when ?+.getbyte(0)
          $log.debug " KEY PRESS +"
          outer.set_divider_location(outer.divider_location+1)
        when ?=.getbyte(0)
          $log.debug " KEY PRESS ="
          outer.set_resize_weight(0.50)
        end
        #outer.get_buffer().wclear
        #outer << "#{ch} got (#{str})"
#        outer.repaint
#        outer.buffer_to_screen
        @form.repaint
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
