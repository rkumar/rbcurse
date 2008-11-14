require 'rubygems'
require 'ncurses'

include Ncurses
include Ncurses::Form

class Datasource
  attr_reader :field_length         # specified by user, length of row in display table
  attr_reader :columns      # returned by sqlite3
  attr_reader :datatypes    # returned by sqlite3
  attr_reader :data_arr    # returned by sqlite3
  attr_reader :sqlstring           # specified by user
  attr_reader :column_separator    # specified by user
  attr_accessor :header_top_left
  attr_accessor :header_top_center
  # queryapp will be created later, so need to set later.
  attr_accessor :main           # pointer to main program for printing messages

  # constructor
  def initialize(main)
    @main = main
    @data_arr = []
    @columns = nil # actual db columnnames -- needed to figure out datatypes
    @user_columns = nil # user specified db columnnames
    @datatypes = nil
    @field_length = 80
    # this should be done in one place for all programs.
    @db = SQLite3::Database.new("testd.db")
    @rows = nil
    @sqlstring = nil
    @command = nil

    @column_separator = " " 
    @column_widths = nil
    @entity = "rows" 
    @excludelist = []
  # something like a level 1 heading
    @header_top_left=nil
  # something like a level 2 heading
    @header_top_center=nil
  end
  # get columns and datatypes, prefetch
  def get_metadata
    # the next line is to get the columns by default since they are displayed at start
    # best for user to define.
    get_data(@sqlstring + " limit 1")
  end
  def get_data(command=@command)
    @columns, *@rows = @db.execute2(command)
    @data_arr = @rows
    @datatypes = @data_arr[0].types if @datatypes.nil?
    return @data_arr
  end


  def format_line(rowctr,current_row_as_array)
    if @column_widths.nil?
      return sprintf("%3d %-76s", rowctr+1, current_row_as_array.join(@column_separator))
    else
      str = sprintf("%3d ", rowctr+1) 
     current_row_as_array.each_index{ |i|
       if @datatypes[i] == "real" or @datatypes[i] == "integer" or  @datatypes[i] == "smallint"
          str += sprintf("%*s ",@column_widths[i], current_row_as_array[i]) 
        else
          str += sprintf("%-*s ",@column_widths[i], current_row_as_array[i]) 
        end
       str += @column_separator if i < (current_row_as_array.length() - 1) #XXX
      }
      return str
    end
  end
  def format_titles
    get_metadata 
    @user_columns = @columns if @user_columns.nil?
    fl = @user_columns.dup
    fl.map!{|f| f.gsub!(/(^\w|_\w)/){|m| m.upcase}}
    if @column_widths.nil?
      str = fl.join(@column_separator)
      if str.length > 70
        max = 70/fl.count
        fl.map! {|cn| 
          if cn.length>max
            cn[0.. max]
          else
            cn
          end
        }
        str = fl.join(@column_separator)
      end
    else
      str = ""
      fl.each_index{ |i|
        fl[i] = fl[i][0..@column_widths[i]] if fl[i].length > @column_widths[i]
        str += sprintf("%-*s ",@column_widths[i], fl[i]) 
        str += @column_separator if i < (fl.length() - 1) 
      }
    end
    str.gsub!(/_/,' ')
    return "%5s" % " "+ str
  end
  def create_search_string(qfields)
    # needs to be generalized with a hash of title and value
    # or the actual fields themselves
    wherecond = []
    i = 0
    #get_metadata if @datatypes.nil?
    qfields.each { |fld|
      value = fld.field_buffer(0).strip
      name = fld.user_object["name"]
      ix = @columns.index(name)
      if ix == nil
        clc = @columns.map{|col| col.downcase }
        ix = clc.index(name.downcase)
      end

      if @datatypes[ix] == "real" or @datatypes[ix] == "integer" or  @datatypes[ix] == "smallint"
        wherecond << " #{name} = #{value}"   if value != ""
      else
        wherecond << " #{name} like '%#{value}%'"   if value != ""
      end
    i += 1
    }
    wherecondstr = wherecond.join(" and ")
    wherecondstr = " where " + wherecondstr if wherecond.length>0
    wherecondstr ||= ""
  end
  def search(curritem, listselected=[])

    qfields = @query_app.form.fields
    @command = @sqlstring + create_search_string(qfields)

    @main.print_status("#{@command}")
    @main.populate_form
  end
  def sort(curritem, listselected=[])
    qfields = @query_app.form.fields
      labels=["?~Help  ","C~Cancel"]
      validchars = "?CR"
      # should not exceed 9
       max = 1
      @columns.each_index {|i|
        labels << "#{i+1}~%10s" % @columns[i]
        validchars += "#{i+1}"
        max = i+1
        break if i > 8
      }
      ret =  @main.askchoice(nil, "Choose type of sort, or 'R' to reverse current sort","1",
                             labels,validchars)
      case ret
      when /[1-#{max}]/:
        @command = @sqlstring + create_search_string(qfields)
        @command = @command + " order by #{ret} asc "
        @main.clear_error
        @main.print_status("#{@command}")
        @main.populate_form
      when 'r'
        if @command.include?" asc "
          @command.sub!(/asc /,' desc ')
        else
          if @command.include?" desc " 
            @command.sub!(/ desc /,' asc ')
          else
            @main.print_error("No existing sort defined")
            return -1
          end
        end
        @main.populate_form
      else
        @main.clear_error
        @main.print_status("Please implement this feature")
      end
      @main.clear_error
      @main.print_status("#{@command}")
  end
  # zeroth index/slice will break in 1.9
  # returns an array of hashes giving ascii value, displaycode and text
  # handler for display_code will be triggered such as handle_D or handle_V
  # if :action specified, sort will be called with curritem, listselected=[]
  # listselected is an array of offsets 
  # We will keep adding stuff here as time goes.
  def get_keys_handled()
    [ { :keycode=>"X"[0], :display_code => "X", :text => "eXlcude", :action => "handle_X" },
      { :keycode=>"V"[0], :display_code => "V", :text => "View   " , :action => "handle_V"},
      { :keycode=>"D"[0], :display_code => "D", :text => "Delete " , :action => "handle_D"},
      { :keycode=>"$"[0], :display_code => "$", :text => "Sort   ", :action => "sort" }
      ]
  end
  # added to enable query form to allow movement into table only if
  # there is data 2008-10-08 17:46 
  # returns number of rows fetched
  def data_length
    return @data_arr.length 
  end
 
end
