#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
##*******************************************************#
#                     testsplittv.rb                    #
#                 written by Rahul Kumar                #
#                    January 06, 2010                   #
#                                                       #
#             test textview inside scrollpane           #
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
require 'rbcurse/rtextarea'
require 'rbcurse/rmultitextview'
require 'rbcurse/undomanager'

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
      $log.debug " FORM #{@form} "
      r = 1; c = 7; ht = 20; w = 50
      #r = 1; c = 3; ht = 24; w = 70
      # filler just to see that we are covering correct space and not wasting lines or cols
#      filler = "*" * 88
#      (ht+2).times(){|i| @form.window.printstring(i,r, filler, $datacolor) }


      @help = "F1 to quit. M- M+ M= v h   C-n   C-p   M-w (alt-w)  : #{$0}      . Check #{$0}.log too"
      RubyCurses::Label.new @form, {'text' => @help, "row" => ht+r, "col" => 2, "color" => "yellow"}

      splitp = SplitPane.new @form do
          name   "mypane" 
          row  r 
          col  c
          width w
          height ht
          #focusable false
          #orientation :VERTICAL_SPLIT
        end

      ## typically height should be ht or at least more than ht/2, but i've kept it at
      ## ht/2-1 to see the footer, and because it was crashing with this.
        t1 = TextArea.new do
          name   "myView" 
          #row 0
          #col  0 
          width w-2
          height (ht/2)-1
          title "README.md"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
        end

        t2 = TextArea.new do
          name   "myView2" 
          #row 0
          #col  0 
          width w-2
          height ht/2
          #height (ht/2)-1
          title "NOTES"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
        end

        splitp.first_component(t1)
        splitp.second_component(t2)
        t1.preferred_width w-4 #/2  ## should pertain more to horizontal orientation
        t1.preferred_height (ht/2)-1 ## this messes things up when we change orientation
        #t1.set_resize_weight 0.50
        t2.min_width 15
        t2.min_height 5
        t1.min_width 12
        t1.min_height 5
        ret = splitp.reset_to_preferred_sizes
        ## if an error is returned you should check what's wrong since you
        ## could still get a blank screen, if your comps area is smaller than 
        ## pane, or other conditions. the log will point out various possible errors.
        splitp.set_resize_weight(0.50) if ret == :ERROR
        File.open("../README.markdown","r") do |file|
           while (line = file.gets)
              t1 << line.chomp
           end
        end
        File.open("../NOTES","r") do |file|
           while (line = file.gets)
              t2 << line.chomp
           end
        end
        undom = SimpleUndo.new t1
        undo2 = SimpleUndo.new t2

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != KEY_F1 )
        #str = keycode_tos ch
        case ch
        when ?\M-v.getbyte(0)
          splitp.orientation(:VERTICAL_SPLIT)
          splitp.set_resize_weight(0.50)
        when ?\M-h.getbyte(0)
          splitp.orientation(:HORIZONTAL_SPLIT)
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
