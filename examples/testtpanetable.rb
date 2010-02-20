#*******************************************************#
#                   testtpanetable.rb                   #
#                 written by Rahul Kumar                #
#                    January 29, 2010                   #
#                                                       #
#     testing tabbedpane with table                     #
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
require 'rbcurse/rtable'
require 'rbcurse/rscrollpane'

class TestTabbedPane
  def initialize
    acolor = $reversecolor
  end
  def run
    $config_hash ||= Variable.new Hash.new
    @window = VER::Window.root_window
    @form = Form.new @window
    $log.debug " MAIN FORM #{@form} "
    r = 1; c = 1;
    h = 20; w = 70
      @tp = RubyCurses::TabbedPane.new @form  do
        height h
        width  w
        row 2
        col 8
        #button_type :ok
      end
      @tab1 = @tp.add_tab "&Table" 
      f1 = @tab1.form
      $log.debug " TABLE FORM #{f1} "

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

        atable = Table.new f1 do
          name   "mytable" 
          row  4 
          col  0
          width 78
          height 15
          #title "A Table"
          #title_attrib (Ncurses::A_REVERSE | Ncurses::A_BOLD)
          cell_editing_allowed true
          editing_policy :EDITING_AUTO
          set_data data, colnames
        end
        sel_col = Variable.new 0
        sel_col.value = 0
        tcm = atable.get_table_column_model
        selcolname = atable.get_column_name sel_col.value
        #
        ## key bindings fo atable
        # column widths 
          tcm.column(0).width 24
          tcm.column(1).width 5
          tcm.column(2).width 18
          #tcm.column(2).editable false
          tcm.column(3).width 7
          tcm.column(4).width 5
          tcm.column(5).width 8
        atable.configure() do
          bind_key(330) { atable.remove_column(tcm.column(atable.focussed_col)) rescue ""  }
          bind_key(?+) {
            acolumn = atable.get_column selcolname
            w = acolumn.width + 1
            acolumn.width w
            #atable.table_structure_changed
          }
          bind_key(?-) {
            acolumn = atable.get_column selcolname
            w = acolumn.width - 1
            if w > 3
            acolumn.width w
            #atable.table_structure_changed
            end
          }
          bind_key(?>) {
            colcount = tcm.column_count-1
            #atable.move_column sel_col.value, sel_col.value+1 unless sel_col.value == colcount
            col = atable.focussed_col
            atable.move_column col, col+1 unless col == colcount
          }
          bind_key(?<) {
            col = atable.focussed_col
            atable.move_column col, col-1 unless col == 0
            #atable.move_column sel_col.value, sel_col.value-1 unless sel_col.value == 0
          }
          #bind_key(KEY_RIGHT) { sel_col.value = sel_col.value+1; current_column sel_col.value}
          #bind_key(KEY_LEFT) { sel_col.value = sel_col.value-1;current_column sel_col.value}
        end

      @tab2 = @tp.add_tab "&ScrollTable" 
      f2 = @tab2.form
        scroll = ScrollPane.new f2 do
          name   "myScroller" 
          row 4
          col  0 
          width w-2
          height h-2
        end

      $log.debug " TABLE FORM 2  #{f2} "
        btable = Table.new nil do
          name   "mytab2" 
          row  0 
          col  0
          width 78
          height 15
          #title "A Table"
          #title_attrib (Ncurses::A_REVERSE | Ncurses::A_BOLD)
          cell_editing_allowed true
          editing_policy :EDITING_AUTO
          set_data data, colnames
        end
        sel_col = Variable.new 0
        sel_col.value = 0
        tcm = btable.get_table_column_model
        selcolname = btable.get_column_name sel_col.value
        #
        ## key bindings fo atable
        # column widths 
          tcm.column(0).width 24
          tcm.column(1).width 5
          tcm.column(2).width 18
          #tcm.column(2).editable false
          tcm.column(3).width 7
          tcm.column(4).width 5
          tcm.column(5).width 8
        scroll.child(btable)
 
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
