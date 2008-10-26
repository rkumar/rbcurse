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

=end

require 'rubygems'
require 'ncurses'
require 'yaml'
require 'editapplication'

include Ncurses
include Ncurses::Form

class <%= @@edit_app["datasource"]["classname"] %> #< Datasource
  attr_reader :header_top_center, :header_top_left
  attr_reader :main 
  def initialize(main)
    @main = main
  # something like a level 1 heading
    @header_top_left='<%=@@edit_app["datasource"]["header_top_left"]%>'
  # something like a level 2 heading
    @header_top_center='<%=@@edit_app["datasource"]["header_top_center"]%>'
  end
  def get_keys_handled
    <%=str="";PP.pp(@@edit_app["datasource"]["keys_handled"],str); str.chomp() +' '%>
  #|| super
  end
end
## I have put defs outside so they can be called from FIELD without needing to pass a pointer 
# to this app
  ###DEFS_COME_HERE###
class <%=@@app["classname"]%> < Application
  def initialize()
    super()

    <%= @@initcode.join("\n  ") %>
    @helpfile = __FILE__
    @datasource =  <%= @@edit_app["datasource"]["classname"]%>.new(self)
    @labelarr = nil
  end

def run
###PROCS_COME_HERE###

  begin
    @main = self 

    form_col = 10 
    ### FORM_TEXT_HERE
    ###FIELDS###

    @fields = fields
    @eapp = EditApplication.new(@fields, self) do |app|
      app.user_prefs(@rt_form)
      app.form_headers["header_top_center"]='<%=@@app["header_top_center"]%>'
      app.form_headers["header_top_left"]='<%=@@app["header_top_left"]%>'
      app.create_header_win()  
      app.create_footer_win() 
      Ncurses::Panel.update_panels

      eform_win_rows = 18 
      eform_win_cols = 0 # default of ncurses
      eform_win_starty = 1
      eform_win_startx = 0
      @eform_win, @eform_panel = app.create_window(eform_win_rows,
                                                   eform_win_cols,
                                                   eform_win_starty,
                                                   eform_win_startx)


      app.wrefresh();
      <% if @@app.include?"form_post_proc" %>
      app.form.set_handler(:form_post_proc, <%=@@app["form_post_proc"]%>)
      <% end %>
      <% if @@app.include?"set_handlers"
      handlers=@@app["set_handlers"]
      handlers.each_pair { |hand, aproc| %> 
      app.form.set_handler(:<%=hand%>, <%=aproc%>)
      <% } %>
      <% end %>
      print_screen_labels(@eform_win, @labelarr) if !@labelarr.nil?

        #@keys_handled = EditApplication.get_keys_handled() + (@datasource.get_keys_handled() ||  [])
        @keys_handled = EditApplication.get_keys_handled() 
      app.add_to_application_labels(@keys_handled)
      app.restore_application_key_labels
      stdscr.refresh();

    app.form.handle_keys_loop
end

    ensure
      # Un post form and free the memory
      #self.free_all #  XXX
  end
end # run
end # class


if __FILE__ == $0
  # Initialize curses
  begin
    stdscr = Ncurses.initscr();
    f =  <%=@@app["classname"]%>.new()
    f.run

  ensure
    Ncurses.endwin();
  end
end
