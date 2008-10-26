#!/usr/bin/ruby

require 'rubygems'
require 'ncurses'
require 'logger'
require 'commons1'
require 'sqlite3'

include Ncurses
include Ncurses::Form
# this has some of the UI like askyesno, print etc.
include Commons1

class DirListing
  attr_reader :field_length
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
  def get_data
    @rows = @db.execute(@command)

    #@str = %x[#{@command}] 
    #@data_arr = @str.split("\n")
    #@data_arr.shift # that total line, we don't want it
    @data_arr = @rows
  end
  def format_line(menuctr,dataitem)
    parts = []
    parts[0],parts[1] = dataitem
      sprintf("%3d %-30s %-30s", menuctr+1, parts[0], parts[1])
      #sprintf("%3d %10d %-12s %-40s ",menuctr+1, parts[4], parts[5..7].join(" "),parts[8])
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
  def print_top_right(currindex)
    "%2d of %3d urls " % [ currindex, @data_arr.length]
  end
  # something like a level 1 heading
  def print_top_left
    "Search"
  end
  # something like a level 2 heading
  def print_top_center
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
  # listselected is an array of offsets - i think!
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
    qfields = @main.get_query_fields()
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
    qfields = @main.get_query_fields()
    @command = @sqlstring + create_search_string(qfields)
    #@command = @sqlstring + wherecondstr
    @main.print_status("#{@command}")
    @main.populate_table
  end
end

# This is the main class that does the row display and handling.
# It gives some basic table functionality - more will be added with time.
# Functions specific to the data, are provided by the datasource class

class Mrows3
  attr_reader :selecteditems
  attr_reader :my_form
  #attr_reader :my_form_win # we will need this soon


  def initialize(unused)

    @table_width=16
    @defaultwin = nil
    @bottom_win = nil # where the keys are printed
    @header_win = nil # where the keys are printed
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
      # the next check of datarr length means that some fields can be left dirty
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
    if !item.nil? # XXX 2008-09-29 15:45 
      if x.field_buffer(0) != ""
        @fields[ix].set_field_back(Ncurses.COLOR_PAIR(4))
        row_focus_gained(my_form_win, @fields, ix, item)
      end
    end
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
      title_row= 1  # this is the start point.

      # change this if you want spaces between lines
      rowspace = 1 # (use 2 for doublespace)


      # change this only if you remove the hline/s.
      title_row_span = 3 # 2 lines plus title XXX for 2 fields

      fieldlen = @datasource.field_length
     
      # XXX YYY
      @qfields = Array.new
      qform_row1 = 1 # 2 2008-09-29 23:38 
      qform_col = 25
      qform_fwidth = 30
      field = FIELD.new(1, qform_fwidth, qform_row1, qform_col, 0, 0)
      field.set_field_back(A_REVERSE)
      @qfields << field
      field = FIELD.new(1, qform_fwidth, qform_row1+1, qform_col, 0, 0)
      field.set_field_back(A_REVERSE)
      @qfields << field
      @qform = FORM.new(@qfields);
      qrows = Array.new()
      qcols = Array.new()
      @qform.scale_form(qrows, qcols);

      qform_win = WINDOW.new(4,Ncurses.COLS, 1, 0) # 0->1, 5->4 2008-09-29 23:38 
      qpanel = qform_win.new_panel
      Ncurses::Panel.update_panels
      qform_win.keypad(TRUE);
      @qform.set_form_win(qform_win);
      #derwincol = 12
      #subwin = my_form_win.derwin(rows[0], cols[0]+2, title_row-1, derwincol);

      @header_win = WINDOW.new(1,0,0,0)
      header_panel = @header_win.new_panel
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
      #qform_win = WINDOW.new(5,Ncurses.COLS-2, 2, 0)
      #my_form_win = WINDOW.new(@rows_to_show+4,0,8,0)
      # we try to position the window as low as we can
      startrow = [5,@table_width-(@rows_to_show+1) ].max
      my_form_win = WINDOW.new(@table_width,0,startrow ,0)
      my_panel = my_form_win.new_panel
      #my_form_win = WINDOW.new(@table_width,0,startrow,0)
      @defaultwin = my_form_win
      # unable to make it 3, can't write to line 0 ??? XXX FIXME
      @bottom_win = WINDOW.new(4,0,Ncurses.LINES-4,0)
      bottom_panel = @bottom_win.new_panel
      #@bottom_win.mvwhline( 1, 0, ACS_HLINE, 10)
      Ncurses::Panel.update_panels

      my_form_win.bkgd(Ncurses.COLOR_PAIR(5));
      my_form_win.keypad(TRUE);

      # Set main window and sub window
      @my_form.set_form_win(my_form_win);
      derwincol = 5 # 12
      subwin = my_form_win.derwin(rows[0], cols[0]+2, 0, derwincol);
      @my_form.set_form_sub(subwin)

      Ncurses.refresh();

      @my_form.post_form();

      # LABELS
      qform_win.mvaddstr(qform_row1,   derwincol , "Title")
      qform_win.mvaddstr(qform_row1+1, derwincol , "URL")
      qform_win.mvaddstr(qform_row1+1, derwincol+qform_fwidth+qform_col , "Press ENTER to run query")
      my_form_win.wrefresh();

      print_screen_labels(my_form_win, @labelarr)

      header = @form["header"]
      posy = posx = 0
      htext = "<APPLICATION NAME>  <VERSION>  "
      posy, posx, htext = header if !header.nil?
      #print_header(htext, posy, posx)
      print_header(htext + " %15s "% @datasource.print_top_left + " %20s"%@datasource.print_top_center , posy, posx)
      print_top_right( @datasource.print_top_right(1))

      # offset 12 taken from derwin
      print_this(my_form_win, @datasource.format_titles, 5, title_row, derwincol)
      #my_form_win.mvwhline( title_row -1, derwincol+1, ACS_HLINE, cols[0])
      my_form_win.mvwhline( title_row+1, derwincol+1, ACS_HLINE, cols[0])
      subwin.box(0,0)
      subwin.wrefresh(); # without this it wont paint till much later
      @header_win.wrefresh();

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
      @qform.form_driver(REQ_FIRST_FIELD);
      # Loop through to get user requests
      @currno = 1
      @intable = false
      @qform.set_current_field(@qfields[0])
      while((ch = qform_win.getch()) != 197 )
        clear_error
        @intable = !@intable if ch==9 # tab
        if @intable == false
          case ch
          when KEY_BACKSPACE, 127  # command mode
            @qform.form_driver(REQ_DEL_PREV);
          when KEY_LEFT
            @qform.form_driver(REQ_PREV_CHAR);
          when KEY_RIGHT
            @qform.form_driver(REQ_NEXT_CHAR);
          when 1  # c-a
            @qform.form_driver(REQ_BEG_LINE);
          when 5  # c-e
            @qform.form_driver(REQ_END_LINE);
          when -1  # c-c
            @qfields.each{ |fld| fld.set_field_buffer(0,"") }
            @qform.form_driver(REQ_FIRST_FIELD);
      
          when KEY_UP
            @qform.form_driver(REQ_PREV_FIELD);
            @qform.form_driver(REQ_END_LINE);
          when KEY_DOWN
            @qform.form_driver(REQ_NEXT_FIELD);
            @qform.form_driver(REQ_END_LINE);
          when KEY_ENTER, 10 # 
            # selection
            @qform.form_driver(REQ_NEXT_FIELD);
            handle_search
            Ncurses::Panel.update_panels();
            Ncurses.doupdate();
            @qform.form_driver(REQ_FIRST_FIELD);
            @qform.form_driver(REQ_END_LINE);
          else
          #  stdscr.refresh # is thsi required ??
          @qform.form_driver(ch)
          end
          #print_error("Press TAB for command mode")
          #Ncurses::Panel.update_panels(); # this was robbing the cursor XXX
          #Ncurses.doupdate();
          next
        end
        if ch==9 # tab
          print_error("Press TAB for input mode")
          next
        end
        case ch
        #when 48..57,65..90,97..122

        when KEY_DOWN, 110 # 'n'
          handle_key_down
        when KEY_UP, 112   # p
          handle_key_up
        when KEY_LEFT
          @my_form.form_driver(REQ_PREV_CHAR); # XXX new definitions for horiz scrolling
        when KEY_RIGHT
          @my_form.form_driver(REQ_NEXT_CHAR);
        when 6 # c-f
          @my_form.form_driver(REQ_NEXT_WORD);
        when 2 # c-b
          @my_form.form_driver(REQ_PREV_WORD);
        when 1  # c-a
          @my_form.form_driver(REQ_BEG_LINE);
        when 5  # c-e
          @my_form.form_driver(REQ_END_LINE);
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
          #@qform.form_driver(ch)
        end
        # by moving next line above updates, now the cursor is not shown
        # at line 2,0 XXX
        print_top_right( @datasource.print_top_right(get_curr_index))
        Ncurses.doupdate();
        Ncurses::Panel.update_panels();
        Ncurses.doupdate();
        subwin.box(0,0) # OMG !!! I have to put this or the bottom keeps vanishing
        subwin.wrefresh(); # without this the border was getting eaten up on scroll
        # down at times when the form is large.
                     
     
      end # while getch loop
    ensure
      # Un post form and free the memory
      @my_form.unpost_form();
      @my_form.free_form();
      @qform.unpost_form();
      @qform.free_form();
      @fields.each {|f| f.free_field()}
      @qfields.each {|f| f.free_field()}
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

    if @currno >= @data_arr.length # XXX 2008-09-29 16:01 
      return
    end
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
    begin # XXX fails with left and rt arrow what if someones wants to trap ?
    suffix=ch.chr.upcase 
    rescue 
      return false
    end
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
      clear_fields(@fields)
      @selecteditems = [] # XXX
      scroll_lines(@fields, @data_arr, @baseno, @rows_to_show)
      # 2008-09-30 00:04 should immediately update headers
      print_top_right(@datasource.print_top_right(get_curr_index))
  end
  def clear_fields(fields)
    fields.each{ |ff| ff.set_field_buffer(0,""); ff.user_object=nil; }
  end
  def handle_search
    #@datasource.search(@qfields)
    @datasource.search(get_curr_index(), get_curr_item())  
  end
  def get_query_fields
    queryflds = []
    @qfields.each{ |qq| queryflds << qq.field_buffer(0) }
    queryflds
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

    f = Mrows3.new(nil)
    f.run

  ensure
    Ncurses.endwin();
  end
end

