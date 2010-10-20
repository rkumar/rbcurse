=begin
  * Name: TabularWidget
  * Description   A widget based on Tabular
  * Author: rk (arunachalesha)
  * file created 2010-09-28 23:37 
FIXME:

TODO 
   * guess_c : have some config : NEVER, FIRST_TIME, EACH_TIME
     if user has specified widths then we don't wanna guess. guess_size 20, ALL.
   * move columns
   * hide columns
   * data truncation based on col wid TODO
   * TODO: search -- how is it working, but curpos is wrong.
   * allow resize of column inside column header
   * Now that we allow header to get focus, we should allow it to handle
    keys, but its not an object like it was in rtable ! AARGH !
   * NOTE: header could become an object in near future, but then why did we break
   away from rtable ?
  --------
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'rbcurse'
require 'rbcurse/listscrollable'
require 'rbcurse/extras/tabular'

#include RubyCurses
module RubyCurses
  extend self
  # used when firing a column resize, so calling application can perhaps
  # resize other columns.
  class ColumnResizeEvent < Struct.new(:source, :index, :type); end

  ##
  # A viewable read only, scrollable table. This is supposed to be a
  # +minimal+, and (hopefully) fast version of Table (@see rtable.rb).
  class TabularWidget < Widget


    include ListScrollable
    dsl_accessor :title   # set this on top
    dsl_accessor :title_attrib   # bold, reverse, normal
    dsl_accessor :footer_attrib   # bold, reverse, normal
    dsl_accessor :list    # the array of arrays of data to be sent by user XXX RISKY bypasses set_content
    dsl_accessor :maxlen    # max len to be displayed
    attr_reader :toprow    # the toprow in the view (offsets are 0)
    attr_reader :winrow   # the row in the viewport/window
    # painting the footer does slow down cursor painting slightly if one is moving cursor fast
    dsl_accessor :print_footer
    dsl_accessor :suppress_borders 
    attr_accessor :current_index
    dsl_accessor :border_attrib, :border_color #  color pair for border
    dsl_accessor :header_attrib, :header_fgcolor, :header_bgcolor  #  2010-10-15 13:21 

    # boolean, whether lines should be cleaned (if containing tabs/newlines etc)
    dsl_accessor :sanitization_required
    # boolean, whether lines should be numbered
    attr_accessor :numbering
    # default or custom sorter
    attr_reader :table_row_sorter

    def initialize form = nil, config={}, &block
      @focusable = true
      @editable = false
      @sanitization_required = true
      @row = 0
      @col = 0
      @cw = {} # column widths keyed on column index - why not array ??
      @pw = [] # preferred column widths 2010-10-20 12:58 
      @calign = {} # columns aligns values, on column index
      @coffsets = {}
      @suppress_borders = false
      @row_offset = @col_offset = 1 
      @chash = {}
      # this should have index of displayed column
      # so user can reorder columns
      #@column_position = [] # TODO
      @separ = @columns = @numbering =  nil
      @y = '|'
      @x = '+'
      @show_focus = false  # don't highlight row under focus TODO
      @list = []
      @_header_adjustment = 0
      super
      # ideally this should have been 2 to take care of borders, but that would break
      # too much stuff !
      @win = @graphic

      @_events.push :CHANGE # thru vieditable
      @_events << :PRESS # new, in case we want to use this for lists and allow ENTER
      @_events << :ENTER_ROW # new, should be there in listscrollable ??
      @_events << :COLUMN_RESIZE_EVENT 
      install_keys
      init_vars
    end
    def init_vars #:nodoc:
      @curpos = @pcol = @toprow = @current_index = 0
      @repaint_all=true 
      @repaint_required=true 

      @row_offset = @col_offset = 0 if @suppress_borders == true
      @internal_width = 2
      @internal_width = 0 if @suppress_borders
      # added 2010-02-11 15:11 RFED16 so we don't need a form.
      @win_left = 0
      @win_top = 0
      @current_column = 0
      # currently i scroll right only if  current line is longer than display width, i should use 
      # longest line on screen.
      @longest_line = 0 # the longest line printed on this page, used to determine if scrolling shd work

      bind_key([?g,?g]){ goto_start } # mapping double keys like vim
      bind_key([?',?']){ goto_last_position } # vim , goto last row position (not column)
      bind_key(?/, :ask_search)
      bind_key(?n, :find_more)
      bind_key([?\C-x, ?>], :scroll_right)
      bind_key([?\C-x, ?<], :scroll_left)
      bind_key(?r) { getstr("Enter a word: ") }
      bind_key(?m, :disp_menu)
      bind_key(?w, :next_column)
      bind_key(?b, :previous_column)
    end
    def columns=(array)
      @_header_adjustment = 1
      @columns = array
      @columns.each_with_index { |c,i| 
        @cw[i] ||= c.to_s.length
        @calign[i] ||= :left
      }
      # maintains index in current pointer and gives next or prev
      @column_pointer = Circular.new @columns.size()-1
    end
    alias :headings= :columns=
    ## 
    # send in a list
    # 
    # @param [Array / Tabular] data to be displayed
    def set_content list
      if list.is_a? RubyCurses::Tabular
        @list = list
      elsif list.is_a? Array
        @list = list
      else
        raise "set_content expects Array not #{list.class}"
      end
      if @table_row_sorter
        @table_row_sorter.model=@list
      else
        @table_row_sorter = TableRowSorter.new @list
      end
      @current_index = @_header_adjustment
      @toprow = 0
      # but what if user has done some resizing, should we respect that ???
      @second_time = false # so that reestimation of column_widths
      # TODO reset current_index and top_row here to 0 ??
      @repaint_required = true
      @recalc_required = true
    end
    # add a row of data 
    # @param [Array] an array containing entries for each column
    def add array
      @list ||= []
      @list << array
      @repaint_required = true
      @recalc_required = true
    end
    alias :<< :add
    alias :add_row :add
    def column_width colindex, width
      return if width < 0
      raise ArgumentError, "wrong width value sent: #{width} " if width.nil? || !width.is_a?(Fixnum) || width < 0
      #@cw[colindex] = width
      @pw[colindex] = width # XXXXX
      get_column(colindex).width = width
      @repaint_required = true
      @recalc_required = true
    end

    # set alignment of given column offset
    # @param [Number] column offset, starting 0
    # @param [Symbol] :left, :right
    def column_align colindex, lrc
      raise ArgumentError, "wrong alignment value sent" if ![:right, :left, :center].include? lrc
      @calign[colindex] = lrc
      get_column(colindex).align = lrc
      @repaint_required = true
      #@recalc_required = true
    end
    # Set a column to hidden  TODO we are not actually doing that
    def column_hidden colindex, tf
      #raise ArgumentError, "wrong alignment value sent" if ![:right, :left, :center].include? lrc
      get_column(colindex).hidden = tf
      @repaint_required = true
      @recalc_required = true
    end
    def move_column

    end
    def expand_column
    end
    def contract_column
    end
    ## display this row number on top
    # programmataically indicate a row to be top row
    def top_row(*val) 
      if val.empty?
        @toprow
      else
        @toprow = val[0] || 0
      end
      @repaint_required = true
    end
    ## ---- for listscrollable ---- ##
    def scrollatrow #:nodoc:
      # TODO account for headers
      if @suppress_borders
        @height - @_header_adjustment 
      else
        @height - (2 + @_header_adjustment) 
      end
    end
    def row_count
      #@list.length
      get_content().length + @_header_adjustment
    end
    ##
    # returns row of first match of given regex (or nil if not found)
    def find_first_match regex #:nodoc:
      @list.each_with_index do |row, ix|
        return ix if !row.match(regex).nil?
      end
      return nil
    end
    ## returns the position where cursor was to be positioned by default
    # It may no longer work like that. 
    def rowcol #:nodoc:
      return @row+@row_offset, @col+@col_offset
    end
    ## print a border
    ## Note that print_border clears the area too, so should be used sparingly.
    def print_borders #:nodoc:
      raise "#{self.class} needs width" unless @width
      raise "#{self.class} needs height" unless @height

      $log.debug " #{@name} print_borders,  #{@graphic.name} "
      
      bordercolor = @border_color || $datacolor
      borderatt = @border_attrib || Ncurses::A_NORMAL
      @graphic.print_border @row, @col, @height-1, @width, bordercolor, borderatt
      print_title
    end
    def print_title #:nodoc:
      raise "#{self.class} needs width" unless @width
      $log.debug " print_title #{@row}, #{@col}, #{@width}  "
      @graphic.printstring( @row, @col+(@width-@title.length)/2, @title, $datacolor, @title_attrib) unless @title.nil?
    end
    def print_foot #:nodoc:
      @footer_attrib ||= Ncurses::A_REVERSE
      footer = "R: #{@current_index+1}, C: #{@curpos+@pcol}, #{@list.length} lines  "
      #$log.debug " print_foot calling printstring with #{@row} + #{@height} -1, #{@col}+2"
      @graphic.printstring( @row + @height -1 , @col+2, footer, $datacolor, @footer_attrib) 
      @repaint_footer_required = false # 2010-01-23 22:55 
    end
    ### FOR scrollable ###
    def get_content
      @list
      #[:columns, :separator,  *@list]
      #[:columns, *@list]
    end
    def get_window #:nodoc:
      @graphic
    end

    def repaint # Tabularwidget :nodoc:
      if @screen_buffer.nil?
        safe_create_buffer
        @screen_buffer.name = "Pad::TW_PAD_#{@name}" unless @screen_buffer.nil?
        $log.debug " tabularwid creates pad #{@screen_buffer} #{@name}"
      end

      #return unless @repaint_required # 2010-02-12 19:08  TRYING - won't let footer print for col move
      paint if @repaint_required
      #  raise "TV 175 graphic nil " unless @graphic
      print_foot if @print_footer && @repaint_footer_required
      buffer_to_window
    end
    def getvalue
      @list
    end
    def current_value
      @list[@current_index]
    end
    # Tabularwidget
    def handle_key ch #:nodoc:
      if header_row?
        ret = header_handle_key ch
        return ret unless ret == :UNHANDLED
      end
      case ch
      when ?\C-d.getbyte(0), 32
        scroll_forward
      when ?\C-b.getbyte(0)
        scroll_backward
      when ?\C-[.getbyte(0), ?t.getbyte(0)
        goto_start #start of buffer # cursor_start
      when ?\C-].getbyte(0), ?G.getbyte(0)
        goto_end # end / bottom cursor_end
      when KEY_UP, ?k.getbyte(0)
        #select_prev_row
        ret = up
        check_curpos
        
      when KEY_DOWN, ?j.getbyte(0)
        ret = down
        check_curpos
      when KEY_LEFT, ?h.getbyte(0)
        cursor_backward
      when KEY_RIGHT, ?l.getbyte(0)
        cursor_forward
      when KEY_BACKSPACE, KEY_BSPACE, KEY_DELETE
        cursor_backward
      when ?\C-a.getbyte(0) #, ?0.getbyte(0)
        # take care of data that exceeds maxlen by scrolling and placing cursor at start
        @repaint_required = true if @pcol > 0 # tried other things but did not work
        set_form_col 0
        @pcol = 0
      when ?\C-e.getbyte(0), ?$.getbyte(0)
        # take care of data that exceeds maxlen by scrolling and placing cursor at end
        # This use to actually pan the screen to actual end of line, but now somewhere
        # it only goes to end of visible screen, set_form probably does a sanity check
        blen = @buffer.rstrip.length
        set_form_col blen
        # search related 
      when @KEY_ASK_FIND
        ask_search
      when @KEY_FIND_MORE
        find_more
      when 10, 13, KEY_ENTER
        #fire_handler :PRESS, self
        fire_action_event
      when ?0.getbyte(0)..?9.getbyte(0)
        # FIXME the assumption here was that if numbers are being entered then a 0 is a number
        # not a beg-of-line command.
        # However, after introducing universal_argument, we can enters numbers using C-u and then press another
        # C-u to stop. In that case a 0 should act as a command, even though multiplier has been set
        if ch == ?0.getbyte(0) and $multiplier == 0
          # copy of C-a - start of line
          @repaint_required = true if @pcol > 0 # tried other things but did not work
          set_form_col 0
          @pcol = 0
          return 0
        end
        # storing digits entered so we can multiply motion actions
        $multiplier *= 10 ; $multiplier += (ch-48)
        return 0
      #when ?\C-u.getbyte(0)
        ## multiplier. Series is 4 16 64
        #@multiplier = (@multiplier == 0 ? 4 : @multiplier *= 4)
        #return 0
      when ?\M-l.getbyte(0) # just added 2010-03-05 not perfect
        scroll_right # scroll data horizontally 
      when ?\M-h.getbyte(0)
        scroll_left
      when ?\C-c.getbyte(0)
        $multiplier = 0
        return 0
      else
        # check for bindings, these cannot override above keys since placed at end
        begin
          ret = process_key ch, self
        rescue => err
          $error_message = err
          @form.window.print_error_message
          $log.error " Tabularwidget ERROR #{err} "
          $log.debug(err.backtrace.join("\n"))
        end
        return :UNHANDLED if ret == :UNHANDLED
      end
      $multiplier = 0 # you must reset if you've handled a key. if unhandled, don't reset since parent could use
      set_form_row
      return 0 # added 2010-01-12 22:17 else down arrow was going into next field
    end
    #
    # allow header to handle keys
    # NOTE: header could become an object in near future
    # We are calling a resize event and passing column index but do we really
    # have a column object that user can access and do something with ?? XXX
    #
    def header_handle_key ch   #:nodoc:
      # TODO pressing = should revert to calculated size ?
      col = _convert_curpos_to_column
      #width = @cw[col] 
      width = @pw[col] || @cw[col] 
      case ch
      when ?-.getbyte(0)
        column_width col, width-1
        # if this event has not been used in a sample it could change in near future
        e = ColumnResizeEvent.new self, col,  :DECREASE
        fire_handler :COLUMN_RESIZE_EVENT, e
        # can fire_hander so user can resize another column
        return 0
      when ?\+.getbyte(0)
        column_width col, width+1
        # if this event has not been used in a sample it could change in near future
        e = ColumnResizeEvent.new self, col,  :INCREASE
        return 0
      end
      return :UNHANDLED
    end
    # newly added to check curpos when moving up or down
    def check_curpos #:nodoc:
      # if the cursor is ahead of data in this row then move it back
      # i don't think this is required
      return
      if @pcol+@curpos > @buffer.length
        addcol((@pcol+@buffer.length-@curpos)+1)
        @curpos = @buffer.length 
        maxlen = (@maxlen || @width-@internal_width)

        # even this row is gt maxlen, i.e., scrolled right
        if @curpos > maxlen
          @pcol = @curpos - maxlen
          @curpos = maxlen-1 
        else
          # this row is within maxlen, make scroll 0
          @pcol=0
        end
        set_form_col 
      end
    end
    # set cursor on correct column tview
    def set_form_col col1=@curpos #:nodoc:
      @cols_panned ||= 0
      @pad_offset ||= 0 # added 2010-02-11 21:54 since padded widgets get an offset.
      @curpos = col1
      maxlen = @maxlen || @width-@internal_width
      #@curpos = maxlen if @curpos > maxlen
      if @curpos > maxlen
        @pcol = @curpos - maxlen
        @curpos = maxlen - 1
        @repaint_required = true # this is required so C-e can pan screen
      else
        @pcol = 0
      end
      # the rest only determines cursor placement
      win_col = 0 # 2010-02-07 23:19 new cursor stuff
      col2 = win_col + @col + @col_offset + @curpos + @cols_panned + @pad_offset
      #$log.debug "TV SFC #{@name} setting c to #{col2} #{win_col} #{@col} #{@col_offset} #{@curpos} "
      #@form.setrowcol @form.row, col
      setrowcol nil, col2
      @repaint_footer_required = true
    end
    def cursor_forward #:nodoc:
      maxlen = @maxlen || @width-@internal_width
      repeatm { 
      if @curpos < @width and @curpos < maxlen-1 # else it will do out of box
        @curpos += 1
        addcol 1
      else
        @pcol += 1 if @pcol <= @buffer.length
      end
      }
      set_form_col 
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41 
    end
    def addcol num #:nodoc:
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41 
      if @form
        @form.addcol num
      else
        @parent_component.form.addcol num
      end
    end
    def addrowcol row,col #:nodoc:
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41 
      if @form
      @form.addrowcol row, col
      else
        @parent_component.form.addrowcol num
      end
    end
    def cursor_backward  #:nodoc:
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

    ## NOTE: earlier print_border was called only once in constructor, but when
    ##+ a window is resized, and destroyed, then this was never called again, so the 
    ##+ border would not be seen in splitpane unless the width coincided exactly with
    ##+ what is calculated in divider_location.
    def paint  #:nodoc:
      my_win = nil
      if @form
        my_win = @form.window
      else
        my_win = @target_window
      end
      @graphic = my_win unless @graphic
      @win_left = my_win.left
      @win_top = my_win.top
      #_guess_col_widths
      estimate_column_widths
      tm = get_content
      @width ||= @preferred_width
      @height ||= [tm.length+3, 10].min
      _prepare_format

      print_borders if (@suppress_borders == false && @repaint_all) # do this once only, unless everything changes
      rc = tm.length
      _maxlen = @maxlen || @width-@internal_width
      #$log.debug " #{@name} Tabularwidget repaint width is #{@width}, height is #{@height} , maxlen #{maxlen}/ #{@maxlen}, #{@graphic.name} roff #{@row_offset} coff #{@col_offset}" 
      tr = @toprow
      acolor = get_color $datacolor
      h = scrollatrow() 
      r,c = rowcol
      print_header
      r += @_header_adjustment # for column header
      @longest_line = @width #maxlen
      0.upto(h - @_header_adjustment) do |hh|
        crow = tr+hh
        if crow < rc
            #focussed = @current_index == crow ? true : false 
            #selected = is_row_selected crow
            content = tm[crow]

            columnrow = false
            if content == :columns
              columnrow = true
            end

            value = convert_value_to_text content, crow

            @buffer = value if crow == @current_index
            # next call modified string. you may wanna dup the string.
            # rlistbox does
            sanitize value if @sanitization_required
            truncate value

            #@graphic.printstring  r+hh, c, "%-*s" % [@width-@internal_width,value], acolor, @attr
            #print_data_row( r+hh, c, "%-*s" % [@width-@internal_width,value], acolor, @attr)
            print_data_row( r+hh, c, @width-@internal_width, value, acolor, @attr)

        else
          # clear rows
          @graphic.printstring r+hh, c, " " * (@width-@internal_width), acolor,@attr
        end
      end
      @repaint_required        = false
      @repaint_footer_required = true
      @buffer_modified         = true # required by form to call buffer_to_screen
      @repaint_all             = false

    end

    # print data rows
    def print_data_row r, c, len, value, color, attr
      @graphic.printstring  r, c, "%-*s" % [len,value], color, attr
    end

    # print header row
    #  allows user to override
    def print_header_row r, c, len, value, color, attr
      #acolor = $promptcolor
      @graphic.printstring  r, c, "%-*s" % [len ,value], color, attr
    end
    def separator
      #return @separ if @separ
      str = ""
      if @numbering
        rows = @list.size.to_s.length
        str = "-"*(rows+1)+@x
      end
      @cw.each_pair { |k,v| str << "-" * (v+1) + @x }
      @separ = str.chop
    end
    # prints the column headers
    # Uses +convert_value_to_text+ and +print_header_row+
    def print_header
      r,c = rowcol
      value = convert_value_to_text :columns, 0
      len = @width - @internal_width
      truncate value # else it can later suddenly exceed line
      @header_color_pair ||= get_color $promptcolor, @header_fgcolor, @header_bgcolor
      @header_attrib ||= @attr
      print_header_row r, c, len, value, @header_color_pair, @header_attrib
    end
    # convert data object to a formatted string for print
    # NOTE: useful for overriding and doing custom formatting
    # @param [Array] array of column data, mostly +String+
    #        Can also be :columns or :separator
    # @param [Fixnum] index of row in data
    def convert_value_to_text r, count
      if r == :separator
        return separator
      elsif r == :columns
        r = @columns
        return "??" unless @columns # column was requested but not supplied
        return @headerfmtstr % r if @numbering
      end
      if @numbering
        r = r.dup
        r.insert 0, count+1
      end
      # unroll r, get width and align
      # This is to truncate column to requested width
      fmta = []
      r.each_with_index { |e, i| 
        w = @cw[i]
        l = e.to_s.length
        fmt = "%-#{w}s "
        if l > w
          fmt = "%.#{w}s "
        else
          # ack we don;t need to recalc this we can pull out of hash FIXME
          case @calign[i]
          when :right
            fmt = "%#{w}s "
          else
            fmt = "%-#{w}s "
          end
        end
        fmta << fmt
      }
      fmstr = fmta.join(@y)
      return fmstr % r;  
    end
    # NOTE = this should only work if user has not specified
    # widths for cols ? What if has ?
    # FIXME: what about column level truncation, if user specifies
    # colw and data in that col exceeds.
    def _guess_col_widths  #:nodoc:
      return if @second_time
      @second_time = true if @list.size > 0
      @list.each_with_index { |r, i| 
        break if i > 10
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
      #sum = @cw.values.inject(0) { |mem, var| mem + var  }
      #$log.debug " SUM is #{sum} "
      total = 0
      @cw.each_pair { |name, val| total += val }
      @preferred_width = total + (@cw.size() *2)
      @preferred_width += 4 if @numbering # FIXME this 4 is rough
    end
    def estimate_column_widths
      @columns.each_with_index { |c, i|  
        if @pw[i]
          @cw[i] = @pw[i]
        else
          @cw[i] = calculate_column_width(i)
        end
      }
      total = 0
      @cw.each_pair { |name, val| total += val }
      @preferred_width = total + (@cw.size() *2)
      @preferred_width += 4 if @numbering # FIXME this 4 is rough
    end
    # if user has not specified preferred_width for a column
    # then we can calculate the same based on data
    def calculate_column_width col
      ret = @cw[col] || 2
      @list.each_with_index { |r, i| 
        break if i > 10
        next if r == :separator
        c = r[col]
        x = c.to_s.length
        ret = x if x > ret
      }
      ret
    end
    def _prepare_format  #:nodoc:
      @fmtstr = nil
      fmt = []
      total = 0
      @cw.each_with_index { |c, i| 
        w = @cw[i]
        @coffsets[i] = total
        total += w + 2

        case @calign[i]
        when :right
          fmt << "%#{w}s "
        else
          fmt << "%-#{w}s "
        end
      }
      @fmstr = fmt.join(@y)
      if @numbering
        @rows ||= @list.size.to_s.length
        @headerfmtstr = " "*(@rows+1)+@y + @fmstr
        @fmstr = "%#{@rows}d "+ @y + @fmstr
        @coffsets.each_pair { |name, val| @coffsets[name] = val + @rows + 2 }
      end
      #$log.debug " FMT : #{@fmstr} "
      #alert "format:     #{@fmstr} "
    end
    ## this is just a test of prompting user for a string
    #+ as an alternative to the dialog.
    def getstr prompt, maxlen=10  #:nodoc:
      tabc = Proc.new {|str| Dir.glob(str +"*") }
      config={}; config[:tab_completion] = tabc
      config[:default] = "default"
      $log.debug " inside getstr before call "
      ret, str = rbgetstr(@form.window, @row+@height-1, @col+1, prompt, maxlen, config)
      $log.debug " rbgetstr returned #{ret} , #{str} "
      return "" if ret != 0
      return str
    end
    # this is just a test of the simple "most" menu
    def disp_menu  #:nodoc:
      $error_message_row ||= 23 # FIXME
      $error_message_col ||= 1 # FIXME
      menu = PromptMenu.new self 
      menu.add( menu.create_mitem( 's', "Goto start ", "Going to start", Proc.new { goto_start} ))
      menu.add(menu.create_mitem( 'r', "scroll right", "I have scrolled ", :scroll_right ))
      menu.add(menu.create_mitem( 'l', "scroll left", "I have scrolled ", :scroll_left ))
      item = menu.create_mitem( 'm', "submenu", "submenu options" )
      menu1 = PromptMenu.new( self, "Submenu Options")
      menu1.add(menu1.create_mitem( 's', "CASE sensitive", "Ignoring Case in search" ))
      menu1.add(menu1.create_mitem( 't', "goto last position", "moved to previous position", Proc.new { goto_last_position} ))
      item.action = menu1
      menu.add(item)
      # how do i know what's available. the application or window should know where to place
      #menu.display @form.window, 23, 1, $datacolor #, menu
      menu.display @form.window, $error_message_row, $error_message_col, $datacolor #, menu
    end
    ##
    # dynamically load a module and execute init method.
    # Hopefully, we can get behavior like this such as vieditable or multibuffers
    def load_module requirename, includename
      require "rbcurse/#{requirename}"
      extend Object.const_get("#{includename}")
      send("#{requirename}_init") #if respond_to? "#{includename}_init"
    end

    # returns true if cursor is on header row
    def header_row?
      return false if @columns.nil?
      1 == @row + (@current_index-@toprow)
    end
    # on pressing ENTER we send user some info, the calling program
    # would bind :PRESS
    # Added a call to sort, should i still call PRESS
    # or just do a sort in here and not call PRESS ???
    #--
    # FIXME we can create this once and reuse
    #++
    def fire_action_event
      require 'rbcurse/ractionevent'
      # the header event must only be used if columns passed
      if header_row?
        # TODO we need to fire correct even for header row, including
        #alert "you are on header row: #{@columns[x]} curpos: #{@curpos}, x:#{x} "
        #aev = TextActionEvent.new self, :PRESS, @columns[x], x, @curpos
        x = _convert_curpos_to_column
        @table_row_sorter.toggle_sort_order x
        @table_row_sorter.sort
        @repaint_required = true
        aev = TextActionEvent.new self, :PRESS,:header, x, @curpos
      else
        aev = TextActionEvent.new self, :PRESS, current_value(), @current_index, @curpos
      end
      fire_handler :PRESS, aev
    end
    # Convert current cursor position to a table column
    # calculate column based on curpos since user may not have
    # user w and b keys (:next_column)
    # @return [Fixnum] column index base 0
    def _convert_curpos_to_column  #:nodoc:
      x = 0
      @coffsets.each_pair { |e,i| 
        if @curpos < i 
          break
        else 
          x += 1
        end
      }
      x -= 1 # since we start offsets with 0, so first auto becoming 1
      return x
    end
    def on_enter
      # so cursor positioned on correct row
      set_form_row
      super
    end
    # called by listscrollable, used by scrollbar ENTER_ROW
    def on_enter_row arow
      fire_handler :ENTER_ROW, self
      @repaint_required = true
    end
    def next_column
      c = @column_pointer.next
      cp = @coffsets[c] 
      #$log.debug " next_column #{c} , #{cp} "
      @curpos = cp if cp
      next_row() if c < @column_pointer.last_index
      #addcol cp
      set_form_col 
    end
    def previous_column
      c = @column_pointer.previous
      cp = @coffsets[c] 
      #$log.debug " prev_column #{c} , #{cp} "
      @curpos = cp if cp
      previous_row() if c > @column_pointer.last_index
      #addcol cp FIXME
      set_form_col 
    end
    private
    def get_column index   #:nodoc:
      return @chash[index] if @chash.has_key? index
      @chash[index] = ColumnInfo.new
    end

    # Some supporting classes
    
    # This is our default table row sorter.
    # It does a multiple sort and allows for reverse sort also.
    # It's a pretty simple sorter and uses sort, not sort_by.
    # Improvements welcome.
    # Usage: provide model in constructor or using model method
    # Call toggle_sort_order(column_index) 
    # Call sort. 
    # Currently, this sorts the provided model in-place. Future versions
    # may maintain a copy, or use a table that provides a mapping of model to result.
    # # TODO check if column_sortable
    class TableRowSorter
      attr_reader :sort_keys
      def initialize model=nil
        self.model = model
        @columns_sort = []
        @sort_keys = nil
      end
      def model=(model)
        @model = model
        @sort_keys = nil
      end
      def sortable colindex, tf
        @columns_sort[colindex] = tf
      end
      def sortable? colindex
        return false if @columns_sort[colindex]==false
        return true
      end
      # should to_s be used for this column
      def use_to_s colindex
        return true # TODO
      end
      # sorts the model based on sort keys and reverse flags
      # @sort_keys contains indices to sort on
      # @reverse_flags is an array of booleans, true for reverse, nil or false for ascending
      def sort
        return unless @model
        return if @sort_keys.empty?
        @model.sort!{|x,y| 
          res = 0
          @sort_keys.each { |ee| 
            e = ee.abs-1 # since we had offsetted by 1 earlier
            abse = e.abs
            if ee < 0
              res = y[abse] <=> x[abse]
            else
              res = x[e] <=> y[e]
            end
            break if res != 0
          }
          res
        }
      end
      # toggle the sort order if given column offset is primary sort key
      # Otherwise, insert as primary sort key, ascending.
      def toggle_sort_order index
        index += 1 # increase by 1, since 0 won't multiple by -1
        # internally, reverse sort is maintained by multiplying number by -1
        @sort_keys ||= []
        if @sort_keys.first && index == @sort_keys.first.abs
          @sort_keys[0] *= -1 
        else
          @sort_keys.delete index # in case its already there
          @sort_keys.delete(index*-1) # in case its already there
          @sort_keys.unshift index
          # TODO delete beyond a max, default 3
        end
      end
      def set_sort_keys list
        @sort_keys = list
      end
    end #class
    # what about is_resizable XXX
    class ColumnInfo < Struct.new(:name, :width, :align, :hidden)
    end

    # a structure that maintains position and gives
    # next and previous taking max index into account.
    # it also circles. Can be used for traversing next component
    # in a form, or container, or columns in a table.
    class Circular < Struct.new(:max_index, :current_index)
      attr_reader :last_index
      attr_reader :current_index
      def initialize  m, c=0
        raise "max index cannot be nil" unless m
        @max_index = m
        @current_index = c
        @last_index = c
      end
      def next
        @last_index = @current_index
        if @current_index + 1 > @max_index
          @current_index = 0
        else
          @current_index += 1
        end
      end
      def previous
        @last_index = @current_index
        if @current_index - 1 < 0
          @current_index = @max_index
        else
          @current_index -= 1
        end
      end
      def is_last?
        @current_index == @max_index
      end
    end

  end # class tabluarw

end # modul
if __FILE__ == $PROGRAM_NAME
  
require 'rbcurse/app'
App.new do
  t = TabularWidget.new @form, :row => 2, :col => 2, :height => 20, :width => 30
  t.columns = ["Name ", "Age ", " Email        "]
  t.add %w{ rahul 32 r@ruby.org }
  t << %w{ _why 133 j@gnu.org }
  t << ["jane", "1331", "jane@gnu.org" ]
  t.column_align 1, :right
  s = TabularWidget.new @form, :row => 2, :col =>32  do |b|
    b.columns = %w{ country continent text }
    b << ["india","asia","a warm country" ] 
    b << ["japan","asia","a cool country" ] 
    b << ["russia","europe","a hot country" ] 
    #b.column_width 2, 30
  end
  s = TabularWidget.new @form , :row => 12, :col => 32 do |b|
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
  require 'rbcurse/extras/scrollbar'
  sb = Scrollbar.new @form, :parent => s
  #t.column_align 1, :right
  #puts t.to_s
  #puts
end
end
