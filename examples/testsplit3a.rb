#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
#*******************************************************#
#                     testsplit3a.rb                    #
#                 written by Rahul Kumar                #
#                    January 16, 2010                   #
#                                                       #
#  Test textview, split and textarea inside splitpane   #
#  This wraps a textview inside a scrollpane, and       #
#  puts the SCRP inside a SPLP                          #
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
          name   "splitleft-outer" 
          
          #width w/3 # 30
          #height ht-0 #/2-1

          orientation :HORIZONTAL_SPLIT
          border_color $promptcolor
          border_attrib Ncurses::A_NORMAL
        end
        taoutrt = TextArea.new nil do
          name   "myTextArea-outrt" 
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
        #  taoutrt.show_caret=true

        tvleft1 = TextView.new nil do
          name   "myviewleft1" 
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
          tvleft1.show_caret=true
        content = File.open("../README.markdown","r").readlines
        tvleft1.set_content content #, :WRAP_WORD

        # to see lower border i need to set height to ht/2 -2 in both cases, but that
        # crashes ruby when i reduce height by 1.
        tvleft2 = TextView.new nil do
          name   "myviewleft2" 
          #row 0
          #col  0 
          width w/2-1
          #height ht
          height (ht/2)-1
          title "NOTES"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
        end
          tvleft2.show_caret=true
        content = File.open("../NOTES","r").readlines
        tvleft2.set_content content #, :WRAP_WORD

        leftscroll1 = ScrollPane.new nil do
          name   "myScrollLeftTop" 
        end
        leftscroll2 = ScrollPane.new nil do
          name   "myScrollLeftBot" 
        end
        scroutrt = ScrollPane.new nil do
          name   "myScroll3-outer-right" 
          #width 46
        end
        leftscroll1.cascade_changes = true
        leftscroll2.cascade_changes = true
        #leftscroll1.preferred_width w/2 #/2  ## should pertain more to horizontal orientation
        leftscroll1.preferred_height (ht/2)-4 ## this messes things up when we change orientation
        # the outer compo needs child set first else cursor does not reach up from
        # lower levels. Is the connection broken ?
        outer.first_component(splitleft)
        outer.second_component(scroutrt)
        #leftscroll2.preferred_height ht/2-2
        scroutrt.child(taoutrt)
        splitleft.first_component(leftscroll1)
        leftscroll1.child(tvleft1)
        splitleft.second_component(leftscroll2)
        leftscroll2.child(tvleft2)
        #tvleft1.preferred_width w/2 #/2  ## should pertain more to horizontal orientation
        #tvleft1.preferred_height (ht/2)-1 ## this messes things up when we change orientation
        #tvleft1.set_resize_weight 0.50
        ret = splitleft.reset_to_preferred_sizes
        splitleft.set_resize_weight(0.50) if ret == :ERROR

        splitleft.preferred_width w/2 #w/3
        splitleft.preferred_height ht/2-2
        #splitleft.set_resize_weight 0.50
        #taoutrt.min_width 10
        #taoutrt.min_height 5
        #splitleft.min_width 12
        #splitleft.min_height 6
        ret = outer.reset_to_preferred_sizes
        outer.set_resize_weight(0.50) if ret == :ERROR

        File.open("../README.markdown","r") do |file|
           while (line = file.gets)
              taoutrt << line.chomp
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
