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
require 'rbcurse/application'
require 'rbcurse/rbeditform'
require 'rbcurse/commons1'

include Ncurses
include Ncurses::Form

class EditApplication < Application
  include Commons1
    attr_reader :datasource
    attr_reader :form
    attr_reader :fields  

    # takes an array of fields and creates a form and manages it
    # also takes caller program, required to call the print and clear
    # takes datasource and sets it up, if not passed it must be passed later
    # to be usable
    def initialize(fields, main, datasource=nil)
      super()
      @fields = fields
      #@main = main
      @main = self
      #@form = create_table_form(fields)
      @form = create_edit_form(fields)
      @form.set_application(self)
      #@form.main = main
      @form.main = self
      @event_listeners = []
      create_datakeys(EditApplication::get_keys_handled()) # 2008-10-14 10:29 
      bind_keys

      # the class which gives data and responds to events
      #set_data_source(datasource) if !datasource.nil?
      @form.setup_observers()
      if block_given?
        begin
          yield self ## 2008-10-24 22:08 
        ensure
          free_all
        end
      end
    end
    ##
    # TODO
    #
    def self.get_keys_handled
      @app_keys_handled=[
        { :keycode=>?\C-g, :display_code => "^G", :text => "Get Help  ", :action => "help" },
        { :keycode=>?\C-c, :display_code => "^C", :text => "Cancel    ", :action => "quit" },
        { :keycode=>?\C-x, :display_code => "^X", :text => "Send   ", :action => "handle_save" },
        { :keycode=>?\C-v, :display_code => "^V", :text => "Save   ", :action => "save"},
        { :keycode=>?\C-k, :display_code => "^K", :text => "Cut Line", :action => "REQ_CLR_EOL"},
        { :keycode=>?\C-d, :display_code => "^D", :text => "Del Char", :action => "REQ_DEL_CHAR"},
        { :keycode=>?\C-a, :display_code => "^A", :text => "Beg Line", :action => "REQ_BEG_LINE"},
        { :keycode=>?\C-e, :display_code => "^E", :text => "End Line", :action => "REQ_END_LINE"},
        { :keycode=>?\M-a, :display_code => "_A", :text => "Beg Fld", :action => "handle_m_a"},
        { :keycode=>?\M-e, :display_code => "_E", :text => "End Fld", :action => "handle_m_e"}
    ]
    @app_keys_handled
  end
#  def create_window(derwincol)
#    #@window, @panel = create_table_window(@form, @form.rows_to_show, derwincol)
#    @window, @panel = create_edit_window(@form, @form.rows_to_show, derwincol)
#    return @window, @panel
#  end
  def create_window(qform_win_rows,
                    qform_win_cols,
                    qform_win_starty,
                    qform_win_startx)
    @window, @panel =  create_custom_window(@form,
                                    qform_win_rows,
                                    qform_win_cols,
                                    qform_win_starty,
                                    qform_win_startx)
    return @window, @panel
  end

      # derwincol is table_offset
  # @deprecated 
  # NOT USED 
  def create_edit_window(my_form, rows_to_show, derwincol)
    
    startrow = 2
      my_form_win = WINDOW.new(rows_to_show,0,startrow ,0)
      my_panel = my_form_win.new_panel
      Ncurses::Panel.update_panels

      my_form_win.bkgd(Ncurses.COLOR_PAIR(5));
      my_form_win.keypad(TRUE);

      # Set main window and sub window
      my_form.set_form_win(my_form_win);
      rows, cols = my_form.user_object[:row_col_array]
      #derwincol = 5 # 12
      # 2008-10-05 12:40 test XXX
      @subwin = my_form_win.derwin(rows+1, cols+2, 0, derwincol);
      raise "could not create subwin! #{rows}, #{cols+2}, #{derwincol}" if @subwin.nil?
      my_form.set_form_sub(@subwin)
      my_form.post_form();
      my_form_win.wrefresh();
      start_row = 1

      Ncurses.refresh();
      repaint_subwin  # without this it wont paint till much later
      @window = my_form_win # shitty FIXME
      @panel = my_panel
      return my_form_win, my_panel
  end
  
  def repaint_subwin
    @subwin.box(0,0)
    @subwin.wrefresh(); # without this it wont paint till much later
  end
  # could be made static / class level - reverted since called from constructor
  def create_edit_form(fields)
    my_form = create_form_with(RBEditForm.new(fields));
    return my_form;
  end

  # creates a simple single field display-only table
  def self.create_edit_fields(rows_to_show,
                          fieldlen, 
                          att_hash={}
                         )
    fields = []
    0.upto(rows_to_show) { |i|
      field = FIELD.new(1, fieldlen, i*(att_hash[:row_space]||1)+(att_hash[:title_row_span]||3), 1, 0, 0)
      field.field_opts_off(O_EDIT)
      field.field_opts_off(O_STATIC)
      fields.push(field)
    }
    return fields
  end

  # not yet in use
  def add_event_listener(obj)
    @event_listeners << obj
  end

  # this differs from the form's key_handler
  # it delegates form's unhandled keys to the datasource.
  # is this the right place for this ??? XXX
  #def handle_keys(ch, curritem, listselected=[])
  ## renamed on 2008-10-04 23:45 
#  def set_data_source(datasource)
#    @datasource = datasource
    # 2008-10-05 09:38 
    #@form.datasource = @datasource # 2008-10-24 10:08 
#    create_datakeys(@datasource.get_keys_handled())
    #add_event_listener(datasource) 
#  end
  def get_data_source()
    @datasource 
  end
  def populate_form
    #@form.populate_form # this could put me in endlessly
  end
  alias  :get_datasource :get_data_source
 

 
  ##
  # Bind some specific keys, this will now show up in the labels below.
  #

  def bind_keys
    bind_key ?\C-w, "REQ_NEXT_WORD"
    bind_key ?\C-b, "REQ_PREV_WORD"
#    bind_key ?\C-l, "REQ_INS_MODE"
#    bind_key ?\C-o, "REQ_OVL_MODE"
  end # method

  def user_prefs hsh
    form.user_object.merge! hsh
  end

  ### ADD HERE ###
end # class
