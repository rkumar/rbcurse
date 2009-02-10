#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
#require 'lib/ver/keyboard'
require 'rbcurse'
require 'rbcurse/rtextarea'
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
      @help = "q to quit. Use any key of key combination to see what's caught. Check logger too"
      RubyCurses::Label.new @form, {'text' => @help, "row" => 21, "col" => 2, "color" => "yellow"}

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != ?q )
        str = keycode_tos ch
        texta << "#{ch} got (#{str})"
        texta.repaint
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
