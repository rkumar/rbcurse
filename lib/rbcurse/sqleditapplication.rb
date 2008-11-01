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

# This has the functionality of a single row editing application
#   * most features are with the tableform itself.
#   * will be related to a datasource 
#
# Arunachalesha 
# @version 
#
require 'rubygems'
require 'ncurses'
require 'rbcurse/editapplication'
require 'rbcurse/rbeditform'
require 'rbcurse/commons1'
require 'rbcurse/singletable'

include Ncurses
include Ncurses::Form

class SqlEditApplication < EditApplication
  include Commons1
  include SingleTable
    attr_reader :form
    attr_reader :fields  
    attr_reader :tablename
    attr_reader :db
    attr_reader :keynames
    attr_accessor :keyvalues
    attr_accessor :order_string
    attr_accessor :where_string
    attr_accessor :findall_limit # how many rows to limit find all to.

    # takes an array of fields and creates a form and manages it
    # also takes caller program, required to call the print and clear
    # takes datasource and sets it up, if not passed it must be passed later
    # to be usable
    def initialize(fields, main, db, tablename, keynames)
      @db = db
      @tablename = tablename
      @keynames = keynames
      @keyvalues = []
      @findall_limit = 100
      @order_string = ""
      @where_string = ""
      super(fields, main)
      #@main = self
      #@form.main = self

      # the class which gives data and responds to events
    end
    def self.create_default_application(fields, db, tablename, keynames, config={}, &block)

      eapp = SqlEditApplication.new(fields, self, db, tablename, keynames)  do |app|
        max_rows = config.fetch("max_rows", 20)
        wrap_at = config.fetch("wrap_at", max_rows)
        labelarr = config.fetch("labelarr", nil)
        eform_win, eform_panel = app.create_window(max_rows, 0, 1, 0)

        app.wrefresh();
        app.print_screen_labels(eform_win, labelarr) if !labelarr.nil?
        keys_handled = app.get_keys_handled() 
        app.instance_eval(&block)
        app.create_header_footer(keys_handled)
        stdscr.refresh();
        begin
          app.form.handle_keys_loop
        rescue => err
          app.print_error("#{err}")
        end
      end
    end
    def get_current_values_as_hash
      @form.get_current_values_as_hash
    end
    def keyvalues
      values = []
      h = @form.get_fields_as_hash
      @keynames.each do |k|
        values << h[k].get_value
      end
      return values
    end
    def generic_form_actions(form)
      $log.debug("inside generic form actions")
      labels=["?~Help  ","C~Cancel", "D~Delete", "U~Update", 
        "M~ins Mode", "I~Insert    ",
        "Spc~Clear  ","F~FindAll", 
        "O~OrderBy",   "W~Where  ",
        "Y~copY from","L~Limit    "]
      validchars = "?CDUMOIFYLW "
      # should not exceed 9
        helptext = "Use Mode to get into insert mode, Insert to insert. Enter text on blank screen and use Findall. C-n (Next), C-p (Prev), C-[ (first) and C-] (last)."
      ret =  @main.askchoice(nil, "Choose action","",
                             labels,validchars, "helptext"=>helptext)
      @main.clear_error
      case ret
      when 'd'
        generic_form_delete(form)
      when 'u'
        generic_form_update(form)
      when 'i'
        begin
          generic_form_insert(form)
        rescue => err
          @main.print_error("ERROR: #{err}")
        end
      when 'm'
        disable_key_fields form, false
        form.set_defaults
        @main.print_status("Use Actions-I to insert")
      when 'y'
        disable_key_fields form, false
        #form.set_defaults
        @main.print_status("Use Actions-I to insert")
      when ' '
        disable_key_fields form, false
        #form.set_defaults
        form.clear_fields
        @main.print_status("Use Actions-F to search")
      when 'f'
        @find_mode = false
        @num_rows=generic_form_findall(form)
        @find_mode = true if @num_rows > 1
      when 'c'
        @main.print_error("Operation Cancelled")
      when 'o'
        @order_string = @main.get_string(nil,"Enter order by columns, separated by commas",50)
        @main.print_status("Use Actions-F to search")
      when 'l'
        @findall_limit = @main.get_string(nil,"Enter limit for find all", 5, @findall_limit)
      when 'w'
        # this may be used if wanting age > 10 or quantity < 1000 etc
        # default bombed on % chars FIXME need to escape the string.
        begin
        @where_string = @main.get_string(nil,"Enter where condition", 50, @where_string)
        @main.print_status("Use Actions-F to search")
        rescue
          @where_string = ""
          @main.print_error("Try again. Could not print earlier WHERE. Have blanked it out.")
        end

        #@where_string = @main.get_string(nil,"Enter where condition", 50)
      when '?'
        @main.print_status("Use Mode to get into insert mode, Insert to insert. Enter text on blank screen and use Findall. C-n (Next), C-p (Prev), C-[ (first) and C-] (last).")
      else
        @main.print_error("Not implemented yet!")
      end
    end
 
    ##
    # 
    #
    def get_keys_handled
      $log.debug("keys handled sql")
      @app_keys_handled=[
        { :keycode=>?\C-g, :display_code => "^G", :text => "Get Help  ", :action => "help" },
        { :keycode=>?\C-c, :display_code => "^C", :text => "Cancel    ", :action => "quit" },
        { :keycode=>?\C-x, :display_code => "^X", :text => "Actions ", :action => method(:generic_form_actions) },
        { :keycode=>?\C-s, :display_code => "^S", :text => "Select  ", :action => method(:generic_form_select)},
        { :keycode=>?\C-k, :display_code => "^K", :text => "Cut Line", :action => "REQ_CLR_EOL"},
        { :keycode=>?\C-d, :display_code => "^D", :text => "Del Char", :action => "REQ_DEL_CHAR"},
        { :keycode=>?\C-a, :display_code => "^A", :text => "Beg Line", :action => "REQ_BEG_LINE"},
        { :keycode=>?\C-e, :display_code => "^E", :text => "End Line", :action => "REQ_END_LINE"},
        { :keycode=>?\M-a, :display_code => "_A", :text => "Beg Fld", :action => "handle_m_a"},
        { :keycode=>?\M-e, :display_code => "_E", :text => "End Fld", :action => "handle_m_e"}
    ]
    @app_keys_handled
  end

#  def free_all
#    super
#    #@db.close if !@db.nil? XXX
#  end
 
  ##
  # Bind some specific keys, this will now show up in the labels below.
  #
  def bind_keys
    $log.debug("bindkey sql")
    bind_key ?\C-w, "REQ_NEXT_WORD"
    bind_key ?\C-b, "REQ_PREV_WORD"
    unbind_key ?\C-x
    bind_key ?\C-x, method(:generic_form_actions)
    bind_key ?\C-n, method(:generic_form_findnext)
    bind_key ?\C-p, method(:generic_form_findprev)
    bind_key ?\C-[, method(:generic_form_findfirst)
    bind_key ?\C-], method(:generic_form_findlast)


  end # method


  ### ADD HERE ###
end # class
