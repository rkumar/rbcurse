=begin
  * Name: rkumar
  * $Id$
  * Description   Query form object with its own key_handler
  * Author:
  * Date:
  * License:
    This is free software; you can copy and distribute and modify
    this program under the term of Ruby's License
    (http://www.ruby-lang.org/LICENSE.txt)

=end

require 'ncurses'
require 'rbcurse/rbform'

include Ncurses
include Ncurses::Form

# An extension of the FORM class.
# Needed so i can attach key_handlers for various forms. 
# Got tired of mucking around with the user_object class.
#
# Arunachalesha 
# @version 

class RBTableForm < RBForm 
  attr_accessor :datasource
  attr_accessor :rows_to_show

  def initialize(fields)
    super(fields)
    @baseno=0
    @currno=1 
    # default value to be overridden by applications
    @rows_to_show = fields.count-1
    @data_arr = []
  end
  def set_application(app)
    super(app)
    #raise "datasource is nil in RBTF set_application"
    @datasource = app.get_data_source
  end

  # receives an int key to process

  def handle_keys(ch, application)
    # these procs are temporarily place here
    # need to find a onetime place for them.
    field_init_proc = proc {
      # what win do i send and why??? XXX
      field_init_hook(self) # this needs to be called by keys too
      # this calls back to main app XXX
      #@main.field_init_hook(self) # this needs to be called by keys too
    }
    field_term_proc = proc {
      x = current_field
      ix = fields.index(x)   # should it not be @fields ? XXX
      fields[ix].set_field_back(A_NORMAL)
      field_term_hook(self) # this needs to be called by keys too
      #@main.field_term_hook(self) # this needs to be called by keys too XXX removed
    }

    set_field_init(field_init_proc)
    set_field_term(field_term_proc)

    case ch
    when 9 # tab XXX 2008-10-10 11:55 at best make crrent row unselected
      # nothing really will be handled by controller. don't want error
    when KEY_DOWN, 110 # 'n'
      handle_key_down
    when KEY_UP, 112   # p
      handle_key_up
    when KEY_LEFT
      form_driver(REQ_PREV_CHAR);
    when KEY_RIGHT
      form_driver(REQ_NEXT_CHAR);
    when 6 # c-f
      form_driver(REQ_NEXT_WORD);
    when 2 # c-b
      form_driver(REQ_PREV_WORD);
    when 1  # c-a
      form_driver(REQ_BEG_LINE);
    when 5  # c-e
      form_driver(REQ_END_LINE);
    when 32 # space
      handle_space
    when 45 # minus
      handle_minus
    when KEY_ENTER, 10, 46, 62 # . >
      # selection
      handle_enter
    when ","[0], "<"[0]
          # prev screen
          #break  XXX return a code fro break
      return :BREAK
    when 59 # ;
      handle_semicolon(self, get_curr_index(), get_curr_item())
    else 
          #return :UNHANDLED
          # we check against the keys installed by datasource
          #should be checking all event_listeners. but shortcut for now
          #consumed=@datasource.handle_keys(ch, get_curr_item(), @selecteditems)
          #raise "application: "+ @application.class.to_s
      consumed=@application.handle_unhandled_keys(ch, get_curr_item(), @selecteditems)
      return :UNHANDLED if !consumed
          # else returns OK from below                                
    end

    return :OK
  end
  # i think the win is required only to refresh if needed
  def field_init_hook(win)
      x = current_field
      ix = fields.index(x)   # should it not be @fields ?
      item = x.user_object
      if !item.nil? 
        if x.field_buffer(0) != ""
          fields[ix].set_field_back(Ncurses.COLOR_PAIR(4))
          row_focus_gained(self, fields, ix, item)
        end
      end
  end
  def field_term_hook(win)
  end
  
  # fields - internal fields array, dataarr - array of values
  # baseindex - start showing from what line
  # toshow - how many rows to show, should be same in each call.

  def scroll_lines(fields, dataarr, baseindex, toshow )
    raise "data arr is null. Check return in get_data()" if dataarr.nil?
    i = 0
    baseindex.upto(baseindex + toshow -1) { |menuctr|
      # the next check of datarr length means that some fields can be left dirty
      if menuctr < 0 || menuctr >= dataarr.length
        return -1
      end
      dataitem = dataarr[menuctr]
      field = fields[i]
      field.user_object = dataitem
      field.set_field_buffer(0, format_line(menuctr,dataitem))
      i += 1
    }
    0
  end

  #scroll page down
  def handle_space
    if @baseno+@rows_to_show < @data_arr.length() 
      incr = [@data_arr.length - (@baseno+@rows_to_show), @rows_to_show].min
      @baseno += incr
      scroll_lines(@fields, @data_arr, @baseno, @rows_to_show)
      field_init_hook(@defaultwin)
    else
      @main.print_error( "No more rows")
    end
  end
  
    #scroll page up
  def handle_minus
    if @baseno > 0
      incr = [@baseno, @rows_to_show].min
      @baseno -= incr
      scroll_lines(@fields, @data_arr, @baseno, @rows_to_show)
      field_init_hook(@defaultwin)
    else
      @main.print_error( "Already at start of index")
    end
  end
  
  # selection
  def handle_enter

    x = current_field
    ix = @fields.index(x)
    item = x.user_object
    status = @datasource.on_selection(get_curr_index(), item)  

  end

    # Go to next field */
  def handle_key_down

    if @currno >= @data_arr.length # XXX 2008-09-29 16:01 
      return
    end
    if @currno < @rows_to_show
      @currno += 1
      form_driver(REQ_NEXT_FIELD);
    else
      #scroll
      if @baseno+@rows_to_show < @data_arr.length() 
        @baseno += 1
        scroll_lines(@fields, @data_arr, @baseno, @rows_to_show)
        field_init_hook(@defaultwin)
      else
        @main.print_error( "No more rows")
      end
    end
    #@main.print_this(@my_form_win, @currno.to_s + "," + @baseno.to_s, 6, Ncurses.LINES-1, 69)
  end
  alias :next_row :handle_key_down 

  # Go to previous field
  def handle_key_up
    # Go to previous field
    if @currno > 1
      @currno -= 1
      form_driver(REQ_PREV_FIELD);
    else
      #scroll
      if @baseno > 0
        @baseno -= 1
        scroll_lines(@fields, @data_arr, @baseno, @rows_to_show)
        field_init_hook(@defaultwin)
      else
        @main.print_error("Already at start of index")
      end
    end
    #@main.print_this(@my_form_win, @currno.to_s + "," + @baseno.to_s, 6, Ncurses.LINES-1, 69)
  end

  # should be put in index or item FIXME , currindex is +1
  #select current field
  
  def handle_semicolon(my_form,currindex, curritem)
    if @selecteditems.include?currindex
      @selecteditems.delete(currindex)
      @main.print_status("Row #{currindex} UNselected")
    else
      @selecteditems << currindex
      @main.print_status("Row #{currindex} selected")
    end
    field = my_form.current_field
    field.set_field_buffer(0, format_line(currindex,field.user_object))
    next_row
  end

  def populate_form
      @data_arr = @datasource.get_data
      clear_fields(@fields)
      @selecteditems = [] 
      @baseno = 0 # 2008-10-08 17:59  reset for subseq query
      @currno = 1 # 2008-10-08 17:59  reset for subseq query
      scroll_lines(@fields, @data_arr, @baseno, @rows_to_show)
      raise "RBTF PF " + @main.class.to_s if @main.nil?
      # 2008-09-30 00:04 should immediately update headers
      index = 1
      index = 0 if @data_arr.length == 0 
      @main.print_top_right(@datasource.header_top_right(index))
  end
  def clear_fields(fields)
    # added setting back to normal. 2008-10-08 18:07 for subseq searches
    form_driver(REQ_FIRST_FIELD) # XXX
    fields.each{ |ff| ff.set_field_buffer(0,""); ff.set_field_back(A_NORMAL); ff.user_object=nil; }
      
    @application.wrefresh # 2008-10-08 18:03 
  end

  # get current index in table/rows
  #  XXX This returns row starting 1 not zero for some reason
  #  So you have to -1 to do any array work
  def get_curr_index
    (@baseno + @currno) -1 # 2008-10-08 17:06 XXX 
  end
  # 2008-10-08 16:59   -1 added since i am getting next item
  def get_curr_item
    @data_arr[get_curr_index()]
  end

  def row_focus_gained(win, fields, ix, item)
    act = @datasource.get_key(item)
    # clear previous off - now its begun to block
    #@main.print_this(win, "%*s" % [40,""], 5, Ncurses.LINES-1, 68)
    #@main.print_this(win, "%s" % act.to_s[0,40], 6, Ncurses.LINES-1, 68)
    @datasource.row_focus_gained(get_curr_index(), item) 
  end

  # needs to be user-defined based on what kind of data comes in
  def format_line(menuctr,dataitem)
    sel =" "
    sel = "X" if @selecteditems.include?(menuctr)
    sel+@datasource.format_line(menuctr,dataitem)
  end

  # this method is called once when the table starts up.
  # if datasource modifies data, like sorting, rerunning etc
  # it must call this. 
  def handle_search
    #@datasource.search(@qfields)
    @datasource.search(get_curr_index(), get_curr_item())  
  end

  # unhandled keys are passed to _other_ listeners

  ### ADD HERE ###
end # class
