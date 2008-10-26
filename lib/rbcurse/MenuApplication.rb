#*******************************************************#
#                                                       #
#                                                       #
# Arunachalesha                                         #
# $Id$  #
#*******************************************************#
require 'rubygems'
require 'ncurses'
require 'Application'

include Ncurses
include Ncurses::Form

class MenuApplication < Application
  def initialize
    super
    @action_posy = Ncurses.LINES-1
    @action_posx = 12
    @app_menu_array = nil
    @app_quit = false
  end
  def create_menu_fields(menuarr)
    @app_menu_array = menuarr
    fields = []
    @app_keyhash = {}
    @app_keypos_hash = {}
    menuarr.each_index { |i|
      fld_width = 70
      spacing = 2
      field = FIELD.new(1, fld_width, i*spacing, 1, 0, 0)
      menuitem = menuarr[i]
      field.user_object = menuitem
      field.set_field_buffer(0, sprintf("%3s    %-20s  - %-30s", menuitem["key"], menuitem["short"],menuitem["long"]))
      field.field_opts_off(O_EDIT)
      field.field_opts_off(O_STATIC)
      fields.push(field)
      @app_keyhash[menuitem["key"].upcase]=menuitem["action"]
      @app_keyhash[menuitem["key"].downcase]=menuitem["action"]
      @app_keypos_hash[menuitem["key"].downcase] = i
    }
    return fields
  end
  def menu_action(action)
    # if user has defined a proc, call it
    if ((str=defined?action)=="method")
      send(action)  # NOT TESTED XXX
    else
      # assume action is a classname with a run
      acts = action.to_s  # if symbol
      actsdc = acts.downcase
      begin
        require "#{actsdc}"
        nextprog=Object::const_get(acts).new(nil)
      rescue LoadError => err_mess
        print_error "ERROR: File '#{actsdc}' with 'class #{acts}' required: " + err_mess
        return
      rescue Exception => exc_mess
        print_error "class #{acts} required: " + err_mess
        return
      end
      if nextprog.respond_to?:run
        nextprog.run
      else
        print_error "ERROR: run() required in: class #{acts}"
      end
    end
  end
   # Go to next field 
  # awful hack, putting the nil params to its standard
  def handle_key_down(my_form, curritem=nil, listselected=[])
    my_form.form_driver(REQ_NEXT_FIELD);
  end
  def handle_keys(my_form_win, my_form)
    field_init_proc = proc {
      x = my_form.current_field
      #fields = @form_field_hash[my_form]
      fields = my_form.user_object[:fields]
      ix = fields.index(x)
      fields[ix].set_field_back(Ncurses.COLOR_PAIR(4))
      item = @app_menu_array[ix]
      act = item["message"]
      # print_status does not refresh the main window. it refreshes its own window.
      # so the above hilighting began failing!!
      print_action(act.to_s)
      field_init_hook()
    }
    field_term_proc = proc {
      x = my_form.current_field
      #fields = @form_field_hash[my_form]
      fields = my_form.user_object[:fields]
      ix = fields.index(x)
      fields[ix].set_field_back(A_NORMAL)
      field_term_hook()
    }

    my_form.set_field_init(field_init_proc)
    my_form.set_field_term(field_term_proc)
    my_form.form_driver(REQ_FIRST_FIELD);
    while((ch = my_form_win.getch()) != KEY_F1 )
      clear_error
      case ch
      when KEY_DOWN
        handle_key_down(my_form)
      when KEY_UP
        handle_key_up(my_form)
      when KEY_ENTER, 10
        # selection
        handle_enter(my_form)
      else
        # check for hotkey
        c = sprintf("%c", ch);
        if @app_keyhash.include?c
          if @app_keyhash[c] == "quit"  # bad hack, i really don't know a better way
            @app_quit = true    # XXX
            break
          end
          handle_hot_key(my_form,c)
        else
          handle_unhandled_key(my_form,ch)
        end
      end
      my_form_win.refresh # absence of this was resulting in highlight showing on wrong row
      @header_win.refresh
      @footer_win.refresh
      # or not showing at all if i removed print.
      Ncurses::Panel.update_panels
      break if @app_quit
    end
  end
  # Go to previous field
  def handle_key_up(my_form, curritem=nil, listselected=[])
    my_form.form_driver(REQ_PREV_FIELD);
  end
  # selection
  def handle_enter(my_form, curritem=nil, listselected=[])
    x = my_form.current_field
    #fields = @form_field_hash[my_form]
    fields = my_form.user_object[:fields]
    ix = fields.index(x)
    item = @app_menu_array[ix]
    act = item["action"]
    if act == "quit"  # bad hack, i really don't know what to do.
      @app_quit = true # XXX
      return
    end
    menu_action(act)
  end
  # currently this only handles keys internally. 2008-09-30 17:00
  # we need to check for listeners so it can be generalized for
  # the multirow / datasource etc.
  # Can be used from menu programs.

  def simple_handle_keys(ch, my_form, curritem, listselected=[])
    return false if @datakeys.nil?
    begin # XXX fails with left and rt arrow what if someones wants to trap ?
    suffix=ch.chr.upcase
    rescue
      return false
    end
    chup=suffix[0] # will break in 1.9
    if @datakeys.include?chup
      if @datakeys[chup] == nil
        #@datasource.send("handle_#{suffix}", curritem, listselected)
        # highly unlikely this will work
        send("handle_#{suffix}", curritem, listselected)
      else
        #@datasource.send(@datakeys[chup], curritem, listselected)
        # XXX many of these guys need my_form if they are key_handlers XXX FIXME
        send(@datakeys[chup], my_form, curritem, listselected)
      end
      return true
    end
    return false
  end
   
 def handle_unhandled_key(my_form, ch)
    x = my_form.current_field
    #fields = @form_field_hash[my_form]
    fields = my_form.user_object[:fields]
    ix = fields.index(x)
    item = @app_menu_array[ix]
    ret = simple_handle_keys(ch, my_form, item, nil) 
    print_error(sprintf("[Command %c is not defined for this screen]   ", ch)) if !ret
  end
 
  def handle_hot_key(my_form, c)
    print_status(@app_keyhash[c].to_s)
    pos = @app_keypos_hash[c.downcase]
    x = my_form.current_field
    #fields = @form_field_hash[my_form]
    fields = my_form.user_object[:fields]
    ix = fields.index(x)
    (pos-ix).times{ my_form.form_driver(REQ_NEXT_FIELD) } if pos > ix
    (ix-pos).times{ my_form.form_driver(REQ_PREV_FIELD) } if pos < ix
    if @app_keyhash[c] == "quit"  # bad hack, i really don't know what to do.
      @app_quit = true
      return -1
    end
    menu_action(@app_keyhash[c])
    0
  end
  def quit(my_form, curritem=nil, listselected=[])
    @app_quit = true
  end


  ### ADD HERE ###
end # class
