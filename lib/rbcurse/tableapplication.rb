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

# This has the functionality of a tabular/multi-row application
#   * key-strokes
#   * most features are with the tableform itself.
#   * will be related to a datasource - lets see about that
#   * features that are across multiple table apps are here.
#
# Arunachalesha 
# @version 
#
require 'rubygems'
require 'ncurses'
require 'rbcurse/application'
require 'rbcurse/rbtableform'

include Ncurses
include Ncurses::Form

class TableApplication < Application
    attr_reader :datasource
    # table form is a ref to the tabular display form
    # it shoud contain and manage its datasource, actually, this class need not be concerned about
    # the datasource - the form should, but for titles
    attr_reader :form
#    attr_reader :window  # alreadt in Application now
    attr_reader :fields  

    # takes an array of fields and creates a form and manages it
    # also takes caller program, required to call the print and clear
    # takes datasource and sets it up, if not passed it must be passed later
    # to be usable
    def initialize(fields, main, datasource=nil)
      super()
      @fields = fields
      @main = main.nil? ? self : main # 2008-10-25 23:01 
      @form = create_table_form(fields)
      @form.set_application(self)
      @form.main = @main
      @event_listeners = []

      # the class which gives data and responds to events
      set_data_source(datasource) if !datasource.nil?
      if block_given?
        begin
          yield self ## 2008-10-24 22:08 
        ensure
          free_all
        end
      end
    end
    def self.get_keys_handled
      @app_keys_handled=[
        { :keycode=>[?<,?,], :display_code => "<", :text => "Back   ", :action => "quit" },
        { :keycode=>[?>,?.], :display_code => ">", :text => "Open   ", :action => "handle_enter"},
        { :keycode=>?P, :display_code => "P", :text => "PrevCmd   ",  :action => "handle_key_up"},
        { :keycode=>?N, :display_code => "N", :text => "NextCmd ", :action => "handle_key_down" },
        { :keycode=>?-, :display_code => "-", :text => "PrevPage ", :action => "handle_minus" },
        { :keycode=>32, :display_code => "Spc", :text => "NextPage ", :action => "handle_space" }
    ]
    @app_keys_handled
  end
  def create_window(derwincol)
    @window, @panel = create_table_window(@form, @form.rows_to_show, derwincol)
    return @window, @panel
  end

      # derwincol is table_offset
  def create_table_window(my_form, rows_to_show, derwincol)
    # this max could cause problems if we wanna have it higher
      #startrow = [5,@table_width-(rows_to_show+1) ].max
    title_row_span = 3
    twidth = [@table_width, rows_to_show+title_row_span+1].min
    startrow = @table_width - (rows_to_show+2)
      #raise "startrow is #{startrow} #{twidth}"
      my_form_win = WINDOW.new(twidth,0,startrow ,0)
      my_panel = my_form_win.new_panel
#      @defaultwin = my_form_win  # XXX concern about variable
      Ncurses::Panel.update_panels

      my_form_win.bkgd(Ncurses.COLOR_PAIR(5));
      my_form_win.keypad(TRUE);

      # Set main window and sub window
      my_form.set_form_win(my_form_win);
      rows, cols = my_form.user_object[:row_col_array]
      #derwincol = 5 # 12
      # 2008-10-05 12:40 test XXX
      rows = [rows, twidth].min
      @subwin = my_form_win.derwin(rows, cols+2, 0, derwincol);
      raise "could not create subwin! #{rows}, #{cols+2}, #{derwincol}" if @subwin.nil?
      my_form.set_form_sub(@subwin)
      my_form.post_form();
      my_form_win.wrefresh();
      start_row = 1
      @main.print_this(my_form_win, @datasource.format_titles, 5, start_row, derwincol+1)
      my_form_win.mvwhline( start_row+1, derwincol+1, ACS_HLINE, cols)

      #myform.window = my_form_win # 2008-10-15 10:02 
      Ncurses.refresh();
      repaint_subwin  # without this it wont paint till much later
      return my_form_win, my_panel
  end
  
  def repaint_subwin
    @subwin.box(0,0)
    @subwin.wrefresh(); # without this it wont paint till much later
  end
  # could be made static / class level - reverted since called from constructor
  def create_table_form(fields)
    my_form = create_form_with(RBTableForm.new(fields));
    return my_form;
  end

  # creates a simple single field display-only table
  def self.create_table_fields(rows_to_show,
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

##### XXX
  #### This looks suspicously like rbeditforms handler
  #### stop passing curritem etc, pass form itself to handlers
  # take care or Proc in action as rbeditform has done.

  # this differs from the form's key_handler
  # it delegates form's unhandled keys to the datasource.
  # is this the right place for this ??? XXX
  #def handle_keys(ch, curritem, listselected=[])
  ## renamed on 2008-10-04 23:45 
  def handle_unhandled_keys(ch, curritem, listselected=[])
    raise "unhandled called : #{ch}: #{@datakeys.count}" if @datakeys.count == 0
    return false if @datakeys.nil?
    begin # XXX chr fails with left and rt arrow what if someones wants to trap ?
      suffix=ch.chr.upcase
    rescue
      return false
    end
    chup=suffix[0] # will break in 1.9
    #raise "unhandled called " + ch + ":"+ chup.chr
    if @datakeys.include?chup
      if @datakeys[chup] == nil
        # 2008-10-08 16:29 
        if @datasource.respond_to?"handle_#{suffix}"
          @datasource.send("handle_#{suffix}", curritem, listselected)
        else
          @main.print_error("Datasource does not handle #{suffix}")
        end
      else
        if @datasource.respond_to?@datakeys[chup]
          @datasource.send(@datakeys[chup], curritem, listselected)
        else
          @main.print_error("Datasource does not handle this key #{chup.chr}")
        end
      end
      return true
    end
    return false
  end
  def set_data_source(datasource)
    @datasource = datasource
    # 2008-10-05 09:38 
    @form.datasource = @datasource
    create_datakeys(@datasource.get_keys_handled())
    add_event_listener(datasource) 
  end
  def get_data_source()
    @datasource 
  end
  def populate_form
    @form.populate_form
  end
  alias  :get_datasource :get_data_source
 
  ### ADD HERE ###
end # class
