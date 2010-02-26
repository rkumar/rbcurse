#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rsplitpane'
#require 'rbcurse/rtestwidget'
#
## this sample creates a single scrollpane, and allows you to change orientation
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

      splitp = SplitPane.new @form do
          name   "mypane" 
          row  r 
          col  c
          width 70
          height ht
  #        focusable false
          #orientation :VERTICAL_SPLIT
        end
      splitp.bind(:PROPERTY_CHANGE){|e| $message.value = e.to_s }

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != ?q.getbyte(0) )
        str = keycode_tos ch
        case ch
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
