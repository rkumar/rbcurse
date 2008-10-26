#!/usr/bin/env ruby 
#######################################################
# Template file used to generate ncurses screen/application
# $Id: form.skel,v 0.6 2008/09/19 10:39:07 arunachala Exp arunachala $
#
#
#######################################################
require 'rubygems'
require 'ncurses'
require 'yaml'
require 'commons1'
#require 'datasource'
require 'editapplication'

include Ncurses
include Ncurses::Form
include Commons1

class Contracts #< Datasource
  attr_reader :header_top_center, :header_top_left
  attr_reader :main 
  def initialize(main)
    @main = main
      @header_top_left = "Demos"
      @header_top_center = "Emailer"
  end
  def get_keys_handled
    return nil
  end
end
  # add localhost if not given. Example of what can be done.
  # # this possibly goes into datasource
  def emailid_format(to, field)
      to = to + "@gmail.com" if to && to.strip != "" && to !~ /@/
      to
  end
class Gen4 < Application
  def initialize()
    super()
    @rt_hashes = YAML::load( File.open( 'gen2.yml' ) )
    @inhash = nil # incoming data, lets demote this to run XXX
    # this will go inside form XXX
    @rt_fields=["from", "to", "cc", "date", "subject", "body"]
  @rt_form={"win_bkgd"=>3, "pipe_output_path"=>"/usr/sbin/sendmail -t", "save_path"=>"out2.txt", "title"=>"Yet another email client in ncurses", "save_format"=>"txt", "title_color"=>3, "save_template"=>"From: {{from}}\r\nTo: {{to}}\r\nCc: {{cc}}\r\nSubject: {{subject}}\r\n\r\n{{body}}\r\n\r\n"}
    @helpfile = __FILE__
    @helpfile = "TODO"
    @datasource =  Contracts.new(self)
    @labelarr = nil
  end
  def form_post_proc(datahash, fields)
    body = datahash["body"]
    #body = RBForm.text_to_multiline(body, 60) # 
    sig = "\n\n--\nThis is my sig!"
    datahash["body"] = body + sig
    datahash
  end

def field_term_hook(form)
end
def field_init_hook(form)
end
def run
  begin
    #form_changed(false);
###PROCS_COME_HERE###
      @form_headers["header_top_center"]=@datasource.header_top_center
      @form_headers["header_top_left"]=@datasource.header_top_left
      @main = self # XXX 2008-10-10 13:19 

      create_header_win()  # super takes care of this

      create_footer_win()  # super takes care of this
      Ncurses::Panel.update_panels

    # inhash is if we have to load up a file
    if @rt_form.include?"infile"
      infile = @rt_form["infile"][0]
      @inhash = YAML::load( File.open( infile ) ) if infile =~ /\.yml$/
    end

    ### FORM_TEXT_HERE
    @fields = Array.new
    
    #from
    
    form_col = 10 # XXX added 
    field = FIELD.new(1, 60, 1, form_col+0, 0, 0)
    
    field.set_field_back(A_NORMAL)
    field.user_object = {:row=>1,  "label"=>"From", "name"=>"from", "help_text"=>"Enter a rate to search on", "field_back"=>"NORMAL", :label=>"From", "width"=>60, "post_proc"=>:emailid_format}
    field.user_object[:col] = form_col+0
            @fields.push(field)
    #to
    
    field = FIELD.new(1, 60, 2, form_col+0, 0, 0)
    field.set_field_back(A_NORMAL)
    field.user_object = {:row=>2,  "label"=>"To", "name"=>"to", "help_text"=>"Enter a TO ", "field_back"=>"NORMAL", :label=>"To", "width"=>60, "post_proc"=>:emailid_format}
    field.user_object[:col] = form_col+0
            @fields.push(field)
    #cc
    field = FIELD.new(1, 60, 3, form_col+0, 0, 0)
    field.set_field_back(A_NORMAL)
    field.user_object = {:row=>3,  "label"=>"Cc", "name"=>"cc", "help_text"=>"Enter a CC ", "field_back"=>"NORMAL", :label=>"Cc", "width"=>60,"post_proc"=>:emailid_format }
    field.user_object[:col] = form_col+0
            @fields.push(field)
    #date
    field = FIELD.new(1, 60, 4, form_col+0, 0, 0)
     field.field_opts_off(O_EDIT); 
       field.field_opts_off(O_ACTIVE); 
    field.user_object = {:row=>4,  "label"=>"Time", "name"=>"time", :label=>"Time", "width"=>60}
    field.user_object[:col] = form_col+0
      
            @fields.push(field)
    #subject
    field = FIELD.new(1, 60, 6, form_col+0,0, 0)
    field.user_object = {:row=>6,  "label"=>"Subject", "name"=>"subject", :label=>"Subject", "width"=>60}
    field.user_object[:col] = form_col+0
    
    field.set_field_back(A_NORMAL)
    
            @fields.push(field)
            
    #body
    
    #field = FIELD.new(5, 60, 8, form_col+0, 0, 0)
    field = FIELD.new(8, 60, 8, 0, 0, 0)
    
    field.user_object = {:row=>8,  "label"=>"----- Message Text -----", "name"=>"body", 
     :label=>"----- Message Text -----", "width"=>60, "label_rowcol"=>[7,0]}
    field.user_object[:col] = 0
    field.set_field_back(A_NORMAL)
    field.field_opts_off(O_STATIC); 
    field.field_opts_on(O_WRAP); 

    @fields.push(field)

    #from

    @fields[0].set_field_type(TYPE_REGEXP, "^[a-z_0-9@.]+ *$");
    #to

    @fields[1].set_field_type(TYPE_REGEXP, "^[a-z_0-9@.]+ *$");

    #cc

    @fields[2].set_field_type(TYPE_REGEXP, "^[a-z0-9_@. ]+$");

    #date

    @fields[3].set_field_type(TYPE_ALNUM, 0);


            
              ###- SET FIELDS

              # Create the form and post it
      #        my_form = FORM.new(@fields);
      @eapp = EditApplication.new(@fields, self, @datasource)
      #@eapp.rt_fields = @rt_fields # temporary 
      #@eapp.form.rt_form = @rt_form # temporary  XXX
      @eapp.user_prefs(@rt_form)
      #@form = @eapp.form
      eform_win_rows = 18 # ? XXX
      eform_win_cols = 0 # default of ncurses
      eform_win_starty = 1
      eform_win_startx = 0
  #    @eform_win, @eform_panel = @eapp.create_edit_window(@eapp.form, eform_win_rows, 15)
      @eform_win, @eform_panel = @eapp.create_window(eform_win_rows,
                                                     eform_win_cols,
                                                     eform_win_starty,
                                                     eform_win_startx)


              # Print field labels
              ###- FIELD LABELS and DEFAULTS too
              # I am throwing in default value placement in this loop as too much redirection
              # involved in each loop
              
                  @fields[0].set_field_buffer(0,"oneness".to_s)
                  @eapp.form.update_current_value("from", "oneness".to_s)
                  @fields[0].set_field_status(false) # won't be seen as modified
                  
                
                  @fields[1].set_field_buffer(0,"rahulb".to_s)
                  @eapp.form.update_current_value("to", "rahulb".to_s)
                  @fields[1].set_field_status(false) # won't be seen as modified
                  
                  @fields[2].set_field_buffer(0,"rahul2012".to_s)
                  @eapp.form.update_current_value("cc", "rahul2012".to_s)
                  @fields[2].set_field_status(false) # won't be seen as modified
                  
                
                  @fields[3].set_field_buffer(0,Time.now.rfc2822.to_s)
                  @eapp.form.update_current_value("date", Time.now.rfc2822.to_s)
                  @fields[3].set_field_status(false) # won't be seen as modified
                  
              @eapp.form.set_defaults(@fields, @inhash) if @inhash != nil # XXX

              @eapp.wrefresh();
              @eapp.form.print_help("Help text will come here");

      print_screen_labels(@eform_win, @labelarr) if !@labelarr.nil?
      # i need this to set the bottom panel
      @keys_handled = EditApplication.get_keys_handled() + (@datasource.get_keys_handled() ||  [])
      add_to_application_labels(@keys_handled)
      restore_application_key_labels
      stdscr.refresh();

      # inform query app, who the output app is
      # @qapp.set_output_application(@tapp)

      # @eapp.handle_keys_loop()
      #@eapp.form.handle_keys_loop(@eform_win)
      @eapp.form.handle_keys_loop

#    rescue Exception => e
    # print_error(e.to_s)
    # @log.error(caller(0).to_s)
#     @log.error(e.backtrace.join("\n"))
     #@log.error(e.backtrace.pretty_inspect)
  #   @log.error(Kernel.pretty_inspect(e.backtrace))


#    ensure
      # Un post form and free the memory
      @eapp.free_all() if !@eapp.nil?
      self.free_all #  XXX
  end
end # run
end # class


if __FILE__ == $0
  # Initialize curses
  begin
    stdscr = Ncurses.initscr();
#    Ncurses.start_color();
##    Ncurses.cbreak();
#    Ncurses.raw();
#    Ncurses.keypad(stdscr, true);
#    Ncurses.noecho();
#    # Initialize few color pairs 
    prog = Gen4.new()
    prog.run

  ensure
    Ncurses.endwin();
  end
end
