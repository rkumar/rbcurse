#!/usr/bin/env ruby -w
#######################################################
# Template file used to generate ncurses screen/application
# $Id: form.skel,v 0.6 2008/09/19 10:39:07 arunachala Exp arunachala $
#
#
#######################################################
require 'rubygems'
require 'ncurses'
require 'yaml'
require 'logger'

include Ncurses
include Ncurses::Form

class Gen2
  def initialize(unused)
    #@stdscr = stdscr
    @log = Logger.new("app.log")
    @log.level = Logger::DEBUG
    @current={}
    @rt_form = {}
    @rt_hashes = YAML::load( File.open( 'gen2.yml' ) )
    #rt_fields = YAML::load( File.open( 'fields.yml' ) )
    #rt_form = YAML::load( File.open( 'form.yml' ) )
    @inhash = nil # incoming data, lets demote this to run XXX
    @@form_status = nil;
    @rt_fields=["from", "to", "cc", "date", "subject", "body"]
  @rt_form={"win_bkgd"=>[3], "pipe_output_path"=>["/usr/sbin/sendmail -t"], "save_path"=>["out2.txt"], "title"=>["An email client in ncurses"], "save_format"=>["txt"], "title_color"=>[3], "save_template"=>["From: {{from}}\r\nTo: {{to}}\r\nCc: {{cc}}\r\nSubject: {{subject}}\r\n\r\n{{body}}\r\n\r\n"]}
  end
  def clear_wins
    #Ncurses::Panel.del_panel(@my_panel) }
    #@my_form_win.delwin
  end

  def template( templateStr, values )
    templateStr.gsub( /\{\{(.*?)\}\}/ ) { values[ $1 ].to_str }
  end

# default save as text, if user has not specified a format

  def default_dump_text(outdata)
    str = ''
    @rt_fields.each{ |fn| 
      value = outdata[fn]
      str << "#{fn}: #{value}\n"
    }
    str << "\n"
  end
def save_as_text(filename, str)
  @log.info(str)
  File.open(filename, "a") {|f| f.puts(str) }
end
def pipe_output (str)
  pipeto = @rt_form["pipe_output_path"][0]
  if pipeto != nil
    proc = IO.popen(pipeto, "w+")
    proc.puts str
    proc.close_write
    #@log.info(proc.gets)
  end
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
    if fielddef != nil
      fields[index].set_field_buffer(0,fielddef.to_s)
      check = fields[index].field_buffer(0)
      if check == nil || check.strip ==''
        # set_buffer failed .. first try
        @log.debug("set_default: #{fn} set_field_buffer failed retrying with chomp() #{fielddef}")
        fields[index].set_field_buffer(0,fielddef.chomp!.to_s)
        check = fields[index].field_buffer(0)
        if check == nil || check.strip ==''
          @log.debug("set_default: set_field_buffer failed again, Trying text_to_multi #{fn} ")
          fielddef = text_to_multiline(fielddef, 60) # FIXME
          fields[index].set_field_buffer(0,fielddef.to_s)
        end
      end
      update_current_value(fn, fielddef.to_s)
      fields[index].set_field_status(false) # won't be seen as modified
    end
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
# get a confirmation from user. very simplistic
#  2008-09-23 21:00 
def get_confirmation(win, askstr, maxlen=1)
  len = askstr.length
  print_this(win, askstr, 1, 21, 2)
  Ncurses.echo();
  yn=''
  yn = win.mvwgetnstr(21,askstr.length+3,yn,maxlen)
  Ncurses.echo();
  yn
end
## prints help text for fields, or actions/events.
def print_help(win, text)
  print_this(win, text, 2, 20, 2)
end
def print_this(win, text, color, x, y)
  if(win == nil)
    win = @stdscr;
  end
  color=Ncurses.COLOR_PAIR(color);
  win.attron(color);
  win.mvprintw(x, y, "%-40s" % text);
  win.attroff(color);
  win.refresh
end
def print_in_middle(win, starty, startx, width, string, color)

  if(win == nil)
    win = @stdscr;
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

def run
  begin
    fields = Array.new
    form_changed(false);
###PROCS_COME_HERE###
  # add localhost if not given. Example of what can be done.
  def emailid_format(to, width)
      to = to + "@localhost" if to && to.strip != "" && to !~ /@/
      to
  end
  def form_post_proc(datahash, metadatahash)
    body = datahash["body"]
    body = multiline_format(body, 60)
    datahash["body"] = body
    datahash
  end


    # inhash is if we have to load up a file
    if @rt_form.include?"infile"
      infile = @rt_form["infile"][0]
      @inhash = YAML::load( File.open( infile ) ) if infile =~ /\.yml$/
    end
    setup_observers()

    ### FORM_TEXT_HERE
    # just in case user does not specify, I need some defaults
    Ncurses.init_pair(1, COLOR_RED, COLOR_BLACK)
    #Ncurses.init_pair(2, COLOR_WHITE, COLOR_BLACK)
    Ncurses.init_pair(2, COLOR_BLACK, COLOR_WHITE)
    Ncurses.init_pair(3, COLOR_BLACK, COLOR_BLUE)

    # Initialize few color pairs 
    Ncurses.init_pair(4, COLOR_YELLOW, COLOR_RED)
    Ncurses.init_pair(5, COLOR_WHITE, COLOR_BLACK)
    Ncurses.init_pair(6, COLOR_WHITE, COLOR_BLUE)
    Ncurses.init_pair(7, COLOR_WHITE, COLOR_RED)
    ###  
    #@stdscr.bkgd(Ncurses.COLOR_PAIR(2));

    
    
    
    #from
    
    field = FIELD.new(1, 60, 1, 1, 0, 0)
    
    field.set_field_back(A_REVERSE)
    
    
      
        # This loop checks to see if user has specified just, fore, pad or 
        # field_just, field_fore or field_pad, and if so sets the same.
        
            
            
            
            fields.push(field)
            
    
    
    #to
    
    field = FIELD.new(1, 60, 2, 1, 0, 0)
    
    field.set_field_back(A_REVERSE)
    
    
      
        # This loop checks to see if user has specified just, fore, pad or 
        # field_just, field_fore or field_pad, and if so sets the same.
        
            
            
            
            fields.push(field)
            
    
    
    #cc
    
    field = FIELD.new(1, 60, 3, 1, 0, 0)
    
    field.set_field_back(A_REVERSE)
    
    
      
        # This loop checks to see if user has specified just, fore, pad or 
        # field_just, field_fore or field_pad, and if so sets the same.
        
            
            
            
            fields.push(field)
            
    
    
    #date
    
    field = FIELD.new(1, 60, 4, 1, 0, 0)
    
     field.field_opts_off(O_EDIT); 
       field.field_opts_off(O_ACTIVE); 
      
      
      
        # This loop checks to see if user has specified just, fore, pad or 
        # field_just, field_fore or field_pad, and if so sets the same.
        
            
            
            
            fields.push(field)
            
    
    
    #subject
    
    field = FIELD.new(1, 60, 6, 1, 0, 0)
    
    field.set_field_back(A_REVERSE)
    
    
      
        # This loop checks to see if user has specified just, fore, pad or 
        # field_just, field_fore or field_pad, and if so sets the same.
        
            
            
            
            fields.push(field)
            
    
    
    #body
    
    field = FIELD.new(5, 60, 8, 1, 0, 0)
    
    field.set_field_back(A_REVERSE)
    
     field.field_opts_off(O_STATIC); 
      
      
       field.field_opts_on(O_WRAP); 
        
        
        # This loop checks to see if user has specified just, fore, pad or 
        # field_just, field_fore or field_pad, and if so sets the same.
        
            
            
            
            fields.push(field)
            



            
            
            
            #from
            
              fields[0].set_field_type(TYPE_REGEXP, "^[a-z_0-9@.]+ *$");
              
              
            
            
            #to
            
              fields[1].set_field_type(TYPE_REGEXP, "^[a-z_0-9@.]+ *$");
              
              
            
            
            #cc
            
              fields[2].set_field_type(TYPE_REGEXP, "^[a-z0-9_@. ]+$");
              
              
            
            
            #date
            
              fields[3].set_field_type(TYPE_ALNUM, 0);
              
              
            
            
            #subject
            
              #INSIDE ELSE
              #
              
              
            
            
            #body
            
              #INSIDE ELSE
              #
              
              
              ###- SET FIELDS


              # Create the form and post it
              my_form = FORM.new(fields);

              my_form.user_object = "PLS START USING *THIS* FOR GOD's SAKE "

              # Calculate the area required for the form
              rows = Array.new()
              cols = Array.new()
              my_form.scale_form(rows, cols);

              # Create the window to be associated with the form 
              my_form_win = WINDOW.new(0,0,0,0)
              # 2008-09-24 22:33 added with panel
              my_panel = my_form_win.new_panel 

              my_form_win.bkgd(Ncurses.COLOR_PAIR(3));
              my_form_win.keypad(TRUE);

              # Set main window and sub window
              my_form.set_form_win(my_form_win);
              my_form.set_form_sub(my_form_win.derwin(rows[0], cols[0], 2, 12));

              # Print a border around the main window and print a title */
              my_form_win.box(0, 0);
              print_in_middle(my_form_win, 1, 0, cols[0] + 14, "An email client in ncurses", Ncurses.COLOR_PAIR(3));

              #@stdscr.mvprintw(2, 45, Time.now.strftime("%Y/%m/%d %H:%M.%S"))
              my_form_win.mvprintw(2, 45, Time.now.strftime("%Y/%m/%d %H:%M.%S"))
              my_form.post_form();

              # Print field labels
              ###- FIELD LABELS and DEFAULTS too
              # I am throwing in default value placement in this loop as too much redirection
              # involved in each loop
              
                my_form_win.mvaddstr(3, 2 , "From")
                
                  fields[0].set_field_buffer(0,"oneness.univ".to_s)
                  update_current_value("from", "oneness.univ".to_s)
                  fields[0].set_field_status(false) # won't be seen as modified
                  
                my_form_win.mvaddstr(4, 2 , "To")
                
                  fields[1].set_field_buffer(0,"rahulbeneg".to_s)
                  update_current_value("to", "rahulbeneg".to_s)
                  fields[1].set_field_status(false) # won't be seen as modified
                  
                my_form_win.mvaddstr(5, 2 , "Cc")
                
                  fields[2].set_field_buffer(0,"rahul".to_s)
                  update_current_value("cc", "rahul".to_s)
                  fields[2].set_field_status(false) # won't be seen as modified
                  
                my_form_win.mvaddstr(6, 2 , "Date")
                
                  fields[3].set_field_buffer(0,Time.now.rfc2822.to_s)
                  update_current_value("date", Time.now.rfc2822.to_s)
                  fields[3].set_field_status(false) # won't be seen as modified
                  
                my_form_win.mvaddstr(8, 2 , "Subject")
                
                my_form_win.mvaddstr(10, 2 , "body")
                

              set_defaults(fields, @inhash) if @inhash != nil # XXX

              print_help(my_form_win,"Help text will come here");

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
                print_status(my_form_win,"Saving data to #{filename}");
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
                  str=''
                  templateStr = @rt_form["save_template"][0]
                  if templateStr!=nil
                    str = template(templateStr, outdata)
                  else
                    str = default_dump_text(outdata)
                  end
                  save_as_text(filename, str)
                  pipeto = @rt_form["pipe_output_path"][0]
                  pipe_output(str) if pipeto != nil
                end
                print_status(my_form_win,"Saved data to #{filename}  ");
                my_form.set_current_field(fields[0]);  
                my_form.form_driver(REQ_FIRST_FIELD);
              }
              helpproc = proc { 
                x = my_form.current_field
                ix = fields.index(x)
                fldname = @rt_fields[ix] 
                h = @rt_hashes[fldname]
                text = ''; 
                case ix 
                 when 0 # from 
                    #found text
                    text = "Enter only #{h['width']} letters"
                     
                   when 1 # to 
                   text = '^[a-z_0-9@.]+ *$'   
                   when 2 # cc 
                   text = '^[a-z0-9_@. ]+$'   
                   when 3 # date 
                   text = 'Valid: alphabets and numbers'  
                   when 4 # subject 
                    #found text
                    text = "No type set"
                     
                   when 5 # body 
                    #found text
                    text = "'Enter all you can. Tab out before saving.'"
                     
                  
          end
          print_help(my_form_win,text.to_s) 
              }
              field_init_proc = proc {
                helpproc.call
                # call any onenter eventhandler specified
                # format (inside field block):
                # onenter :myproc
                pproc = get_current_field_attr_scalar(my_form, fields,"onenter")
                # untested XXX 
                value=send(pproc, my_form, fields, @rt_hashes) if pproc != nil
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
                #print_status(my_form_win,"Exited #{fldname} modified: #{x.field_status}")
                x.set_field_status(false);
                notify_observers(fldname, fields)
              }
              form_init_proc = proc {
                print_status(my_form_win,"Inside form_init_proc")
              }
              form_term_proc = proc {
                print_status(my_form_win,"Inside form_term_proc")
              }
              my_form.set_field_init(field_init_proc)
              my_form.set_field_term(field_term_proc)
              my_form.set_form_init(form_init_proc)
              my_form.set_form_term(form_term_proc)

              my_form_win.mvprintw(Ncurses.LINES - 2, 28, "Use UP, DOWN arrow keys. Alt-h for help.");
              my_form_win.mvprintw(Ncurses.LINES - 1, 28, "^Q Quit ^X Save");
              stdscr.refresh();
              # 2008-09-24 22:33 added with panel
              Ncurses::Panel.update_panels
              Ncurses.doupdate()

              # Loop through to get user requests unless 147 == alt Q
%w[ TSTP CONT ABRT HUP STOP PIPE IO IOT CHLD CLD ILL INFO QUIT SYS TRAP TTOU  URG USR1 USR2 ].each { | alrm |
  Signal.trap("SIG#{alrm}") { stdscr.mvprintw(17, 2, "%-40s" % "#{alrm} "); stdscr.refresh; }
}
              while true
                begin
                ch = my_form_win.getch()
                rescue Exception => e
                  my_form_win.mvprintw(Ncurses.LINES - 3, 2, e.to_s)
                  my_form_win.refresh();
                  stdscr.refresh();
                end
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
                  #my_form_win.mvprintw(Ncurses.LINES - 2, 18, "[%3d, %c]", ret, ret);
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
                  print_status(my_form_win,"SAVE as YAML");
                when 197,-1 # alt-Q alt-q
                  if form_changed? == true
                    yn=get_confirmation(nil,"Form was changed. Wish to save Y/N?: ")
                    yn = my_form_win.getstr(yn)
                    if yn =~ /[Yy]/
                      saveproc.call
                      form_changed(false)
                      next
                    else
                      print_status(my_form_win,"Abandoning changes. Bye!")
                      break
                    end
                  else
                    break
                  end
                else

                  # If this is a normal character, it gets Printed    
                  #      my_form_win.mvprintw(Ncurses.LINES - 2, 18, "["+ch.to_s+"]");
                  my_form_win.mvprintw(Ncurses.LINES - 2, 18, "[%3d, %c]", ch, ch);
                  #stdscr.mvprintw(Ncurses.LINES - 1, 18, "C-x Save");

                  stdscr.refresh();
                  my_form.form_driver(ch);
                end
              end
  ensure
    # Un post form and free the memory
    my_form.unpost_form();
    my_form.free_form();
    fields.each {|f| f.free_field()}
    Ncurses::Panel.del_panel(my_panel) 
    my_form_win.delwin
    #clear_wins
  end

end
end

if __FILE__ == $0
  # Initialize curses
  begin
    stdscr = Ncurses.initscr();
    Ncurses.start_color();
    Ncurses.cbreak();
    Ncurses.keypad(stdscr, true);
    Ncurses.noecho();
    trap("INT") {  }

#Signal.trap("SIGTSTP") { puts "SIGTSTP"; }
#Signal.trap("SIGTSTP") { "SIG_IGN" }

  #Signal.trap("SIG#{alrm}") { "SIG_IGN" }
  

    prog = Gen2.new(stdscr)
    prog.run

  ensure
    Ncurses.endwin();
  end
end
