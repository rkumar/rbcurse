#!/usr/bin/env ruby
#######################################################
# Template file used to generate ncurses screen/application
# $Id: gen3.rb,v 0.2 2008/09/22 17:35:27 arunachala Exp arunachala $
#
#
#######################################################
require 'rubygems'
require 'ncurses'
require 'yaml'

include Ncurses
include Ncurses::Form

# default save as text, if user has not specified a format
def save_as_text (filename, outdata)
  str = ''
  @rt_fields.each{ |fn| 
    value = outdata[fn]
    str << "#{fn}: #{value}\n"
  }
  str << "\n"
  File.open(filename, "a") {|f| f.puts(str) }
end
# default save as yaml, can be overridden by user
def save_as_yaml (filename, outdata)
  File.open(filename || "out.yml", "w") { | f | YAML.dump( outdata, f )} 
end
## a multi-line field rejects text containing newlines.
#  So we split incoming text on newline, then pad it to the width of the
# field so it looks just as expected.
# lines longer than width are split and then padded.
# 2008-09-22 19:28 
def text_to_multiline(text, width)
  lines = text.split("\n")
  lines.map!{ |line|  
    if line.length <= width
      sprintf("%-#{width}s", line) 
    else
      sublines = line.scan(/.{1,#{width}}/)
      sublines.map!{ |sline| sprintf("%-#{width}s", line)  }
      sublines.join
    end
  }
  text = lines.join
  text
end


## used for formatting what was entered in a multi-line field
# in order to save as file, or post out
def multiline_format(text, width)
  # ncurses pads each row with spaces rather than put a newline. Very annoying.
  lines = text.scan(/.{1,#{width}}/)
  lines.map{|l| l.strip!}
  lines = lines.join("\n")
  lines
end
# returns current field hash, convenience method
def get_current_field_hash(form, fields)    
    x = form.current_field
    ix = fields.index(x)
    fldname = @rt_fields[ix] 
    h = @rt_hashes[fldname]
    h
end 

## returns the attribute of a field - only one
# which is good for *most* fields 
# but *not* for fieldtype, opts_on, opts_off, observes and a couple more
# returns nil if no such attribute
def get_current_field_attr_scalar(form, fields, attrib)
  fhash = get_current_field_hash(form, fields)    
  value = fhash[attrib][0] if fhash.include?attrib
  value
end
## returns an array of attributes
# can be used for opts, observes, fieldtype etc
def get_current_field_attrs(form, fields, attrib)
  fhash = get_current_field_hash(form, fields)    
  value = fhash[attrib] if fhash.include?attrib
  value
end

## resets all fields as well as current hash.
# If another hash is supplied it should set its values in
def set_defaults(fields, anotherhash)
  clear_current_values
  @rt_hashes.each { |fn, fhash|
    fielddef = ''
    index = fhash["index"]
    if fhash.include?"default"
      fielddef = fhash["default"][0]
      if fielddef != nil
        fielddef = eval(fielddef) #rescue fielddef
      end
    end
    if anotherhash!= nil
      if anotherhash.include?fn
        fielddef = anotherhash[fn]
      end
    end
    fields[index].set_field_buffer(0,fielddef.to_s)
    update_current_value(fn, fielddef.to_s)
    fields[index].set_field_status(false) # won't be seen as modified
  }
      print_status(stdscr," " * 40);
end
def clear_current_values
  @current = {}
end
def update_current_value(fldname, value)
  @current[fldname]=value
end
def get_current_values
  @current
end
# get the value of a field using its fieldname
def getv(fldname)
  @current[fldname]
end
## prints status text for fields, or actions/events.
def print_status(win, text)
  print_this(win, text, 1, 21, 2)
end
## prints help text for fields, or actions/events.
def print_help(win, text)
  print_this(win, text, 2, 20, 2)
end
def print_this(win, text, color, x, y)
  if(win == nil)
    win = stdscr;
  end
  color=Ncurses.COLOR_PAIR(color);
  win.attron(color);
  win.mvprintw(x, y, "%-40s" % text);
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
## check each field
# is it observing any others
# if yes, then register itself as an observer
# in the notify list of the other field
def setup_observers()
  @rt_hashes.each { |fldname, fhash|
    if fhash.include?"observes"
      watching = fhash["observes"]
      watching.each { |w|
        if !@rt_hashes[w.to_s].include?"notifies"
          @rt_hashes[w.to_s]["notifies"] = []
        end
        @rt_hashes[w.to_s]["notifies"] << fldname
      }
    end
  }
end
def notify_observers(fldname, fields)
  observers = @rt_hashes[fldname]["notifies"]
  return if !observers
  observers.each{ |oname|
    fhash = @rt_hashes[oname]
    update_func = fhash["update_func"][0]
    print_status(nil, update_func)
    value = eval(update_func) #rescue 0;
    update_current_value(oname, value.to_s)
    fields[fhash["index"]].set_field_buffer(0,value.to_s)
  }
end

fields = Array.new
@current={}
@@form_status = nil;
form_changed(false);
@rt_form = {}
@rt_hashes = YAML::load( File.open( 'gen3.yml' ) )
#rt_fields = YAML::load( File.open( 'fields.yml' ) )
#rt_form = YAML::load( File.open( 'form.yml' ) )
@rt_fields=["item", "rate", "qty", "state_code", "total", "date"]
@rt_form={"win_bkgd"=>[3], "save_path"=>["out3.txt"], "title"=>["Dependent Fields"], "save_format"=>["txt"], "title_color"=>[3]}
###PROCS_COME_HERE###
  @@states = {"MI" => "Michigan",
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
      if (@@states[val] != nil) 
        afield.set_field_buffer(0,@@states[val])
        return true
      else
        return false
      end
    }


# Initialize curses
begin
  setup_observers()
  stdscr = Ncurses.initscr();
  Ncurses.start_color();
  Ncurses.cbreak();
  Ncurses.keypad(stdscr, true);
  Ncurses.noecho();
  trap("INT") {  }



  ### FORM_TEXT_HERE
  # just in case user does not specify, I need some defaults
  Ncurses.init_pair(1, COLOR_RED, COLOR_BLACK)
  Ncurses.init_pair(2, COLOR_WHITE, COLOR_BLACK)
  Ncurses.init_pair(3, COLOR_WHITE, COLOR_BLUE)
  
  # Initialize few color pairs 
  Ncurses.init_pair(1, COLOR_RED, COLOR_BLACK)
  Ncurses.init_pair(2, COLOR_WHITE, COLOR_BLACK)
  Ncurses.init_pair(3, COLOR_WHITE, COLOR_BLUE)
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

  
  
  
  #item
  
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
  
  
  
  #total
  
  field = FIELD.new(1, 10, 10, 1, 0, 0)
  
  field.set_field_back(A_UNDERLINE)
  
   field.field_opts_off(O_ACTIVE); 
      field.field_opts_off(O_EDIT); 
     
  
  
  # This loop checks to see if user has specified just, fore, pad or 
  # field_just, field_fore or field_pad, and if so sets the same.
   field.set_field_just(JUSTIFY_RIGHT); 
  
   field.set_field_fore(Ncurses.COLOR_PAIR(1)); 
  
  
  
  fields.push(field)
  
  
  
  #date
  
  field = FIELD.new(1, 20, 12, 1, 0, 0)
  
   field.field_opts_off(O_ACTIVE); 
      field.field_opts_off(O_EDIT); 
     
  
  
  # This loop checks to see if user has specified just, fore, pad or 
  # field_just, field_fore or field_pad, and if so sets the same.
  
  
  
  
  fields.push(field)
  



  
  
  
  #item
  
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
      
    
  
  
  #total
  
      #INSIDE ELSE
      #
      
    
  
  
  #date
  
      #INSIDE ELSE
      #
      
    
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
  print_in_middle(my_form_win, 1, 0, cols[0] + 14, "Dependent Fields", Ncurses.COLOR_PAIR(3));

  stdscr.mvprintw(2, 45, Time.now.strftime("%Y/%m/%d %H:%M.%S"))
  my_form.post_form();

  # Print field labels
  ###- FIELD LABELS and DEFAULTS too
    # I am throwing in default value placement in this loop as too much redirection
    # involved in each loop
  
     my_form_win.mvaddstr(4, 2 , "Item")
    
     my_form_win.mvaddstr(6, 2 , "rate")
    
     my_form_win.mvaddstr(8, 2 , "Qty")
    
    fields[2].set_field_buffer(0,120.to_s)
    update_current_value("qty", 120.to_s)
    fields[2].set_field_status(false) # won't be seen as modified
    
     my_form_win.mvaddstr(10, 2 , "State code")
    
    fields[3].set_field_buffer(0,@@states.keys.first.to_s)
    update_current_value("state_code", @@states.keys.first.to_s)
    fields[3].set_field_status(false) # won't be seen as modified
    
     my_form_win.mvaddstr(12, 2 , "Total")
    
     my_form_win.mvaddstr(14, 2 , "Date")
    
    fields[5].set_field_buffer(0,Time.now.to_s)
    update_current_value("date", Time.now.to_s)
    fields[5].set_field_status(false) # won't be seen as modified
    
  
  print_help(stdscr,"Help text will come here");

  my_form_win.wrefresh();
  my_form.set_current_field(fields[0]);  
  my_form.form_driver(REQ_FIRST_FIELD);

  saveproc = proc {
      outdata = get_current_values
      outdata.each {|fldnam,value| 
        h = @rt_hashes[fldnam];
        # 2008-09-21 00:06 if a postprocessor defined call it.
        # this is largely due to the multi-line field giving me spaces not newlines.
        if h.include?"post_proc"
          pproc = h["post_proc"][0];
          value=send(pproc, value, h["width"]) ## FIXME why width? could be other things
        end
        outdata[fldnam]=value
        }
        ## if the user defined a method form_post_proc, lets call it
        # passing the hash of values and the hash of dsl specs he gave us 
        if defined? form_post_proc
          outdata = send(:form_post_proc, outdata, @rt_hashes)
        end
  #    outdata.delete(rt_fields[0]) ; # remove help field fiXME move help to another independent field
      filename = @rt_form["save_path"][0] || 'out.txt'
      #sysfields[0].set_field_buffer(0,"Saving data to #{filename}");
      print_status(stdscr,"Saving data to #{filename}");
### XXX FIXME put this into methods and call them with default being
# save_as_text
# create a format at generation time and use that, if none given
# if save_proc specified, use that.
      if @rt_form["save_format"][0]=='yml'
        File.open(filename || "out.yml", "w") { | f | YAML.dump( outdata, f )} 
      else
  #      str = ''
        File.open("dump.yml", "w") { | f | YAML.dump( outdata, f )} 
        # one last time we check defaults for blank fields
        # altho now we check on tab-out, if user clears but does not
        # tab out, this will still catch it.
        @rt_fields.each_index{ |i| 
          fn = @rt_fields[i]
          value = outdata[fn]
          # value can be nil, need to check if user wants entered
          
          #value = value || @rt_hashes[fn]["default"] || ''
          if value == nil || value.strip == ''
            value = @rt_hashes[fn]["default"][0] rescue ''
            # 2008-09-22 22:28 
            outdata[fn] = value
          end
         # str << fn +": "+value + "\n"
        }
        #str << "\n"
        #File.open(filename, "a") {|f| f.puts(str) }
        save_as_text(filename, outdata)
      end
      print_status(stdscr,"Saved data to #{filename}  ");
      my_form.set_current_field(fields[0]);  
      my_form.form_driver(REQ_FIRST_FIELD);
  }
  helpproc = proc { 
    x = my_form.current_field
    ix = fields.index(x)
    fldname = @rt_fields[ix] 
    h = @rt_hashes[fldname]
      text = ''; case ix 
       when 0 # item 
        #found text
      text = "Enter item code"
       
     when 1 # rate 
      # attempting range
        text = 'Valid: 0 - 1000'  
     when 2 # qty 
       # trying eval else delaying till runtime 
       text = 'Valid: 0 - 1000'  
     when 3 # state_code 
       # trying eval else delaying till runtime 
       text =  'Valid: ' + @@states.keys.join(", ")  
     when 4 # total 
      # final else last ditch
        text = 'No help for this field' 
     when 5 # date 
      # final else last ditch
        text = 'No help for this field' 
    
          end
          print_help(stdscr,text.to_s) 
  }
  field_init_proc = proc {
    helpproc.call
    # call any onenter eventhandler specified
    # format (inside field block):
    # onenter :myproc
    pproc = get_current_field_attr_scalar(my_form, fields,"onenter")
    # untested XXX 
    value=send(pproc, my_form, fields, @rt_hashes)  if pproc != nil
  }
  field_term_proc = proc {
    x = my_form.current_field
    ix = fields.index(x)
    fldname = @rt_fields[ix] 
    h = @rt_hashes[fldname]
    value = x.field_buffer(0)
    if x.field_status == true
      value.strip!
      if value == ''  # user blanked out value
        if h.include?"default"
          value = h["default"][0]
          if value != nil
            value = eval(value) rescue value
          end
        end
      end
      # call specific procs if exist TODO
      # 2008-09-21 19:13 - lets show him the result then and there!
      if h.include?"post_proc"
        pproc = h["post_proc"][0];
        value=send(pproc, value,h["width"])
      end
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
      update_current_value(fldname, value.to_s)
      ## update the result online 2008-09-21 19:46 
      x.set_field_buffer(0,value.to_s)
      #    print_status(nil, "updated #{fldname} with [#{value}] ")
      form_changed(true);
    end
    #print_status(stdscr,"Exited #{fldname} modified: #{x.field_status}")
    x.set_field_status(false);
    notify_observers(fldname, fields)
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
  while((ch = my_form_win.getch()) )
    case ch
    when 9 # tab
        my_form.form_driver(REQ_VALIDATION);
        my_form.form_driver(REQ_NEXT_FIELD);
        # Go to the end of the present buffer
        # Leaves nicely at the last character
        my_form.form_driver(REQ_END_LINE);
    when KEY_DOWN
      ret=my_form.form_driver(REQ_NEXT_LINE);
      if ret < 0
        # Go to next field */
        my_form.form_driver(REQ_VALIDATION);
        my_form.form_driver(REQ_NEXT_FIELD);
        # Go to the end of the present buffer
        # Leaves nicely at the last character
        my_form.form_driver(REQ_END_LINE);
      end

    #when KEY_UP
    when 353 # 353 is tab with TERM=screen # 90  # back-tab
      # Go to previous field
      my_form.form_driver(REQ_VALIDATION);
      my_form.form_driver(REQ_PREV_FIELD);
      my_form.form_driver(REQ_END_LINE);

    when KEY_LEFT
      # Go to previous char
      my_form.form_driver(REQ_PREV_CHAR);

    when KEY_RIGHT
      # Go to next char
      my_form.form_driver(REQ_NEXT_CHAR);

    when KEY_BACKSPACE,127
      my_form.form_driver(REQ_DEL_PREV);
    when 153 # alt-h XXX
      helpproc.call
    when 24  # c-x
      my_form.form_driver(REQ_VALIDATION);
      my_form.form_driver(REQ_PREV_FIELD);
      saveproc.call
      form_changed(false)
      set_defaults(fields, nil)
      # save method
    when KEY_ENTER,10   # enter and c-j
      my_form.form_driver(REQ_NEXT_LINE);
    when KEY_UP # 11  # c-k
      ret=my_form.form_driver(REQ_PREV_LINE);
      if ret < 0
        my_form.form_driver(REQ_VALIDATION);
        my_form.form_driver(REQ_PREV_FIELD);
        my_form.form_driver(REQ_END_LINE);
      end
      #print_status(stdscr,"KEY UP GOT: #{ret}")
      #stdscr.mvprintw(Ncurses.LINES - 2, 18, "[%3d, %c]", ret, ret);
    when 1  # c-a
      my_form.form_driver(REQ_BEG_LINE);
    when 5  # c-e
      my_form.form_driver(REQ_END_LINE);
    when 165  # A-a
      my_form.form_driver(REQ_BEG_FIELD);
    when 180  # A-e
      my_form.form_driver(REQ_END_FIELD);
    when 11 # c-k # 154  # A-k
      my_form.form_driver(REQ_CLR_EOL);
    when 25  # c-y
      print_status(stdscr,"SAVE as YAML");
    when 147 # alt-Q alt-q
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
      #      stdscr.mvprintw(Ncurses.LINES - 2, 18, "["+ch.to_s+"]");
      stdscr.mvprintw(Ncurses.LINES - 2, 18, "[%3d, %c]", ch, ch);
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
