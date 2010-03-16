#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rmulticontainer'
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
      $log.debug "START #{colors} colors  --------- testmulticomp"
      @form = Form.new @window
      @ctr = 1
      r = 1; c = 30;

      mc = MultiContainer.new @form  do
        name "multic"
        row  r 
        col  c
        width 60
        height 15
        title "Multiconty"
      end
      ctr = 1

      @form.bind_key(?\M-a) do
        $log.debug " Inside M-a MULTI "
        texta = TextArea.new do
          name  "mytext#{ctr}" 
          title "Enter Something-#{ctr}"
          title_attrib (Ncurses::A_REVERSE | Ncurses::A_BOLD)
        end
        mc.add texta, "Enter Something #{ctr}"
        texta << "Hello World"
        texta << "Hello World"
        ctr += 1
      end
      @help = "F1 to quit. M-a to open new component. M-: for menu  #{$0} "
      RubyCurses::Label.new @form, {'text' => @help, "row" => 21, "col" => 2, "color" => "yellow"}

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != KEY_F1 )
        str = keycode_tos ch
        $log.debug  "#{ch} got (#{str})"
        @form.handle_key ch
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
