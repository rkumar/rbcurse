require 'rbcurse'
require 'fileutils'
require 'rbcurse/rlistbox'
require 'rbcurse/vieditable'
require 'rbcurse/undomanager'
##
# Created on : Wed Sep 22 22:30:13 IST 2010
# (c) rkumar (arunachalesha)
#
module RubyCurses
  class DirectoryList < Listbox
    #dsl_accessor :xxx
    include ViEditable

    def initialize form, config={}, &block
      super
      #@_events.push(*[:EVENT, :EVENT2])
      @current_path ||= Dir.getwd
      @_header_array = [ "Attr", "Size", "Modified" , "Name" , "<Order_by_Extension>" ]
      @_header = " %s %8s  %19s %s   %s " % @_header_array
      @curpos = 0
    end
    def init_vars
      # which rows are not data, thus don't fire, or give error
      @_non_data_indices = []
      @_header_row_index   = 0
      @one_key_selection = false # this allows us to map keys to methods
      vieditable_init_listbox
      undom = SimpleUndo.new self
      bind_key(?\M-h, :scroll_left)
      bind_key(?\M-l, :scroll_right)
      bind_key(KEY_RIGHT, :cursor_forward)
      bind_key(KEY_LEFT, :cursor_backward)
      bind_key(?$, :end_of_line)
      bind_key(?\C-e, :end_of_line)
      bind_key(?\C-a, :start_of_line)
      super
    end
    # changing the current path, refreshes files
    def current_path(*val)
      if val.empty?
        return @current_path
      else
        raise ArgumentError, "current_path should be a directory:#{val[0]}." unless File.directory? val[0]
        oldvalue = @current_path
        if oldvalue != val[0]
          @current_path = val[0]
          populate @current_path
          fire_property_change(:current_path, oldvalue, @current_path)
        end
      end
      self
    end
    # populate the list with full information of file 
    # XXX THIS BECOMES A PAIN TO UPDATE !
    def populate path
      case path
      when String
        @current_path = path
        @entries = Dir.new(path).entries
        @entries.delete(".")
      when Array
        path = @current_path
        # we've been passed @entries so we don't need to put it again ??? XXX
      end
      # TODO K M etc
      list @entries
      @list.insert 0, @_header
      @title = @current_path
    end
    # called by parent's repaint
    def convert_value_to_text file, crow
      if @short
        file
      else
        if crow == @_header_row_index
          return file
        else
          # OUCH i don't know if its a header !!
          fullname = File.join(@current_path, file)
          fname = file
          stat = File::Stat.new fullname
          time = stat.mtime.to_s[0..18]
          attr = stat.directory? ? "d" : "-"
          attr << (stat.writable? ? "w" : "-")
          attr << (stat.readable? ? "r" : "-")
          attr << (stat.executable? ? "x" : "-")
          fname << "/" if stat.directory? && fname[-1] != "/"
          value = " %s %8d  %s %s" % [attr, stat.size, time, fname]
          return value
        end
      end
    end

    def create_default_cell_renderer
      cell_renderer( RubyCurses::DirectoryListCellRenderer.new "", {:color=>@color, :bgcolor=>@bgcolor, :parent => self, :display_length=> @width-2-@left_margin})
    end
    def _get_word_under_cursor line=@_header, pos=@curpos
      finish = line.index(" ", pos)
      start = line.rindex(" ",pos)
      finish = -1 if finish.nil?
      start = 0 if start.nil?
      return line[start..finish]
    end
    # sorts entries by various parameters.
    # Not optimal since it creates file stat objects each time rather than cacheing, but this is a demo of widgets
    # not a real directory lister!
    def sort_by key, reverse=false
      # remove parent before sorting, keep at top
      first = @entries.delete_at(0) if @entries[0]==".."
      #key ||= @sort_key
      sort_keys = { 'Name' => :name, 'Modified' => :mtime, "Size" => :size, "<Order_by_Extension>" => :ext, 'Attr' => :attr, "Accessed" => :atime }
      key = sort_keys[key] if sort_keys.has_key? key
      #if key == @sort_key
        #reverse = true
      #end
      cdir=@current_path+"/"
      case key
      when  :size
        @entries.sort! {|x,y| xs = File.stat(cdir+x); ys = File.stat(cdir+y); 
          if reverse
            xs.size <=> ys.size 
          else
            ys.size <=> xs.size 
          end
        }
      when  :mtime
        @entries.sort! {|x,y| xs = File.stat(cdir+x); ys = File.stat(cdir+y); 
          if reverse
            xs.mtime <=> ys.mtime 
          else
            ys.mtime <=> xs.mtime 
          end
        }
      when  :atime
        @entries.sort! {|x,y| xs = File.stat(cdir+x); ys = File.stat(cdir+y); 
          if reverse
            xs.atime <=> ys.atime 
          else
            ys.atime <=> xs.atime 
          end
        }
      when  :name
        @entries.sort! {|x,y| x <=> y 
          if reverse
            x <=> y
          else
            y <=> x
          end
        }
      when  :ext
        @entries.sort! {|x,y| 
          if reverse
            File.extname(cdir+x) <=> File.extname(cdir+y) 
          else
            File.extname(cdir+y) <=> File.extname(cdir+x) 
          end
        }
      when  :attr
        @entries.sort! {|x,y| xs = File.stat(cdir+x); ys = File.stat(cdir+y); 
          x = xs.directory? ? "d" : "D"
          y = ys.directory? ? "d" : "D"
          if reverse
            x <=> y
          else
            y <=> x
          end
        }
      end
      @sort_key = key
      @entries.insert 0, first unless first.nil?  # keep parent on top
      populate @entries
    end
    GIGA_SIZE = 1073741824.0
    MEGA_SIZE = 1048576.0
    KILO_SIZE = 1024.0

    # Return the file size with a readable style.
    def readable_file_size(size, precision)
      case
        #when size == 1 : "1 B"
      when size < KILO_SIZE then "%d B" % size
      when size < MEGA_SIZE then "%.#{precision}f K" % (size / KILO_SIZE)
      when size < GIGA_SIZE then "%.#{precision}f M" % (size / MEGA_SIZE)
      else "%.#{precision}f G" % (size / GIGA_SIZE)
      end
    end
    def date_format t
      t.strftime "%Y/%m/%d"
    end

    # on pressing Enter, execute this action.
    # Here we take the current file and if its a directory, we step into it.
    def fire_action_event
      if @_non_data_indices.include? @current_index
        Ncurses.error
        return
      end
      if @_header_row_index == @current_index
        # user hit enter on the header row. we determine column and sort.
        header = _get_word_under_cursor
        #@reverse = false
        if header == @_last_header_sorted
          @reverse = !@reverse # clicking 2 times won't reverse again
        else 
          @reverse = false
        end
        sort_by header.strip, @reverse
        @_last_header_sorted = header
        return
      end
      value = current_value
      value = value.split.last
      if value == ".."
        _path = File.dirname(@current_path)
      else
        _path =  File.join(@current_path, value)
      end
      if File.directory? _path
        populate _path
      end

      super
    end
    def addcol num
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41
      if @form
        @form.addcol num
      else
        @parent_component.form.addcol num
      end
    end
    # set cursor column position
    # if i set col1 to @curpos, i can move around left right if key mapped
    def set_form_col col1=@curpos
      col1 ||= 0
      @cols_panned ||= 0 # RFED16 2010-02-17 23:40
      win_col = 0 # 2010-02-17 23:19 RFED16
      col2 = win_col + @col + @col_offset + col1 + @cols_panned + @left_margin
     setrowcol nil, col2 # 2010-02-17 23:19 RFED16
    end
    def start_of_line
      @repaint_required = true if @pcol > 0 # tried other things but did not work
      set_form_col 0
      @pcol = 0
    end
    # this does not work, since the value in list is not the printed value
    def end_of_line
      blen = current_value.rstrip.length
      set_form_col blen
    end
 
    def cursor_backward
      repeatm {
        if @curpos > 0
          @curpos -= 1
          set_form_col
          #addcol -1
        elsif @pcol > 0
          @pcol -= 1
        end
      }
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41
    end
  
    
    def cursor_forward
      @curpos ||= 0
      maxlen = @maxlen || @width-2
      repeatm {
        if @curpos < @width and @curpos < maxlen-1 # else it will do out of box
          @curpos += 1
          addcol 1
        else
          #@pcol += 1 if @pcol <= @buffer.length
          # buffer not eixstent FIXME
        end
      }
      set_form_col
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41
    end
    def [](index)
      @entries[index]
    end
 
    @private
    def longest_line=(l)
      @longest_line = l
    end
    def longest_line
      @longest_line 
    end
  def edit_line lineno=@current_index
    line = @list[lineno]
    prompt = "Edit NAme: "
    maxlen = 80
    config={}; 
    oldline = line.dup
    config[:default] = line
    ret, str = rbgetstr(@form.window, $error_message_row, $error_message_col,  prompt, maxlen, config)
    $log.debug " rbgetstr returned #{ret} , #{str} "
    return if ret != 0
    @list[lineno].replace(str)
    fire_handler :CHANGE, InputDataEvent.new(0,oldline.length, self, :DELETE_LINE, lineno, oldline)     #  2008-12-24 18:34 
    fire_handler :CHANGE, InputDataEvent.new(0,str.length, self, :INSERT_LINE, lineno, str)
    @repaint_required = true
  end
    ##
  end # class

  ## 
  # A cell renderer should not changed the length of a line otherwise scrolling etc goes for a toss.
  # The calling repaint method does trimming.
  #
  # A cell renderer can do small modifications, or color changing to data.
  # Here we should color directories or bak files or hidden files, swap files etc differently
  # Should this class do the trimming of data, else its hard to figure out what the extension
  # is if its trimeed out. But then it would have to handle the panning too.
  require 'rbcurse/listcellrenderer'
  class DirectoryListCellRenderer < ListCellRenderer
    #def initialize text="", config={}, &block
      #super
    #end
    # sets @color_pair and @attr

    ##
    #  paint a list box cell
    #  2010-09-02 15:38 changed focussed to take true, false and :SOFT_FOCUS
    #  SOFT_FOCUS means the form focus is no longer on this field, but this row
    #  was focussed when use was last on this field. This row will take focus
    #  when field is focussed again
    #
    #  @param [Buffer] window or buffer object used for printing
    #  @param [Fixnum] row
    #  @param [Fixnum] column
    #  @param [Fixnum] actual index into data, some lists may have actual data elsewhere and
    #                  display data separate. e.g. rfe_renderer (directory listing)
    #  @param [String] text to print in cell
    #  @param [Boolean, :SOFT_FOCUS] cell focussed, not focussed, cell focussed but field is not focussed
    #  @param [Boolean] cell selected or not
    def repaint graphic, r=@row,c=@col, row_index=-1,value=@text, focussed=false, selected=false

      prepare_default_colors focussed, selected
      if row_index == 0
        #nvalue = " %s %8s  %19s %s   %s " % value.split(",")
        graphic.printstring r, c, "%-s" % value, @color_pair,@attr
      else
        $log.debug " CELL XXX GTETING  #{row_index} ,#{value}"

        #fullname = File.join(parent.current_path, value)
        #fname = value
        #stat = File::Stat.new fullname
        #time = stat.mtime.to_s[0..18]
        ## TODO K M etc
        #attr = stat.directory? ? "d" : "-"
        #attr << (stat.writable? ? "w" : "-")
        #attr << (stat.readable? ? "r" : "-")
        #attr << (stat.executable? ? "x" : "-")
        #fname << "/" if stat.directory?
        #value = " %s %8d  %s %s" % [attr, stat.size, time, fname]
        #if value.length > @parent.longest_line
          #@parent.longest_line = value.length
        #end

        # ensure we do not exceed
        if !@display_length.nil?
          if value.length > @display_length
            value = value[0..@display_length-1]
          end
        end
        len = @display_length || value.length
        graphic.printstring r, c, "%-*s" % [len, value], @color_pair,@attr
      end
    end
    # ADD HERE 
  end
end # module
# set filetype=ruby
