#!/usr/bin/ruby

require 'rubygems'
require 'ncurses'
require 'commons1'
require 'logger'
require 'queryapplication'
require 'datasource'
require 'sqlite3'

include Ncurses
include Ncurses::Form
# this has some of the UI like askyesno, print etc.
include Commons1

class Contracts < Datasource
  # added so search etc can be facilitated slightly better
  attr_accessor :query_app
  def initialize(main)
    super
    @columns = nil 
    @field_length = 85
    # this should be done in one place for all programs.
    @db = SQLite3::Database.new( 'testd.db' )
    @sqlstring = 'select contract_id, contract_execution_date, rate, quantity, product_name from contracts'

    #@command = @sqlstring.dup
    @column_separator = nil
    @column_separator = " " if @column_separator.nil? 
    @column_widths = [8, 10, 5, 8, 15]
    @entity = "contracts" 
  # something like a level 1 heading
    @header_top_left='Demos'
  # something like a level 2 heading
    @header_top_center='Contracts'
  end
  # 
  # most significant part of multirow listing, like a key, to act upon for most purposes
  def get_key(dataitem)
    dataitem[0] # id, needed for deletion
  end
  # if you need to print a message in message area related to this
  def get_message(dataitem)
    dataitem[1] # title
  end
  def on_selection(currindex, dataitem)
    ret =  @main.askyesno(nil, "Are you sure you wish to proceed?")
    @main.clear_error
    if ret
      key = get_key(dataitem)
      @main.print_status("on_selection invoked: Aaah you have selected #{key}")
    else
      @main.print_status("Operation cancelled")
    end
    return 0
  end
  def row_focus_gained(currindex, dataitem)
      @main.print_status(dataitem[-1])
  end
  # return string to be printed on top right with each traversal
  # should try to pass item in so he does not have to pop.
  def header_top_right(currindex)
    "%3d of %3d #{@entity} " % [ currindex, @data_arr.length]
  end
  # some additional data that cannot be shown in lines, to be displayed elsewhere, as in a box. 
  # example could be email text of selected email headers/subjects
  def get_associated_data(dataitem)
    dataitem[0]
  end
  # returns an array of hashes giving ascii value, displaycode and text
  # handler for display_code will be triggered such as handle_D or handle_V
  # if :action specified, sort will be called with curritem, listselected=[]
  # listselected is an array of offsets 
  def get_keys_handled()
    [{:keycode=>88, :display_code=>"X", :text=>"eXlcude"},
 {:keycode=>86, :display_code=>"V", :text=>"View   "},
 {:keycode=>999, :display_code=>" ", :text=>"       "},
 {:action=>"sort", :keycode=>36, :display_code=>"$", :text=>"Sort   "}] \
  || super
  end
end

# This is the main class that ties in a TableApp and a QueryApplication.
# Functions specific to the data, are provided by the datasource class

class ContractViewer < Application

  attr_reader :table_form
  attr_reader :helpfile

  def initialize(unused)

    super()

    @table_form = nil

    @helpfile = __FILE__
    @helpfile = "TODO"
    # instantiate a datasource
    @datasource =  Contracts.new(self)
  end

  # Called by table app for now.
  # Have to ensure that other apps call us too.
  def field_init_hook(my_form_win)
  end
  def field_term_hook(my_form_win)
  end

  ###DEFS_COME_HERE###

  # main program which does the job. This is called by the menu program.

  def run

    ###PROCS_COME_HERE###

    begin
      @form_headers["header_top_center"]=@datasource.header_top_center
      @form_headers["header_top_left"]=@datasource.header_top_left
      @main = self # XXX 2008-10-10 13:19 

      create_header_win()  # super takes care of this

      create_footer_win()  # super takes care of this
      Ncurses::Panel.update_panels

      @rows_to_show = 12

      #title_row_span = 3 # 2 lines plus title XXX for 2 fields

      fieldlen = @datasource.field_length

      # query fields
      qform_row1 = 1 # which row to start query fields from
      qform_col = 25
      qform_label_offset = 5
      #qform_field_width = 30
      ###QFIELDS###
fields = Array.new
    #rate

    field = FIELD.new(1, 10, 1, qform_col+0, 0, 0)
    field.user_object = {:row=>1, "fieldtype"=>"NUMERIC", "label"=>"Rate", "name"=>"rate", "help_text"=>"Enter a rate to search on", "field_back"=>"REVERSE", :label=>"Rate", "width"=>10}
    field.user_object[:col] = qform_col+0

    field.set_field_back(A_REVERSE)

    fields.push(field)
                #quantity

    field = FIELD.new(1, 10, 2, qform_col+0, 0, 0)
    field.user_object = {:row=>2, "fieldtype"=>"INTEGER", "label"=>"Quantity", "name"=>"quantity", "field_back"=>"REVERSE", :label=>"Quantity", "width"=>10}
    field.user_object[:col] = qform_col+0

    field.set_field_back(A_REVERSE)

    fields.push(field)
                #contract_execution_date

    field = FIELD.new(1, 12, 3, qform_col+0, 0, 0)
    field.user_object = {:row=>3, "label"=>"Execution Date", "name"=>"contract_execution_date", "field_back"=>"REVERSE", :label=>"Execution Date", "width"=>12}
    field.user_object[:col] = qform_col+0

    field.set_field_back(A_REVERSE)

    fields.push(field)
                #product_name

    field = FIELD.new(1, 12, 1, qform_col+30, 0, 0)
    field.user_object = {:row=>1, "label"=>"Product Name", "name"=>"product_name", "field_back"=>"REVERSE", :label=>"Product Name", "width"=>12}
    field.user_object[:col] = qform_col+30

    field.set_field_back(A_REVERSE)

    fields.push(field)

    #rate

    fields[0].set_field_type(TYPE_NUMERIC, 2,0,10000 );
    fields[0].set_field_just(JUSTIFY_RIGHT)

    #quantity

    fields[1].set_field_type(TYPE_INTEGER, 2,0,10000 );
    fields[1].set_field_just(JUSTIFY_RIGHT)

    #contract_execution_date

    #product_name

 ###- SET FIELDS

      #how_many = 2
      #@qfields = create_query_fields(how_many, qform_field_width, qform_row1, qform_col)
      @qfields = fields
      @qapp = QueryApplication.new(@qfields, self)
      @qform = @qapp.form
      qform_win_rows = 4
      qform_win_cols = 0 # default of ncurses
      qform_win_starty = 1
      qform_win_startx = 0
      @qform_win, @qform_panel = @qapp.create_window(qform_win_rows, 
                                       qform_win_cols, 
                                       qform_win_starty,
                                       qform_win_startx)

      @fields = TableApplication.create_table_fields(@rows_to_show,
                                                     fieldlen, 
                                                     att_hash={})
      @tapp = TableApplication.new(@fields, self, @datasource)

      # inform the application that this is my datasource, so it can do its stuff using this class
      #@tapp.set_data_source(@datasource)
      @table_form = @tapp.form

      # populate fields
      @tapp.populate_form if @prepopulate

      table_offset = qform_label_offset
      @my_form_win, @my_form_panel = @tapp.create_window(table_offset)

      Ncurses.refresh();

      # extra LABELS
      #@qform_win.mvaddstr(qform_row1+2, qform_label_offset+qform_field_width+qform_col , 
      @qform_win.mvaddstr(qform_row1+2, 75,
                          "Press ENTER to run")
      @tapp.wrefresh();

      print_screen_labels(@my_form_win, @labelarr)

      # i need this to set the bottom panel
      @keys_handled = TableApplication.get_keys_handled() + @datasource.get_keys_handled()
      add_to_application_labels(@keys_handled)
      @qapp.restore_application_key_labels
      stdscr.refresh();

      # inform query app, who the output app is
      @qapp.set_output_application(@tapp)

      @qapp.handle_keys_loop()

#    rescue Exception => e
    # print_error(e.to_s)
    # @log.error(caller(0).to_s)
#     @log.error(e.backtrace.join("\n"))
     #@log.error(e.backtrace.pretty_inspect)
  #   @log.error(Kernel.pretty_inspect(e.backtrace))


    ensure
      # Un post form and free the memory
      @qapp.free_all() if !@qapp.nil?
      @tapp.free_all() if !@tapp.nil?
      self.free_all #  XXX
      #Ncurses::Panel.del_panel(@header_panel)  if !@qform_panel.nil?
      #@header_win.delwin
      # queryapp may have delled this. since i stored it when returning ?XXX
      #Ncurses::Panel.del_panel(@qform_panel)  if !@qform_panel.nil?
      #@qform_win.delwin  if !@qform_win.nil?
      #Ncurses::Panel.del_panel(@my_form_panel)   if !@my_form_panel.nil?
      #@my_form_win.delwin  if !@my_form_win.nil?
    end
  end
  # temporary hack so Datasource need not know 2008-10-04 19:25  XXX
  def populate_table
    @table_form.populate_form
  end

  # temporary hack so Datasource need not know 2008-10-04 19:25  XXX
  def get_query_fields
    @qapp.get_query_fields
  end

  # ADD HERE
end

if __FILE__ == $0
  # Initialize curses
  begin
    stdscr = Ncurses.initscr();
    Ncurses.start_color();
    Ncurses.cbreak();
    Ncurses.noecho();
    Ncurses.keypad(stdscr, true);
    trap("INT") {  }

    # Initialize few color pairs 
    Ncurses.init_pair(1, COLOR_RED, COLOR_BLACK);
    Ncurses.init_pair(2, COLOR_BLACK, COLOR_WHITE);
    Ncurses.init_pair(3, COLOR_BLACK, COLOR_BLUE);
    Ncurses.init_pair(4, COLOR_YELLOW, COLOR_RED); # for selected item
    # 5 is also used to clear off previous message, error, status since it has a black
    # background
    Ncurses.init_pair(5, COLOR_WHITE, COLOR_BLACK); # for unselected menu items
    Ncurses.init_pair(6, COLOR_WHITE, COLOR_BLUE); # for bottom/top bar
    Ncurses.init_pair(7, COLOR_WHITE, COLOR_RED); # for error messages
    #stdscr.bkgd(Ncurses.COLOR_PAIR(6)); ## DO NOT TOUCH stdscr please

    f =  ContractViewer.new(nil)
    f.run

  ensure
    Ncurses.endwin();
  end
end
