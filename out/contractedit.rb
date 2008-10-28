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
    @datasource =  Contracts.new(self)
    @labelarr = nil
    @field_start_col = 14 
    yield self if block_given?  # 2008-10-26 19:49 
  end # initialize


  def create_fields
    ### FORM_TEXT_HERE
    ###FIELDS###
    fields = Array.new
    #contract_id

    field = FIELD.new(1, 10, 1, @field_start_col+@field_start_col+0, 0, 0)
    field.user_object = {"label"=>"contract_id", "name"=>"contract_id", "help_text"=>"Enter a contract ", :row=>1, "field_back"=>"REVERSE", :label=>"contract_id", "index"=>1, "width"=>10}
    field.user_object[:col] = @field_start_col+@field_start_col+0

    field.set_field_back(A_REVERSE)

    fields.push(field)
    #product_name
    field = FIELD.new(1, 10, 2, @field_start_col+@field_start_col+0, 0, 0)
    field.user_object = {"label"=>"product_name", "name"=>"product_name", "help_text"=>"Enter a name ", :row=>2, "field_back"=>"REVERSE", :label=>"product_name", "index"=>2, "width"=>10}
    field.user_object[:col] = @field_start_col+@field_start_col+0
    field.set_field_back(A_REVERSE)
    fields.push(field)
    #rate

    field = FIELD.new(1, 6, 3, @field_start_col+@field_start_col+0, 0, 0)
    field.user_object = {"label"=>"rate", "name"=>"rate", "help_text"=>"Enter a rate to search on", :row=>3, "field_back"=>"REVERSE", :label=>"rate", "index"=>3, "width"=>5}
    field.user_object[:col] = @field_start_col+@field_start_col+0
    field.set_field_back(A_REVERSE)
    field.set_field_type(TYPE_NUMERIC, 2, 0, 1000)
    fields.push(field)

    datefields = %w[ contract_execution_date contract_commencement_date  contract_execution_date ]
    integerfields = %w[ quantity ]
    numericfields = %w[ rate ]
    flen = @field_start_col + @field_start_col -5
    fieldz = %w[ seller_company_name customer_company_name contract_execution_date contract_commencement_date  contract_execution_date  product_type_name quantity]
    fieldz.each_index do |ix|
      fname = fieldz[ix]
      sname = fname
      sname = fname[0..flen] if fname.length>flen
      field = FIELD.new(1, 20, ix+4, @field_start_col+@field_start_col+0, 0, 0)
      field.user_object = {"label"=>sname, "name"=>"#{fname}", "help_text"=>"Enter a #{fname} ", :row=>ix+4, "field_back"=>"REVERSE", :label=>"#{sname}", "index"=>ix+4, "width"=>12}
      field.user_object[:col] = @field_start_col+@field_start_col+0
      field.set_field_back(A_REVERSE)
      if datefields.include? fname
        field.set_field_type(TYPE_REGEXP, "^[12][0-9]\{3}[\-/][0-9]\{2}[\-/][0-9]\{2}")
        field.user_object["help_text"] = "#{fname}: Use format 2009-12-31"
        #field.set_field_type(TYPE_REGEXP, "[12]\d\d\d[X]\d\d[X]\d\d")
      elsif integerfields.include? fname
        field.set_field_type(TYPE_INTEGER, 2, 0, 1000)
        field.user_object["help_text"] = "#{fname}: Valid range is 0,1000"
      elsif numericfields.include? fname
        field.set_field_type(TYPE_NUMERIC, 2, 0, 1000)
        field.user_object["help_text"] = "#{fname}: Valid range is 0,1000"
      end
      fields.push(field)
    end
    return fields
  end

  def create_application fields
    ###PROCS_COME_HERE###
    @main = self 

    @fields = fields
    @eapp = EditApplication.new(@fields, self) 
    @eapp.user_prefs(@rt_form)
    @eapp.form_headers["header_top_center"]='Contract Edit'
    @eapp.form_headers["header_top_left"]='Demo'
    #    @eapp.create_header_win()  
    #    @eapp.create_footer_win() 
    #    Ncurses::Panel.update_panels

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

    #@keys_handled = EditApplication.get_keys_handled() + (@datasource.get_keys_handled() ||  [])
    @keys_handled = EditApplication.get_keys_handled() 
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
      def new_create_fields tablename
        columns = []
        datatypes = []
        db = SQLite3::Database.new('testd.db') 
        command = %Q{select * from #{tablename} limit 1}
        $log.debug(command)
        columns, *rows = db.execute2(command)
        datatypes = rows[0].types 
        $log.debug("2.columns")
        $log.debug(columns)
        
        field_start_col = 14
        field_start_row = 1
        fields = []
        flen = field_start_col + field_start_col -5 # max size of col name
        fieldwidth = 15
        columns.each_index do |ix|
          currow = ix
          if ix >= ContractEdit::max_rows() -1
            field_start_col = 36
            currow -= (ContractEdit::max_rows() -1)
          end
          fname = columns[ix]
          sname = fname
          sname = fname[0..flen] if fname.length>flen
          field = FIELD.create_field(fieldwidth, currow+field_start_row, field_start_col+field_start_col, fname, type=datatypes[ix],label=sname, height=1, nrows=0, nbufs=0, config={}) do |fld|
            fld.set_reverse true
          end
          yield ix, fname, field, datatypes[ix] if block_given?
          fields.push(field)
        end # columns
        $log.debug("done NEW creating fields"+fields.size.to_s)
        return fields
      end
      def my_create_fields tablename
        columns = []
        datatypes = []
        db = SQLite3::Database.new('testd.db') 
        command = %Q{select * from #{tablename} limit 1}
        $log.debug(command)
        columns, *rows = db.execute2(command)
        datatypes = rows[0].types 
        $log.debug("1.columns")
        $log.debug(columns)
        $log.debug("1.datatypes")
        $log.debug(datatypes)
        $log.debug(columns.length)
        
        field_start_col = 14
        field_start_row = 1
        fields = []
        flen = field_start_col + field_start_col -5 # max size of col name
        fieldwidth = 15
        columns.each_index do |ix|
          currow = ix
          if ix >= ContractEdit::max_rows() -1
            field_start_col = 36
            currow -= (ContractEdit::max_rows() -1)
          end
          fname = columns[ix]
          sname = fname
          sname = fname[0..flen] if fname.length>flen
          field = FIELD.new(1, fieldwidth, currow+field_start_row, field_start_col+field_start_col+0, 0, 0)
          field.user_object = {"label"=>sname, "name"=>"#{fname}", "help_text"=>"Enter a #{fname} ", :row=>currow+field_start_row, "field_back"=>"REVERSE", :label=>"#{sname}", "index"=>ix, "width"=>fieldwidth}
          field.user_object[:col] = field_start_col+field_start_col+0
          field.set_field_back(A_REVERSE)
          case datatypes[ix]
          when "date":
            field.set_field_type(TYPE_REGEXP, "^[12][0-9]\{3}[\-/][0-9]\{2}[\-/][0-9]\{2}")
            field.user_object["help_text"] = "#{fname}: Use format 2009-12-31"
            #field.set_field_type(TYPE_REGEXP, "[12]\d\d\d[X]\d\d[X]\d\d")
          when "integer"
            field.set_field_type(TYPE_INTEGER, 2, 0, 10000)
            field.user_object["help_text"] = "#{fname}: Valid range is 0,10000"
          when "smallint"
            field.set_field_type(TYPE_INTEGER, 2, 0, 127)
            field.user_object["help_text"] = "#{fname}: Valid range is 0,127"
          when "real"
            field.set_field_type(TYPE_NUMERIC, 2, 0, 10000)
            field.user_object["help_text"] = "#{fname}: Valid range is 0,10000"
          end
          yield ix, fname, field, datatypes[ix] if block_given?
          fields.push(field)
        end # columns
        $log.debug("done creating fields")
        return fields
      end # my_create_fields
  begin
    stdscr = Ncurses.initscr();
    f =  ContractEdit.new { |ff|
      #fields = ff.create_fields
      #fields = my_create_fields "contracts"
      fields = new_create_fields "contracts" 
      fields[0].set_read_only true
      fields[0].set_reverse false

      ff.create_application fields
      form = ff.eapp.form
      app = ff.eapp
      app.update_application_key_label("^X","^X","Update")
      app.update_application_key_label("^V","^V","Insert")
      app.restore_application_key_labels
      def my_form_init(form)
        @db = SQLite3::Database.new('testd.db')
        $log.debug("method set db")
        @contract_id = 'C74'
      end
      form.set_handler :form_init, method(:my_form_init)

      def my_form_insert(form)
        raise "db nil " if @db.nil?
        valhash = form.get_current_values_as_hash
        $log.debug("GOT VALUES IN FORM SAVE")
        $log.debug(valhash.to_s)
        ret = generic_insert @db, "contracts", valhash
        $log.debug("Passed insert")
        form.changed = false
      end
      #form.set_handler :form_save, method(:my_form_insert)
      app.bind_key ?\C-V, method(:my_form_insert)
      def generic_insert db, tablename, valhash
        names = []
        values = []
        qm = []
        valhash.each_pair do |k,v|
          names << k
          values << v
          qm << '?'
        end
        sql=%Q{insert into #{tablename} (  #{names.join(",")}  ) values (  #{qm.join(",")}  ) }
        $log.debug(sql)
        ret = db.execute(sql, *values)
      end
      def my_form_update(form)
        raise "db nil " if @db.nil?
        valhash = form.get_current_values_as_hash
        $log.debug("GOT VALUES IN FORM UPD")
        $log.debug(valhash.to_s)
        ret = generic_update @db, "contracts", valhash
        $log.debug("Passed update")
      end
      form.set_handler :form_save, method(:my_form_update)
      ## 

      def generic_update db, tablename, valhash
        names = []
        values = []
        valhash.each_pair do |k,v|
          names << "#{k} = ?"
          values << v
        end
        key = valhash["contract_id"]
        values << key
        sql=%Q{update #{tablename} set  #{names.join(",")}   where contract_id = ? }
        $log.debug(sql)
        ret = db.execute(sql, *values)
      end
      def my_form_term(form)
        @db.close
        $log.debug("form_term")
      end
      form.set_handler :form_term , method(:my_form_term)

      def my_form_populate(form)
        raise "db nil in form_populate " if @db.nil?
        return if @contract_id.nil?
        @db.results_as_hash = true
        sql=%Q{ select * from contracts where contract_id=?}
        row = @db.execute(sql, @contract_id)
        $log.debug(sql)
        $log.debug(row[0])
        #form.set_values_hash row[0]
        form.set_defaults row[0]
      end
      form.set_handler :form_populate , method(:my_form_populate)
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
