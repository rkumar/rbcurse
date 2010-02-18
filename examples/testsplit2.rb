#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rsplitpane'
#require 'rbcurse/rtestwidget'
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
      r = 3; c = 5; ht = 18; w = 70
      # filler just to see that we are covering correct space and not wasting lines or cols
      filler = "*" * 88
#      (ht+2).times(){|i| @form.window.printstring(i,r, filler, $datacolor) }


      @help = "q to quit. v for vertical split, h - horizontal. -/+/= to resize split. : #{$0}"
      RubyCurses::Label.new @form, {'text' => @help, "row" => ht+r, "col" => 2, "color" => "yellow"}
        splitp = SplitPane.new @form do
          name   "mainpane" 
          row  r 
          col  c
          width w
          height ht
          #focusable false
          #orientation :VERTICAL_SPLIT
          orientation :HORIZONTAL_SPLIT
          #set_resize_weight 0.60
        end
        # note that splitc has no form. so focus has to be managed XXX
        splitc = SplitPane.new nil do
          name   "FC" 
          #row  r 
          #col  c

          ## earlier commented now bombing
          #width w-4 # 30
          #height ht/2-1

          #focusable false
          #orientation :HORIZONTAL_SPLIT
          orientation :VERTICAL_SPLIT
          border_color $promptcolor
          border_attrib Ncurses::A_NORMAL
        end
        splitc2 = SplitPane.new nil do
          name   "2C" 
          #
          ## not present earlier now bombing
          #width w-4
          #height ht/2-1

          orientation :VERTICAL_SPLIT
          border_color $promptcolor
          border_attrib Ncurses::A_REVERSE
        end
        splitp.first_component(splitc)
        splitp.second_component(splitc2)
        splitc.preferred_width w/2
        splitc.preferred_height ht/2-2
        splitc.set_resize_weight 0.50
        splitc2.min_width 15
        splitc2.min_height 5
        splitc.min_width 12
        splitc.min_height 6
        ret = splitp.reset_to_preferred_sizes
        splitp.set_resize_weight(0.50) if ret == :ERROR

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != ?q.getbyte(0) )
        str = keycode_tos ch
        case ch
        when ?v.getbyte(0)
          $log.debug " ORIENTATION VERTICAL"
          splitp.orientation(:VERTICAL_SPLIT)
          splitp.reset_to_preferred_sizes
        when ?h.getbyte(0)
          $log.debug " ORIENTATION HORIZ"
          splitp.orientation(:HORIZONTAL_SPLIT)
          splitp.reset_to_preferred_sizes
        when ?-.getbyte(0)
          $log.debug " KEY PRESS -"
          splitp.set_divider_location(splitp.divider_location-1)
        when ?+.getbyte(0)
          $log.debug " KEY PRESS +"
          splitp.set_divider_location(splitp.divider_location+1)
        when ?=.getbyte(0)
          $log.debug " KEY PRESS ="
          splitp.set_resize_weight(0.50)
        end
        #splitp.get_buffer().wclear
        #splitp << "#{ch} got (#{str})"
#        splitp.repaint
#        splitp.buffer_to_screen
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
