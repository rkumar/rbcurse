## rkumar, 2009
# Sample demo of various widgets and their interaction.
# This is a simple sql client which allows table / column selection, construction
# of SQL queries, and multiple resultsets.
# Use C-q to quit, Alt-Tab to move out of Table to next field.
# Please see bind_key statements in this app for some key bindings in table.
# This is an offshoot of sqlc.rb -- this demo uses a multicontainer for tables
# instead of a tabbed panes. 
#
require 'rubygems'
require 'ncurses'
require 'logger'
require 'sqlite3'
require 'rbcurse'
require 'rbcurse/rcombo'
require 'rbcurse/rtextarea'
require 'rbcurse/rtable'
#require 'rbcurse/table/tablecellrenderer'
#require 'rbcurse/comboboxcellrenderer'
#require 'rbcurse/keylabelprinter'
require 'rbcurse/applicationheader'
#require 'rbcurse/action' # not used here
#require 'rbcurse/rtabbedpane'
require 'rbcurse/rmulticontainer'

# pls get testd.db from
# http://www.benegal.org/files/screen/testd.db
# or put some other sqlite3 db name there.

## must give me @content, @columns, @datatypes (opt)
class Datasource
# attr_reader :field_length         # specified by user, length of row in display table
  attr_accessor :columns      # names of columns in array
  attr_accessor :datatypes    # array of datatyps of columns required to align: int, real, float, smallint
  attr_accessor :content    # 2 dim data
  attr_accessor :user_columns  # columnnames provided by user, overrides what is generated for display
# attr_reader :sqlstring           # specified by user

  # constructor
  def initialize(config={}, &block)
    @content = []
    @columns = nil # actual db columnnames -- needed to figure out datatypes
    @user_columns = nil # user specified db columnnames, overrides what may be provided
    @datatypes = nil
#   @rows = nil
#   @sqlstring = nil
#   @command = nil

    instance_eval(&block) if block_given?
  end
  def connect dbname
   @db = SQLite3::Database.new(dbname)
  end
  # get columns and datatypes, prefetch
  def get_data command
    @columns, *rows = @db.execute2(command)
    @content = rows
    return nil if @content.nil? or @content[0].nil?
    @datatypes = @content[0].types #if @datatypes.nil?
    @command = command
    return @content
  end
  def get_metadata table
    get_data "select * from #{table} limit 1"
    return @columns
  end
  ##
  # returns columns_widths, and updates that variable
  def estimate_column_widths tablewidth, columns
    colwidths = {}
    min_column_width = (tablewidth/columns.length) -1
    $log.debug("min: #{min_column_width}, #{tablewidth}")
    @content.each_with_index do |row, cix|
      break if cix >= 20
      row.each_index do |ix|
        col = row[ix]
        colwidths[ix] ||= 0
        colwidths[ix] = [colwidths[ix], col.length].max
      end
    end
    total = 0
    colwidths.each_pair do |k,v|
      name = columns[k.to_i]
      colwidths[name] = v
      total += v
    end
    colwidths["__TOTAL__"] = total
    column_widths = colwidths
    @max_data_widths = column_widths.dup

    columns.each_with_index do | col, i|
        if @datatypes[i].match(/(real|int)/) != nil
          wid = column_widths[i]
       #   cw = [column_widths[i], [8,min_column_width].min].max
          $log.debug("XXX #{wid}. #{columns[i].length}")
          cw = [wid, columns[i].length].max
          $log.debug("int #{col} #{column_widths[i]}, #{cw}")
        elsif @datatypes[i].match(/(date)/) != nil
          cw = [column_widths[i], [12,min_column_width].min].max
          #cw = [12,min_column_width].min
          $log.debug("date #{col}  #{column_widths[i]}, #{cw}")
        else
          cw = [column_widths[i], min_column_width].max
          if column_widths[i] <= col.length and col.length <= min_column_width
            cw = col.length
          end
          $log.debug("else #{col} #{column_widths[i]}, #{col.length} #{cw}")
        end
        column_widths[i] = cw
        total += cw
    end
    column_widths["__TOTAL__"] = total
    $log.debug("Estimated col widths: #{column_widths.inspect}")
    @column_widths = column_widths
    return column_widths
  end

  # added to enable query form to allow movement into table only if
  # there is data 2008-10-08 17:46 
  # returns number of rows fetched
  def data_length
    return @content.length 
  end
 
end
def get_key_labels
  key_labels = [
    ['C-q', 'Exit'], nil,
    ['M-s', 'Save'], ['M-m', 'Move']
  ]
  return key_labels
end
def get_key_labels_table
  key_labels = [
    ['M-n','NewRow'], ['M-d','DelRow'],
    ['C-x','Select'], nil,
    ['M-0', 'Top'], ['M-9', 'End'],
    ['C-p', 'PgUp'], ['C-n', 'PgDn'],
    ['M-Tab','Nxt Fld'], ['Tab','Nxt Col'],
    ['+','Widen'], ['-','Narrow']
  ]
  return key_labels
end
class Sqlc
  def initialize
    @window = VER::Window.root_window
    $catch_alt_digits = false # we want to use Alt-1, 2 for tabs.
    @form = Form.new @window
    @tab_ctr = 0

    @db = Datasource.new
    @db.connect "testd.db"
  end
  def run
    title = "rbcurse"
    @header = ApplicationHeader.new @form, title, {:text2=>"Demo", :text_center=>"SQL Client"}
    status_row = RubyCurses::Label.new @form, {'text' => "", :row => Ncurses.LINES-4, :col => 0, :display_length=>70}
    @status_row = status_row
    # setting ENTER across all objects on a form
    @form.bind(:ENTER) {|f| status_row.text = f.help_text unless f.help_text.nil? }
    r = 1; c = 1;
    @data = [ ["No data"] ]
    data = @data
    colnames = %w[ Result ]

    ta_ht = 5
    t_width = 78
    sqlarea = TextArea.new @form do
      name   "sqlarea" 
      row  r 
      col  c
      width t_width
      height ta_ht
      title "Sql Query"
      title_attrib (Ncurses::A_REVERSE | Ncurses::A_BOLD)
      help_text "Enter query and press Run or Meta-r"
    end
    sqlarea << "select * from contacts"
    buttrow = r+ta_ht+1 #Ncurses.LINES-4
    b_run = Button.new @form do
      text "&Run"
      row buttrow
      col c
      help_text "Run query"
    end
    ## We use Action to create a button: to test out ampersand with MI and Button
    b_clear = Button.new @form do
      #action new_act
      text "&Clear"
      row buttrow
      col c+10
      help_text "Clear query entry box "
    end
    b_clear.command { 
      sqlarea.remove_all
      sqlarea.focus
    }

    # using ampersand to set mnemonic

    b_construct = Button.new @form do
      text "Constr&uct"
      row buttrow
      col c+25
      help_text "Select a table, select columns and press this to construct an SQL"
    end

    Button.button_layout [b_run, b_clear, b_construct], buttrow, startcol=5, cols=Ncurses.COLS-1, gap=5

    @tp = create_tabbed_pane @form, buttrow, t_width, c
    @tp.show
    @data = data

    b_run.command { 
      query =  sqlarea.get_text
      run_query query
    }
    #
    ## key bindings fo atable
    # column widths 
    app = self
    #atable.configure() do
      ##bind_key(330) { atable.remove_column(tcm.column(atable.focussed_col)) rescue ""  }
      #bind_key(?+) {
        #acolumn = atable.column atable.focussed_col()
        #w = acolumn.width + 1
        #acolumn.width w
        ##atable.table_structure_changed
      #}
      #bind_key(?-) {
        #acolumn = atable.column atable.focussed_col()
        #w = acolumn.width - 1
        #if w > 3
          #acolumn.width w
          ##atable.table_structure_changed
        #end
      #}
      ## added new method on 2009-10-08 00:47 
      #bind_key(?=) {
        #atable.size_columns_to_fit
      #}
      #bind_key(?>) {
        #tcm = atable.get_table_column_model
        #colcount = tcm.column_count-1
        ##atable.move_column sel_col.value, sel_col.value+1 unless sel_col.value == colcount
        #col = atable.focussed_col
        #atable.move_column col, col+1 unless col == colcount
      #}
      #bind_key(?<) {
        #col = atable.focussed_col
        #atable.move_column col, col-1 unless col == 0
        ##atable.move_column sel_col.value, sel_col.value-1 unless sel_col.value == 0
      #}
      ## TODO popup and key labels
      #bind_key(?\M-h, app) {|tab,td| $log.debug " BIND... #{tab.class}, #{td.class}"; app.make_popup atable}
    #end
    #keylabel = RubyCurses::Label.new @form, {'text' => "", "row" => r+table_ht+3, "col" => c, "color" => "yellow", "bgcolor"=>"blue", "display_length"=>60, "height"=>2}
    #eventlabel = RubyCurses::Label.new @form, {'text' => "Events:", "row" => r+table_ht+6, "col" => c, "color" => "white", "bgcolor"=>"blue", "display_length"=>60, "height"=>2}

    # report some events
    #atable.table_model.bind(:TABLE_MODEL_EVENT){|e| #eventlabel.text = "Event: #{e}"}
    #atable.get_table_column_model.bind(:TABLE_COLUMN_MODEL_EVENT){|e| eventlabel.text = "Event: #{e}"}

    tablist_ht = 6
    mylist = @db.get_data "select name from sqlite_master"
    # mylist is an Array of SQLite3::ResultSet::ArrayWithTypesAndFields
    mylist.collect!{|x| x[0] }  ## 1.9 hack, but will it run on 1.8 ??
    $listdata = Variable.new mylist
        tablelist = Listbox.new @form do
          name   "tablelist" 
          row  1
          col  t_width+2
          width 20
          height tablist_ht
#         list mylist
          list_variable $listdata
          #selection_mode :SINGLE
          #show_selector true
          title "Tables"
          title_attrib 'reverse'
          help_text "Press ENTER to run * query, Space to select columns"
        end
        #tablelist.bind(:PRESS) { |alist| @status_row.text = "Selected #{alist.current_index}" }
        tablelist.list_selection_model().bind(:LIST_SELECTION_EVENT,tablelist) { |lsm, alist| @status_row.text = "Selected #{alist.current_index}" }

  collist = []
  $coldata = Variable.new collist
  columnlist = Listbox.new @form do
    name   "columnlist" 
    row  tablist_ht+2
    col  t_width+2
    width 20
    height 15
    #         list mylist
    list_variable $coldata
    #selection_mode :SINGLE
    #show_selector true
    title "Columns"
    title_attrib 'reverse'
    help_text "Press ENTER to append columns to sqlarea, Space to select"
  end
  ## pressing SPACE on a table populates column list with its columns so they can be selected
  tablelist.bind_key(32) {  
    @status_row.text = "Selected #{tablelist.get_content()[tablelist.current_index]}" 
    table = "#{tablelist.get_content()[tablelist.current_index]}" 
    ##table = table[0] if table.class==Array ## 1.9 ???
    columnlist.list_data_model.remove_all
    columnlist.list_data_model.insert 0, *@db.get_metadata(table)
  }
  ## pressing ENTER on a table runs a query on it, no need to type and SQL
  tablelist.bind_key(13) {  
    @status_row.text = "Selected #{tablelist.get_content()[tablelist.current_index]}" 
    table = "#{tablelist.get_content()[tablelist.current_index]}" 
    ##table = table[0] if table.class==Array ## 1.9 ???
    run_query "select * from #{table}"
  }
  columnlist.bind_key(13) {  
    ## append column name to sqlarea if ENTER pressed
    column = "#{columnlist.get_content()[columnlist.current_index]}" 
    sqlarea << "#{column},"
  }
  columnlist.bind_key(32) {  
    ## select row - later can press Construct button
    columnlist.toggle_row_selection
    column = "#{columnlist.get_content()[columnlist.current_index]}" 
  }
  ## construct an SQL after selecting some columns in the column list
    b_construct.command { 
    table = "#{tablelist.get_content()[tablelist.current_index]}" 
    #table = table[0] if table.class==Array ## 1.9 ???
    indexes = columnlist.selected_rows()
    columns=[]
    indexes.each do |i|
      columns << columnlist.get_content()[i]
    end
    sql = "select #{columns.join(',')} from #{table}"
    sqlarea << sql
    }


    @form.repaint
    @window.wrefresh
    Ncurses::Panel.update_panels
    begin
    while((ch = @window.getchar()) != ?\C-q.getbyte(0) )
      s = keycode_tos ch
      status_row.text = "Pressed #{ch} , #{s}.  Press C-q to quit, Alt-Tab for exiting table "
      @form.handle_key(ch)

      @form.repaint
      @window.wrefresh
    end
    ensure
    @window.destroy if !@window.nil?
    end
  end
  ## execute the query in the textarea
  # @param [String] sql string
  def run_query sql
      #query =  sqlarea.get_text
      query =  sql
      begin
      @content = @db.get_data query
      if @content.nil?
        @status_row.text = "0 rows retrieved"
        return
      end
      #cw = @db.estimate_column_widths @atable.width, @db.columns
      atable = create_table @tp, @tab_ctr #,  buttrow, t_width, c
      atable.set_data @content, @db.columns
      cw = atable.estimate_column_widths @db.columns, @db.datatypes
      atable.set_column_widths cw
      rescue => exc
        $log.debug(exc.backtrace.join("\n"))
        alert exc.to_s
        return
      end
      @status_row.text = "#{@content.size} rows retrieved"
      atable.repaint
  end
  ## create a Table component for populating with data
  def create_table tp, counter #, buttrow, t_width, c
    table_ht = 15
    atable = Table.new do
      name   "sqltable#{counter}" 
      #cell_editing_allowed true
      #editing_policy :EDITING_AUTO
      #help_text "M-Tab for next field, M-8 amd M-7 for horiz scroll, + to resize, C-q quit"
      help_text "M-Tab for next field, C-q quit"
    end
    atable.bind(:TABLE_TRAVERSAL_EVENT){|e| @header.text_right "Row #{e.newrow+1} of #{atable.row_count}" }
    @tab_ctr += 1
    #tab1 = tp.add_tab "Tab&#{@tab_ctr}" , atable
    tab1 = tp.add atable, "Tab&#{@tab_ctr}" 
    return atable
  end
  ## create the single tabbedpane for populating with resultsets
  def create_tabbed_pane form, buttrow, t_width, c
      tp = MultiContainer.new @form do
        name "multic"
        height 16
        width  t_width
        row buttrow +1
        col c
        #row  r 
        #col  c
        #width 60
        #height 15
        title "Results"
      end
      #tp = RubyCurses::TabbedPane.new form do
        #height 16
        #width  t_width
        #row buttrow +1
        #col c
        #button_type :ok
      #end
      return tp
  end
end
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils

  begin
    # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG

    colors = Ncurses.COLORS
    $log.debug "START #{colors} colors  SQLC demo "

    catch(:close) do
      t = Sqlc.new
      t.run
  end
  rescue => ex
  ensure
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
