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

# This has a query form (v simple) and a reference to an output table
# It will pass unhandled keys to the output table
# Also it will invoke the handle_search and other expected methods of the
# output table. populate table/form could be one.
#   * key-strokes
#   * selection and other features specific to mrows
#   * will be related to a datasource - lets see about that
#
# Arunachalesha 
# @version 
#
require 'rubygems'
require 'ncurses'
require 'rbcurse/tableapplication'
require 'rbcurse/rbqueryform'

include Ncurses
include Ncurses::Form

#  2008-10-04 15:01 
# This class should handle the integration between the query form and the table form.
# It should be aware of which is the query window and which s the results.
# Currently there is nothing here to make it look like it is a query application.
#
class QueryApplication < Application 
  attr_reader :form
#  attr_reader :window
  attr_reader :output_app
  attr_reader :output_form # this is internal to output_app and we should avoid this

  def initialize(fields, main)
    super()
    #@main = main
    @main = self  # 2008-10-25 20:36 WINDOWNIL
    raise "Error main nil" if main.nil?
    @form = create_query_form(fields)
    @form.set_application(self)
    #@form.main = main
    @form.main = self  # 2008-10-25 20:36 WINDOWNIL
    if block_given?
      begin
        yield self ## 2008-10-25 20:22 
      ensure
        free_all
      end
    end
  end
  # this is what the query form relates to.
  # should this be the form or the app ????? XXX lets see
  def set_output_application(output)
    @output_app = output
    @output_form = @output_app.form 
    @output_app.datasource.query_app = self
  end
  def populate_form
    @output_form.populate_form
  end

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

  # create a basic query form, nothing great

  def create_query_form(fields)
    f=RBQueryForm.new(fields);
    my_form = create_form_with(f)
    # 2008-10-10 12:31 next 2 lines added since main not initia in query form
    my_form.set_application(self)
    my_form.main = @main
    #my_form = create_form_with(RBQueryForm.new(fields));
    #form = FORM.new(fields);

    return my_form;
  end

  # the names should be different.
  # an app checks and handles keys in a loop, despatching for form;s keyhandlers for indiv
  # strokes.
  # A form handles a key at a time. loop added so doesn't ovrride App class when we put it

  def handle_keys_loop()


    # keys that will be passed in by datasource and loaded in here for quick ref
    @form.form_driver(REQ_FIRST_FIELD);
    # Loop through to get user requests
    @intable = false
    @form.set_current_field(@form.fields[0])

    while((ch = @window.getch()) != 197 )
      @main.clear_error
      #@intable = !@intable if ch==9 or ch == 266 # tab
      @intable = !@intable if ch == 266 #  F2
      @intable = false if ch==9 # tab
      # 2008-10-08 17:31 XXX don't let him go if no data
      @intable = false if @intable and @output_app.datasource.data_length == 0
      if @intable == false
        #application_key_labels
        # this does basic key handling of any form except that for ENTER 
        # it calls the handle_search and then updates display
        ret = @form.handle_keys(ch, self)
        if ch == KEY_ENTER or ch == 10
          @intable = true # XXX should be data
          make_table_selected
        end
        # if handler returns -1 we allow next handler to process
        # usually for control keys that were not handled.
        break if ret == :BREAK or ret == :QUIT
        next if ret == :OK
      end
      #IF ch==9 or ch == 266 # tab
      if ch == 266 # tab
        # new 2008-10-05  added so first row lookks selected
        if @intable == true
          make_table_selected
        else
          @form.refresh
        end
        next
      end
      ret = @output_form.handle_keys(ch, self)
      # if handler returns -1 we allow next handler to process
      # usually for control keys that were not handled.
      break if ret == :BREAK or ret == :QUIT
      if ret == :UNHANDLED
        # we check against the keys installed by datasource
        #should be checking all event_listeners. but shortcut for now
        #consumed=@datasource.handle_keys(ch, get_curr_item(), @selecteditems)
        #consumed=handle_keys(ch, @output_form.get_curr_item(), @selecteditems)

        application_key_handler(ch);
        #@main.print_error( sprintf("[Command %c (%d) is not defined for this screen]   ", ch,ch))
      end
      #@qform.form_driver(ch)
      # by moving next line above updates, now the cursor is not shown
      # at line 2,0 XXX
      @main.print_top_right(@output_form.datasource.header_top_right(@output_form.get_curr_index+1))
      @window.refresh
      Ncurses.doupdate();
      Ncurses::Panel.update_panels();
      Ncurses.doupdate(); # this is essential otherwise does not update row movment properly
      #repaint_subwin; # without this the border was getting eaten up on scroll
      # down at times when the form is large.
    end # while getch loop
  end # def
  # old, avoid usage since you don't get titles
  def get_query_fields
    queryflds = [] 
    fields = @form.fields
    fields.each{ |qq| queryflds << qq.field_buffer(0) }
    queryflds
  end
  def make_table_selected
    @output_form.field_init_hook(nil)
    # hack to make the selection appear
    @output_form.form_driver(REQ_NEXT_CHAR)
    @output_form.form_driver(REQ_PREV_CHAR)
    @output_form.wrefresh
    #@main.restore_application_key_labels
    @output_app.restore_application_key_labels
  end
  def restore_application_key_labels
    if @form.key_labels != nil
      @key_labels = @form.key_labels
    end
    super
  end

  ### ADD HERE ###
end # class
