=begin
  * Name: singletable
  * $Id$
  * Description   Tries to give some basic functionality of select, update, delete, insert
  *  assumes that includeing class provides the following methods:
  *    - get_db - returns database instance
  *    - get_tablename - returns string containg table name
  *    - get_keynames  - returns array of strings containing key field/s
  *    - get_keyvalues - returns array containing values from form or wherever
  *                      to use for searching (not required where values_hash passed.
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
  def generic_form_insert form, db=nil, tablename=nil, valhash=nil
    db ||= get_db
    tablename ||= get_tablename
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
    ret = db.execute(sql, *values)
    form.form_changed(true)
  end
  ##
  # creates an update sql based on tablename, values hash
  # and array of keynames
  # @param db  - instance of database
  # @param tablename string - name of table
  # @param valhash hash - fieldname and value from form
  # @param key_array  - fieldnames array
  def generic_form_update form=nil, db=nil, tablename=nil, valhash=nil, key_array=nil
    db ||= get_db
    tablename ||= get_tablename
    valhash ||= get_current_values_as_hash  rescue form.get_current_values_as_hash
    key_array ||= get_keynames

    names = []
    raise "No keys passed. Cowardly refusal to update table." if key_array.nil?
    values = []
    valhash.each_pair do |k,v|
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
    ret = db.execute(sql, *values)
    form.form_changed(true)
  end
  def generic_form_select form
    ret  = form.get_string(nil, "Enter a contract_id", 5, @contract_id)
    if ret != ''
      @contract_id = ret 
      generic_form_populate form 
    end
  end
  def generic_form_populate form, db=nil, tablename=nil, key_array=nil, values=nil
    raise "form does not implement set_defaults" if !form.respond_to? :set_defaults
    db ||= get_db
    tablename ||= get_tablename
    key_array ||= get_keynames
    values ||= get_keyvalues

    @db.results_as_hash = true
    wheres=[]
    key_array.each do |k|
      wheres << "#{k} = ?"
    end
    wherestr = wheres.join(" AND ")
    sql=%Q{ SELECT * FROM #{tablename} WHERE #{wherestr} }
    $log.debug(sql)
    $log.debug(values)
    row = @db.execute(sql, *values)
    if block_given?
      yield row[0] 
    else
      form.set_defaults row[0]
    end
  end
  def generic_form_delete form=nil, db=nil, tablename=nil, key_array=nil, values=nil
    db ||= get_db
    tablename ||= get_tablename
    key_array ||= get_keynames
    values ||= get_keyvalues

    wheres=[]
    key_array.each do |k|
      wheres << "#{k} = ?"
    end
    wherestr = wheres.join(" AND ")
    sql=%Q{ DELETE FROM #{tablename} WHERE #{wherestr} }
    $log.debug(sql)
    $log.debug(values)
    row = @db.execute(sql, *values)
  end
  def generic_create_fields db, tablename, max_rows
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
end
