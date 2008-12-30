# this is a test program, tests out tabbed panes. type F1 to exit
#
$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'lib/ver/ncurses'
require 'lib/ver/window'
require 'lib/rbcurse/rwidget'
require 'lib/rbcurse/rtabbedpane'

class TestTabbedPane
  def initialize
    @layout = { :height => 12, :width => 50, :top => 5, :left => 10 }
    @window = VER::Window.new(@layout)
    begin
      main
    ensure
      @window.destroy unless @window.nil?
    end
  end
  def main
      @tp = RubyCurses::TabbedPane.new @window do
        height 12
        width  50
        row 5
        col 10
      end
      @tab1 = @tp.add_tab "&Language" 
      f1 = @tab1.form
      $radio = Variable.new
      radio1 = RadioButton.new f1 do
        text_variable $radio
        text "ruby"
        value "ruby"
        color "red"
        row 4
        col 2
      end
      radio2 = RadioButton.new f1 do
        text_variable $radio
        text  "jruby"
        value  "jruby"
        color "green"
        row 5
        col 2
      end
      radio3 = RadioButton.new f1 do
        text_variable $radio
        text  "macruby"
        value  "macruby"
        color "cyan"
        row 6
        col 2
      end
      @tab2 = @tp.add_tab "&Settings"
      f2 = @tab2.form
      checkbutton = RubyCurses::CheckBox.new f2 do
        text "Use &HTTP/1.0"
        row 3
        col 4
      end
      checkbutton = RubyCurses::CheckBox.new f2 do
        text "Use &frames"
        row 5
        col 4
      end
      checkbutton = RubyCurses::CheckBox.new f2 do
        text "&Use SSL"
        row 6
        col 4
      end
      @tab3 = @tp.add_tab "&Editors"
      f3 = @tab3.form
      butts = %w[ &Vim E&macs &Jed &Other ]
      row = 3
      butts.each do |name|
        RubyCurses::CheckBox.new f3 do
          text name
          row row
          col 4
        end
        row +=1
      end
      @tp.show
      @tp.handle_keys
  end
end
if $0 == __FILE__
  # Initialize curses
  begin
    # XXX update with new color and kb
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG
    n = TestTabbedPane.new
  rescue => ex
  ensure
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
