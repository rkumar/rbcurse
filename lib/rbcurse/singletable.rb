=begin
  * Name: singletable
  * $Id$
  * Description   Tries to give some basic functionality of select, update, delete, insert
  *  assumes that includeing class provides the following methods:
  *    - db() - returns database instance
  *    - tablename() - returns string containg table name
  *    - keynames()  - returns array of strings containing key field/s
  *    - get_current_values_as_hash - returns hash of values, rbeditform gives this.
                         form.get_current_values_as_hash
  * Author: rkumar
  * Date: 2008-10-29 19:21 
  * License:
    this program under the term of Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
##

module SingleTable
  ## have put form as first since form is passed by handlers and you should be able to install this
  #  with set_handler rather than wrapping.
  def generic_form_insert form, ddb=nil, tablename=nil, valhash=nil
    $log.debug("inside generic form insert")
    ddb ||= db()
    tablename ||= tablename()
    kvalues ||= keyvalues()
    raise "Blank key field passed to form_insert" if kvalues.nil?
    kvalues.each do |kv|
      if kv.nil? or kv.strip.empty?
        raise "Blank key field passed to form_insert"
      end
    end
    valhash ||= get_current_values_as_hash rescue form.get_current_values_as_hash
    
    names = []
    values = []
    qm = []
    valhash.each_pair do |k,v|
      names << k
      values << v
      qm << '?'
    end
    sql=%Q{insert into #{tablename} (  #{names.join(",")}  ) values (  #{qm.join(",")}  ) }
    ret = ddb.execute(sql, *values)
    form.form_changed(true)
  end
  ##
  # creates an update sql based on tablename, values hash
  # and array of keynames
  # @param db  - instance of database
  # @param tablename string - name of table
  # @param valhash hash - fieldname and value from form
  # @param key_array  - fieldnames array
  # TODO don't update keys, many DB's will fail on that.
  def generic_form_update form=nil, ddb=nil, tablename=nil, valhash=nil, key_array=nil
    $log.debug("inside generic form update")
    ddb ||= db()
    tablename ||= tablename()
    valhash ||= get_current_values_as_hash  rescue form.get_current_values_as_hash
    key_array ||= keynames()

    kvalues ||= keyvalues()
    raise "No data selected. Use C-s to select first" if !@data_selected
    raise "No keys passed. Cowardly refusal to delete data." if kvalues.nil?
    names = []
    values = []
    valhash.each_pair do |k,v|
      next if key_array.include? k   # don't want keys to be updated. 2008-11-01 23:26 
      names << "#{k} = ?"
      values << v
    end
    wheres=[]
    key_array.each do |k|
      key = valhash[k]
      values << key
      wheres << "#{k} = ?"
    end
    sql=%Q{UPDATE #{tablename} SET  #{names.join(",")} WHERE #{wheres.join(" and ")} }
    $log.debug(sql)
    ret = ddb.execute(sql, *values)
    form.form_changed(true)
  end
  def generic_form_select form
    key_array ||= keynames()
    @keyvalues ||= []
    raise "No key fields specified to search on. Cannot proceed." if key_array.nil?
    key_array.each_index do |ix|
      ret  = form.get_string(nil, "Enter a #{key_array[ix]}", 10, @keyvalues[ix])
      if ret != ''
        @keyvalues[ix] = ret 
      else
        return
      end
    end
    generic_form_populate form, nil, nil, nil, @keyvalues
  end
  def generic_form_populate form, ddb=nil, tablename=nil, key_array=nil, values=nil
    raise "form does not implement set_defaults" if !form.respond_to? :set_defaults
    ddb ||= db()
    tablename ||= tablename()
    key_array ||= keynames()
    values ||= keyvalues()
    #raise "db IS nil" if db().nil?
    raise "db is nil" if ddb.nil?
    raise "No keys passed. Stubborn refusal to select data." if values.nil? or values[0]==""

    ddb.results_as_hash = true
    wheres=[]
    key_array.each do |k|
      wheres << "#{k} = ?"
    end
    wherestr = wheres.join(" AND ") or " 1=1 "
    sql=%Q{ SELECT * FROM #{tablename} WHERE #{wherestr} }
    $log.debug(sql)
    $log.debug(values)
    row = ddb.execute(sql, *values)
    $log.debug("ROW:SELECT")
    $log.debug(row[0])
    raise "No rows found for #{values}" if row[0].nil?
    if block_given?
      yield row[0] 
    else
      form.set_defaults row[0]
    end
    disable_key_fields form, true
    @data_selected = true
    form.form_changed(false)
  end
  def generic_form_delete form=nil, ddb=nil, tablename=nil, key_array=nil, values=nil
    $log.debug("inside generic form delete")
    ddb ||= db()
    tablename ||= tablename()
    key_array ||= keynames()
    values ||= keyvalues()
    raise "No data selected. Use C-s to select first" if !@data_selected
    raise "No keys passed. Cowardly refusal to delete data." if values.nil?

    wheres=[]
    key_array.each do |k|
      wheres << "#{k} = ?"
    end
    wherestr = wheres.join(" AND ")
    sql=%Q{ DELETE FROM #{tablename} WHERE #{wherestr} }
    $log.debug(sql)
    $log.debug(values)
    row = ddb.execute(sql, *values)
    @data_selected = false
  end
  def self.generic_create_fields db, tablename, max_rows
    columns = []
    datatypes = []
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
      if ix >= max_rows -1
        field_start_col = 36
        currow -= (max_rows -1)
      end
      fname = columns[ix]
      sname = fname
      static = true
      sname = fname[0..flen] if fname.length>flen
      width = fieldwidth
      case datatypes[ix]
      when "date"
        width = 10
      when "smallint"
        width = 3
      when "integer","real"
        width = 7
      else
        len=datatypes[ix].scan(/\d+/)[0]
        if len.to_i > fieldwidth
          static = false
        else
          width = len.to_i
        end
      end
      field = FIELD.create_field(width, currow+field_start_row, field_start_col+field_start_col, fname, type=datatypes[ix],label=sname, height=1, nrows=0, nbufs=0, config={}) do |fld|
        fld.set_reverse true
        fld.set_static(false) if !static
      end
      yield ix, fname, field, datatypes[ix] if block_given?
      fields.push(field)
    end # columns
    $log.debug("done NEW creating fields"+fields.size.to_s)
    return fields
  end
  def disable_key_fields form, flag=true
    keynames().each do |k|
      f = form.get_field_by_name(k)
      f.set_read_only flag
      f.set_reverse !flag
    end
  end
  def generic_form_findall form, ddb=nil, tablename=nil, key_array=nil, values=nil
    ddb ||= db()
    tablename ||= tablename()
    key_array ||= keynames()
    #values ||= keyvalues()
    valhash ||= get_current_values_as_hash rescue form.get_current_values_as_hash
    #raise "db IS nil" if db().nil?
    raise "db is nil" if ddb.nil?

    form.form_changed(false)
    ddb.results_as_hash = true
    wheres=[]
    values=[]
    valhash.each_pair do |k,v|
      next if v.nil? or v.strip == ""
      wheres << "#{k} = ?"
      values << v
    end
    wherestr = wheres.join(" AND ")
    wherestr = "1=1  " if wherestr==""
    wherestr += " AND #{@where_string} " if @where_string != ""
    order_by = @order_string != "" ? " ORDER BY #{@order_string} " : ""
    sql=%Q{ SELECT * FROM #{tablename}  WHERE #{wherestr} #{order_by} LIMIT #{@findall_limit} }
    $log.debug(sql)
    $log.debug(valhash)
    $log.debug(values)
    @find_results = ddb.execute(sql, *values)
    $log.debug("ROW:SELECT #{@find_results.length}")
    $log.debug(@find_results)
    raise "No rows found for #{values} #{wherestr}" if @find_results.nil? or @find_results.length==0
    if block_given?
      yield @find_results 
    else
      form.set_defaults @find_results[0]
    end
    disable_key_fields form, false
    @find_result_index = 0
    @data_selected = true
    @main.print_status("Row #{@find_result_index+1} of #{@find_results.length} ")
    return @find_results.length
  end
  def generic_form_findnext form, ddb=nil, tablename=nil, key_array=nil, values=nil
    @find_result_index += 1
    if @find_result_index >= @find_results.length
      @find_result_index = @find_results.length() -1
      @main.print_error("No more results")
      return
    end
    row = @find_results[@find_result_index]
    if block_given?
      yield row
    else
      form.set_defaults row
    end
    @main.print_status("Row #{@find_result_index+1} of #{@find_results.length} ")
  end
  def generic_form_findprev form, ddb=nil, tablename=nil, key_array=nil, values=nil
    @find_result_index -= 1
    if @find_result_index < 0
      @find_result_index = 0
      @main.print_error("Already on first row")
      return
    end
    row = @find_results[@find_result_index]
    if block_given?
      yield row
    else
      form.set_defaults row
    end
    @main.print_status("Row #{@find_result_index+1} of #{@find_results.length} ")
  end
  def generic_form_findfirst form, ddb=nil, tablename=nil, key_array=nil, values=nil
    @find_result_index = 0
    row = @find_results[0]
    if block_given?
      yield row
    else
      form.set_defaults row
    end
    @main.print_status("Row #{@find_result_index+1} of #{@find_results.length} ")
  end
  def generic_form_findlast form, ddb=nil, tablename=nil, key_array=nil, values=nil
    @find_result_index = @find_results.length-1
    row = @find_results[@find_results.length-1]
    if block_given?
      yield row
    else
      form.set_defaults row
    end
    @main.print_status("Row #{@find_result_index+1} of #{@find_results.length} ")
  end

end
