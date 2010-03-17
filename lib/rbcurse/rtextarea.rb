=begin
  * Name: TextArea
  * Description   Editable text area
  * Author: rkumar (arunachalesha)
   2009-12-26 14:43 buffered version of rtextarea.rb. See BUFFERED
  * major change: 2010-02-12 13:34  simplifying the buffer stuff.
  * see FIXME of textview for some common issues to look at.
  * removed many edit functions to listeditable - 2010-03-12 10:16 
  
Todo: 
  * shoud we store path, so a save can be done
  --------
  * Date: 2008-11-14 23:43 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/listscrollable'
require 'rbcurse/rinputdataevent'
require 'rbcurse/listeditable'

include Ncurses
include RubyCurses
module RubyCurses
  extend self

  ## a multiline text editing widget
  # TODO - giving data to user - adding newlines, and withog adding.
  #  - respect newlines for incoming data
  #  we need a set_text method, passing nil or blank clears
  #  current way is not really good. remove_all sucks.
  #   TODO don't set maxlen if nil. compute it as a local in methods. Else splitpane will not
  #   work correctly.
  class TextArea < Widget
    include ListScrollable
    include ListEditable
    dsl_accessor :title
    dsl_accessor :title_attrib   # bold, reverse, normal
    dsl_accessor :footer_attrib   # bold, reverse, normal added 2009-12-26 18:25 was this missing or delib
    dsl_accessor :list    # the array of data to be sent by user
    dsl_accessor :maxlen    # max display length of a row/line 
    attr_reader :toprow
    dsl_accessor :auto_scroll # boolean, keeps view at end as data is inserted.
    dsl_accessor :print_footer
    dsl_accessor :editable          # allow editing
    dsl_accessor :suppress_borders # added 2010-02-12 12:21 values true or false
    attr_accessor :overwrite_mode # boolean: insert or overwrite, default false.

    def initialize form = nil, config={}, &block
      @focusable = true
      @editable = true
      @row = 0
      @col = 0
      @curpos = 0
      @list = []
      super
      @row_offset = @col_offset = 1 # for cursor display on first entry, so not positioned on border
      @orig_col = @col
      # this does result in a blank line if we insert after creating. That's required at 
      # present if we wish to only insert
      if @list.empty?
      #  @list << "\r"   # removed this on 2009-02-15 17:25 lets see how it goes
      end
     # @scrollatrow = @height-2
      @content_rows = @list.length
      #@win = @form.window
      @win = @graphic # 2009-12-26 14:54 BUFFERED  replace form.window with graphic
    #  init_scrollable
      #print_borders
      # 2010-01-10 19:35 compute locally if not set
      #@maxlen ||= @width-2
      install_keys
      init_vars
    end
    def init_vars
      @repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41 
      @toprow = @current_index = @pcol = 0
      @repaint_all=true 
      ## 2010-02-12 12:20 RFED16 taking care if no border requested
      @suppress_borders ||= false
      @row_offset = @col_offset = 0 if @suppress_borders == true
      # added 2010-02-11 15:11 RFED16 so we don't need a form.
      @win_left = 0
      @win_top = 0
      @longest_line = 0
      bind_key(?\M-w, :kill_ring_save)
      bind_key(?\C-y, :yank)
      bind_key(?\M-y, :yank_pop)
      bind_key(?\M-\C-w, :append_next_kill)
      bind_key(?\M-d, :delete_word)
      bind_key(?\M-f, :forward_word)
    end
    def rowcol
    #  $log.debug "textarea rowcol : #{@row+@row_offset+@winrow}, #{@col+@col_offset}"
      return @row+@row_offset, @col+@col_offset
    end
    ##
    # this avoids wrapping. Better to use the <<.
    def Oinsert off0, *data
      @list.insert off0, *data
      # fire_handler :CHANGE, self  # 2008-12-09 14:56  NOT SURE
    end
    # private
    def wrap_text(txt, col = @maxlen)
       col ||= @width - 2
      #$log.debug "inside wrap text for :#{txt}"
      txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,
               "\\1\\3\n") 
    end
    ## 
    # trying to wrap and insert
    def insert off0, data
       _maxlen = @maxlen || @width - 2
      if data.length > _maxlen
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
    # wraps line sent in if longer than _maxlen
    # Typically a line is sent in. We wrap and put a hard return at end.
    def << data
      # if width if nil, either set it, or add this to a container that sets it before calling this method
      _maxlen = @maxlen || @width - 2
      if data.length > _maxlen
        #$log.debug "wrapped append for #{data}"
        data = wrap_text data
        #$log.debug "after wrap text for :#{data}"
        data = data.split("\n")
        # 2009-01-01 22:24 the \n was needed so we would put a space at time of writing.
        # we need a soft return so a space can be added when pushing down.
        # commented off 2008-12-28 21:59 
        #data.each {|line| @list << line+"\n"}
        data.each {|line| @list << line}
         @list[-1] << "\r" #XXXX
      else
        #$log.debug "normal append for #{data}"
        data << "\r" if data[-1,1] != "\r" #XXXX
        @list << data
      end
      set_modified  # added 2009-03-07 18:29 
      goto_end if @auto_scroll 
      self
    end
    def wrap_para line=@current_index
      line ||= 0
      l=[]
      while true
        if @list[line].nil? or @list[line]=="" or @list[line]==13 #"\r"
          break
        end
        #$log.debug "lastchar #{@list[line][-1]}, appending: #{@list[line]}]"
        t =  @list[line]
        l << t.strip
        @list.delete_at line
        break if t[-1]==13 # "\r"
    #    line += 1
      end
      str=l.join(" ")
      #$log.debug " sending insert : #{str}."
      insert line, str
    end
    ##
    # private
    def print_borders
      window = @graphic # 2009-12-26 14:54 BUFFERED
      color = $datacolor
      #window.print_border @row, @col, @height, @width, color
      ## NOTE: If it bombs in next line, either no form passed
      ##+ or you using this embedded and need to set should_create_buffer true when
      ##+ creating. See examples/testscrollta.rb.
      window.print_border @row, @col, @height-1, @width, color
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
      @graphic.printstring( @row, @col+(@width-@title.length)/2, @title, $datacolor, @title_attrib) unless @title.nil?
    end
    # text_area print footer
    def print_foot
      @footer_attrib ||= Ncurses::A_REVERSE
      footer = "R: #{@current_index+1}, C: #{@curpos}, #{@list.length} lines  "
      #$log.debug " print_foot calling printstring with #{@row} + #{@height} -1, #{@col}+2"
      # changed 2010-01-02 19:31 BUFFERED we were exceeding 1
      #@graphic.printstring( @row + @height, @col+2, footer, $datacolor, @footer_attrib) 
      @graphic.printstring( @row + @height-1, @col+2, footer, $datacolor, @footer_attrib) 
      @repaint_footer_required = false
    end
    ### FOR scrollable ###
    def get_content
      @list
    end
    def get_window
      @graphic
    end
    ### FOR scrollable ###
    def repaint # textarea
      if @screen_buffer.nil? and @should_create_buffer
        safe_create_buffer
        @screen_buffer.name = "Pad::TXTA_PAD_#{@name}"
        $log.debug " textarea creates pad #{@screen_buffer} #{@name}"
      end
      
      #return unless @repaint_required # 2010-02-12 19:08  TRYING - won't let footer print if only col move
      paint if @repaint_required
      print_foot if @print_footer && (@repaint_footer_required || @repaint_required)
      buffer_to_window # 2010-02-12 14:54 RFED16
    end
    def getvalue
      @list
    end
    # textarea
    
    def handle_key ch
      @current_key = ch # I need some funcs to know what key they were mapped to
      @buffer = @list[@current_index]
      if @buffer.nil? and @list.length == 0
        ## 2009-10-04 22:39 
        # what this newline does is , if we use << to append, data is appended
        # to second line
        @list << "\n" # changed space to newline so wrapping puts a line.
        @current_index = 0 ; ## added 2009-10-04 21:47 
        @buffer = @list[@current_index]
      end
      ## 2009-10-04 20:48  i think the next line was resulting in a hang if buffer nil
      # in sqlc on pressing Clear.
      # if buffer is nil and user wants to enter something -- added UNHANDLED
      return :UNHANDLED if @buffer.nil?
      $log.debug "TA: before: curpos #{@curpos} blen: #{@buffer.length}"
      # on any line if the cursor is ahead of buffer length, ensure its on last position
      # what if the buffer is somehow gt maxlen ??
      if @curpos > @buffer.length
        addcol(@buffer.length-@curpos)+1
        @curpos = @buffer.length
      end
      $log.debug "TA: after : curpos #{@curpos} blen: #{@buffer.length}, w: #{@width} max #{@maxlen}"
      #pre_key
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
        end
      when 330, ?\C-d.getbyte(0) # delete char
        if @editable
          delete_curr_char 
        end
      when ?\C-k.getbyte(0) # delete till eol
        # i'ved added curpos == 0 since emacs deletes a line if cursor is at 0
        # Earlier behavior was based on alpine which leaves a blank line
        if @editable
          #if @buffer == ""
          if @buffer.chomp == "" or @curpos == 0
            delete_line
          else
            delete_eol 
          end
        end
      #when ?\C-u.getbyte(0)
        ## since textareas are editable we use a control key to increase
        ## multiplier. Series is 4 16 64
        #@multiplier = (@multiplier == 0 ? 4 : @multiplier *= 4)
        #return 0
      when ?\C-_.getbyte(0) # changed from C-u so i can use C-u for multipliers
        if @undo_handler
          @undo_handler.undo
        else
          undo_delete
        end
      when ?\C-r.getbyte(0) # redo if UndoHandler installed
        return unless @undo_handler
        @undo_handler.redo
      when ?\C-a.getbyte(0)
        cursor_bol
      when ?\C-e.getbyte(0)
        cursor_eol
        #set_form_col @buffer.length
      #when @KEY_ASK_FIND_FORWARD
      #  ask_search_forward
      #when @KEY_ASK_FIND_BACKWARD
      #  ask_search_backward
      when @KEY_ASK_FIND
        ask_search
      when @KEY_FIND_MORE
        find_more
      #when @KEY_FIND_NEXT
      #  find_next
      #when @KEY_FIND_PREV
      #  find_prev
      else
        #$log.debug(" textarea ch #{ch}")
        ret = putc ch
        if ret == :UNHANDLED
          # check for bindings, these cannot override above keys since placed at end
          ret = process_key ch, self
          $log.debug "TA process_key #{ch} got ret #{ret} in #{@name} "
          return :UNHANDLED if ret == :UNHANDLED
        end
      end
      set_form_row
      set_form_col  # testing 2008-12-26 19:37 
      $multiplier = 0 # reset only if key handled
      return 0
    end
    # this is broken, delete_buffer could be a line or a string or array of lines
    def undo_delete
        # added 2008-11-27 12:43  paste delete buffer into insertion point
        return if @delete_buffer.nil?
        $log.warn "undo_delete is broken! perhaps cannot be used . textarea 347 "
        # FIXME - can be an array
        case @delete_buffer
        when Array
          # we need to unroll array, and it could be lines not just a string
          str = @delete_buffer.first
        else
          str = @delete_buffer
        end
        @buffer.insert @curpos, str 
        set_modified 
        fire_handler :CHANGE, InputDataEvent.new(@curpos,@curpos+@delete_buffer.length, self, :INSERT, @current_index, @delete_buffer)     #  2008-12-24 18:34 
    end
    # FIXME - fire event not correct, not undo'ing correctly, check row and also slash r append
    def insert_break
      return -1 unless @editable
      # insert a blank row and append rest of this line to cursor
      $log.debug "ENTER PRESSED at  #{@curpos}, on row #{@current_index}"
      @delete_buffer = (delete_eol || "")
      @list[@current_index] << "\r"
      $log.debug "DELETE BUFFER #{@delete_buffer}" 
      @list.insert @current_index+1, @delete_buffer 
      @curpos = 0
      down
      col = @orig_col + @col_offset
      setrowcol @row+1, col
      # FIXME maybe this should be insert line since line inserted, not just data, undo will delete it
      fire_handler :CHANGE, InputDataEvent.new(@curpos,@curpos+@delete_buffer.length, self, :INSERT_LINE, @current_index, @delete_buffer)     #  2008-12-24 18:34 
    end
    # set cursor on correct column
    def set_form_col col1=@curpos
      @curpos = col1
      @cols_panned ||= 0
      cursor_bounds_check
      
      ## added win_col on 2009-12-28 20:21 for embedded forms BUFFERED TRYING OUT
      win_col = 0 # 2010-02-07 23:19 new cursor stuff
      #col = win_col + @orig_col + @col_offset + @curpos
      #col = win_col + @orig_col + @col_offset + @curpos + @cols_panned
      # 2010-01-14 13:31 changed orig_col to col for embedded forms, splitpanes.
      col = win_col + @col + @col_offset + @curpos + @cols_panned
      $log.debug "sfc: wc:#{win_col}  col:#{@col}, coff:#{@col_offset}. cp:#{@curpos} colsp:#{@cols_panned} . "
      #@form.setrowcol @form.row, col   # added 2009-12-29 18:50 BUFFERED
      $log.debug " TA calling setformrow col nil, #{col} "
      setrowcol nil, col   # added 2009-12-29 18:50 BUFFERED
      @repaint_footer_required = true
    end
    def cursor_bounds_check
      max = buffer_len()
      @curpos = max if @curpos > max # check 2008-12-27 00:02 
    end
    def buffer_len
      @list[@current_index].nil? ? 0 : @list[@current_index].chomp().length  
    end
    def do_current_row # :yields current row
      yield @list[@current_index]
      @buffer = @list[@current_index]
    end
    ##
    # FIXME : if cursor at end of last line then forward takes cursor to start
    # of last line (same line), should stop there.
    def cursor_forward num=1
      #$log.debug "next char cp #{@curpos}, #{@buffer.length}. wi: #{@width}"
      #$log.debug "next char cp ll and ci #{@list.length}, #{@current_index}"
      #if @curpos < @width and @curpos < maxlen-1 # else it will do out of box
      return if at_eol? and at_last_line?
      repeatm { 
      if @curpos < buffer_len()
        @curpos += 1
        addcol 1
      else # trying this out 2008-12-26 20:18 
        @curpos = 0
        down 1 # if not then multipler will trigger there too
      end
      cursor_bounds_check
      }
    end
    ## added 2009-10-04 22:13 
    # returns whether cursor is at end of line
    def at_eol?
      if @curpos+1== @list[@current_index].length  
        return  true
      end
      return false
    end
    ## added 2009-10-04 22:13 
    # returns whether at last line (required so that forward does not go to start)
    def at_last_line?
      return true if @list.length == @current_index + 1
      return false
    end
    # FIXME : these 2 only require the footer to be repainted not everything
    # We should be able to manage that. We need a repaint_footer_required.
    # Setting repaint_required really slows performance when one presses the right arrow key
    # since a repaint is happenign repeatedly for each key.
    def addcol num
#     @repaint_required = true # added 2010-01-15 23:59, so that footer is updated, sucks!
      @repaint_footer_required = true # 2010-01-23 22:41 
      my_win = @form || @parent_component.form # 2010-02-12 12:51 
      my_win.addcol num
    end
    def addrowcol row,col
      #@repaint_required = true # added 2010-01-15 23:59 
      @repaint_footer_required = true # 2010-01-23 22:41 
      my_win = @form || @parent_component.form # 2010-02-12 12:51 
      my_win.addrowcol row, col
    end
    ## 2009-10-04 23:01 taken care that you can't go back at start of textarea
    # it was going onto border
  def cursor_backward
      #$log.debug "back char cp ll and ci #{@list.length}, #{@current_index}"
      #$log.debug "back char cb #{@curpos}, #{@buffer.length}. wi: #{@width}"
      return if @curpos == 0 and @current_index == 0 # added 2009-10-04 23:02 
      repeatm { 
        if @curpos > 0
          @curpos -= 1
          addcol -1
        else # trying this out 2008-12-26 20:18 
          ret = up
          cursor_eol if ret != -1
        end
      }
  end
    # private
    # when backspace pressed in position zero if the previous line is filled we may have to bring 
    # down the last word and join, rather than go up
    # FIXME : make logic simple. Append entire line to above line. Then go to maxlen if not a space,
    # reverse to find last space. Lop off all after space and replace this line with that balance.
    # UNDO and REDO has to work in this case too. FIXME bare in mind handlers when doing this
    def join_to_prev_line
      return -1 unless @editable
      return if @current_index == 0
      oldcurpos = @curpos
      oldprow = @current_index
      prev = @list[@current_index-1].chomp
      prevlen = prev.length
      # 2008-12-26 21:37 delete previous line if nothing there. This moves entire buffer up.
      if prevlen == 0
        delete_line @current_index-1
        up
        return
      end
      _maxlen = @maxlen || @width - 2
      space_left = _maxlen - prevlen
      # prev line is full exit
      return if space_left == 0

      # get last space, if none, return
      blank_found = @buffer.rindex(' ', space_left)
      return unless blank_found # no word in the space i can carry up.
      # get string for carrying up
      carry_up = @buffer[0..blank_found]
      result = @list[@current_index-1].chomp! # this has to be undone too.
      @list[@current_index-1] << carry_up
      #$log.debug "carry up: #{carry_up} prevrow:#{@list[@current_index -1]}"
      # remove from curr line
      @list[@current_index].slice!(0..carry_up.length-1)
      $log.debug "carry up: #{carry_up} currrow:#{@list[@current_index]}"
      #@list[@current_index] ||= ""
      up
      addrowcol -1,0
      @curpos = prevlen
      # if result not nil, then we need that to be recorded FIXME
      fire_handler :CHANGE, InputDataEvent.new(oldcurpos,oldcurpos+carry_up.length, self, :DELETE, oldprow, carry_up)
      fire_handler :CHANGE, InputDataEvent.new(prevlen,prevlen+carry_up.length, self, :INSERT, oldprow-1, carry_up)

      ## BUG. carry full words up, or if no space then bring down last word of prev lien and join with first
      #carry_up = words_in_length @buffer, space_left #@buffer[0..space_left] # XXX
      #if carry_up.nil?
        ## carry down last word
        #prev_wd = remove_last_word @current_index-1
        ## 2010-01-14 18:26 check added else crashing if C-h pressed with no data in line
        #if !prev_wd.nil?
           #@buffer.insert 0, prev_wd
           #@curpos = prev_wd.length
           #$log.debug " carry up nil! prev_wd (#{prev_wd}) len:#{prev_wd.length}"
           #fire_handler :CHANGE, InputDataEvent.new(0,prev_wd.length, self, :INSERT, oldprow, prev_wd)     #  2008-12-26 23:07 
        #end
      #else
        #$log.debug " carrying up #{carry_up.length} #{carry_up}, space: #{space_left}"
        #@list[@current_index-1]=prev + carry_up
        #space_left2 = @buffer[(carry_up.length+1)..-1]
        #@list[@current_index]=space_left2 #if !space_left2.nil?
        #@list[@current_index] ||= ""
        #up
        #addrowcol -1,0
        #@curpos = prevlen
        #fire_handler :CHANGE, InputDataEvent.new(oldcurpos,carry_up.length, self, :DELETE, oldprow, carry_up)     #  2008-12-24 18:34 
        #fire_handler :CHANGE, InputDataEvent.new(prevlen,carry_up.length, self, :INSERT, oldprow-1, carry_up)     #  2008-12-24 18:34 
      #end
      ## FIXME -- can;t have a naked for reference here.
      ##@form.col = @orig_col + @col_offset + @curpos
      col1 = @orig_col + @col_offset + @curpos
      setrowcol nil, col1 # 2010-02-12 13:09  RFED16

#     $log.debug "carry up: nil" if carry_up.nil?
#     $log.debug "listrow nil " if @list[@current_index].nil?
#     $log.debug "carry up: #{carry_up} prow:#{@list[@current_index]}"
    end
    # private
    # when backspace pressed in position zero if the previous line is filled we may have to bring 
    # down the last word and join, rather than go up
    # FIXME : make logic simple. Append entire line to above line. Then go to maxlen if not a space,
    # reverse to find last space. Lop off all after space and replace this line with that balance.
    # UNDO and REDO has to work in this case too. FIXME bare in mind handlers when doing this
    def old_join_to_prev_line
      return -1 unless @editable
      return if @current_index == 0
      oldcurpos = @curpos
      oldprow = @current_index
      prev = @list[@current_index-1].chomp
      prevlen = prev.length
      # 2008-12-26 21:37 delete previous line if nothing there. This moves entire buffer up.
      if prevlen == 0
        delete_line @current_index-1
        up
        return
      end
      _maxlen = @maxlen || @width - 2
      space_left = _maxlen - prev.length
      # BUG. carry full words up, or if no space then bring down last word of prev lien and join with first
      carry_up = words_in_length @buffer, space_left #@buffer[0..space_left] # XXX
      if carry_up.nil?
        # carry down last word
        prev_wd = remove_last_word @current_index-1
        # 2010-01-14 18:26 check added else crashing if C-h pressed with no data in line
        if !prev_wd.nil?
           @buffer.insert 0, prev_wd
           @curpos = prev_wd.length
           $log.debug " carry up nil! prev_wd (#{prev_wd}) len:#{prev_wd.length}"
           fire_handler :CHANGE, InputDataEvent.new(0,prev_wd.length, self, :INSERT, oldprow, prev_wd)     #  2008-12-26 23:07 
        end
      else
        $log.debug " carrying up #{carry_up.length} #{carry_up}, space: #{space_left}"
        @list[@current_index-1]=prev + carry_up
        space_left2 = @buffer[(carry_up.length+1)..-1]
        @list[@current_index]=space_left2 #if !space_left2.nil?
        @list[@current_index] ||= ""
        up
        addrowcol -1,0
        @curpos = prevlen
        fire_handler :CHANGE, InputDataEvent.new(oldcurpos,carry_up.length, self, :DELETE, oldprow, carry_up)     #  2008-12-24 18:34 
        fire_handler :CHANGE, InputDataEvent.new(prevlen,carry_up.length, self, :INSERT, oldprow-1, carry_up)     #  2008-12-24 18:34 
      end
      # FIXME -- can;t have a naked for reference here.
      #@form.col = @orig_col + @col_offset + @curpos
      col1 = @orig_col + @col_offset + @curpos
      setrowcol nil, col1 # 2010-02-12 13:09  RFED16

#     $log.debug "carry up: nil" if carry_up.nil?
#     $log.debug "listrow nil " if @list[@current_index].nil?
#     $log.debug "carry up: #{carry_up} prow:#{@list[@current_index]}"
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
    def push_last_word lineno=@current_index
       _maxlen = @maxlen || @width - 2
      #lastspace = @buffer.rindex(" ")
      #lastspace = @list[lineno].rindex(/ \w/)
      line = @list[lineno]
      line = @list[lineno][0.._maxlen+1] if line.length > _maxlen
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
       _maxlen = @maxlen || @width - 2
      @list[lineno].insert pos, lastchars 
      len = @list[lineno].length 
      if len > _maxlen
          push_last_word lineno #- sometime i may push down 10 chars but the last word is less
        end
    end
    ## 
    # add one char. careful, i shoved a string in yesterday.
    def putch char
       _maxlen = @maxlen || @width - 2
      @buffer ||= @list[@current_index]
      return -1 if !@editable #or @buffer.length >= _maxlen
      #if @chars_allowed != nil # remove useless functionality
        #return if char.match(@chars_allowed).nil?
      #end
      raise "putch expects only one char" if char.length != 1
      oldcurpos = @curpos
      #$log.debug "putch : pr:#{@current_index}, cp:#{@curpos}, char:#{char}, lc:#{@buffer[-1]}, buf:(#{@buffer})"
      if @overwrite_mode
        @buffer[@curpos] = char
      else
        @buffer.insert(@curpos, char)
      end
      @curpos += 1 
      #$log.debug "putch INS: cp:#{@curpos}, max:#{_maxlen}, buf:(#{@buffer.length})"
      if @curpos-1 > _maxlen or @buffer.length()-1 > _maxlen
        lastchars, lastspace = push_last_word @current_index
        #$log.debug "last sapce #{lastspace}, lastchars:#{lastchars},lc:#{lastchars[-1]}, #{@list[@current_index]} "
        ## wrap on word XX If last char is 10 then insert line
        @buffer = @list[@current_index]
        if @curpos-1 > _maxlen  or @curpos-1 > @buffer.length()-1
          ret = down 
          # keep the cursor in the same position in the string that was pushed down.
          @curpos = oldcurpos - lastspace  #lastchars.length # 0
        end
      end
      set_form_row
      @buffer = @list[@current_index]
      set_form_col
      @modified = true
      fire_handler :CHANGE, InputDataEvent.new(oldcurpos,@curpos, self, :INSERT, @current_index, char)     #  2008-12-24 18:34 
      @repaint_required = true
      0
    end
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
    # move up one char from next row to current, used when deleting in a line
    # should not be called if line ends in "\r"
    def move_char_up
      @list[@current_index] << @list[@current_index+1].slice!(0)
      delete_line(@current_index+1) if next_line().length==0
    end
    # tries to move up as many as possible
    # should not be called if line ends in "\r"
    def move_chars_up
      oldprow = @current_index
      oldcurpos = @curpos
       _maxlen = @maxlen || @width - 2
      space_left = _maxlen - @buffer.length
      can_move = [space_left, next_line.length].min
      carry_up =  @list[@current_index+1].slice!(0, can_move)
      @list[@current_index] << carry_up
      delete_line(@current_index+1) if next_line().length==0
      fire_handler :CHANGE, InputDataEvent.new(oldcurpos,oldcurpos+can_move, self, :INSERT, oldprow, carry_up)     #  2008-12-24 18:34 
    end
    ## returns next line, does not move to it,
    def next_line
      @list[@current_index+1]
    end
    def current_line
      @list[@current_index]
    end
    def do_relative_row num
      yield @list[@current_index+num] 
    end
    def set_modified tf=true
      @modified = tf
      @repaint_required = tf
      @repaint_footer_required = tf
      # 2010-01-14 22:45 putting a check for form, so not necessary to have form set when appending data
      @form.modified = true if tf and !@form.nil?
    end
    def cursor_eol
       _maxlen = @maxlen || @width - 2
      $log.error "ERROR !!! bufferlen gt _maxlen #{@buffer.length}, #{_maxlen}" if @buffer.length > _maxlen
      set_form_col current_line().chomp().length()-1
    end
    def cursor_bol
      set_form_col 0
    end
    #def to_s this was just annoying in debugs
    def get_text
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
    #alias :get_text :to_s
    ## ---- for listscrollable ---- ##
    def scrollatrow
      @height-3 # 2010-01-02 19:28 BUFFERED 
    end
    def row_count
      @list.size
    end
    def paint
      # not sure where to put this, once for all or repeat 2010-02-12 RFED16
      my_win = @form? @form.window : @target_window
      $log.warn "neither form not target window given!!! TA paint 751" unless my_win
      @win_left = my_win.left # unused remove TODO
      @win_top = my_win.top
      print_borders if (@suppress_borders == false && @repaint_all) # do this once only, unless everything changes
      rc = row_count
      _maxlen = @maxlen || @width-2 # TODO fix in other branches remove ||= 
      $log.debug " #{@name} textarea repaint width is #{@width}, height is #{@height} , maxlen #{_maxlen}/ #{@maxlen}, #{@graphic.name} "
      tm = get_content
      tr = @toprow
      acolor = get_color $datacolor
      h = scrollatrow()
      r,c = rowcol
      @longest_line = @width # _maxlen scroll uses width not maxlen
      $log.debug " TA:::: #{tr} , #{h}, r #{r} c #{c} "
      0.upto(h) do |hh|
        crow = tr+hh
        if crow < rc
            #focussed = @current_index == crow ? true : false 
            #selected = is_row_selected crow
          content = tm[crow].chomp rescue ""
            content.gsub!(/\t/, '  ') # don't display tab
            content.gsub!(/[^[:print:]]/, '')  # don't display non print characters
            if !content.nil? 
              if content.length > _maxlen # only show _maxlen
                @longest_line = content.length if content.length > @longest_line
                content = content[@pcol..@pcol+_maxlen-1] 
              else
                content = content[@pcol..-1]
              end
            end
            #renderer = get_default_cell_renderer_for_class content.class.to_s
            #renderer = cell_renderer()
            #renderer.repaint @form.window, r+hh, c+(colix*11), content, focussed, selected
            #renderer.repaint @form.window, r+hh, c, content, focussed, selected
            @graphic.printstring  r+hh, c, "%-*s" % [@width-2,content], acolor, @attr
            if @search_found_ix == tr+hh
              if !@find_offset.nil?
                @graphic.mvchgat(y=r+hh, x=c+@find_offset, @find_offset1-@find_offset, Ncurses::A_NORMAL, $reversecolor, nil)
              end
            end

        else
          # clear rows
            # TODO the spaces string can be stored once outside loop
          @graphic.printstring r+hh, c, " " * (@width-2), acolor,@attr
        end
      end
      show_caret_func

      @table_changed = false
      @repaint_required = false
      @repaint_footer_required = true # 2010-01-23 22:41 
      @buffer_modified = true # required by form to call buffer_to_screen
      @repaint_all = false # added 2010-01-14 for redrawing everything
    end
    def ask_search_forward
        regex =  get_string("Enter regex to search", 20, @last_regex||"")
        ix = _find_next regex, @current_index
        if ix.nil?
          alert("No matching data for: #{regex}")
        else
          set_focus_on(ix)
          set_form_col @find_offset
        end
    end
  end # class textarea
  ##
end # modul
