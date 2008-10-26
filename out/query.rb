#!/usr/bin/ruby

require 'rubygems'
require 'ncurses'
require 'commons1'
require 'logger'
require 'queryapplication'
require 'sqlite3'

include Ncurses
include Ncurses::Form
# this has some of the UI like askyesno, print etc.
include Commons1

class FFHistory
  attr_reader :field_length
  # added so search etc can be facilitated slightly better
  attr_accessor :query_app
  def initialize(main)
    @main = main
    @data_arr = []
    @field_length = 80
    @db = SQLite3::Database.new( "places1.sqlite" )
    @rows = nil
    @sqlstring = "select title, url, id from moz_places"
    #@sqlstring = "select title, url from moz_places where title like '%pylon%'"
    @command = @sqlstring.dup
    @excludelist = []
  end
  # related table form 2008-10-03 22:12 
  def get_data
    @rows = @db.execute(@command)
    @data_arr = @rows
  end
  def format_line(menuctr,dataitem)
    dataitem[0].gsub!(/[^[:space:][:print:]]/,'')  # remove junk chars 2008-10-04 18:35 
      sprintf("%3d %-30s %-30s", menuctr+1, dataitem[0], dataitem[1])
  end
  def format_titles
      sprintf("      %-30s %-30s ", "Title", "URL")
  end
  # most significant part of multirow listing, like a key, to act upon for most purposes
  def get_key(dataitem)
    dataitem[2] # id, needed for deletion
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
      @main.print_status(dataitem[1][0..79])
  end
  # return string to be printed on top right with each traversal
  # should try to pass item in so he does not have to pop.
  def header_top_right(currindex)
    "%3d of %3d urls " % [ currindex, @data_arr.length]
  end
  # something like a level 1 heading
  def header_top_left 
    "Search"
  end
  # something like a level 2 heading
  def header_top_center
    "Firefox History"
  end
  # some additional data that cannot be shown in lines, to be displayed elsewhere, as in a box. 
  # example could be email text of selected email headers/subjects
  def get_associated_data(dataitem)
    dataitem[0]
  end
  # will break in 1.9
  # returns an array of hashes giving ascii value, displaycode and text
  # handler for display_code will be triggered such as handle_D or handle_V
  # if :action specified, sort will be called with curritem, listselected=[]
  # listselected is an array of offsets 
  def get_keys_handled()
    [ { :keycode=>"X"[0], :display_code => "X", :text => "eXlcude" },
      { :keycode=>"V"[0], :display_code => "V", :text => "View   " },
      { :keycode=>"D"[0], :display_code => "D", :text => "Delete " },
      { :keycode=>"$"[0], :display_code => "$", :text => "Sort   ", :action => "sort" }
      ]
  end
  # called when key x/X pressed
  # the list actually has indexes not items! Needed to mark off rows with X
  def handle_D(curritem, listselected=[])
    ret =  @main.askyesno(nil, "Are you sure you wish to delete?")
    @main.clear_error
    if !ret
      @main.print_status("Operation cancelled")
      return -1
    end
    selectedids = []
    listselected.each{ |idx|
      item = @data_arr[idx]
      selectedids << item[2]
    }
    selected_id_str = selectedids.join(", ")
    sqlstr = "delete from moz_places where id in (#{selected_id_str})"
    rows = @db.execute(sqlstr)
    @main.print_status("Deleted: #{rows} #{sqlstr}")
    @main.populate_table
  end
  # called when key x/X pressed
  def handle_X(curritem, listselected=[])
    labels = ["^L~ClearExcludes","  ~             "]
    validints=[?\C-l]
    ret,str =  @main.ask_string(nil, "Enter string to exclude:", 20, "", labels, validints)
    @main.print_status("Chosen #{ret} #{str}")
    @excludelist << str if ret == 0
    case ret
    when -1
      @main.print_status("Command cancelled")
    when 0
      tmplist = @excludelist.map{|xcl| " title not like '%#{xcl}%' "}
      tmpstring = tmplist.join(" and ")
        #@command = @sqlstring + " where title not like '%#{str}%'"
        @command = @sqlstring + " where " + tmpstring
        @main.clear_error
        if @command.length > 80
        @main.print_status(@command[-79..-1])
        else
        @main.print_status("#{@command}")
        end
        @main.populate_table
    when ?\C-l
      @excludelist=[]
      @main.print_status("Cleared excludelist")
    end
  end
  # called when key v/V pressed
  def handle_V(curritem, listselected=[])
      @main.print_status("Called View")
  end
  # called when key '$' pressed
  def sort(curritem, listselected=[])
    #qfields = @main.get_query_fields()
    qfields = @query_app.get_query_fields()
      labels=["?~Help  ","C~Cancel",   "T~[Title]", "U~Url    "]
      ret =  @main.askchoice(nil, "Choose type of sort, or 'R' to reverse current sort","T",labels,"?CTUR")
      case ret
      when 't'
        @command = @sqlstring + create_search_string(qfields)
        @command = @command + " order by title asc "
        @main.clear_error
        @main.print_status("#{@command}")
        @main.populate_table
      when 'u'
        @command = @sqlstring + create_search_string(qfields)
        @command = @command + " order by url asc "
        @main.populate_table
      when 'r'
        if @command.include?" asc "
          @command.sub!(/asc /,' desc ')
        else
          if @command.include?" desc " 
            @command.sub!(/ desc /,' asc ')
          else
            @main.print_error("No existing sort defined")
            return -1
          end
        end
        @main.populate_table
      end
      @main.clear_error
    @main.print_status("#{@command}")
    #  @main.print_status("Chosen #{ret}")
  end
  def create_search_string(qfields)
    qtitle,qurl = qfields
    qtitle.strip!
    qurl.strip!
    wherecond = []
    wherecond << " title like '%#{qtitle}%'"   if qtitle != ""
    wherecond << " url like '%#{qurl}%'"       if qurl != ""
    wherecondstr = wherecond.join(" and ")
    wherecondstr = " where " + wherecondstr if wherecond.length>0
    wherecondstr ||= ""
  end
  def search(curritem, listselected=[])
    #qfields = @main.get_query_fields()
    qfields = @query_app.get_query_fields()
    @command = @sqlstring + create_search_string(qfields)
    #@command = @sqlstring + wherecondstr
    @main.print_status("#{@command}")
    @main.populate_table
  end
end

# This is the main class that ties in a TableApp and a QueryApplication.
# Functions specific to the data, are provided by the datasource class

class Query < Application
  attr_reader :table_form

  def initialize(unused)

    super()

    @table_form = nil

    # instantiate a datasource
    @datasource = FFHistory.new(self)
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
      create_header_win()  # super takes care of this

      create_footer_win()  # super takes care of this
      Ncurses::Panel.update_panels

      # change this to show more or less rows
      # table form assumes number of fields is the number of rows to display.
      # if thats not the case, use form.rows_to_show
      @rows_to_show = 12

      # change this to make the whole table start above or below.
      title_row = 1  # this is the start point. XXX unused after refac. pls use

      # change this if you want spaces between lines
      row_space = 1 # (use 2 for doublespace) XXX unused after refac. pls use


      # change this only if you remove the hline/s.
      title_row_span = 3 # 2 lines plus title XXX for 2 fields

      fieldlen = @datasource.field_length
     
      # query fields
      qfield_labels = ["Title","URL"]
      how_many = 2
      qform_row1 = 1 # which row to start query fields from
      qform_col = 25
      qform_label_offset = 5
      qform_field_width = 30
      # when we use a DSL this will be a hash of fields like it once was
      @qfields = create_query_fields(how_many, qform_field_width, qform_row1, qform_col)
      set_field_label_info(@qfields, qfield_labels, {:just => :right, :offset => qform_label_offset})
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
      @qform_win.mvaddstr(qform_row1+1, qform_label_offset+qform_field_width+qform_col , 
                          "Press ENTER to run query")
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
      Ncurses::Panel.del_panel(@qform_panel) 
      @qform_win.delwin
      Ncurses::Panel.del_panel(@my_form_panel) 
      @my_form_win.delwin
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

    f = Query.new(nil)
    f.run

  ensure
    Ncurses.endwin();
  end
end

