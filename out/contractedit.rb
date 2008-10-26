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
  * TODO
    * do save of values
    * allow caller to pass ID and select and populate
    * put all fields on screen

=end

require 'rubygems'
require 'ncurses'
require 'yaml'
require 'editapplication'

include Ncurses
include Ncurses::Form

class Contracts #< Datasource
  attr_reader :header_top_center, :header_top_left
  attr_reader :main 
  def initialize(main)
    @main = main
    @header_top_left='Demos'
    @header_top_center='Contracts'
  end
  def get_keys_handled
    [{:keycode=>88, :display_code=>"X", :text=>"eXlcude"},
 {:keycode=>86, :display_code=>"V", :text=>"View   "},
 {:keycode=>999, :display_code=>" ", :text=>"       "},
 {:action=>"sort", :keycode=>36, :display_code=>"$", :text=>"Sort   "}] 
  #|| super
  end
end
class ContractEdit < Application
  attr_reader :eapp
  ###DEFS_COME_HERE###
  def initialize()
    super()

    @rt_fields=["contract_id", "contract_id", "product_name", "rate"]
  @rt_form={"classname"=>"ContractEdit", "mydefs"=>"  def someproc\n\n  end\n", "myprocs"=>"  myfieldcheck = proc { |afield|\n    }\n"}
    @helpfile = __FILE__
    @datasource =  Contracts.new(self)
    @labelarr = nil

    ###PROCS_COME_HERE###


    form_col = 10 
    ### FORM_TEXT_HERE
    ###FIELDS###
    fields = Array.new
    #contract_id

    field = FIELD.new(1, 10, 1, form_col+form_col+0, 0, 0)
    field.user_object = {"label"=>"contract_id", "name"=>"contract_id", "help_text"=>"Enter a contract ", :row=>1, "field_back"=>"REVERSE", :label=>"contract_id", "index"=>1, "width"=>10}
    field.user_object[:col] = form_col+form_col+0

    field.set_field_back(A_REVERSE)

    fields.push(field)
                #product_name

    field = FIELD.new(1, 10, 2, form_col+form_col+0, 0, 0)
    field.user_object = {"label"=>"product_name", "name"=>"product_name", "help_text"=>"Enter a name ", :row=>2, "field_back"=>"REVERSE", :label=>"product_name", "index"=>2, "width"=>10}
    field.user_object[:col] = form_col+form_col+0

    field.set_field_back(A_REVERSE)

    fields.push(field)
                #rate

    field = FIELD.new(1, 5, 3, form_col+form_col+0, 0, 0)
    field.user_object = {"label"=>"rate", "name"=>"rate", "help_text"=>"Enter a rate to search on", :row=>3, "field_back"=>"REVERSE", :label=>"rate", "index"=>3, "width"=>5}
    field.user_object[:col] = form_col+form_col+0

    field.set_field_back(A_REVERSE)

    fields.push(field)

    #contract_id

    #product_name

    #rate

 ###- SET FIELD DEFAULTS THIS IS DONE BY set_default in the form no need here

    #contract_id

    #product_name

    #rate

      @main = self 

    @fields = fields
    @eapp = EditApplication.new(@fields, self) 
      @eapp.user_prefs(@rt_form)
      @eapp.form_headers["header_top_center"]='Contract Edit'
      @eapp.form_headers["header_top_left"]='Demo'
      @eapp.create_header_win()  
      @eapp.create_footer_win() 
      Ncurses::Panel.update_panels

      eform_win_rows = 18 
      eform_win_cols = 0 # default of ncurses
      eform_win_starty = 1
      eform_win_startx = 0
      @eform_win, @eform_panel = @eapp.create_window(eform_win_rows,
                                                   eform_win_cols,
                                                   eform_win_starty,
                                                   eform_win_startx)

      @eapp.wrefresh();

      print_screen_labels(@eform_win, @labelarr) if !@labelarr.nil?

        #@keys_handled = EditApplication.get_keys_handled() + (@datasource.get_keys_handled() ||  [])
        @keys_handled = EditApplication.get_keys_handled() 
      @eapp.add_to_application_labels(@keys_handled)
      @eapp.restore_application_key_labels
      stdscr.refresh();
  end # initialize

  def run
    begin
      @eapp.form.handle_keys_loop
    ensure
      # Un post form and free the memory
      @eapp.free_all
      #self.free_all #  XXX
    end
  end # run
end # class

if __FILE__ == $0
  # Initialize curses
  begin
    stdscr = Ncurses.initscr();
    f =  ContractEdit.new()
    h = {}
    h['contract_id']="T200"
    h['product_name']="Powerbook"
    h['rate']=2.33
    f.eapp.form.set_values_hash h

    f.run

  ensure
    Ncurses.endwin();
  end
end
