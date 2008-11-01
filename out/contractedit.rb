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
require 'rbcurse/editapplication'
require 'rbcurse/singletable'
require 'sqlite3'

include Ncurses
include Ncurses::Form

class Contracts #< Datasource
  attr_reader :header_top_center, :header_top_left
  attr_reader :main 
  def initialize(main)
    @main = main
    @header_top_left='Demos'
    @header_top_center='Contracts'
  end
  def get_keys_handled
    [{:keycode=>88, :display_code=>"X", :text=>"eXlcude"},
 {:keycode=>86, :display_code=>"V", :text=>"View   "},
 {:keycode=>999, :display_code=>" ", :text=>"       "},
 {:action=>"sort", :keycode=>36, :display_code=>"$", :text=>"Sort   "}] 
  #|| super
  end
end
class ContractEdit < Application
  attr_reader :eapp
  attr_accessor :field_start_col
  @@max_rows = 20 
  def self.max_rows
    @@max_rows
  end


  ###DEFS_COME_HERE###
  def initialize()
    super()

    @rt_fields=["contract_id", "contract_id", "product_name", "rate"]
  @rt_form={"classname"=>"ContractEdit", "mydefs"=>"  def someproc\n\n  end\n", "myprocs"=>"  myfieldcheck = proc { |afield|\n    }\n"}
    @helpfile = __FILE__
#    @datasource =  Contracts.new(self)
    @labelarr = nil
    @field_start_col = 14 
    yield self if block_given?  # 2008-10-26 19:49 
  end # initialize
  
  #def create_fields
  #end

  def create_application fields
    ###PROCS_COME_HERE###
    @main = self 

    @fields = fields
    @eapp = EditApplication.new(@fields, self) 
    @eapp.user_prefs(@rt_form)
    @eapp.form_headers["header_top_center"]='Contract Edit'
    @eapp.form_headers["header_top_left"]='Demo'

    eform_win_rows = @@max_rows
    eform_win_cols = 0 # default of ncurses
    eform_win_starty = 1
    eform_win_startx = 0
    @eform_win, @eform_panel = @eapp.create_window(eform_win_rows,
                                                   eform_win_cols,
                                                   eform_win_starty,
                                                   eform_win_startx)

    @eapp.wrefresh();

    print_screen_labels(@eform_win, @labelarr) if !@labelarr.nil?

    @keys_handled = @eapp.get_keys_handled() 
    @eapp.create_header_footer(@keys_handled)
    stdscr.refresh();
  end # create_application

  def run
    f = create_fields
    create_application f
    main_loop
  end
  def main_loop
    begin
      @eapp.form.handle_keys_loop
    ensure
      # Un post form and free the memory
      @eapp.free_all
      #self.free_all #  XXX
    end
  end # run
end # class

if __FILE__ == $0
  # Initialize curses
  begin
    stdscr = Ncurses.initscr();
    f =  ContractEdit.new { |ff|
      include SingleTable
      #fields = ff.create_fields
      @db = SQLite3::Database.new('testd.db') 
      fields = generic_create_fields @db, "contracts" , 22
      #fields[0].set_read_only true
      fields[0].set_reverse false

      ff.create_application fields
      @form = form = ff.eapp.form
      app = ff.eapp
      app.update_application_key_label("^X","^X","Update")
      app.update_application_key_label("^V","^V","Insert")
      app.insert_application_key_label(   4,"^Z","Delete")
      app.insert_application_key_label(   5,"^S","Select")
      app.restore_application_key_labels
      def db
        @db ||= SQLite3::Database.new('testd.db') 
      end
      ## returns string containg table name
      def tablename 
        "contracts"
      end
      ##  returns array of strings containing key field/s
      def keynames
        ["contract_id"]
      end 
      ##  returns array containing values from form or wherever
      def keyvalues
        @contract_id
      end 
      ## returns hash of values, rbeditform gives this.
      def get_current_values_as_hash 
        @form.get_current_values_as_hash
      end
      def my_form_init(form)
        @db ||= SQLite3::Database.new('testd.db')
        $log.debug("method set db")
        @contract_id = 'T201'
      end
      form.set_handler :form_init, method(:my_form_init)

      #form.set_handler :form_save, method(:generic_form_insert)
      app.bind_key ?\C-V, method(:generic_form_insert)
      app.bind_key ?\C-Z, method(:generic_form_delete)
      app.bind_key ?\C-S, method(:generic_form_select)
      form.set_handler :form_save, method(:generic_form_update)
      ## 

      ##
      def my_form_term(form)
        @db.close
        $log.debug("form_term")
      end
      form.set_handler :form_term , method(:my_form_term)

      #form.set_handler :form_populate , :generic_populate
      form.set_handler :form_populate , method(:generic_form_populate)
    }
=begin
    h = {}
    h['product_type_name']="Laptop"
    h['rate']=499
    h['seller_company_name']="apple"
    f.eapp.form.set_values_hash h
=end

    f.main_loop

  ensure
    Ncurses.endwin();
  end
end
