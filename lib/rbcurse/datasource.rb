require 'rubygems'

## must give me @content, @columns, @datatypes (opt)
class Datasource
# attr_reader :field_length         # specified by user, length of row in display table
  attr_accessor :columns      # names of columns in array
  attr_accessor :datatypes    # array of datatyps of columns required to align: int, real, float, smallint
  attr_accessor :content    # 2 dim data
  attr_accessor :user_columns  # columnnames provided by user, overrides what is generated for display
# attr_reader :sqlstring           # specified by user
  attr_accessor :column_separator    # specified by user
  attr_accessor :column_widths    # specified by user (opt)
  attr_accessor :header_top_left   # string to print
  attr_accessor :header_top_center   # string to print
  attr_accessor :main           # pointer to main program for printing messages

  # constructor
  def initialize(config={}, &block)
    @main = main
    @content = []
    @columns = nil # actual db columnnames -- needed to figure out datatypes
    @user_columns = nil # user specified db columnnames, overrides what may be provided
    @datatypes = nil
#   @field_length = 80
    # this should be done in one place for all programs.
#   @db = SQLite3::Database.new("testd.db")
#   @rows = nil
#   @sqlstring = nil
#   @command = nil

    @column_separator = " " 
    @column_widths = nil
    @entity = "rows" 
    @header_top_left=nil
    @header_top_center=nil
    instance_eval(&block) if block_given?
  end
=begin
  # get columns and datatypes, prefetch
  def get_data
    @columns, *rows = @db.execute2(command)
    @content = rows
    @datatypes = @content[0].types if @datatypes.nil?
    return @content
  end
=end

  # added to enable query form to allow movement into table only if
  # there is data 2008-10-08 17:46 
  # returns number of rows fetched
  def data_length
    return @content.length 
  end
 
end
