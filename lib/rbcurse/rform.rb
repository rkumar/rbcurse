=begin
  * Name: TextView and TextArea
  * $Id$
  * Description   Our own form with own simple field to make life easier. Ncurses forms are great, but
  *         honestly the sequence sucks and is a pain after a while for larger scale work.
  *         We need something less restrictive.
  * Author: rkumar (arunachalesha)
TODO 
  * Field/entry
    - textvariable - bding field to a var so the var is updated
  * 
  
   2008-12-24 18:01  moved menu etc to rmenu.rb
  --------
  * Date: 2008-11-14 23:43 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/scrollable'
require 'rbcurse/selectable'
require 'rbcurse/rinputdataevent'

include Ncurses
include RubyCurses
module RubyCurses
  extend self

  ## a multiline text editing widget
  # TODO - giving data to user - adding newlines, and withog adding.
  #  - respect newlines for incoming data
  #   
  class OldTextArea < Widget
    include Scrollable
    dsl_accessor :height
    dsl_accessor :title
    dsl_accessor :title_attrib   # bold, reverse, normal
    dsl_accessor :list    # the array of data to be sent by user
    dsl_accessor :maxlen    # the array of data to be sent by user
    attr_reader :toprow
    attr_reader :prow
    attr_reader :winrow
    dsl_accessor :auto_scroll # boolean, keeps view at end as data is inserted.
    dsl_accessor :print_footer
    dsl_accessor :editable          # allow editing
    attr_accessor :modified          # boolean, value modified or not 2009-01-08 12:29 

    def initialize form, config={}, &block
      @focusable = true
      @editable = true
      @left_margin = 1
      @row = 0
      @col = 0
      @curpos = 0
      @show_focus = false
      @list = []
      super
      @row_offset = @col_offset = 1
      @orig_col = @col
      # this does result in a blank line if we insert after creating. That's required at 
      # present if we wish to only insert
      if @list.empty?
        @list << "\r"
      end
      @scrollatrow = @height-2
      @content_rows = @list.length
      @win = @form.window
      init_scrollable
      print_borders
      @maxlen ||= @width-2
    end
    def rowcol
    #  $log.debug "textarea rowcol : #{@row+@row_offset+@winrow}, #{@col+@col_offset}"
      return @row+@row_offset+@winrow, @col+@col_offset
    end
    ##
    # this avoids wrapping. Better to use the <<.
    def Oinsert off0, *data
      @list.insert off0, *data
      # fire_handler :CHANGE, self  # 2008-12-09 14:56  NOT SURE
    end
    # private
    def wrap_text(txt, col = @maxlen)
      $log.debug "inside wrap text for :#{txt}"
      txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,
               "\\1\\3\n") 
    end
    def remove_all
      @list = []
    end
    ## 
    # trying to wrap and insert
    def insert off0, data
      if data.length > @maxlen
        data = wrap_text data
      #  $log.debug "after wrap text done :#{data}"
        data = data.split("\n")
         data[-1] << "\r" #XXXX
      else
        data << "\r" if data[-1,1] != "\r" #XXXX
      end
      data.each do |row|
        @list.insert off0, row
        off0 += 1
      end
      #$log.debug " AFTER INSERT: #{@list}"
    end
    ##
    # wraps line sent in if longer than maxlen
    # Typically a line is sent in. We wrap and put a hard return at end.
    def << data
      if data.length > @maxlen
        $log.debug "wrapped append for #{data}"
        data = wrap_text data
        $log.debug "after wrap text for :#{data}"
        data = data.split("\n")
        # 2009-01-01 22:24 the \n was needed so we would put a space at time of writing.
        # we need a soft return so a space can be added when pushing down.
        # commented off 2008-12-28 21:59 
        #data.each {|line| @list << line+"\n"}
        data.each {|line| @list << line}
         @list[-1] << "\r" #XXXX
      else
        $log.debug "normal append for #{data}"
        data << "\r" if data[-1,1] != "\r" #XXXX
        @list << data
      end
      goto_end if @auto_scroll # to test out.
      self
    end
    def wrap_para line=@prow
      line ||= 0
      l=[]
      while true
        if @list[line].nil? or @list[line]=="" or @list[line]==13 #"\r"
          break
        end
        $log.debug "lastchar #{@list[line][-1]}, appending: #{@list[line]}]"
        t =  @list[line]
        l << t.strip
        @list.delete_at line
        break if t[-1]==13 # "\r"
    #    line += 1
      end
      str=l.join(" ")
      $log.debug " sending insert : #{str}."
      insert line, str
    end
    ##
    # private
    def print_borders
      window = @form.window
      color = $datacolor
      window.print_border @row, @col, @height, @width, color
      print_title
=begin
      hline = "+%s+" % [ "-"*(width-((1)*2)) ]
      hline2 = "|%s|" % [ " "*(width-((1)*2)) ]
      window.printstring( row=startrow, col=startcol, hline, color)
      print_title
      (startrow+1).upto(startrow+height-1) do |row|
        window.printstring(row, col=startcol, hline2, color)
      end
      window.printstring(startrow+height, col=startcol, hline, color)
=end
  
    end
    # private
    def print_title
      @form.window.printstring( @row, @col+(@width-@title.length)/2, @title, $datacolor, @title_attrib) unless @title.nil?
    end
    # text_area print footer
    def print_foot
      @footer_attrib ||= Ncurses::A_REVERSE
      footer = "R: #{@prow+1}, C: #{@curpos}, #{@list.length} lines  "
      @form.window.printstring( @row + @height, @col+2, footer, $datacolor, @footer_attrib) 
    end
    ### FOR scrollable ###
    def get_content
      @list
    end
    def get_window
      @form.window
    end
    ### FOR scrollable ###
    def repaint # textarea
      paint
      print_foot if @print_footer
    end
    def getvalue
      @list
    end
    # textarea
    
    def handle_key ch
      @buffer = @list[@prow]
      if @buffer.nil? and @list.length == 0
        @list << "\n" # changed space to newline so wrapping puts a line.
        @buffer = @list[@prow]
      end
      return if @buffer.nil?
      $log.debug "TA: before: curpos #{@curpos} blen: #{@buffer.length}"
      # on any line if the cursor is ahead of buffer length, ensure its on last position
      # what if the buffer is somehow gt maxlen ??
      if @curpos > @buffer.length
        addcol(@buffer.length-@curpos)+1
        @curpos = @buffer.length
      end
      $log.debug "TA: after : curpos #{@curpos} blen: #{@buffer.length}, w: #{@width} max #{@maxlen}"
      pre_key
      case ch
      when ?\C-n.getbyte(0)
        scroll_forward
      when ?\C-p.getbyte(0)
        scroll_backward
      when ?\C-[.getbyte(0)
        goto_start #cursor_start of buffer
      when ?\C-].getbyte(0)
        goto_end # cursor_end of buffer
      when KEY_UP
        #select_prev_row
        ret = up
      when KEY_DOWN
        ret = down
      when KEY_ENTER, 10, 13
        insert_break
      when KEY_LEFT
        cursor_backward
      when KEY_RIGHT
        cursor_forward
      when KEY_BACKSPACE, 127
        if @editable   # checking here means that i can programmatically bypass!!
          delete_prev_char 
          #fire_handler :CHANGE, self  # 2008-12-22 15:23 
        end
      when 330, ?\C-d.getbyte(0) # delete char
        if @editable
          delete_curr_char 
          #fire_handler :CHANGE, self  # 2008-12-22 15:23 
        end
      when ?\C-k.getbyte(0) # delete till eol
        if @editable
          if @buffer == ""
            delete_line 
            #fire_handler :CHANGE, self  # 2008-12-22 15:23 
          else
            delete_eol 
            #fire_handler :CHANGE, self  # 2008-12-22 15:23 
          end
        end
      when ?\C-u.getbyte(0)
        undo_delete
      when ?\C-a.getbyte(0)
        cursor_bol
      when ?\C-e.getbyte(0)
        cursor_eol
        #set_form_col @buffer.length
      else
        #$log.debug(" textarea ch #{ch}")
        ret = putc ch
        return ret if ret == :UNHANDLED
      end
      post_key
      set_form_row
      set_form_col  # testing 2008-12-26 19:37 
    end
    def undo_delete
        # added 2008-11-27 12:43  paste delete buffer into insertion point
        @buffer.insert @curpos, @delete_buffer unless @delete_buffer.nil?
        fire_handler :CHANGE, InputDataEvent.new(@curpos,@curpos+@delete_buffer.length, self, :INSERT, @prow, @delete_buffer)     #  2008-12-24 18:34 
    end
    def insert_break
      return -1 unless @editable
      # insert a blank row and append rest of this line to cursor
      $log.debug "ENTER PRESSED at  #{@curpos}, on row #{@prow}"
      @delete_buffer = (delete_eol || "")
      @list[@prow] << "\r"
      $log.debug "DELETE BUFFER #{@delete_buffer}" 
      @list.insert @prow+1, @delete_buffer 
      @curpos = 0
      down
      @form.col = @orig_col + @col_offset
      #addrowcol 1,0
      @form.row = @row + 1 + @winrow
      #fire_handler :CHANGE, self  # 2008-12-09 14:56 
      fire_handler :CHANGE, InputDataEvent.new(@curpos,@curpos+@delete_buffer.length, self, :INSERT, @prow, @delete_buffer)     #  2008-12-24 18:34 
    end
    # puts cursor on correct row.
    def set_form_row
      @form.row = @row + 1 + @winrow
    end
    # set cursor on correct column
    def set_form_col col1=@curpos
      @curpos = col1
      cursor_bounds_check
      @form.col = @orig_col + @col_offset + @curpos
      $log.debug "sfc: #{@orig_col}, #{@col_offset}. #{@curpos}. "
    end
    def cursor_bounds_check
      max = buffer_len()
      @curpos = max if @curpos > max # check 2008-12-27 00:02 
    end
    def buffer_len
      @list[@prow].nil? ? 0 : @list[@prow].chomp().length  
    end
    def do_current_row # :yields current row
      yield @list[@prow]
      @buffer = @list[@prow]
    end
    def delete_eol
      return -1 unless @editable
      pos = @curpos-1
      @delete_buffer = @buffer[@curpos..-1]
      # if pos is 0, pos-1 becomes -1, end of line!
      @list[@prow] = pos == -1 ? "" : @buffer[0..pos]
      $log.debug "delete EOL :pos=#{pos}, #{@delete_buffer}: row: #{@list[@prow]}:"
      @buffer = @list[@prow]
      cursor_backward if @curpos > 0 # now cursor back goes up to prev line
      #fire_handler :CHANGE, self  # 2008-12-09 14:56 
      fire_handler :CHANGE, InputDataEvent.new(@curpos,@curpos+@delete_buffer.length, self, :DELETE, @prow, @delete_buffer)     #  2008-12-24 18:34 
      return @delete_buffer
    end
    def cursor_forward num=1
      $log.debug "next char cp #{@curpos}, #{@buffer.length}. wi: #{@width}"
      #if @curpos < @width and @curpos < @maxlen-1 # else it will do out of box
      if @curpos < buffer_len()
        @curpos += 1
        addcol 1
      else # trying this out 2008-12-26 20:18 
        @curpos = 0
        down
      end
      cursor_bounds_check
    end
    def addcol num
      @form.addcol num
    end
    def addrowcol row,col
    @form.addrowcol row, col
  end
  def cursor_backward
    if @curpos > 0
      @curpos -= 1
      addcol -1
    else # trying this out 2008-12-26 20:18 
      ret = up
      cursor_eol if ret != -1
    end
  end
  def delete_line line=@prow
    return -1 unless @editable
    $log.debug "called delete line"
    @delete_buffer = @list.delete_at line
    @buffer = @list[@prow]
    if @buffer.nil?
      up
      @form.row = @row + 1 + @winrow
    end
    #fire_handler :CHANGE, self  # 2008-12-09 14:56 
    fire_handler :CHANGE, InputDataEvent.new(@curpos,@curpos+@delete_buffer.length, self, :DELETE, @prow, @delete_buffer)     #  2008-12-24 18:34 
  end
    def delete_curr_char num=1
      return -1 unless @editable
      num.times do
        delete_at
        set_modified 
      end
    end
    def delete_prev_char num=1
      return -1 if !@editable 
      num.times do
      if @curpos <= 0
        join_to_prev_line
        return
      end
      @curpos -= 1 if @curpos > 0
      delete_at
      set_modified 
      addcol -1
      end
    end
    # private
    # when backspace pressed in position zero if the previous line is filled we may have to bring 
    # down the last word and join, rather than go up
    def join_to_prev_line
      return -1 unless @editable
      return if @prow == 0
      oldcurpos = @curpos
      oldprow = @prow
      prev = @list[@prow-1].chomp
      prevlen = prev.length
      # 2008-12-26 21:37 delete previous line if nothing there. This moves entire buffer up.
      if prevlen == 0
        delete_line @prow-1
        up
        return
      end
      space_left = @maxlen - prev.length
      # BUG. carry full words up, or if no space then bring down last word of prev lien and join with first
      carry_up = words_in_length @buffer, space_left #@buffer[0..space_left] # XXX
      if carry_up.nil?
        # carry down last word
        prev_wd = remove_last_word @prow-1
        @buffer.insert 0, prev_wd
        @curpos = prev_wd.length
        $log.debug " carry up nil! prev_wd (#{prev_wd}) len:#{prev_wd.length}"
        fire_handler :CHANGE, InputDataEvent.new(0,prev_wd.length, self, :INSERT, oldprow, prev_wd)     #  2008-12-26 23:07 
      else
        $log.debug " carrying up #{carry_up.length} #{carry_up}, space: #{space_left}"
        @list[@prow-1]=prev + carry_up
        space_left2 = @buffer[(carry_up.length+1)..-1]
        @list[@prow]=space_left2 #if !space_left2.nil?
        @list[@prow] ||= ""
        up
        addrowcol -1,0
        @curpos = prevlen
        fire_handler :CHANGE, InputDataEvent.new(oldcurpos,carry_up.length, self, :DELETE, oldprow, carry_up)     #  2008-12-24 18:34 
        fire_handler :CHANGE, InputDataEvent.new(prevlen,carry_up.length, self, :INSERT, oldprow-1, carry_up)     #  2008-12-24 18:34 
      end
      @form.col = @orig_col + @col_offset + @curpos

#     $log.debug "carry up: nil" if carry_up.nil?
#     $log.debug "listrow nil " if @list[@prow].nil?
#     $log.debug "carry up: #{carry_up} prow:#{@list[@prow]}"
    end
    ##
    # return as many words as fit into len for carrying up..
    # actually there is a case of when the next char (len+1) is a white space or word boundary. XXX
    def words_in_length buff, len
      return nil if len == 0
      str = buff[0..len]
      ix = str.rindex(/\s/)
      $log.debug " str #{str} len #{len} ix #{ix} , buff #{buff}~"
      return nil if ix.nil?
      ix = ix > 0 ? ix - 1 : ix
      $log.debug " str[]:#{str[0..ix]}~ len #{len} ix #{ix} , buff #{buff}~"
      return str[0..ix]
    end
    # push the last word from given line to next
    # I have modified it to push all words that are exceeding maxlen.
    # This was needed for if i push 10 chars to next line, and the last word is less then the line will 
    # exceed. So i must push as many words as exceed length.
    def push_last_word lineno=@prow
      #lastspace = @buffer.rindex(" ")
      #lastspace = @list[lineno].rindex(/ \w/)
      line = @list[lineno]
      line = @list[lineno][0..@maxlen+1] if line.length > @maxlen
      lastspace = line.rindex(/ \w/)
      $log.debug " PUSH:2 #{lastspace},#{line},"
      if !lastspace.nil?
        lastchars = @list[lineno][lastspace+1..-1]
        @list[lineno] = @list[lineno][0..lastspace]
        $log.debug "PUSH_LAST:ls:#{lastspace},lw:#{lastchars},lc:#{lastchars[-1]},:#{@list[lineno]}$"
        if lastchars[-1,1] == "\r" or @list[lineno+1].nil?
          # open a new line and keep the 10 at the end.
          append_row lineno, lastchars
        else
          # check for soft tab \n - NO EVEN THIS LOGIC IS WRONG.
          #if lastchars[-1,1] == "\n"
          if lastchars[-1,1] != ' ' and @list[lineno+1][0,1] !=' '
            #@list[lineno+1].insert 0, lastchars + ' '
            insert_wrap lineno+1, 0, lastchars + ' '
          else
            #@list[lineno+1].insert 0, lastchars 
            insert_wrap lineno+1, 0, lastchars 
          end
        end
        return lastchars, lastspace
      end
      return nil
    end
    ##
    # this attempts to recursively insert into a row, seeing that any stuff exceeding is pushed down further.
    # Yes, it should check for a para end and insert. Currently it could add to next para.
    def insert_wrap lineno, pos, lastchars
      @list[lineno].insert pos, lastchars 
      len = @list[lineno].length 
      if len > @maxlen
          push_last_word lineno #- sometime i may push down 10 chars but the last word is less
        end
    end
    ## 
    # add one char. careful, i shoved a string in yesterday.
      def putch char
        @buffer ||= @list[@prow]
        return -1 if !@editable #or @buffer.length >= @maxlen
      if @chars_allowed != nil
        return if char.match(@chars_allowed).nil?
      end
      raise "putch expects only one char" if char.length != 1
      oldcurpos = @curpos
      $log.debug "putch : pr:#{@prow}, cp:#{@curpos}, char:#{char}, lc:#{@buffer[-1]}, buf:(#{@buffer})"
      @buffer.insert(@curpos, char)
      @curpos += 1 
      $log.debug "putch INS: cp:#{@curpos}, max:#{@maxlen}, buf:(#{@buffer.length})"
      if @curpos-1 > @maxlen or @buffer.length()-1 > @maxlen
        lastchars, lastspace = push_last_word @prow
        #$log.debug "last sapce #{lastspace}, lastchars:#{lastchars},lc:#{lastchars[-1]}, #{@list[@prow]} "
        ## wrap on word XX If last char is 10 then insert line
        @buffer = @list[@prow]
        if @curpos-1 > @maxlen  or @curpos-1 > @buffer.length()-1
          ret = down 
          # keep the cursor in the same position in the string that was pushed down.
          @curpos = oldcurpos - lastspace  #lastchars.length # 0
        end
      end
      set_form_row
      @buffer = @list[@prow]
      set_form_col
      @modified = true
      #fire_handler :CHANGE, self  # 2008-12-09 14:56 
      fire_handler :CHANGE, InputDataEvent.new(oldcurpos,@curpos, self, :INSERT, @prow, char)     #  2008-12-24 18:34 
      0
    end
    def append_row lineno=@prow, chars=""
        $log.debug "append row sapce:#{chars}."
      @list.insert lineno+1, chars
    end
    ##
    # removes and returns last word in given line number, or nil if no whitespace
    def remove_last_word lineno
      @list[lineno].chomp!
      line=@list[lineno]
      lastspace = line.rindex(" ")
      if !lastspace.nil?
        lastchars = line[lastspace+1..-1]
        @list[lineno].slice!(lastspace..-1)
        $log.debug " remove_last: lastspace #{lastspace},#{lastchars},#{@list[lineno]}"
        fire_handler :CHANGE, InputDataEvent.new(lastspace,lastchars.length, self, :DELETE, lineno, lastchars)     #  2008-12-26 23:06 
        return lastchars
      end
      return nil
    end

    def putc c
      if c >= 32 and c <= 126
        ret = putch c.chr
        if ret == 0
        # addcol 1
          set_modified 
          return 0
        end
      end
      return :UNHANDLED
    end
    # DELETE func
    def delete_at index=@curpos
      return -1 if !@editable 
      $log.debug "dele : #{@prow} #{@buffer} #{index}"
      char = @buffer.slice!(@curpos,1)  # changed added ,1 and take char for event
      # if no newline at end of this then bring up prev character/s till maxlen
      # NO WE DON'T DO THIS ANYLONGER 2008-12-26 21:09 lets see
=begin
      if @buffer[-1,1]!="\r"
        @buffer[-1]=" " if @buffer[-1,1]=="\n"
        if !next_line.nil? and next_line.length > 0
          move_chars_up
        end
      end
=end
      #@modified = true 2008-12-22 15:31 
      set_modified true
      #fire_handler :CHANGE, self  # 2008-12-09 14:56 
      fire_handler :CHANGE, InputDataEvent.new(@curpos,@curpos, self, :DELETE, @prow, char)     #  2008-12-24 18:34 
    end
    # move up one char from next row to current, used when deleting in a line
    # should not be called if line ends in "\r"
    def move_char_up
      @list[@prow] << @list[@prow+1].slice!(0)
      delete_line(@prow+1) if next_line().length==0
    end
    # tries to move up as many as possible
    # should not be called if line ends in "\r"
    def move_chars_up
      oldprow = @prow
      oldcurpos = @curpos
      space_left = @maxlen - @buffer.length
      can_move = [space_left, next_line.length].min
      carry_up =  @list[@prow+1].slice!(0, can_move)
      @list[@prow] << carry_up
      delete_line(@prow+1) if next_line().length==0
      fire_handler :CHANGE, InputDataEvent.new(oldcurpos,oldcurpos+can_move, self, :INSERT, oldprow, carry_up)     #  2008-12-24 18:34 
    end
    ## returns next line, does not move to it,
    def next_line
      @list[@prow+1]
    end
    def current_line
      @list[@prow]
    end
    def do_relative_row num
      yield @list[@prow+num] 
    end
    def set_modified tf=true
      @modified = tf
      @form.modified = true if tf
    end
    def cursor_eol
      $log.error "ERROR !!! bufferlen gt maxlen #{@buffer.length}, #{@maxlen}" if @buffer.length > @maxlen
      set_form_col current_line().chomp().length()-1
    end
    def cursor_bol
      set_form_col 0
    end
    def to_s
      l = getvalue
      str = ""
      old = " "
      l.each_with_index do |line, i|
        tmp = line.gsub("\n","")
        tmp.gsub!("\r", "\n")
        if old[-1,1] !~ /\s/ and tmp[0,1] !~ /\s/
          str << " "
        end
        str << tmp
        old = tmp
      end
      str
    end
  end # class textarea
  ##
  # A viewable read only box. Can scroll. 
  # Intention is to be able to change content dynamically - the entire list.
  # Use set_content to set content, or just update the list attrib
  # TODO - 
  #      - searching, goto line - DONE
  class OldTextView < Widget
    include Scrollable
    dsl_accessor :height  # height of viewport
    dsl_accessor :title   # set this on top
    dsl_accessor :title_attrib   # bold, reverse, normal
    dsl_accessor :footer_attrib   # bold, reverse, normal
    dsl_accessor :list    # the array of data to be sent by user
    dsl_accessor :maxlen    # max len to be displayed
    attr_reader :toprow    # the toprow in the view (offsets are 0)
    attr_reader :prow     # the row on which cursor/focus is
    attr_reader :winrow   # the row in the viewport/window
    dsl_accessor :print_footer

    def initialize form, config={}, &block
      @focusable = true
      @editable = false
      @left_margin = 1
      @row = 0
      @col = 0
      @show_focus = false  # don't highlight row under focus
      @list = []
      super
      @row_offset = @col_offset = 1
      @orig_col = @col
      # this does result in a blank line if we insert after creating. That's required at 
      # present if we wish to only insert
      @scrollatrow = @height-2
      @content_rows = @list.length
      @win = @form.window
      init_scrollable
      print_borders
      @maxlen ||= @width-2
    end
    ## 
    # send in a list
    # e.g.         set_content File.open("README.txt","r").readlines
    #
    def set_content list
      @list = list
    end
    ## display this row on top
    def top_row(*val)
      if val.empty?
        @toprow
      else
        @toprow = val[0] || 0
        @prow = val[0] || 0
      end
    end
    ## ---- for listscrollable ---- ##
    def scrollatrow
      @height - 2
    end
    def row_count
      @list.length
    end
    ##
    # returns row of first match of given regex (or nil if not found)
    def find_first_match regex
      @list.each_with_index do |row, ix|
        return ix if !row.match(regex).nil?
      end
      return nil
    end
    def rowcol
      #$log.debug "textarea rowcol : #{@row+@row_offset+@winrow}, #{@col+@col_offset}"
      return @row+@row_offset+@winrow, @col+@col_offset
    end
    def wrap_text(txt, col = @maxlen)
      $log.debug "inside wrap text for :#{txt}"
      txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,
               "\\1\\3\n") 
    end
    def print_borders
      window = @form.window
      color = $datacolor
      window.print_border @row, @col, @height, @width, color
      print_title
=begin
      hline = "+%s+" % [ "-"*(width-((1)*2)) ]
      hline2 = "|%s|" % [ " "*(width-((1)*2)) ]
      window.printstring(row=startrow, col=startcol, hline, color)
      print_title
      (startrow+1).upto(startrow+height-1) do |row|
        window.printstring( row, col=startcol, hline2, color)
      end
      window.printstring( startrow+height, col=startcol, hline, color)
=end
  
    end
    def print_title
      @form.window.printstring( @row, @col+(@width-@title.length)/2, @title, $datacolor, @title_attrib) unless @title.nil?
    end
    def print_foot
      @footer_attrib ||= Ncurses::A_REVERSE
      footer = "R: #{@prow+1}, C: #{@curpos}, #{@list.length} lines  "
      @form.window.printstring( @row + @height, @col+2, footer, $datacolor, @footer_attrib) 
    end
    ### FOR scrollable ###
    def get_content
      @list
    end
    def get_window
      @form.window
    end
    ### FOR scrollable ###
    def repaint # textview
      paint
      print_foot if @print_footer
    end
    def getvalue
      @list
    end
    # textview
    # [ ] scroll left right DONE
    def handle_key ch
      @buffer = @list[@prow]
      if @buffer.nil? and @list.length == 0
        @list << "\r"
        @buffer = @list[@prow]
      end
      return if @buffer.nil?
      $log.debug " before: curpos #{@curpos} blen: #{@buffer.length}"
      if @curpos > @buffer.length
        addcol(@buffer.length-@curpos)+1
        @curpos = @buffer.length
      end
      $log.debug "TV after loop : curpos #{@curpos} blen: #{@buffer.length}"
      pre_key
      case ch
      when ?\C-n.getbyte(0)
        scroll_forward
      when ?\C-p.getbyte(0)
        scroll_backward
      when ?0.getbyte(0), ?\C-[.getbyte(0)
        goto_start #start of buffer # cursor_start
      when ?\C-].getbyte(0)
        goto_end # end / bottom cursor_end
      when KEY_UP
        #select_prev_row
        ret = up
        #addrowcol -1,0 if ret != -1 or @winrow != @oldwinrow                 # positions the cursor up 
        @form.row = @row + 1 + @winrow
      when KEY_DOWN
        ret = down
        @form.row = @row + 1 + @winrow
      when KEY_LEFT
        cursor_backward
      when KEY_RIGHT
        cursor_forward
      when KEY_BACKSPACE, 127
        cursor_backward
      when 330
        cursor_backward
      when ?\C-a.getbyte(0)
        # take care of data that exceeds maxlen by scrolling and placing cursor at start
        set_form_col 0
        @pcol = 0
      when ?\C-e.getbyte(0)
        # take care of data that exceeds maxlen by scrolling and placing cursor at end
        blen = @buffer.rstrip.length
        if blen < @maxlen
          set_form_col blen
        else
          @pcol = blen-@maxlen
          set_form_col @maxlen-1
        end
      else
        $log.debug("TEXTVIEW XXX ch #{ch}")
        return :UNHANDLED
      end
      post_key
      # XXX 2008-11-27 13:57 trying out
      set_form_row
    end
    # puts cursor on correct row.
    def set_form_row
      @form.row = @row + 1 + @winrow
    end
    # set cursor on correct column tview
    def set_form_col col=@curpos
      @curpos = col
      @form.col = @orig_col + @col_offset + @curpos
    end
    def cursor_forward
      if @curpos < @width and @curpos < @maxlen-1 # else it will do out of box
        @curpos += 1
        addcol 1
      else
        # XXX 2008-11-26 23:03 trying out
        @pcol += 1 if @pcol <= @buffer.length
      end
    end
    def addcol num
      @form.addcol num
    end
    def addrowcol row,col
      @form.addrowcol row, col
    end
    def cursor_backward
      if @curpos > 0
        @curpos -= 1
        addcol -1
      elsif @pcol > 0 # XXX added 2008-11-26 23:05 
        @pcol -= 1   
      end
    end
    def next_line
      @list[@prow+1]
    end
    def do_relative_row num
      yield @list[@prow+num] 
    end
  end # class textview
end # modul
