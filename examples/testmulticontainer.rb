## 
#  This tests both multicontainer and container
#
require 'rubygems'
require 'logger'
require 'rbcurse'
require 'rbcurse/rmulticontainer'
require 'rbcurse/rcontainer'
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new((File.join(ENV["LOGDIR"] || "./" ,"rbc13.log")))
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
        title "Multicontainer"
      end
      ctr = 1

      c1 = Container.new 
      mc.add c1, "A form"
      f1 = Field.new do
        name "name"
        text "rahul"
        row 1
        col 10
      end
      f2 = Field.new nil, :name => "email", :text => "me@somebody.com", :row => 2, :col => 10
      c1.add( f1, f2)

      c2 = Container.new 
      mc.add c2, "Another form"
      f3 = Field.new do
        name "language"
        text "ruby"
        row 1
        col 10
      end
      f4 = Field.new nil, :name => "version", :text => "1.9.2", :row => 2, :col => 10
      c2.add( f3, f4)
      @help = "F10 to quit. M-a to open new component. M-: for menu  #{$0} "
      RubyCurses::Label.new @form, {'text' => @help, "row" => 21, "col" => 2, "color" => "yellow"}

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != KEY_F10 )
        break if ch == ?\C-q.getbyte(0)
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
