=begin
  * Name: dbcommon
  * $Id$
  * Description  Common DB  stuff 
  * Author: rkumar
  * Date: 2008-11-13 13:33 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end

##
# dependencies
#   - @content  the window on which writing is happening
#   - $db - database connection
module DBCommon

  ##
  # executes sql command and creates @content
  # also calculates numpadding

  def sql(command)
    #command = %Q{select * from #{tablename} limit 1}
    @columns, *@datarows = $db.execute2(command)
    @datatypes = @datarows[0].types
    @content = @datarows
    $db.close
    # used for padding the row number printed on the left side
    @numpadding = @content.length.to_s.length  # how many digits the max row is: 10 is 2, 100 is 3 etc
    $log.debug("sql: #{command}")
    $log.debug("content len: #{@content.length}")
  end

  ##
  # expects content to be 2 dim array.
  def search_content regex
    res = []
    @content.each_with_index do |row, ix| res << ix if row.grep(/#{regex}/) != [] end
    return res
  end
  def format_titles
    #   get_metadata
    @column_separator ||= "|"

    #min_column_width = Ncurses.COLS/@columns.length # XXX
    min_column_width = @cols/@columns.length
    $log.debug("MIN: #{min_column_width}")
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
      total = 0
      fl.each_index{ |i|
        if @datatypes[i].match(/(real|int)/) != nil
          cw = [@column_widths[i], [8,min_column_width].min].max
          $log.debug("int #{@column_widths[i]}, #{cw}")
        elsif @datatypes[i].match(/(date)/) != nil
          cw = [@column_widths[i], [12,min_column_width].min].max
          #cw = [12,min_column_width].min
          $log.debug("date #{@column_widths[i]}, #{cw}")
        else
          cw = [@column_widths[i], min_column_width].max
          $log.debug("else #{@column_widths[i]}, #{cw}")
        end
        @column_widths[i] = cw
        total += cw
        fl[i] = fl[i][0..cw-1] if fl[i].length >= cw
        str += sprintf("%-*s",cw, fl[i])
        str += @column_separator if i < (fl.length() - 1)
      }
    end
    @column_widths["__TOTAL__"] = total
    str.gsub!(/_/,' ')
    return "%5s" % " "+ str
  end 
  def estimate_column_widths
    colwidths = {}
    #min_column_width = Ncurses.COLS/@columns.length # XXX 2008-11-13 23:03 
    min_column_width = @cols/@columns.length
    #@columns.each_index { |i| colwidths[i]=min_column_width }
    @content.each_index do |cix|
      break if cix >= 20
      row = @content[cix]
      row.each_index do |ix|
        col = row[ix]
        colwidths[ix] ||= 0
        colwidths[ix] = [colwidths[ix], col.length].max
      end
    end
    total = 0
    colwidths.each_pair do |k,v|
      name = @columns[k.to_i]
      colwidths[name] = v
      total += v
    end
    colwidths["__TOTAL__"] = total
    @column_widths = colwidths
  end
end
