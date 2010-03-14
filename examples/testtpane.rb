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
# position cursor in button form and press M-x to add a few tabs
# M-l in button form will scroll. M-h to scroll left.
# dd to kill a tab, u to undo kill, or p/P to paste deleted tab
#
#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rtabbedpane'
require 'rbcurse/rtextview'
require 'rbcurse/rtextarea'
require 'rbcurse/rtable'

class TestTabbedPane
  def initialize
    acolor = $reversecolor
    @tctr = 0
  end
  def run
    $config_hash ||= Variable.new Hash.new
    @window = VER::Window.root_window
    @form = Form.new @window
    @form.name = "MainForm"
    r = 4; c = 7;
    h = 20; w = 70
      @tp = RubyCurses::TabbedPane.new @form  do
        name "MainPane"
        height h
        width  w
        row 2
        col 8
        #button_type :ok
      end

        textview = TextView.new do
          name   "myView" 
          row 4
          col 0 
          #width w-0
          #height h-4
          title "README.mrku"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
        end
        content = File.open("../README.markdown","r").readlines
        textview.set_content content #, :WRAP_WORD
        #textview.show_caret = true

      @tab1 = @tp.add_tab "&TextView", textview
      #@tabl.add_component textview
      #f1 = @tab1.form
        


      #f2 = @tab2.form
      r = 4
        texta = TextArea.new do
          name   "myText" 
          #row r
          #col 2 
          #width w-5
          #height h-5
          title "EditMe.txt"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
        end
        @tab2 = @tp.add_tab "&Settings", texta

        texta << "I expect to pass through this world but once." << "Any good therefore that I can do, or any kindness or abilities that I can show to any fellow creature, let me do it now."
        texta << "Let me not defer it or neglect it, for I shall not pass this way again."
        texta << " "
        texta << "q to exit."
        texta << "Some more text going below scrollpane.. "
        texta << "Love all creatures for they are none but yourself."
        #texta.show_caret = true # since the cursor is not showing correctly, show internal one.

      @tab3 = @tp.add_tab "&Editors"
      #f3 = @tab3.form
      f3 = @tp.form @tab3
      butts = %w[ &Vim E&macs &Jed E&lvis ]
      bcodes = %w[ VIM EMACS JED ELVIS]
      row = 2
      butts.each_with_index do |name, i|
        RubyCurses::CheckBox.new f3 do
          text name
          variable $config_hash
          name bcodes[i]
          row row+i
          col 5
        end
      end
      tab3 = @tp.add_tab "S&ongs"
      #f3 = tab3.form
      #f3 = @tp.form tab3
      data = [["Pathetique",3,"Tchaikovsky",3.21, true, "WIP"],
        ["Ali Maula Ali Maula",3,"NFAK",3.47, true, "WIP"],
        ["Tera Hijr Mera Nasib",92,"Razia Sultan",412, true, "Fin"],
        ["Piano Concerto 4&5",4,"Beethoven",110.0, false, "Cancel"],
        ["Toccata and Fugue",4,"J S Bach",102.72, false, "Postp"],
        ["Symphony No. 3",4,"Henryk Gorecki",102.72, true, "Postp"],
        ["The Great Gig in the Sky",8,"Pink Floyd",12.72, false, "Todo"],
        ["Steppes of Central Asia",9,"Borodin",12.2, false, "WIP"],
        ["Wish You Were Here",8,"Pink Floyd",2.7, false, "Todo"],
        ["Habanera",nil,"Maria Callas",112.7, true, "Cancel"],
        ["Mack the Knife",9,"Loius Armstrong",12.2, false, "Todo"],
        ["Prince Igor",9,"Borodin",16.3, false, "WIP"],
        ["Shahbaaz Qalandar",9,"Nusrat Fateh Ali Khan",12.2, false, "Todo"],
        ["Raag Darbari",9,"Ustad Fateh Ali Khan",12.2, false, "Todo"],
        ["Yaad-e-Mustafa Aisi",9,"Santoo Khan",12.2, true, "Todo"],
        ["Chaconne",4,"Johann S Bach",12.42, true, "Postp"],
        ["Raag Jaunpuri",9,"Ustad Fateh Ali Khan",12.2, false, "Todo"],
        ["Dalaleragita",9,"Vaishnava",12.2, false, "Todo"],
        ["Prasada sevaya",9,"Vaishnava",12.2, false, "Todo"],
        ["Sri Rupamanjiri",9,"Vaishnava",12.2, false, "Todo"],
        ["M Vlast ",9,"Smetana",12.2, false, "Todo"],
        ["Jai Radha Madhava",163,"Jagjit Singh",5.4, false, "WIP"]]
      colnames = %w[ Song Cat Artist Ratio Flag Status]
      statuses = ["Todo", "WIP", "Fin", "Cancel", "Postp"]

      row = 1
      # when adding as a component it is best not to specify row and col
      # We can skip sizing too for large components, so comp will fill the TP.
        atable = Table.new do
          name   "mytable" 
          #row  row 
          #col  0
          #width 76
          #height h - 4
          #title "A Table"
          #title_attrib (Ncurses::A_REVERSE | Ncurses::A_BOLD)
          cell_editing_allowed true
          editing_policy :EDITING_AUTO
          set_data data, colnames
        end
        tab3.component = atable
        sel_col = Variable.new 0
        sel_col.value = 0
        tcm = atable.get_table_column_model
        selcolname = atable.get_column_name sel_col.value
          tcm.column(0).width 24
          tcm.column(1).width 3
          tcm.column(2).width 18
          #tcm.column(2).editable false
          tcm.column(3).width 7
          tcm.column(4).width 5
          tcm.column(5).width 6
      @help = "F1 to quit. M-s M-t M-e M-o, TAB, M-x to add tab  #{$0} Check logger too"
            RubyCurses::Label.new @form, {'text' => @help, "row" => r+h+2, "col" => 2, "color" => "yellow"}

            # M-x when inside the buttons form will create a new tab
            @form.bind_key(?\M-x) {
              textv = TextView.new 
              t = @tp.add_tab "Text#{@tctr}", textv
              textv.set_content content
              @tctr += 1
            }
      @form.repaint
      $catch_alt_digits = false # we want to use Alt-1, 2 for tabs.
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
