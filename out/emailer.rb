#!/usr/bin/env ruby 
=begin
  * Name: rkumar
  * $Id$
  * Description   
  * Author:
  * Date:
  * License:
    This is free software; you can copy and distribute and modify
    this program under the term of Ruby's License
    (http://www.ruby-lang.org/LICENSE.txt)

=end

require 'rubygems'
require 'ncurses'
require 'yaml'
require 'editapplication'

include Ncurses
include Ncurses::Form

class Messages #< Datasource
  attr_reader :header_top_center, :header_top_left
  attr_reader :main 
  def initialize(main)
    @main = main
  # something like a level 1 heading
    @header_top_left=''
  # something like a level 2 heading
    @header_top_center=''
  end
  def get_keys_handled
    nil 
  #|| super
  end
end
## I have put defs outside so they can be called from FIELD without needing to pass a pointer 
# to this app
  ###DEFS_COME_HERE###
  # add localhost if not given. Example of what can be done.
  def emailid_format(to, field)
      to = to + "@gmail.com" if to && to.strip != "" && to !~ /@/
      to
  end
  # @return datahash
  def form_post_proc(datahash, fields)
    body = datahash["body"]
    #body = multiline_format(body, 60)
    sig = "

--
This is my sig!"
    datahash["body"] = body + sig
    datahash
  end

class Emailer < Application
  def initialize()
    super()

    @rt_fields=["from", "to", "cc", "date", "subject", "body"]
  @rt_form={"pipe_output_path"=>"/usr/sbin/sendmail -t", "save_path"=>"out2.txt", "classname"=>"Emailer", "save_format"=>"txt", "outfile"=>"email.rb", "form_post_proc"=>"method(:form_post_proc)", "header_top_left"=>"Demos", "header_top_center"=>"Rmailer", "save_template"=>"From: {{from}}\r\nTo: {{to}}\r\nCc: {{cc}}\r\nSubject: {{subject}}\r\n\r\n{{body}}\r\n\r\n"}
    @helpfile = __FILE__
    @datasource =  Messages.new(self)
    @labelarr = nil
  end

def run
###PROCS_COME_HERE###

  begin
    @main = self 

    form_col = 10 
    ### FORM_TEXT_HERE
    ###FIELDS###
fields = Array.new
    #from

    field = FIELD.new(1, 60, 1, form_col+1, 0, 0)
    field.user_object = {"fieldtype"=>[:REGEXP, "^[a-z_0-9@.]+ *$"], "label"=>"From", "position"=>[1, 1], "name"=>"from", :label=>"From", "help_text"=>"Enter your id", "default"=>"oneness.univ", :row=>1, "index"=>0, "post_proc"=>"method(:emailid_format)", "min_data_width"=>0, "width"=>60}
    field.user_object[:col] = form_col+1

      field.user_object["post_proc"]=method(:emailid_format)

    fields.push(field)
                #to

    field = FIELD.new(1, 60, 2, form_col+1, 0, 0)
    field.user_object = {"label"=>"To", "fieldtype"=>[:REGEXP, "^[a-z_0-9@.]+ *$"], "position"=>[2, 1], "name"=>"to", :label=>"To", "default"=>"rahulbeneg", :row=>2, "index"=>1, "post_proc"=>"method(:emailid_format)", "width"=>60}
    field.user_object[:col] = form_col+1

      field.user_object["post_proc"]=method(:emailid_format)

    fields.push(field)
                #cc

    field = FIELD.new(1, 60, 3, form_col+1, 0, 0)
    field.user_object = {"label"=>"Cc", "fieldtype"=>[:REGEXP, "^[a-z0-9_@. ]+$"], "position"=>[3, 1], "name"=>"cc", :label=>"Cc", "default"=>"rahul", :row=>3, "index"=>2, "post_proc"=>"method(:emailid_format)", "width"=>60}
    field.user_object[:col] = form_col+1

      field.user_object["post_proc"]=method(:emailid_format)

    fields.push(field)
                #date

    field = FIELD.new(1, 60, 4, form_col+1, 0, 0)
    field.user_object = {"label"=>"Date", "fieldtype"=>:ALNUM, "position"=>[4, 1], "name"=>"date", :label=>"Date", "default"=>"lambda {Time.now.rfc2822}", :row=>4, "opts_off"=>[:O_EDIT, :O_ACTIVE], "index"=>3, "width"=>60}
    field.user_object[:col] = form_col+1

      field.user_object["default"]=lambda {Time.now.rfc2822}

  field.field_opts_off(O_EDIT); 
       field.field_opts_off(O_ACTIVE); 

    fields.push(field)
                #subject

    field = FIELD.new(1, 60, 6, form_col+1, 0, 0)
    field.user_object = {"label"=>"Subject", "position"=>[6, 1], "name"=>"subject", :label=>"Subject", "help_text"=>"Enter a subject for your email", :row=>6, "index"=>4, "width"=>60}
    field.user_object[:col] = form_col+1

    fields.push(field)
                #body

    field = FIELD.new(8, 60, 8, form_col+-10, 0, 0)
    field.user_object = {"label"=>"----- Message Text -----", "position"=>[8, -10], "name"=>"body", :label=>"----- Message Text -----", "help_text"=>"Tab out before saving.", "field_back"=>:NORMAL, :row=>8, "opts_off"=>[:O_STATIC], "height"=>8, "index"=>5, "opts_on"=>[:O_WRAP], "width"=>60, "label_rowcol"=>[7, 1]}
    field.user_object[:col] = form_col+-10

    field.set_field_back(A_NORMAL)

  field.field_opts_off(O_STATIC); 

  field.field_opts_on(O_WRAP); 

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

    #body

 ###- SET FIELD DEFAULTS THIS IS DONE BY set_default in the form no need here

    #from

                  #fields[0].set_value(oneness.univ.to_s)
                  #fields[0].set_field_status(false) # won't be seen as modified

    #to

                  #fields[1].set_value(rahulbeneg.to_s)
                  #fields[1].set_field_status(false) # won't be seen as modified

    #cc

                  #fields[2].set_value(rahul.to_s)
                  #fields[2].set_field_status(false) # won't be seen as modified

    #date

                  #fields[3].set_value(lambda {Time.now.rfc2822}.to_s)
                  #fields[3].set_field_status(false) # won't be seen as modified

    #subject

    #body


    @fields = fields
    @eapp = EditApplication.new(@fields, self) do |app|
      app.user_prefs(@rt_form)
      app.form_headers["header_top_center"]='Rmailer'
      app.form_headers["header_top_left"]='Demos'
      app.create_header_win()  
      app.create_footer_win() 
      Ncurses::Panel.update_panels

      eform_win_rows = 18 
      eform_win_cols = 0 # default of ncurses
      eform_win_starty = 1
      eform_win_startx = 0
      @eform_win, @eform_panel = app.create_window(eform_win_rows,
                                                   eform_win_cols,
                                                   eform_win_starty,
                                                   eform_win_startx)

      app.wrefresh();

      app.form.set_handler(:form_post_proc, method(:form_post_proc))

      print_screen_labels(@eform_win, @labelarr) if !@labelarr.nil?

        #@keys_handled = EditApplication.get_keys_handled() + (@datasource.get_keys_handled() ||  [])
        @keys_handled = app.get_keys_handled() 
      app.add_to_application_labels(@keys_handled)
      app.restore_application_key_labels
      stdscr.refresh();

    app.form.handle_keys_loop
end

    ensure
      # Un post form and free the memory
      #self.free_all #  XXX
  end
end # run
end # class

if __FILE__ == $0
  # Initialize curses
  begin
    stdscr = Ncurses.initscr();
    f =  Emailer.new()
    f.run

  ensure
    Ncurses.endwin();
  end
end
