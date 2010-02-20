#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
#*******************************************************#
#                     testsrolltable.rb                 #
#                 written by Rahul Kumar                #
#                    January 18, 2010                   #
#                                                       #
#  Test table inside a scrollpane.                      #
#  The table here has minimal functionality. Pls refer  #
#  testtable.rb for more complete functionality.        #
#
#  /----+----+----+-----\
#  |____|____|____|_____|
#  |    |    |    |    V|
#  |    |    |    |    V|
#  +    |    |    |    V|
#  |    |    |    |    V|
#  |    |    |    |    V|
#  |>>>>>>>>>>>   |     |
#  \----+----+----+-----/
#  http://totalrecall.files.wordpress.com/2010/01/rbcurse-tablescrollpane.png
#
#
#            Released under ruby license. See           #
#         http://www.ruby-lang.org/en/LICENSE.txt       #
#               Copyright 2010, Rahul Kumar             #
#*******************************************************#
# Creates a scrollpane with a Table 
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rtable'
require 'rbcurse/rscrollpane'
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
#    file = File.open("v#{$0}.log", File::WRONLY | File::APPEND | File::CREAT)
    $log = Logger.new("v#{$0}.log")
    $log.level = Logger::DEBUG

    @window = VER::Window.root_window

    catch(:close) do
      colors = Ncurses.COLORS
      @form = Form.new @window
      r = 3; c = 7; w = 80
      ht = 20

        scroll = ScrollPane.new @form do
          name   "myScroller" 
          row r
          col  c 
          width w
          height ht
        end
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

        atable = Table.new nil do
          name   "mytext" 
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
        scroll.child(atable)

      @help = "F1 to quit. This is a test of Table inside a scrollpane. #{$0} M-n M-p M-< M-> M-h M-l"
      RubyCurses::Label.new @form, {'text' => @help, "row" => ht+r+1, "col" => 2, "color" => "yellow"}

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != KEY_F1 ) # ?q.getbyte(0) )
        str = keycode_tos ch
        @form.handle_key(ch)
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
