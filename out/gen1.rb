#!/usr/bin/env ruby
#######################################################
# Template file used to generate ncurses screen
# $Id: gen1.rb,v 0.2 2008/09/19 15:25:07 arunachala Exp $
#
#
#######################################################
require 'rubygems'
require 'ncurses'
require 'yaml'

include Ncurses
include Ncurses::Form


# returns control, alt, alt+ctrl, alt+control+shift etc
def getchar win
  while 1 
    ch = win.getch
    if ch == -1
      if @stack.first == 27
        @stack.clear
        return 27
      end
      @stack.clear
      next
    end
    if @stack.first == 27
      ch = 128 + ch
      @stack.clear
      return ch
    end
    if ch == 27
      @stack << 27
      next
    end
    return ch
  end
end
def update_struct(fldname, value)
  @current[fldname]=value
end
## prints status text for fields, or actions/events.
def print_status(win, text)
  if(win == nil)
    win = stdscr;
  end
  color=Ncurses.COLOR_PAIR(1);
  win.attron(color);
  win.mvprintw(21, 2, "Status: %-40s" % text);
  win.attroff(color);
  win.refresh
end
## prints help text for fields, or actions/events.
def print_help(win, text)
  if(win == nil)
    win = stdscr;
  end
  color=Ncurses.COLOR_PAIR(2);
  win.attron(color);
  win.mvprintw(20, 2, "%-40s" % text);
  win.attroff(color);
  win.refresh
end
def print_in_middle(win, starty, startx, width, string, color)

  if(win == nil)
    win = stdscr;
  end
  x = Array.new
  y = Array.new
  Ncurses.getyx(win, y, x);
  if(startx != 0)
    x[0] = startx;
  end
  if(starty != 0)
    y[0] = starty;
  end
  if(width == 0)
    width = 80;
  end
  length = string.length;
  temp = (width - length)/ 2;
  x[0] = startx + temp.floor;
  win.attron(color);
  win.mvprintw(y[0], x[0], "%s", string);
  win.attroff(color);
  Ncurses.refresh();
end
def form_changed(bool)
  @@form_status=bool;
end
def form_changed?
  @@form_status
end

fields = Array.new
@current={}
@@form_status = nil;
form_changed(false);
rt_form = {}
rt_hashes = YAML::load( File.open( 'gen1.yml' ) )
#rt_fields = YAML::load( File.open( 'fields.yml' ) )
#rt_form = YAML::load( File.open( 'form.yml' ) )
  rt_fields=["from", "rate", "qty", "state_code", "numbers", "nickname", "enumcheck"]
  rt_form={"win_bkgd"=>[3], "save_path"=>["out.txt"], "title"=>["My Formy"], "save_format"=>["txt"], "title_color"=>[3]}
###PROCS_COME_HERE###
  states = {"MI" => "Michigan",
            "VA" => "Virginia",
            "VE" => "Vermont"}
  
  mycharcheck = proc { |ch|
    if (('A'..'Z').include?(ch))
      return true
    else
      return false
    end
  }
  myfieldcheck = proc { |afield|
      val = afield.field_buffer(0)
      val.strip!
      if (states[val] != nil) 
        afield.set_field_buffer(0,states[val])
        return true
      else
        return false
      end
    }


# Initialize curses
begin
  stdscr = Ncurses.initscr();
  Ncurses.start_color();
  Ncurses.raw();
  Ncurses.keypad(stdscr, true);
  Ncurses::halfdelay(tenths = 10)

  Ncurses.noecho();
  trap("INT") {  }



  ### FORM_TEXT_HERE
  # just in case user does not specify, I need some defaults
  Ncurses.init_pair(1, COLOR_RED, COLOR_BLACK)
  Ncurses.init_pair(2, COLOR_BLACK, COLOR_WHITE)
  Ncurses.init_pair(3, COLOR_BLACK, COLOR_BLUE)
  
  # Initialize few color pairs 
#  Ncurses.init_pair(1, COLOR_RED, COLOR_BLACK)
#  Ncurses.init_pair(2, COLOR_WHITE, COLOR_BLACK)
#  Ncurses.init_pair(3, COLOR_WHITE, COLOR_BLUE)
  ###  
  stdscr.bkgd(Ncurses.COLOR_PAIR(2));

  # Initialize the fields
  ###- INIT FIELDS
  #field = FIELD.new(1, 20, Ncurses.LINES - 3, 2, 0, 0) 
#  field = FIELD.new(1, 50, 20, 2, 0, 0) 
#  field.set_field_back(A_REVERSE) 
#  field.field_opts_off( O_ACTIVE); # This field is a static label */
#  field.set_field_just( JUSTIFY_CENTER); # Center Justification */
#  field.set_field_buffer( 0, "This is help text. Alt-h for field specific help");  
#  sysfields.push(field) 

  
  
  
  #from
  
  field = FIELD.new(1, 10, 2, 1, 0, 0)
  field.set_field_back(A_UNDERLINE)
  
  
  # This loop checks to see if user has specified just, fore, pad or 
  # field_just, field_fore or field_pad, and if so sets the same.
  
  
  
  
  fields.push(field)
  
  
  
  #rate
  
  field = FIELD.new(1, 10, 4, 1, 0, 0)
  field.set_field_back(A_UNDERLINE)
  
  
  # This loop checks to see if user has specified just, fore, pad or 
  # field_just, field_fore or field_pad, and if so sets the same.
  
  
  
  
  fields.push(field)
  
  
  
  #qty
  
  field = FIELD.new(1, 10, 6, 1, 0, 0)
  field.set_field_back(A_UNDERLINE)
  
  
  # This loop checks to see if user has specified just, fore, pad or 
  # field_just, field_fore or field_pad, and if so sets the same.
  
  
  
  
  fields.push(field)
  
  
  
  #state_code
  
  field = FIELD.new(1, 10, 8, 1, 0, 0)
  field.set_field_back(A_UNDERLINE)
  
  
  # This loop checks to see if user has specified just, fore, pad or 
  # field_just, field_fore or field_pad, and if so sets the same.
  
  
  
  
  fields.push(field)
  
  
  
  #numbers
  
  field = FIELD.new(1, 10, 10, 1, 0, 0)
  field.set_field_back(A_UNDERLINE)
  
  
  # This loop checks to see if user has specified just, fore, pad or 
  # field_just, field_fore or field_pad, and if so sets the same.
   field.set_field_just(JUSTIFY_RIGHT); 
  
   field.set_field_fore(Ncurses.COLOR_PAIR(1)); 
  
  
  
  fields.push(field)
  
  
  
  #nickname
  
  field = FIELD.new(1, 10, 12, 1, 0, 0)
  field.set_field_back(A_UNDERLINE)
  
  
  # This loop checks to see if user has specified just, fore, pad or 
  # field_just, field_fore or field_pad, and if so sets the same.
  
  
  
  
  fields.push(field)
  
  
  
  #enumcheck
  
  field = FIELD.new(1, 10, 14, 1, 0, 0)
  field.set_field_back(A_UNDERLINE)
  
  
  # This loop checks to see if user has specified just, fore, pad or 
  # field_just, field_fore or field_pad, and if so sets the same.
  
  
  
  
  fields.push(field)
  



  
  
  
  #from
  
    fields[0].set_field_type(TYPE_ALNUM, 0);
    
    
  
  
  #rate
  
    
    fields[1].set_field_type(TYPE_NUMERIC, 2,0,1000 );
    fields[1].set_field_just(JUSTIFY_RIGHT)
    
    
  
  
  #qty
  
    
    fields[2].set_field_type(TYPE_INTEGER, 2,0,1000 );
    fields[2].set_field_just(JUSTIFY_RIGHT)
    
    
  
  
  #state_code
  
      customtype3 = FIELDTYPE.new(myfieldcheck,mycharcheck)
      fields[3].set_field_type(customtype3);
      
    
  
  
  #numbers
  
      fields[4].set_field_type(TYPE_REGEXP, "^ *[0-9]* *$");
    
    
  
  
  #nickname
  
    fields[5].set_field_type(TYPE_ALPHA, 0);
    
    
  
  
  #enumcheck
  
    fields[6].set_field_type(TYPE_ENUM, ["one","two","three"],false,false );
    
    
  ###- SET FIELDS


  # Create the form and post it
  my_form = FORM.new(fields);

  my_form.user_object = "My identifier"

  # Calculate the area required for the form
  rows = Array.new()
  cols = Array.new()
  my_form.scale_form(rows, cols);

  # Create the window to be associated with the form 
  my_form_win = WINDOW.new(rows[0] + 3, cols[0] + 14, 1, 1);
  my_form_win.bkgd(Ncurses.COLOR_PAIR(3));
  my_form_win.keypad(TRUE);

  # Set main window and sub window
  my_form.set_form_win(my_form_win);
  my_form.set_form_sub(my_form_win.derwin(rows[0], cols[0], 2, 12));

  # Print a border around the main window and print a title */
  my_form_win.box(0, 0);
  print_in_middle(my_form_win, 1, 0, cols[0] + 14, "My Formy", Ncurses.COLOR_PAIR(3));

  stdscr.mvprintw(2, 45, Time.now.strftime("%Y/%m/%d %H:%M.%S"))
  my_form.post_form();

  # Print field labels
  ###- FIELD LABELS and defaults too
    # I am throwing in default value placement in this loop as too much redirection
    # involved in each loop
  
     my_form_win.mvaddstr(4, 2 , "From")
    
     my_form_win.mvaddstr(6, 2 , "rate")
    
    fields[1].set_field_buffer(0,rand(1000).to_s)
    fields[1].set_field_status(false) # won't be seen as modified
    
     my_form_win.mvaddstr(8, 2 , "Qty")
    
    fields[2].set_field_buffer(0,120.to_s)
    fields[2].set_field_status(false) # won't be seen as modified
    
     my_form_win.mvaddstr(10, 2 , "State code")
    
    fields[3].set_field_buffer(0,states.keys.first.to_s)
    fields[3].set_field_status(false) # won't be seen as modified
    
     my_form_win.mvaddstr(12, 2 , "numbers")
    
     my_form_win.mvaddstr(14, 2 , "nickname")
    
     my_form_win.mvaddstr(16, 2 , "enumcheck")
    
  
  print_help(stdscr,"Help text will come here");

  my_form_win.wrefresh();
  my_form.set_current_field(fields[0]);  
  my_form.form_driver(REQ_FIRST_FIELD);

  saveproc = proc {
      outdata = Hash.new
      ctr = 0; 
      fields.each {|f| outdata[rt_fields[ctr]]=f.field_buffer(0); ctr+=1 }
  #    outdata.delete(rt_fields[0]) ; # remove help field FIXME move help to another independent field
      filename = rt_form["save_path"][0] || 'out.txt'
      #sysfields[0].set_field_buffer(0,"Saving data to #{filename}");
      print_status(stdscr,"Saving data to #{filename}");
      if rt_form["save_format"][0]=='yml'
        File.open(filename || "out.yml", "w") { | f | YAML.dump( outdata, f )} 
      else
        str = ''
        rt_fields.each_index{ |i| 
          fn = rt_fields[i]
          value = outdata[fn]
          str << fn +": "+value + "\n"
        }
        str << "\n"
        File.open(filename, "a") {|f| f.puts(str) }
      end
      print_status(stdscr,"Saved data to #{filename}  ");
      my_form.set_current_field(fields[0]);  
      my_form.form_driver(REQ_FIRST_FIELD);
  }
  helpproc = proc { 
    x = my_form.current_field
    ix = fields.index(x)
    fldname = rt_fields[ix] 
    h = rt_hashes[fldname]
      text = ''; case ix 
       when 0 # from 
        #found text
      text = "Enter only #{h['width']} letters"
       
     when 1 # rate 
      # attempting range
        text = 'Valid: 0 - 1000'  
     when 2 # qty 
       # trying eval else delaying till runtime 
       text = 'Valid: 0 - 1000'  
     when 3 # state_code 
       # trying eval else delaying till runtime 
       text =  'Valid: ' + states.keys.join(", ")  
     when 4 # numbers 
       text = '^ *[0-9]* *$'   
     when 5 # nickname 
       # trying eval else delaying till runtime 
       text = 'abcdefghijklmnopqrstuvwxyz'  
     when 6 # enumcheck 
       # trying eval else delaying till runtime 
       text = 'Valid: ["one","two","three"]'  
    
          end
          print_help(stdscr,text.to_s) 
  }
  field_init_proc = proc {
    helpproc.call
  }
  field_term_proc = proc {
    x = my_form.current_field
    ix = fields.index(x)
    fldname = rt_fields[ix] 
    h = rt_hashes[fldname]
    value = x.field_buffer(0)
    if x.field_status == true
      value.strip!
      # call specific procs if exist TODO
      if h.include?"valid"
        if value.match(h["valid"][0])
          print_status(nil, "OK: #{value} pass #{h['valid']}")
        else
          print_status(nil, "ERROR: #{value} does not pass #{h['valid']}")
          my_form.set_current_field(x);
          x.set_field_status(true);
          return
        end
      end
      update_struct(fldname, x.field_buffer(0))
      form_changed(true);
    end
    #print_status(stdscr,"Exited #{fldname} modified: #{x.field_status}")
    x.set_field_status(false);
  }
  form_init_proc = proc {
    print_status(stdscr,"Inside form_init_proc")
  }
  form_term_proc = proc {
    print_status(stdscr,"Inside form_term_proc")
  }
  my_form.set_field_init(field_init_proc)
  my_form.set_field_term(field_term_proc)
  my_form.set_form_init(form_init_proc)
  my_form.set_form_term(form_term_proc)

  stdscr.mvprintw(Ncurses.LINES - 2, 28, "Use UP, DOWN arrow keys. Alt-h for help.");
  stdscr.mvprintw(Ncurses.LINES - 1, 28, "^Q Quit ^X Save");
  stdscr.refresh();

  # Loop through to get user requests unless 147 == alt Q
  @stack =  []
  #while((ch = my_form_win.getch()) )
  while((ch = getchar(my_form_win)))
    case ch
    when -1
      next
    when KEY_DOWN
      # Go to next field */
      my_form.form_driver(REQ_VALIDATION);
      my_form.form_driver(REQ_NEXT_FIELD);
      # Go to the end of the present buffer
      # Leaves nicely at the last character
      my_form.form_driver(REQ_END_LINE);

    when KEY_UP
      # Go to previous field
      my_form.form_driver(REQ_VALIDATION);
      my_form.form_driver(REQ_PREV_FIELD);
      my_form.form_driver(REQ_END_LINE);

    when KEY_LEFT
      # Go to previous field
      my_form.form_driver(REQ_PREV_CHAR);

    when KEY_RIGHT
      # Go to previous field
      my_form.form_driver(REQ_NEXT_CHAR);

    when KEY_BACKSPACE,127
      my_form.form_driver(REQ_DEL_PREV);
    when KEY_F1, ?\M-h
      helpproc.call
    when 24  # c-x
      saveproc.call
      form_changed(false)
      # save method
    when 25  # c-y
      print_status(stdscr,"SAVE as YAML");
    when ?\C-q, ?\C-w # alt-Q alt-q
      if form_changed? == true
        print_status(stdscr,"Form was changed. Wish to save?")
        yn=''
        yn = my_form_win.getstr(yn)
        if yn =~ /[Yy]/
          saveproc.call
          form_changed(false)
          next
        else
          break
        end
      else
      #  print_status(stdscr,"Form was not changed. Wish to exit?")
      #  ch = my_form_win.getch()
        break
      end
    else

      # If this is a normal character, it gets Printed    
      stdscr.mvprintw(Ncurses.LINES - 2, 18, "["+ch.to_s+"]");
      stdscr.mvprintw(Ncurses.LINES - 1, 18, "[%3d, %c] %s   ", ch, ch, @stack.inspect);
      #stdscr.mvprintw(Ncurses.LINES - 1, 18, "C-x Save");

      stdscr.refresh();
      my_form.form_driver(ch);
    end
  end
  # Un post form and free the memory
  my_form.unpost_form();
  my_form.free_form();
  fields.each {|f| f.free_field()}


ensure
  Ncurses.endwin();
end
