#!/usr/bin/env ruby

require 'rubygems'
require 'ncurses'
require 'commons1'
require 'MenuApplication'

include Ncurses
include Ncurses::Form
include Commons1

class Menu1 < MenuApplication
  def initialize
    super
    @fields = nil
    @menuarr=[{"action"=>"ContractViewer", "short"=>"Contracts", "message"=>"Contracts", "key"=>"C", "long"=>"View Contracts"}, {"action"=>"TransactionViewer", "short"=>"Transactions", "message"=>"Trans", "key"=>"T", "long"=>"View Transactions"}, {"action"=>"Gen2", "short"=>"Email", "message"=>"Email", "key"=>"E", "long"=>"Le ugly email sender"}, {"action"=>"Help", "short"=>"Help", "message"=>"Help", "key"=>"?", "long"=>"Get help on using KillerCurses(tm)"}, {"action"=>"quit", "short"=>"Quit", "message"=>"Quit", "key"=>"Q", "long"=>"Leave the KillerCurses program"}]
    @labelarr=[{"position"=>[-1, 28], "color_pair"=>5, "text"=>"Copyright 2008, University of Antarctica"}]
    @form_headers={"header"=>[0, 0, "  Demo App, V0.2    MAIN MENU "], "header_top_center"=>"NCOR", "header_top_left"=>"TUIsted"}

    # additional labels
    #what about keys to be bound but not shown like ,. which are synomous to <>
    # 2008-10-01 00:42 you  can specify multiple keys like < and , which both bind to 
    # same action. Case is taken care of for alphas.
    @keys_handled=[
        { :keycode=>[?<,?,], :display_code => "<", :text => "Back   ", :action => "quit" },
        { :keycode=>[?>,?.], :display_code => ">", :text => "CurRow ", :action => "handle_enter"},
        { :keycode=>?P, :display_code => "P", :text => "PrevCmd ",  :action => "handle_key_up"},
        { :keycode=>?N, :display_code => "N", :text => "NextCmd ", :action => "handle_key_down" }
    ]

  end

  # may be defined by user to extend functionality of when a menu row gets focus
  def field_init_hook
  end
  # may be defined by user to extend functionality of when a menu row loses focus
  def field_term_hook
  end

  ###DEFS_COME_HERE###
  
  def run

    ###PROCS_COME_HERE###

    create_header_win()  # super takes care of this

    create_footer_win()  # super takes care of this
    Ncurses::Panel.update_panels

    @main = self
    # Initialize the fields 
    @fields = create_menu_fields(@menuarr)

    begin
    # Create the form and post it
      @my_form = create_default_form(@fields)
      #@form = @my_form # XXX
      @my_form_win,@my_form_panel = create_default_window(@my_form)

      print_screen_labels(@my_form_win, @labelarr)

      print_headers(@form_headers)

      add_to_application_labels(@keys_handled)
      restore_application_key_labels()
      stdscr.refresh();


      # Loop through to get user requests
      # how to extend key_handing ??? XXX
      handle_keys(@my_form_win, @my_form)

#    ensure
      # Un post form and free the memory
      self.free_all
      @my_form.unpost_form();
      @my_form.free_form();
      @fields.each {|f| f.free_field()}
      Ncurses::Panel.del_panel(@my_form_panel) 
      @my_form_win.delwin
      
    end
  end
end

if __FILE__ == $0
  # Initialize curses
  begin
    stdscr = Ncurses.initscr();
    Ncurses.start_color();
    Ncurses.cbreak();
    Ncurses.noecho();
    Ncurses.keypad(stdscr, true);

    m = Menu1.new
    m.run

  ensure
    Ncurses.endwin();
  end

end
