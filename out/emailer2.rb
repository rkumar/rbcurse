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
require 'commons1'
require 'editapplication'
#require 'datasource'
#require ''

include Ncurses
include Ncurses::Form
include Commons1

# add localhost if not given. Example of what can be done. XXX
def oldemailid_format(to, field)
to = to + "@gmail.com" if to && to.strip != "" && to !~ /@/
  to
end
class Messages #< Datasource
  attr_reader :header_top_center, :header_top_left
  attr_reader :main 
  def initialize(main)
    @main = main
  # something like a level 1 heading
    @header_top_left='Demos'
  # something like a level 2 heading
    @header_top_center='Rmailer'
  end
  def get_keys_handled
    nil 
  #|| super
  end
end
class Emailer < Application
  def initialize()
    super()
    # this will go inside form XXX
    @rt_fields=["from", "to", "cc", "date", "subject", "body"]
  @rt_form={"pipe_output_path"=>"/usr/sbin/sendmail -t", "save_path"=>"out2.txt", "classname"=>"Emailer", "save_format"=>"txt", "outfile"=>"email.rb", "save_template"=>"From: {{from}}\r\nTo: {{to}}\r\nCc: {{cc}}\r\nSubject: {{subject}}\r\n\r\n{{body}}\r\n\r\n"}
    @helpfile = __FILE__
    @datasource =  Messages.new(self)
    @labelarr = nil
  end
  ###DEFS_COME_HERE###
  # @return datahash
  def form_post_proc(datahash, myform)
    body = datahash["body"]
    #body = multiline_format(body, 60)
    sig = "

--
This is my sig!"
    datahash["body"] = body + sig
    datahash
  end

# field_term_hook(form) field_init_hook(form) form_init_hook(form) and form_term_hook(form)
# will be called, if defined

def emailid_format(to, field)
to = to + "@gmail.com" if to && to.strip != "" && to !~ /@/
  to
end
def run
###PROCS_COME_HERE###

  begin
      @form_headers["header_top_center"]=@datasource.header_top_center
      @form_headers["header_top_left"]=@datasource.header_top_left
      @main = self # XXX 2008-10-10 13:19 

      create_header_win()  # super takes care of this

      create_footer_win()  # super takes care of this
      Ncurses::Panel.update_panels

    form_col = 10 # XXX added 
    ### FORM_TEXT_HERE
    ###FIELDS###
# I pity anyone who comes into this file hoping to make some sense
fields = Array.new
    #from

    field = FIELD.new(1, 60, 1, form_col+1, 0, 0)
    field.user_object = {"fieldtype"=>[:REGEXP, "^[a-z_0-9@.]+ *$"], "label"=>"From", "position"=>[1, 1], "name"=>"from", "help_text"=>"Enter your id", "default"=>"oneness.univ", :label=>"From", "index"=>0, :row=>1, "post_proc"=>method(:emailid_format), "min_data_width"=>0, "width"=>60}
    field.user_object[:col] = form_col+1

    fields.push(field)
                #to

    field = FIELD.new(1, 60, 2, form_col+1, 0, 0)
    field.user_object = {"label"=>"To", "fieldtype"=>[:REGEXP, "^[a-z_0-9@.]+ *$"], "position"=>[2, 1], "name"=>"to", "default"=>"rahulbeneg", :label=>"To", "index"=>1, :row=>2, "post_proc"=>method(:emailid_format), "width"=>60}
    field.user_object[:col] = form_col+1

    fields.push(field)
                #cc

    field = FIELD.new(1, 60, 3, form_col+1, 0, 0)
    field.user_object = {"label"=>"Cc", "fieldtype"=>[:REGEXP, "^[a-z0-9_@. ]+$"], "position"=>[3, 1], "name"=>"cc", :label=>"Cc", "index"=>2, :row=>3, "post_proc"=>method(:emailid_format), "width"=>60}
    field.user_object[:col] = form_col+1

    fields.push(field)
                #date

    field = FIELD.new(1, 60, 4, form_col+1, 0, 0)
    field.user_object = {"label"=>"Date", "fieldtype"=>:ALNUM, "position"=>[4, 1], "name"=>"date", "default"=>lambda{Time.now.rfc2822}, :label=>"Date", "opts_off"=>[:O_EDIT, :O_ACTIVE], "index"=>3, :row=>4, "width"=>60}
    field.user_object[:col] = form_col+1

  field.field_opts_off(O_EDIT); 
       field.field_opts_off(O_ACTIVE); 

    fields.push(field)
                #subject

    field = FIELD.new(1, 60, 6, form_col+1, 0, 0)
    field.user_object = {"label"=>"Subject", "position"=>[6, 1], "name"=>"subject", "help_text"=>"Enter a subject for your email", :label=>"Subject", "index"=>4, :row=>6, "width"=>60}
    field.user_object[:col] = form_col+1

    fields.push(field)
                #body

    field = FIELD.new(8, 60, 8, form_col+-10, 0, 0)
    field.user_object = {"label"=>"----- Message Text -----", "position"=>[8, -10], "name"=>"body", "help_text"=>"'Tab out before saving.'", "field_back"=>:NORMAL, :label=>"----- Message Text -----", "opts_off"=>[:O_STATIC], "height"=>8, "index"=>5, :row=>8, "opts_on"=>[:O_WRAP], "width"=>60, "label_rowcol"=>[7, 1]}
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


    @fields = fields
    @eapp = EditApplication.new(@fields, self, @datasource)
      @eapp.user_prefs(@rt_form)
      eform_win_rows = 18 # ? XXX
      eform_win_cols = 0 # default of ncurses
      eform_win_starty = 1
      eform_win_startx = 0
      @eform_win, @eform_panel = @eapp.create_window(eform_win_rows,
                                                     eform_win_cols,
                                                     eform_win_starty,
                                                     eform_win_startx)

    # inhash is if we have to load up a file CUT THIS CRAP OUT LET IT BE HOOKED IN
    if @rt_form.include?"infile"
      infile = @rt_form["infile"][0]
      @inhash = YAML::load( File.open( infile ) ) if infile =~ /\.yml$/
      @eapp.form.set_defaults(@inhash) if @inhash != nil # XXX
    end

      @eapp.wrefresh();
      @eapp.form.print_help("Help text will come here");

      print_screen_labels(@eform_win, @labelarr) if !@labelarr.nil?
      # i need this to set the bottom panel
      @keys_handled = EditApplication.get_keys_handled() + (@datasource.get_keys_handled() ||  [])
      add_to_application_labels(@keys_handled)
      restore_application_key_labels
      stdscr.refresh();

      @eapp.form.set_handler(:form_post_proc, method(:form_post_proc)) if !defined?:form_post_proc.nil?
      @eapp.form.handle_keys_loop(@eform_win)

#    rescue Exception => e
    # print_error(e.to_s)
    # @log.error(caller(0).to_s)
#     @log.error(e.backtrace.join("\n"))
     #@log.error(e.backtrace.pretty_inspect)
  #   @log.error(Kernel.pretty_inspect(e.backtrace))

    ensure
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
    f =  Emailer.new()
    f.run

  ensure
    Ncurses.endwin();
  end
end
