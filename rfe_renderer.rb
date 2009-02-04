require 'rubygems'
require 'ncurses'
require 'logger'
require 'lib/rbcurse/rwidget'
module RubyCurses

  ## 
  # This is a basic list cell renderer that will render the to_s value of anything.
  # Using alignment one can use for numbers too.
  # However, for booleans it will print true and false. If editing, you may want checkboxes
  class RfeRenderer < ListCellRenderer
    def initialize text="", config={}, &block
      super
      @orig_bgcolor = @bgcolor
      @orig_color = @color
      @orig_attr = @attr
    end
    ##
    ##
    # 
    def repaint graphic, r=@row,c=@col, value=@text, focussed=false, selected=false

      @bgcolor = @orig_bgcolor
      @color = @orig_color
      @row_attr = @orig_attr
      path = @parent.cur_dir()+"/"+value
      stat = File.stat(path)
      if File.directory? path
        @row_attr = Ncurses::A_BOLD
        #@color = 'yellow'
      end
      value = format_string(value, path,  stat)
      super

    end
  GIGA_SIZE = 1073741824.0
  MEGA_SIZE = 1048576.0
  KILO_SIZE = 1024.0

  # Return the file size with a readable style.
  def readable_file_size(size, precision)
    case
      #when size == 1 : "1 B"
      when size < KILO_SIZE : "%d B" % size
      when size < MEGA_SIZE : "%.#{precision}f K" % (size / KILO_SIZE)
      when size < GIGA_SIZE : "%.#{precision}f M" % (size / MEGA_SIZE)
      else "%.#{precision}f G" % (size / GIGA_SIZE)
    end
  end
  def date_format t
    t.strftime "%Y/%m/%d"
  end
  def format_string fn, path,stat
    max_len = 30
    f = fn.dup
    if File.directory? path
      #"%-*s\t(dir)" % [max_len,f]
      #f = "/"+f # disallows search on keypress
      f = "/"+f 
    end
    if f.size > max_len
      f = f[0..max_len-1]
    end
    "%-*s  %10s  %s" % [max_len,f,  readable_file_size(stat.size,1), date_format(stat.mtime)]
  end
  # ADD HERE 
  end
end
