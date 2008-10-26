#!/usr/bin/ruby

require 'rubygems'
require 'ncurses'
require 'logger'
require 'commons'

include Ncurses
include Ncurses::Form
# this has some of the UI like askyesno, print etc.
include Commons

class DirListing
  attr_reader :field_length
  def initialize(main)
    @main = main
    @data_arr = []
    @field_length = 70
    @command = "/bin/ls -l"
  end
  def get_data
    @str = %x[#{@command}] 
    @data_arr = @str.split("\n")
    @data_arr.shift # that total line, we don't want it
    @data_arr
  end
  def format_line(menuctr,dataitem)
    #sprintf("%3s    %-20s  - %-30s", dataitem["key"], dataitem["short"],dataitem["long"])
    parts = dataitem.split(/\s+/)
    if parts.length < 3
      sprintf("%-60s", dataitem)
    else
      sprintf("%3d %10d %-12s %-40s ",menuctr+1, parts[4], parts[5..7].join(" "),parts[8])
    end
  end
  def format_titles
      sprintf("      %10s %-12s %-40s ", "Size", "Date", "Filename")
  end
  # most significant part of multirow listing, like a key, to act upon for most purposes
  def get_key(dataitem)
    parts = dataitem.split(/\s+/)
    parts.last
  end
  # if you need to print a message in message area related to this
  def get_message(dataitem)
    get_key(dataitem)
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
      #@main.print_status("row focus #{currindex}")
  end
  # return string to be printed on top right with each traversal
  # should try to pass item in so he does not have to pop.
  def print_top_right(currindex)
        "%2d of %3d files " % [ currindex, @data_arr.length]
  end
  # something like a level 1 heading
  def print_top_left
    "Utils"
  end
  # something like a level 2 heading
  def print_top_center
    "FileLister"
  end
  # some additional data that cannot be shown in lines, to be displayed elsewhere, as in a box. 
  # example could be email text of selected email headers/subjects
  def get_associated_data(dataitem)
    ""
  end
  # will break in 1.9
  # returns an array of hashes giving ascii value, displaycode and text
  # handler for display_code will be triggered such as handle_D or handle_V
  # if :action specified, sort will be called with curritem, listselected=[]
  # listselected is an array of offsets - i think!
  def get_keys_handled()
    [ { :keycode=>"D"[0], :display_code => "D", :text => "Delete" },
      { :keycode=>"V"[0], :display_code => "V", :text => "View" },
      { :keycode=>"$"[0], :display_code => "$", :text => "Sort", :action => "sort" }
      ]
  end
  # called when key d/D pressed
  def handle_D(curritem, listselected=[])
    ret =  @main.askyesno(nil, "Are you sure you wish to delete?")
    @main.print_status("Chosen #{ret}")
  end
  # called when key v/V pressed
  def handle_V(curritem, listselected=[])
      @main.print_status("Called View")
  end
  # called when key '$' pressed
  def sort(curritem, listselected=[])
      labels=["?~Help  ","C~Cancel",   "N~[Name]", "X~eXtn  ",   "Z~siZe  ","D~Date  "]
      ret =  @main.askchoice(nil, "Choose type of sort, or 'R' to reverse current sort","N",labels,"?NCXZDR")
      case ret
      when 'n'
        @command = "/bin/ls -l"
        @main.populate_table
      when 'd'
        @command = "/bin/ls -lt"
        @main.populate_table
      when 'z'
        @command = "/bin/ls -lS"
        @main.populate_table
      when 'r'
        if @command[-1].chr == 'r'
          @command = @command[0..-2]
        else
          @command = @command+"r"
        end
        @main.populate_table
      end
      @main.clear_error
      @main.print_status("Chosen #{ret}")
  end
end

# This is the main class that does the row display and handling.
# It gives some basic table functionality - more will be added with time.
# Functions specific to the data, are provided by the datasource class

class Menuscr
  attr_reader :selecteditems
  attr_reader :my_form
  #attr_reader :my_form_win # we will need this soon


  def initialize(unused)

    @defaultwin = nil
    @log = Logger.new("app.log")  # should this not be for the whole app, passed ?
    @log.level = Logger::DEBUG
    @data_arr = []
    @event_listeners = []
    @current={}
    @rt_form = {}
    #@rt_hashes = YAML::load( File.open( 'gen2.yml' ) )
    @@form_status = nil;
    @selecteditems = []
    @baseno = @currno = 0
    @rows_to_show = 0
    @my_form = nil
    @labelarr=[{"position"=>[-4, 28], "color_pair"=>5, "text"=>"Copyright 2008, University of Antartica"}]
    # keys that will be passed in by datasource and loaded in here for quick ref
    @datakeys = nil
    @form={"header"=>[0, 0, "NcursesOnRails, V0.1 "]}
    # this is pathetic and needs to be redone. 2am kind of stuff.
    @key_labels=["<~Back",">~Open",  "P~Prev  ","N~Next", "-~PrevPage","Spc~NextPage", "_Q~Quit  "," ;~Select"]



    # instantiate a datasource
    @datasource = DirListing.new(self)
    add_event_listener(@datasource) 
    # he should add himself, but i am worried whether he can pass himself from the constructor.
  end

  # get current index in table/rows
  def get_curr_index
    @baseno + @currno
  end
  def get_curr_item
    @data_arr[get_curr_index()]
  end
  # not yet in use
  def add_event_listener(obj)
    @event_listeners << obj
  end

  def get_data()
    @datasource.get_data
  end

  def row_focus_gained(win, fields, ix, item)
    #act = item["message"]
    act = @datasource.get_key(item)
    # clear previous off - now its begun to block
    #print_this(win, "%*s" % [40,""], 5, Ncurses.LINES-1, 68)
    #print_this(win, "%s" % act.to_s[0,40], 6, Ncurses.LINES-1, 68)
    @datasource.row_focus_gained(get_curr_index(), item) 
  end

  # needs to be user-defined based on what kind of data comes in
  def format_line(menuctr,dataitem)
    sel =" "
    sel = "X" if @selecteditems.include?(menuctr)
    sel+@datasource.format_line(menuctr,dataitem)
  end

  # fields - internal fields array, dataarr - array of values
  # baseindex - start showing from what line
  # toshow - how many rows to show, should be same in each call.

  def scroll_lines(fields, dataarr, baseindex, toshow )
    i = 0
    baseindex.upto(baseindex + toshow -1) { |menuctr|
      if menuctr < 0 || menuctr >= dataarr.length
        return -1
      end
      dataitem = dataarr[menuctr]
      field = fields[i]
      field.user_object = dataitem
      field.set_field_buffer(0, format_line(menuctr,dataitem))
      i += 1
    }
    0
  end

  def field_init(my_form_win)
    x = @my_form.current_field
    ix = @fields.index(x)
    item = x.user_object
    @fields[ix].set_field_back(Ncurses.COLOR_PAIR(4))
    row_focus_gained(my_form_win, @fields, ix, item)
  end

  ###DEFS_COME_HERE###

  # main program which does the job. This is called by the menu program.

  def run
    
  ###PROCS_COME_HERE###
    
    begin
      @fields = Array.new

      # i need this to set the panel
      @data_key_arr =@datasource.get_keys_handled()

      #create a hash of keys for quick lookup on keypress, action mostly null
      # keys will be ascii values - no longer too much work for me here.
      @datakeys = {}
      @data_key_arr.each { |khash|
        @datakeys[khash[:keycode]]=khash[:action]
      }

      @baseno=0

      # change this to show more or less rows
      @rows_to_show = 12

      # change this to make the whole table start above or below.
      title_row= 6  # this is the start point.

      # change this if you want spaces between lines
      rowspace = 1 # (use 2 for doublespace)


      # change this only if you remove the hline/s.
      title_row_span = 3 # 2 lines plus title

      fieldlen = @datasource.field_length
     
      # XXX YYY
      @qfields = Array.new
      field = FIELD.new(1, 15, 1, 1, 0, 0)
      field.set_field_back(A_REVERSE)
      @qfields << field
      field = FIELD.new(1, 15, 1, 1, 0, 0)
      field.set_field_back(A_REVERSE)
      @qfields << field
      @qform = FORM.new(@qfields);
      qrows = Array.new()
      qcols = Array.new()
      @qform.scale_form(qrows, qcols);
      qform_win = WINDOW.new(title_row-4,0,title_row-1,50)
      qpanel = qform_win.new_panel
      Ncurses::Panel.update_panels
      qform_win.keypad(TRUE);
      @qform.set_form_win(qform_win);
      #derwincol = 12
      #subwin = my_form_win.derwin(rows[0], cols[0]+2, title_row-1, derwincol);

      Ncurses.refresh();

      @qform.post_form();
      qform_win.wrefresh();
      
     
      
      # only create the fields

      @baseno.upto(@rows_to_show) { |i|
        field = FIELD.new(1, fieldlen, i*rowspace+title_row_span, 1, 0, 0)
        field.field_opts_off(O_EDIT)
        field.field_opts_off(O_STATIC)
        @fields.push(field)
      }

      # Create the form and post it
      @my_form = FORM.new(@fields);

      # populate fields
      populate_table

      @my_form.user_object = "My identifier" ## DANG ! We've been looking for this !

      # Calculate the area required for the form
      rows = Array.new()
      cols = Array.new()
      @my_form.scale_form(rows, cols);

      # Create the window to be associated with the form 
      my_form_win = WINDOW.new(0,0,0,0)
      @defaultwin = my_form_win
      my_panel = my_form_win.new_panel
      Ncurses::Panel.update_panels

      my_form_win.bkgd(Ncurses.COLOR_PAIR(5));
      my_form_win.keypad(TRUE);

      # Set main window and sub window
      @my_form.set_form_win(my_form_win);
      derwincol = 12
      subwin = my_form_win.derwin(rows[0], cols[0]+2, title_row-1, derwincol);
      @my_form.set_form_sub(subwin)

      Ncurses.refresh();

      @my_form.post_form();

      my_form_win.wrefresh();

      print_screen_labels(my_form_win, @labelarr)

      header = @form["header"]
      posy = posx = 0
      htext = "<APPLICATION NAME>  <VERSION>  "
      posy, posx, htext = header if !header.nil?
      #print_header(htext, posy, posx)
      print_header(htext + " %15s "% @datasource.print_top_left + " %20s"%@datasource.print_top_center , posy, posx)
      print_top_right(@datasource.print_top_right(1))

      # offset 12 taken from derwin
      print_this(my_form_win, @datasource.format_titles, 5, title_row, derwincol)
      #my_form_win.mvwhline( title_row -1, derwincol+1, ACS_HLINE, cols[0])
      my_form_win.mvwhline( title_row +1, derwincol+1, ACS_HLINE, cols[0])
      subwin.box(0,0)

      add_to_application_labels(@data_key_arr)
      restore_application_key_labels
      
      stdscr.refresh();

      field_init_proc = proc {
        field_init(my_form_win) # this needs to be called by keys too
      }
      field_term_proc = proc {
        x = @my_form.current_field
        ix = @fields.index(x)
        @fields[ix].set_field_back(A_NORMAL)
      }

      @my_form.set_field_init(field_init_proc)
      @my_form.set_field_term(field_term_proc)
      @my_form.form_driver(REQ_FIRST_FIELD);
      # Loop through to get user requests
      @currno = 1
      while((ch = my_form_win.getch()) != 197 )
        clear_error
        case ch
        when KEY_DOWN, 110 # 'n'
          handle_key_down
        when KEY_UP, 112   # p
          handle_key_up
        when 32 # space
          handle_space
        when 45 # minus
          handle_minus
        when KEY_ENTER, 10, 46, 62 # . >
          # selection
          handle_enter
        when ","[0], "<"[0]
          # prev screen
          break
        when 59 # ;
          handle_semicolon(@my_form,get_curr_index(), get_curr_item()) 
        else
          # we check against the keys installed by datasource
          #should be checking all event_listeners. but shortcut for now
          #consumed=@datasource.handle_keys(ch, get_curr_item(), @selecteditems)
          consumed=handle_keys(ch, get_curr_item(), @selecteditems)
          if !consumed
            print_error( sprintf("[Command %c (%d) is not defined for this screen]   ", ch,ch))
          end
        end
     
        print_top_right(@datasource.print_top_right(get_curr_index))
      end # while getch loop
    ensure
      # Un post form and free the memory
      @my_form.unpost_form();
      @my_form.free_form();
      @fields.each {|f| f.free_field()}
    end
  end

  # should be put in index or item FIXME , currindex is +1
  #select current field
  
  def handle_semicolon(my_form,currindex, curritem)
    if @selecteditems.include?currindex-1
      @selecteditems.delete(currindex-1)
      print_status("Row #{currindex} UNselected")
    else
      @selecteditems << currindex-1
      print_status("Row #{currindex} selected")
    end
    field = my_form.current_field
    field.set_field_buffer(0, format_line(currindex-1,field.user_object))
    next_row
  end

    # Go to next field */
  def handle_key_down
    if @currno < @rows_to_show
      @currno += 1
      @my_form.form_driver(REQ_NEXT_FIELD);
    else
      #scroll
      if @baseno+@rows_to_show < @data_arr.length() 
        @baseno += 1
        scroll_lines(@fields, @data_arr, @baseno, @rows_to_show)
        field_init(@defaultwin)
      else
        print_error( "No more rows")
      end
    end
    #print_this(my_form_win, @currno.to_s + "," + @baseno.to_s, 6, Ncurses.LINES-1, 69)
  end
  alias :next_row :handle_key_down 

  # Go to previous field
  def handle_key_up
    # Go to previous field
    if @currno > 1
      @currno -= 1
      @my_form.form_driver(REQ_PREV_FIELD);
    else
      #scroll
      if @baseno > 0
        @baseno -= 1
        scroll_lines(@fields, @data_arr, @baseno, @rows_to_show)
        field_init(@defaultwin)
      else
        print_error("Already at start of index")
      end
    end
    #print_this(my_form_win, @currno.to_s + "," + @baseno.to_s, 6, Ncurses.LINES-1, 69)
  end

  #scroll page down
  def handle_space
    if @baseno+@rows_to_show < @data_arr.length() 
      incr = [@data_arr.length - (@baseno+@rows_to_show), @rows_to_show].min
      @baseno += incr
      scroll_lines(@fields, @data_arr, @baseno, @rows_to_show)
      field_init(@defaultwin)
    else
      print_error( "No more rows")
    end
  end
  
    #scroll page up
  def handle_minus
    if @baseno > 0
      incr = [@baseno, @rows_to_show].min
      @baseno -= incr
      scroll_lines(@fields, @data_arr, @baseno, @rows_to_show)
      field_init(@defaultwin)
    else
      print_error( "Already at start of index")
    end
  end
  
  # selection
  def handle_enter
    x = @my_form.current_field
    ix = @fields.index(x)
    item = x.user_object
    status = @datasource.on_selection(get_curr_index(), item)  
  end

  # unhandled keys are passed to other listeners

  def handle_keys(ch, curritem, listselected=[])
    return false if @datakeys.nil?
    suffix=ch.chr.upcase
    chup=suffix[0] # will break in 1.9
    if @datakeys.include?chup
      if @datakeys[chup] == nil
        @datasource.send("handle_#{suffix}", curritem, listselected)
      else
        @datasource.send(@datakeys[chup], curritem, listselected)
      end
      return true
    end
    return false
  end

  # this method is called once when the table starts up.
  # if datasource modifies data, like sorting, rerunning etc
  # it must call this. 
  def populate_table
      @data_arr = @datasource.get_data
      scroll_lines(@fields, @data_arr, @baseno, @rows_to_show)
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

    f = Menuscr.new(nil)
    f.run

  ensure
    Ncurses.endwin();
  end
end

