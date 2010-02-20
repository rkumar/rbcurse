#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
#*******************************************************#
#                     testsplittv.rb                    #
#                 written by Rahul Kumar                #
#                    January 06, 2010                   #
#                                                       #
#             test textview inside splitpane            #
#             Startup is vertical split                 # 
#                                                       #
#            Released under ruby license. See           #
#         http://www.ruby-lang.org/en/LICENSE.txt       #
#               Copyright 2010, Rahul Kumar             #
#*******************************************************#
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rsplitpane'
require 'rbcurse/rtextview'

## This sample creates a single scrollpane, 
##+ and embeds a textarea inside it
##+ and allows you to change orientation
##+ and move divider around using - + and =.
#
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
      r = 1; c = 3; ht = 24; w = 70
      # filler just to see that we are covering correct space and not wasting lines or cols
#      filler = "*" * 88
#      (ht+2).times(){|i| @form.window.printstring(i,r, filler, $datacolor) }


      @help = "q to quit. - + = v h   C-n   C-p   M-w (alt-w)  : #{$0}                 . Check #{$0}.log too"
      RubyCurses::Label.new @form, {'text' => @help, "row" => ht+r, "col" => 2, "color" => "yellow"}

      splitp = SplitPane.new @form do
          name   "mypane" 
          row  r 
          col  c
          width w
          height ht
          #focusable false
          orientation :VERTICAL_SPLIT
        end
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
        content = File.open("../README.markdown","r").readlines
        t1.set_content content #, :WRAP_WORD

        # to see lower border i need to set height to ht/2 -2 in both cases, but that
        # crashes ruby when i reduce height by 1.
        t2 = TextView.new nil do
          name   "myView2" 
          #row 0
          #col  0 
          width w/2-1
          height ht
          #height (ht/2)-1
          title "NOTES"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
        end
        content = File.open("../NOTES","r").readlines
        t2.set_content content #, :WRAP_WORD

        splitp.first_component(t1)
        splitp.second_component(t2)
        t1.preferred_width w/2 #/2  ## should pertain more to horizontal orientation
        #t1.preferred_height (ht/2)-1 ## this messes things up when we change orientation
        t1.preferred_height ht ## this messes things up when we change orientation
        #t1.set_resize_weight 0.50
        t2.min_width 15
        t2.min_height 5
        t1.min_width 12
        t1.min_height 8
        ret = splitp.reset_to_preferred_sizes
        splitp.set_resize_weight(0.50) if ret == :ERROR

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != ?q.getbyte(0) )
        str = keycode_tos ch
        case ch
        when ?v.getbyte(0)
          splitp.orientation(:VERTICAL_SPLIT)
          splitp.set_resize_weight(0.50)
        when ?h.getbyte(0)
          splitp.orientation(:HORIZONTAL_SPLIT)
          splitp.set_resize_weight(0.50)
        when ?-.getbyte(0)
          ret = splitp.set_divider_location(splitp.divider_location-1)
          next if ret == :ERROR
        when ?+.getbyte(0)
          ret = splitp.set_divider_location(splitp.divider_location+1)
          next if ret == :ERROR
        when ?=.getbyte(0)
          splitp.set_resize_weight(0.50)
        end
        #splitp.get_buffer().wclear
        #splitp << "#{ch} got (#{str})"
        #splitp.repaint
        #splitp.buffer_to_screen
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
