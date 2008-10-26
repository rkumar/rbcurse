=begin
  * Name: rkumar
  * $Id$
  * Description   Query form object with its own key_handler
  * Author:
  * Date:
  * License:
    This is free software; you can copy and distribute and modify
    this program under the term of Ruby's License
    (http://www.ruby-lang.org/LINCENSE.txt)

=end

# An extension of the FORM class.
# Needed so i can attach key_handlers for various forms. 
# Got tired of mucking around with the user_object class.
#
# Arunachalesha 
# @version 
#
#require 'ncurses'
require 'rbcurse/rbform'

include Ncurses
include Ncurses::Form

class RBQueryForm < RBForm 
  attr_reader :key_labels

  def initialize(fields)
    super(fields)
    @key_labels=["^G~Help  ", "  ~      ","Ent~Run Query","a-Q~Exit     "]
  end

  # receives an int key to process
  def handle_keys(ch, application)

    # added hooks here 2008-10-06 10:52 
    # these procs are temporarily place here
    # need to find a onetime place for them.

    @main.print_key_labels( 0, 0, @key_labels)
    field_init_proc = proc {
      # what win do i send and why??? XXX
      #field_init_hook(self) # this needs to be called by keys too
      # this calls back to main app XXX but there are 2 forms
      #@main.field_init_hook(self) # this needs to be called by keys too
    }
    field_term_proc = proc {
      #x = current_field
      #ix = fields.index(x)
      #fields[ix].set_field_back(A_NORMAL)
      #field_term_hook(self) # this needs to be called by keys too
      #@main.field_term_hook(self) # this needs to be called by keys too
    }
    set_field_init(field_init_proc)
    set_field_term(field_term_proc)
    case ch
    when KEY_BACKSPACE, 127  # command mode
      form_driver(REQ_DEL_PREV);
    when KEY_LEFT
      form_driver(REQ_PREV_CHAR);
    when KEY_RIGHT
      form_driver(REQ_NEXT_CHAR);
    when 1  # c-a
      form_driver(REQ_BEG_LINE);
    when 5  # c-e
      form_driver(REQ_END_LINE);
    when -1  # c-c
      #@qfields.each{ |fld| fld.set_field_buffer(0,"") }  # XXX 
      fields = get_fields()
      fields.each{ |fld| fld.set_field_buffer(0,"") }  # XXX 
      form_driver(REQ_FIRST_FIELD);

    when KEY_UP
      form_driver(REQ_PREV_FIELD);
      form_driver(REQ_END_LINE);
    when KEY_DOWN, 9  # tab added 2008-10-10 11:56 XXX
      form_driver(REQ_NEXT_FIELD);
      form_driver(REQ_END_LINE);
    when KEY_ENTER, 10 #
      # selection
      form_driver(REQ_NEXT_FIELD);
#      raise "application "+ application.class.to_s
      application.output_form.handle_search                       # XXX
      #should return a SUBMIT and let qa handle it
      Ncurses::Panel.update_panels();
      Ncurses.doupdate();
      form_driver(REQ_FIRST_FIELD);
      form_driver(REQ_END_LINE);
    else
      # chr range is 0..255
      if ch > 255 or ch.chr =~ /[[:cntrl:]]/
        # seems a tab comes here
        #Ncurses.beep
        # either we just swallow it with a beep, or ret a -1 
        # so it can be processed. Like saw a alt-q or F1 or quit command
        return :UNHANDLED
      else
      #  stdscr.refresh # is thsi required ??
        form_driver(ch)
      end
    end
    #print_error("Press TAB for command mode")
    #Ncurses::Panel.update_panels(); # this was robbing the cursor XXX
    #Ncurses.doupdate();
#   next
    # since this chap handles all keys, we return a zero so no need to pass on.
    # Actually we should trap control keys and return a -1 rather than pass to
    # handler
    return :OK
  end



  ### ADD HERE ###
end # class
