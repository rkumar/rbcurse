#!/usr/bin/env ruby -w
=begin
  * Name          : A Quick take on tabular data. Readonly.
  * Description   : To show tabular data inside a control, rather than going by the huge
                    Table object, I want to create a simple, minimal table data generator.
                    This will be thrown into a TextView for the user to navigate, select
                    etc.
                    I would use this applications where the tabular data is fairly fixed
                    not where i want the user to select columns, move them, expand etc.
  *               :
  * Author        : rkumar
  * Date          : 
  * License       :
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end

#
# A simple tabular data generator. Given table data in arrays and a column heading row in arrays, it 
# quickely generates tabular data. It only takes left and right alignment of columns into account.
#   You may specify individual column widths. Else it will take the widths of the column names you supply 
# in the startup array. You are encouraged to supply column widths.
#   If no columns are specified, and no widths are given, it take the widths of the first row 
# as a model to determine column widths. 
#
module RubyCurses

  class Tabular
    GUESSCOLUMNS = 20

  def yield_or_eval &block
    return unless block
    if block.arity > 0
      yield self
    else
      self.instance_eval(&block)
    end
  end
    # stores column info internally
    class ColumnInfo < Struct.new(:name, :w, :align)
    end
    # an array of column titles
    attr_reader :columns
    # boolean, does user want lines numbered
    attr_accessor :numbering
    # x is the + character used a field delim in separators
    # y is the field delim used in data rows, default is pipe or bar
    attr_accessor :x, :y

    # takes first optional argument as array of column names
    # second optional argument as array of data arrays
    # @yield self
    #
    def initialize cols=nil, *args, &block
      @chash = {}
      @cw = {}
      @calign = {}
      @separ = @columns = @numbering =  nil
      @y = '|'
      @x = '+'
      self.columns = cols if cols
      if !args.empty?
        puts "ARGS after shift #{args} "
        if !args.empty?
          self.data = args
        end
      end
      yield_or_eval(&block) if block_given?
    end
    #
    # set columns names 
    # @param [Array<String>] column names, preferably padded out to width for column
    def columns=(array)
      $log.debug "tabular got columns #{array.count} #{array.inspect} " if $log
      @columns = array
      @columns.each_with_index { |c,i| 
        @chash[i] = ColumnInfo.new(c, c.to_s.length) 
        @cw[i] ||= c.to_s.length
        #@calign[i] ||= :left # 2011-09-27 prevent setting later on
      }
    end
    alias :headings= :columns=
    #
    # set data as an array of arrays
    # @param [Array<Array>] data as array of arrays
    def data=(list)
      puts "got data: #{list.size} " if !$log
      puts list if !$log
      @list = list
    end

    # add a row of data 
    # @param [Array] an array containing entries for each column
    def add array
      $log.debug "tabular got add  #{array.count} #{array.inspect} " if $log
      @list ||= []
      @list << array
    end
    alias :<< :add
    alias :add_row :add

    # set width of a given column
    # @param [Number] column offset, starting 0
    # @param [Number] width
    def column_width colindex, width
      @cw[colindex] ||= width
      if @chash[colindex].nil?
        @chash[colindex] = ColumnInfo.new("", width) 
      else
        @chash[colindex].w = width
      end
      @chash
    end

    # set alignment of given column offset
    # @param [Number] column offset, starting 0
    # @param [Symbol] :left, :right
    def align_column colindex, lrc
      raise ArgumentError, "wrong alignment value sent" if ![:right, :left, :center].include? lrc
      @calign[colindex] ||= lrc
      if @chash[colindex].nil?
        @chash[colindex] = ColumnInfo.new("", nil, lrc)
      else
        @chash[colindex].align = lrc
      end
      @chash
    end

    # 
    # Now returns an array with formatted data
    # @return [Array<String>] array of formatted data
    def render
      buffer = []
      _guess_col_widths
      rows = @list.size.to_s.length
      @rows = rows
      _prepare_format
      
      str = ""
      if @numbering
        str = " "*(rows+1)+@y
      end
      str <<  @fmstr % @columns
      buffer << str
      #puts "-" * str.length
      buffer << separator
      if @list
        if @numbering
          @fmstr = "%#{rows}d "+ @y + @fmstr
        end
        #@list.each { |e| puts e.join(@y) }
        count = 0
        @list.each_with_index { |r,i|  
          value = convert_value_to_text r, count
          buffer << value
          count += 1
        }
      end
      buffer
    end
    def convert_value_to_text r, count
      if r == :separator
        return separator
      end
      if @numbering
        r.insert 0, count+1
      end
      return @fmstr % r;  
    end
    # use this for printing out on terminal
    # @example
    #     puts t.to_s
    def to_s
      render().join "\n"
    end
    def add_separator
      @list << :separator
    end
    def separator
      return @separ if @separ
      str = ""
      if @numbering
        str = "-"*(@rows+1)+@x
      end
      @cw.each_pair { |k,v| str << "-" * (v+1) + @x }
      @separ = str.chop
    end
    private
    def _guess_col_widths  #:nodoc:
      @list.each_with_index { |r, i| 
        break if i > GUESSCOLUMNS
        next if r == :separator
        r.each_with_index { |c, j|
          x = c.to_s.length
          if @cw[j].nil?
            @cw[j] = x
          else
            @cw[j] = x if x > @cw[j]
          end
        }
      }
    end
    def _prepare_format  #:nodoc:
      @fmtstr = nil
      fmt = []
      @cw.each_with_index { |c, i| 
        w = @cw[i]
        case @calign[i]
        when :right
          fmt << "%#{w}s "
        else
          fmt << "%-#{w}s "
        end
      }
      @fmstr = fmt.join(@y)
      puts "format: #{@fmstr} "
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  include RubyCurses
  $log = nil
  t = Tabular.new(['a', 'b'], [1, 2], [3, 4])
  puts t.to_s
  puts 
  t = Tabular.new([" Name ", " Number ", "  Email    "])
  t.add %w{ rahul 32 r@ruby.org }
  t << %w{ _why 133 j@gnu.org }
  t << %w{ Jane 1331 jane@gnu.org }
  t.column_width 1, 10
  t.align_column 1, :right
  puts t.to_s
  puts

  s = Tabular.new do |b|
    b.columns = %w{ country continent text }
    b << ["india","asia","a warm country" ] 
    b << ["japan","asia","a cool country" ] 
    b << ["russia","europe","a hot country" ] 
    b.column_width 2, 30
  end
  puts s.to_s
  puts
  puts "::::"
  puts
  s = Tabular.new do |b|
    b.columns = %w{ place continent text }
    b << ["india","asia","a warm country" ] 
    b << ["japan","asia","a cool country" ] 
    b << ["russia","europe","a hot country" ] 
    b << ["sydney","australia","a dry country" ] 
    b << ["canberra","australia","a dry country" ] 
    b << ["ross island","antarctica","a dry country" ] 
    b << ["mount terror","antarctica","a windy country" ] 
    b << ["mt erebus","antarctica","a cold place" ] 
    b << ["siberia","russia","an icy city" ] 
    b << ["new york","USA","a fun place" ] 
    b.column_width 0, 12
    b.column_width 1, 12
    b.numbering = true
  end
  puts s.to_s
end
