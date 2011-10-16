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
      # we need to refer to file types, executable, dir, link, otherwise we'll go crazy 
      @color_hash = {
        '.rb' =>      [get_color($datacolor, 'red', 'black'), 0],
        '.txt' =>     [get_color($datacolor, 'white', 'black'), 0],
        '.gemspec' => [get_color($datacolor, 'yellow', 'black'), 0],
        '.gem' => [get_color($datacolor, 'yellow', 'black'), 0],
        '.c' =>       [get_color($datacolor, 'green', 'black'), 0],
        '.py' =>      [get_color($datacolor, 'green', 'black'), 0],
        '.tgz' =>     [get_color($datacolor, 'red', 'black'), get_attrib('bold')],
        '.gz' => [get_color($datacolor, 'red', 'black'), 0],
        '.zip' => [get_color($datacolor, 'red', 'black'), 0],
        '.jar' => [get_color($datacolor, 'red', 'black'), 0],
        '.html' => [get_color($datacolor, 'green', 'black'), get_attrib('reverse')],
        "" => [get_color($datacolor, 'yellow', 'black'), get_attrib('bold')],
        '.jpg' => [get_color($datacolor, 'magenta', 'black'), 0],
        '.png' => [get_color($datacolor, 'magenta', 'black'), 0],
        '.sh' => [get_color($datacolor, 'red', 'black'), 0],
        '.mp3' => [get_color($datacolor, 'cyan', 'blue'), 0],
        '.bak' => [get_color($datacolor, 'magenta', 'black'), 0],
        '.tmp' => [get_color($datacolor, 'black', 'blue'), 0],
        '.pl' => [get_color($datacolor, 'green', 'black'), 0],
        '.java' => [get_color($datacolor, 'cyan', 'blue'), 0],
        '.class' => [get_color($datacolor, 'magenta', 'black'), 0],
        '.pyc' => [get_color($datacolor, 'magenta', 'black'), 0],
        '.o' => [get_color($datacolor, 'magenta', 'black'), 0],
        '.a' => [get_color($datacolor, 'magenta', 'black'), 0],
        '.lib' => [get_color($datacolor, 'magenta', 'black'), 0]
      } 
    end

    # override parent method to set color_pair and attr for different kind of files
    def select_colors focussed, selected 
      ext = File.extname(@path)
      c = @color_hash[ext]
      c = [$datacolor, FFI::NCurses::A_NORMAL] unless c
      if File.directory? @path
        c = [get_color($datacolor, 'blue', 'black'), FFI::NCurses::A_BOLD] 
      end
      @color_pair, @attr = *c
      if selected
        #@attr = FFI::NCurses::A_UNDERLINE | FFI::NCurses::A_BOLD # UL not avaible on screen
        @attr = FFI::NCurses::A_REVERSE | FFI::NCurses::A_BOLD
        @color_pair = $datacolor
      end
      if focussed
        @attr = FFI::NCurses::A_REVERSE # | FFI::NCurses::A_BOLD
      end
    end
    # 
    def repaint graphic, r=@row,c=@col, row_index=-1, value=@text, focussed=false, selected=false

      @bgcolor = @orig_bgcolor
      @color = @orig_color
      @row_attr = @orig_attr
      # XXX ouch, when we delete from list, must delete from here too.
      value = @parent.entries[row_index]
      if value[0,1]=="/"
        path = value.dup
      else
        path = @parent.cur_dir()+"/"+value 
      end
      @path = path # i need it in select_color
      begin
      stat = File.stat(path)
      if File.directory? path
        @row_attr = Ncurses::A_BOLD
        #@color = 'yellow'
      end
      value = format_string(value, path,  stat)
      super

      rescue => err
        $log.debug " rfe_renderer: #{err}"
      end

    end
  GIGA_SIZE = 1073741824.0
  MEGA_SIZE = 1048576.0
  KILO_SIZE = 1024.0

  # Return the file size with a readable style.
  def readable_file_size(size, precision)
    case
      #when size == 1  then "1 B"
      when size < KILO_SIZE  then "%d B" % size
      when size < MEGA_SIZE  then "%.#{precision}f K" % (size / KILO_SIZE)
      when size < GIGA_SIZE  then "%.#{precision}f M" % (size / MEGA_SIZE)
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
