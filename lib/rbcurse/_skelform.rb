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
require 'commons1'
require 'editapplication'
#require 'datasource'
#require '<%=@@edit_app["datasource"]["apptype"]%>'

include Ncurses
include Ncurses::Form
include Commons1

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
    # this will go inside form XXX
    <%= @@initcode.join("\n  ") %>
    @helpfile = __FILE__
    @datasource =  <%= @@edit_app["datasource"]["classname"]%>.new(self)
    @labelarr = nil
  end

# field_term_hook(form) field_init_hook(form) form_init_hook(form) and form_term_hook(form)
# will be called, if defined  --- NOPE, MUST BE SET 2008-10-24 14:46 

def run
###PROCS_COME_HERE###

  begin
      <% if @@app.include?"header_top_center" %>
      @form_headers["header_top_center"]="<%=@@app["header_top_center"] %>"
      @form_headers["header_top_left"]="<%=@@app["header_top_left"] %>"
      <% end %>
      #@form_headers["header_top_center"]=@datasource.header_top_center
      #@form_headers["header_top_left"]=@datasource.header_top_left
      @main = self # XXX 2008-10-10 13:19 

      create_header_win()  # super takes care of this

      create_footer_win()  # super takes care of this
      Ncurses::Panel.update_panels


    form_col = 10 # XXX added 
    ### FORM_TEXT_HERE
    ###FIELDS###

    @fields = fields
    @eapp = EditApplication.new(@fields, self, @datasource)
      @eapp.user_prefs(@rt_form)
      eform_win_rows = 18 # ? XXX
      eform_win_cols = 0 # default of ncurses
      eform_win_starty = 1
      eform_win_startx = 0
      @eform_win, @eform_panel = @eapp.create_window(eform_win_rows,
                                                     eform_win_cols,
                                                     eform_win_starty,
                                                     eform_win_startx)


    # inhash is if we have to load up a file CUT THIS CRAP OUT LET IT BE HOOKED IN
    if @rt_form.include?"infile"
      infile = @rt_form["infile"][0]
      @inhash = YAML::load( File.open( infile ) ) if infile =~ /\.yml$/
      @eapp.form.set_defaults(@inhash) if @inhash != nil # XXX
    end

      @eapp.wrefresh();
      @eapp.form.print_help("Help text will come here");
      <% if @@app.include?"form_post_proc" %>
        @eapp.form.set_handler(:form_post_proc, <%=@@app["form_post_proc"]%>)
      <% end %>
      <% if @@app.include?"set_handlers"
        handlers=@@app["set_handlers"]
        handlers.each_pair { |hand, aproc| %> 
        @eapp.form.set_handler(:<%=hand%>, <%=aproc%>)
      <% } %>
      <% end %>
      print_screen_labels(@eform_win, @labelarr) if !@labelarr.nil?
      # i need this to set the bottom panel
      @keys_handled = EditApplication.get_keys_handled() + (@datasource.get_keys_handled() ||  [])
      add_to_application_labels(@keys_handled)
      restore_application_key_labels
      stdscr.refresh();

      @eapp.form.handle_keys_loop(@eform_win)

#    rescue Exception => e
    # print_error(e.to_s)
    # @log.error(caller(0).to_s)
#     @log.error(e.backtrace.join("\n"))
     #@log.error(e.backtrace.pretty_inspect)
  #   @log.error(Kernel.pretty_inspect(e.backtrace))


    ensure
      # Un post form and free the memory
      @eapp.free_all() if !@eapp.nil?
      self.free_all #  XXX
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
