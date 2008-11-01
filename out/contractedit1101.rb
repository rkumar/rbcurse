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

class ContractEdit1101  < Application

  ###DEFS_COME_HERE###
  def initialize()
    super()

    @helpfile = __FILE__
    @labelarr = nil
  end # initialize
  

  def run
    ###PROCS_COME_HERE###
    begin
    @db = SQLite3::Database.new('testd.db') 
    fields = SingleTable.generic_create_fields @db, "contracts" , 20

    @eapp = SqlEditApplication.create_default_application(fields, @db, "contracts", ["contract_id"])  do
      @rt_form={"classname"=>"NewContractEdit", "mydefs"=>"  def someproc\n\n  end\n", "myprocs"=>"  myfieldcheck = proc { |afield|\n    }\n"}
      user_prefs(@rt_form)
      form_headers["header_top_center"]='Contract Edit'
      form_headers["header_top_left"]='Demo'
    end
    ensure
      @db.close if !@db.nil?
    end

  end # run

end # class

if __FILE__ == $0
  # Initialize curses
  begin
    stdscr = Ncurses.initscr();
    f = ContractEdit1101.new 
    f.run
  ensure
    Ncurses.endwin();
  end
end
