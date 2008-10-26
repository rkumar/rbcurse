#!/usr/bin/ruby

require 'rubygems'
require 'ncurses'
require 'commons1'
require 'logger'
require 'queryapplication'
require 'datasource'
require '<%=@@table_app["datasource"]["apptype"]%>'

include Ncurses
include Ncurses::Form
# this has some of the UI like askyesno, print etc.
include Commons1

class <%= @@table_app["datasource"]["classname"] %> < Datasource
  # added so search etc can be facilitated slightly better
  attr_accessor :query_app
  def initialize(main)
    super
    @columns = <%=@@table_app["datasource"]["column_titles"].inspect %> 
    @field_length = <%=@@table_app["field_length"] || 80%>
    # this should be done in one place for all programs.
    @db = SQLite3::Database.new( '<%=@@table_app["datasource"]["db"]%>' )
    @sqlstring = '<%=@@table_app["datasource"]["sqlstring"]%>'

    #@command = @sqlstring.dup
    @column_separator = <%= @@table_app["datasource"]["column_separator"].inspect %>
    @column_separator = " " if @column_separator.nil? 
    @column_widths = <%= @@table_app["datasource"]["column_widths"].inspect || nil%>
    @entity = "<%=@@table_app['datasource']['entity']%>" 
  # something like a level 1 heading
    @header_top_left='<%=@@table_app["datasource"]["header_top_left"]%>'
  # something like a level 2 heading
    @header_top_center='<%=@@table_app["datasource"]["header_top_center"]%>'
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
    <%=str="";PP.pp(@@table_app["datasource"]["keys_handled"],str); str.chomp() +' \\'%>
  || super
  end
end

# This is the main class that ties in a TableApp and a QueryApplication.
# Functions specific to the data, are provided by the datasource class

class <%=@@app["classname"]%> < Application
    
  attr_reader :table_form

  def initialize(unused)

    super()

    @table_form = nil
    @helpfile = __FILE__ # a helpfile name will be determined from this.

    # instantiate a datasource
    @datasource =  <%= @@table_app["datasource"]["classname"]%>.new(self)
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
      @main = self
             
      create_header_win()  # super takes care of this

      create_footer_win()  # super takes care of this
      Ncurses::Panel.update_panels

      @rows_to_show = <%=@@table_app["rows_to_show"]%>

      #title_row_span = 3 # 2 lines plus title XXX for 2 fields

      fieldlen = @datasource.field_length
     
      # query fields
      qform_row1 = 1 # which row to start query fields from
      qform_col = 25
      qform_label_offset = 5
      qform_field_width = 30
      ###QFIELDS###
      #how_many = 2
      #@qfields = create_query_fields(how_many, qform_field_width, qform_row1, qform_col)
      @qfields = fields
      @qapp = QueryApplication.new(@qfields, self)
      @qform = @qapp.form
      qform_win_rows = 4
      qform_win_cols = 0 # default of ncurses
      qform_win_starty = 1
      qform_win_startx = 0
      @qform_win = @qapp.create_window(qform_win_rows, 
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
      @my_form_win = @tapp.create_window(table_offset)
      
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
      restore_application_key_labels
      stdscr.refresh();

      # inform query app, who the output app is
      @qapp.set_output_application(@tapp)

      @qapp.handle_keys_loop()

    ensure
      # Un post form and free the memory
      @qapp.free_all() if !@qapp.nil?
      @tapp.free_all() if !@tapp.nil?
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

    f =  <%=@@app["classname"]%>.new(nil)
    f.run

  ensure
    Ncurses.endwin();
  end
end

