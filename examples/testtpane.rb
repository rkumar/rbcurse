#*******************************************************#
#                      testtpane.rb                     #
#                 written by Rahul Kumar                #
#                    January 20, 2010                   #
#                                                       #
#     testing tabbedpane with textarea, view, listbox   #
#                                                       #
#            Released under ruby license. See           #
#         http://www.ruby-lang.org/en/LICENSE.txt       #
#               Copyright 2010, Rahul Kumar             #
#*******************************************************#

# this is a test program, tests out tabbed panes. type F1 to exit
#
#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rtabbedpane'
require 'rbcurse/rtextview'
require 'rbcurse/rtextarea'

class TestTabbedPane
  def initialize
    acolor = $reversecolor
  end
  def run
    $config_hash ||= Variable.new Hash.new
    @window = VER::Window.root_window
    @form = Form.new @window
    r = 1; c = 1;
    h = 20; w = 70
      @tp = RubyCurses::TabbedPane.new @form  do
        height h
        width  w
        row 2
        col 8
        #button_type :ok
      end
      @tab1 = @tp.add_tab "&TextView" 
      f1 = @tab1.form

        textview = TextView.new f1 do
          name   "myView" 
          row 4
          col 2 
          width w-5
          height h-5
          title "README.mrku"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
          #should_create_buffer true
        end
        content = File.open("../README.markdown","r").readlines
        textview.set_content content #, :WRAP_WORD
        textview.show_caret = true



      @tab2 = @tp.add_tab "&Settings"
      f2 = @tab2.form
      r = 4
        texta = TextArea.new f2 do
          name   "myText" 
          row r
          col 2 
          width w-5
          height h-5
          title "EditMe.txt"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
          #should_create_buffer true
        end
        texta << "I expect to pass through this world but once." << "Any good therefore that I can do, or any kindness or abilities that I can show to any fellow creature, let me do it now."
        texta << "Let me not defer it or neglect it, for I shall not pass this way again."
        texta << " "
        texta << "q to exit."
        texta << "Some more text going below scrollpane.. "
        texta << "Love all creatures for they are none but yourself."
        #texta.show_caret = true # since the cursor is not showing correctly, show internal one.

      @tab3 = @tp.add_tab "&Editors"
      f3 = @tab3.form
      butts = %w[ &Vim E&macs &Jed E&lvis ]
      bcodes = %w[ VIM EMACS JED ELVIS]
      row = 4
      butts.each_with_index do |name, i|
        RubyCurses::CheckBox.new f3 do
          text name
          variable $config_hash
          name bcodes[i]
          row row+i
          col 5
        end
      end
      @help = "F1 to quit. Use any key of key combination to see what's caught. #{$0} Check logger too"
            RubyCurses::Label.new @form, {'text' => @help, "row" => r+h+2, "col" => 2, "color" => "yellow"}
      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != KEY_F1 )
       # @tp.repaint
        @form.handle_key(ch)
        @window.wrefresh
      end
      #@tp.show
      #@tp.handle_keys
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
