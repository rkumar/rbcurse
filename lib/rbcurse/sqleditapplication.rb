=begin
  * Name: sqleditapplication.rb
  * $Id$
  * Description: sql table editing and viewing application.   
  * Author: rkumar
  * Date: 2008-11-01
  * License: (http://www.ruby-lang.org/LICENSE.txt)

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
    attr_reader :config
    attr_accessor :keyvalues
    attr_accessor :order_string
    attr_accessor :where_string
    attr_accessor :findall_limit # how many rows to limit find all to.
    # should navigation keys be displayed or not, true/false, default false
    attr_accessor :show_navigation_keys
    attr_accessor :use_rowid   # true or false. useful if someone has duplicated and no unique

    # takes an array of fields and creates a form and manages it
    # also takes caller program, required to call the print and clear
    # takes datasource and sets it up, if not passed it must be passed later
    # to be usable
    def initialize(fields, main, db, tablename, keynames, config={})
      @db = db
      @tablename = tablename
      @keynames = keynames
      @config = config
      @keyvalues = []
      @use_rowid = true
      @findall_limit = config.fetch("findall_limit", 100)
      @order_string = config.fetch("order_string", "")
      @where_string = config.fetch("where_string", "")
      set_form_actions(config.fetch("form_actions", [:all]))
      set_sql_actions(config.fetch("sql_actions", [:all]))
      super(fields, main)
      #@main = self
      #@form.main = self

      # the class which gives data and responds to events
    end
    ##
    # creates a default application given a table name and key field.
    # It will create fields as per its defaults.
    #
    def self.create_default_application(db, tablename, keynames, fields = nil, config={}, &block)

      fields = SingleTable.generic_create_fields(db, tablename , 20, config) if fields.nil?

      eapp = SqlEditApplication.new(fields, self, db, tablename, keynames, config)  do |app|
        max_rows = config.fetch("max_rows", 20)
        wrap_at = config.fetch("wrap_at", max_rows)
        labelarr = config.fetch("labelarr", nil)
        eform_win, eform_panel = app.create_window(max_rows, 0, 1, 0)

        if config.include? "keys"
            app.form.set_handler :form_init, Proc.new { app.generic_form_populate(app.form, nil, nil, nil, config["keys"])}
        end

        app.wrefresh();
        app.print_screen_labels(eform_win, labelarr) if !labelarr.nil?
        @mode = config.fetch("mode", :all)
        mode = @mode
        case mode
        when :view_one
          app.set_sql_actions([:nosubmenu])
        when :view_any
          app.set_sql_actions([:select, :nosubmenu])
        when :delete_one
          app.set_sql_actions([:delete])
        when :delete_any
          app.set_sql_actions([:select,:delete])
        when :edit_one
          app.set_sql_actions([:delete, :update])
        when :edit_any
          app.set_sql_actions([:select, :delete, :update])
        when :insert
          app.set_sql_actions([:insert])
        when :browse
          app.set_sql_actions([:select,:findall])
        when :all
        end
        #app.form_headers["header_top_center"] = "Table: #{tablename} Mode: #{mode.to_s}"
        app.form_headers["header_top_center"] = "#{tablename.capitalize} #{mode.to_s.capitalize}"
        app.instance_eval(&block)
        keys_handled = app.get_keys_handled() 
        app.create_header_footer(keys_handled)
        stdscr.refresh();
        begin
          app.form.handle_keys_loop
        rescue => err
          $log.error(err.backtrace.join("\n"))
          app.print_error("SEA: #{err}")
        end
      end
    end
    def self.create_view_one_application(db, tablename, keyfields, fields, config={}, &block)
      #config.merge!({"mode"=>:view_one, "keys"=>keys})
      config["mode"]=:view_one
      app=self.create_default_application(db, tablename, keyfields, fields, config, &block )
      return app
    end
    def self.create_view_any_application(db, tablename, keyfields, fields, config={}, &block)
      config["mode"]=:view_any
      app=self.create_default_application(db, tablename, keyfields, fields, config, &block )
      return app
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
    def set_sql_actions(actions)
      @sql_actions = actions
    end
    def set_form_actions(actions)
      @form_actions = actions
    end
    def generic_sql_actions(form)
      labels=["?~Help  ","C~Cancel"] 
      validchars = "?C"
      if @sql_actions.include? :all or @sql_actions.include? :delete
        labels << "D~Delete" 
        validchars += "D"
      else
        labels << " ~      " 
      end
      if @sql_actions.include? :all or @sql_actions.include? :update
        labels << "U~Update" 
        validchars += "U"
      else
        labels << " ~      " 
      end
      if @sql_actions.include? :all or @sql_actions.include? :insert
        labels += [ "M~ins Mode", "I~Insert    "]
        validchars += "MIY"
      end
      if @sql_actions.include? :all or @sql_actions.include? :findall
        labels += [ "Spc~Clear  ","F~FindAll", "O~OrderBy",   "W~Where  ", "L~Limit    "]
        validchars += " FOWL"
      end
      if @sql_actions.include? :all or @sql_actions.include? :insert
        labels << "Y~copY from"
      end
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
        disable_key_fields form, false, false
        form.set_defaults
        @main.print_status("Use Actions-I to insert")
      when 'y'
        disable_key_fields form, false, false
        #form.set_defaults
        @main.print_status("Use Actions-I to insert")
      when ' '
        disable_key_fields form, false, false
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
      $log.debug("SQL_ACT: #{@sql_actions}")
      @app_keys_handled=[
        { :keycode=>?\C-g, :display_code => "^G", :text => "Get Help  ", :action => "help" },
        { :keycode=>?\C-c, :display_code => "^C", :text => "Cancel    ", :action => "quit" }
      ]
    @app_keys_handled << 
      { :keycode=>?\C-x, :display_code => "^X", :text => "Actions ", :action => method(:generic_sql_actions) } if !@sql_actions.include? :nosubmenu
    @app_keys_handled << 
        { :keycode=>?\C-s, :display_code => "^S", :text => "Select  ", :action => method(:generic_form_select)} if @sql_actions.include? :all or @sql_actions.include? :select
    @app_keys_handled += [
        { :keycode=>?\C-k, :display_code => "^K", :text => "Cut Line", :action => "REQ_CLR_EOL"},
        { :keycode=>?\C-d, :display_code => "^D", :text => "Del Char", :action => "REQ_DEL_CHAR"}] if sql_actions_include? :update or sql_actions_include? :insert

        # only if navig keys to be displayed, but take care that the keys shold not stop working!
    @app_keys_handled += [
        { :keycode=>?\C-a, :display_code => "^A", :text => "Beg Line", :action => "REQ_BEG_LINE"},
        { :keycode=>?\C-e, :display_code => "^E", :text => "End Line", :action => "REQ_END_LINE"},
        { :keycode=>?\M-a, :display_code => "_A", :text => "Beg Fld", :action => "handle_m_a"},
        { :keycode=>?\M-e, :display_code => "_E", :text => "End Fld", :action => "handle_m_e"} ] if @show_navigation_keys
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
    $log.debug("BIND: #{@sql_actions}")
    super
#    bind_key ?\C-x, method(:generic_sql_actions) # conditional
    if sql_actions_include? :browse or sql_actions_include? :find_all
      bind_key ?\C-n, method(:generic_form_findnext)
      bind_key ?\C-p, method(:generic_form_findprev)
      bind_key ?\C-[, method(:generic_form_findfirst)
      bind_key ?\C-], method(:generic_form_findlast)
    end
  end # method
  def sql_actions_include? act
    return true if @mode == :all or @sql_actions.include? :all
    return (@mode == act or @sql_actions.include? act)
  end

  ### ADD HERE ###
end # class
