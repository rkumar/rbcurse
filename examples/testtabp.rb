# this is a test program, tests out tabbed panes. type F1 to exit
#
#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
#require 'rbcurse/rtabbedpane'
require 'rbcurse/rtabbedwindow'

class TestTabbedPane
  def initialize
    acolor = $reversecolor
    #$config_hash ||= {}
  end
  def run
    $config_hash ||= Variable.new Hash.new
    #configvar.update_command(){ |v| $config_hash[v.source()] = v.value }
      @tp = RubyCurses::TabbedWindow.new nil  do
        height 12
        width  50
        row 5
        col 10
        button_type :ok
      end
      @tab1 = @tp.add_tab "&Language" 
      f1 = @tab1.form
      #$radio = Variable.new
      radio1 = RadioButton.new f1 do
        #variable $radio
        variable $config_hash
        name "radio1"
        text "ruby"
        value "ruby"
        color "red"
        row 4
        col 2
      end
      radio2 = RadioButton.new f1 do
        #variable $radio
        variable $config_hash
        name "radio1"
        text  "jruby"
        value  "jruby"
        color "green"
        row 5
        col 2
      end
      radio3 = RadioButton.new f1 do
        #variable $radio
        variable $config_hash
        name "radio1"
        text  "macruby"
        value  "macruby"
        color "cyan"
        row 6
        col 2
      end
      @tab2 = @tp.add_tab "&Settings"
      f2 = @tab2.form
      r = 3
      butts = [ "Use &HTTP/1.0", "Use &frames", "&Use SSL" ]
      bcodes = %w[ HTTP, FRAMES, SSL ]
      butts.each_with_index do |t, i|
        RubyCurses::CheckBox.new f2 do
          text butts[i]
          variable $config_hash
          name bcodes[i]
          row r+i
          col 4
        end
      end
      @tab3 = @tp.add_tab "&Editors"
      f3 = @tab3.form
      butts = %w[ &Vim E&macs &Jed &Other ]
      bcodes = %w[ VIM EMACS JED OTHER]
      row = 3
      butts.each_with_index do |name, i|
        RubyCurses::CheckBox.new f3 do
          text name
          variable $config_hash
          name bcodes[i]
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
    n.run
  rescue => ex
  ensure
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
