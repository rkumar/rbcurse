#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rtextarea'
#require 'rbcurse/oldrtextarea'
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
      $log.debug "START #{colors} colors  ---------"
      @form = Form.new @window
      r = 1; c = 30;

        texta = TextArea.new @form do
          name   "mytext" 
          row  r 
          col  c
          width 60
          height 15
          editable false
          focusable false
          title "Keypresses"
          auto_scroll true
          title_attrib (Ncurses::A_REVERSE | Ncurses::A_BOLD)
        end
      @help = "q to quit. Use any key of key combination to see what's caught.: #{$0} Check logger too"
      RubyCurses::Label.new @form, {'text' => @help, "row" => 21, "col" => 2, "color" => "yellow"}

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != ?q.getbyte(0) )
        str = keycode_tos ch
        $log.debug  "#{ch} got (#{str})"
        texta << "#{ch} got (#{str})"
        texta.repaint
        # 2010-01-01 16:00 not much point calling handle_key since textarea is not editable
        # and will return unhandled and thus NOT do a repaint. so we have to repaint anyway.
        #ret = @form.handle_key(ch)
        #$log.debug " form handlekey returned: #{ret} "
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
