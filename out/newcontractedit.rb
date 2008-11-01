$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/lib"
=begin
  * Name: rkumar
  * $Id$
  * TODO
    * do save of values - DONE
    * allow caller to pass ID and select and populate
    * put all fields on screen - DONE not all but more
=end

require 'rubygems'
require 'ncurses'
require 'rbcurse/sqleditapplication'
require 'rbcurse/singletable'
require 'sqlite3'

include Ncurses
include Ncurses::Form

class NewContractEdit  < Application
  #include SingleTable
  attr_reader :eapp
  attr_accessor :field_start_col
  @@max_rows = 20 
  def self.max_rows
    @@max_rows
  end


  ###DEFS_COME_HERE###
  def initialize()
    super()

    @db = SQLite3::Database.new('testd.db') 
  @rt_form={"classname"=>"NewContractEdit", "mydefs"=>"  def someproc\n\n  end\n", "myprocs"=>"  myfieldcheck = proc { |afield|\n    }\n"}
    @helpfile = __FILE__
    @labelarr = nil
    @field_start_col = 14 
    yield self if block_given?  # 2008-10-26 19:49 
  end # initialize
  

  #def create_application fields
  def run
    ###PROCS_COME_HERE###
    fields = SingleTable.generic_create_fields @db, "contracts" , 20

    @fields = fields
    @eapp = SqlEditApplication.new(@fields, self, @db, "contracts", ["contract_id"])  do |app|

      #class << app
      #def keyvalues
      #  @contract_id
      #end
      #end
      app.user_prefs(@rt_form)
      app.form_headers["header_top_center"]='Contract Edit'
      app.form_headers["header_top_left"]='Demo'

      eform_win_rows = @@max_rows
      eform_win_cols = 0 # default of ncurses
      eform_win_starty = 1
      eform_win_startx = 0
      @eform_win, @eform_panel = app.create_window(eform_win_rows,
                                                     eform_win_cols,
                                                   eform_win_starty,
                                                   eform_win_startx)

      app.wrefresh();

      print_screen_labels(@eform_win, @labelarr) if !@labelarr.nil?

      @keys_handled = app.get_keys_handled() 
      app.create_header_footer(@keys_handled)
      stdscr.refresh();
      begin
        app.form.handle_keys_loop
      rescue => err
        app.print_error("#{err}")
      end
    end
  end # run

  def orun
    fields = SingleTable.generic_create_fields @db, "contracts" , 20
    create_application fields
    main_loop
  end
  def main_loop
    begin
      @eapp.form.handle_keys_loop
    ensure
      # Un post form and free the memory
  #    @eapp.free_all
      #self.free_all #  XXX
    end
  end # run
end # class

if __FILE__ == $0
  # Initialize curses
  begin
    stdscr = Ncurses.initscr();
    f = NewContractEdit.new 
    f.run

=begin
    }{ |ff|
      def my_form_init(form)
        @db ||= SQLite3::Database.new('testd.db')
        $log.debug("method set db")
        @contract_id = 'T201'
      end
      form.set_handler :form_init, method(:my_form_init)


      ##
      def my_form_term(form)
        @db.close
        $log.debug("form_term")
      end
      form.set_handler :form_term , method(:my_form_term)

      #form.set_handler :form_populate , :generic_populate
      form.set_handler :form_populate , method(:generic_form_populate)
    }
=end
=begin
    h = {}
    h['product_type_name']="Laptop"
    h['rate']=499
    h['seller_company_name']="apple"
    f.eapp.form.set_values_hash h
=end

  #  f.main_loop

  ensure
    Ncurses.endwin();
  end
end
