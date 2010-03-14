# Some methods for manipulating lists
# Different components may bind different keys to these
# Currently will be called by TextArea and the editable version
# of TextView (vieditable).
#
require 'rbcurse/rinputdataevent'
module ListEditable

    def remove_all
      @list = []
      set_modified  # added 2009-02-13 22:28 so repaints
    end
    # current behav is a mix of vim's D and C-k from alpine, i don;t know how i screwed it up like this
    # Should be:
    # 1. do not take cursor back by 1 (this is vims D behavior)
    # 2. retain EOL, we need to evaluate at undo
    # 3. if nothing coming in delete buffer then join next line here
    # 4. if line is blank, it will go to delete line (i think).
    # Earlier, a C-k at pos 0 would blank the line and not delete it (copied from alpine).
    # The next C-k would delete. emacs deletes if C-k at pos 0.
    def delete_eol
      return -1 unless @editable
      pos = @curpos -1 # retain from 0 till prev char
      @delete_buffer = @buffer[@curpos..-1]
      # currently eol is there in delete_buff often. Should i maintain it ? 2010-03-08 18:29 UNDO
      #@delete_buffer.chomp! # new 2010-03-08 18:29 UNDO - this worked but hope does not have othe impact

      # if pos is 0, pos-1 becomes -1, end of line!
      @list[@current_index] = pos == -1 ? "" : @buffer[0..pos]
      $log.debug "delete EOL :pos=#{pos}, #{@delete_buffer}: row: #{@list[@current_index]}:"
      @buffer = @list[@current_index]
      if @delete_buffer == ""
        $log.debug " TA: DELETE going to join next "
        join_next_line # pull next line in
      end
      oldcur = @curpos
      #x cursor_backward if @curpos > 0 #  this was vims behavior -- knoecked off
      #fire_handler :CHANGE, self  # 2008-12-09 14:56 
      fire_handler :CHANGE, InputDataEvent.new(oldcur,oldcur+@delete_buffer.length, self, :DELETE, @current_index, @delete_buffer)     #  2008-12-24 18:34 
      set_modified 
      return @delete_buffer
    end
    def join_next_line
      # return if last line  TODO
      buff = @list.delete_at(@current_index + 1)
      if buff
        $log.debug " TA: DELETE inside to join next #{buff}  "
        fire_handler :CHANGE, InputDataEvent.new(0,0+buff.length, self, :DELETE_LINE, @current_index+1, buff)  
        @buffer << buff
      end
    end
  # deletes given line or current
  # now fires DELETE_LINE so no guessing by undo manager
  def delete_line line=@current_index
    return -1 unless @editable
    if !$multiplier or $multiplier == 0 
      @delete_buffer = @list.delete_at line
    else
      @delete_buffer = @list.slice!(line, $multiplier)
    end
    $multiplier = 0
    add_to_kill_ring @delete_buffer
    @buffer = @list[@current_index]
    if @buffer.nil?
      up
      setrowcol @row + 1, nil # @form.col
    end
    # warning: delete buffer can now be an array
    fire_handler :CHANGE, InputDataEvent.new(@curpos,@curpos+@delete_buffer.length, self, :DELETE_LINE, line, @delete_buffer)     #  2008-12-24 18:34 
    set_modified 
  end
    def delete_curr_char num=($multiplier == 0 ? 1 : $multiplier)
      return -1 unless @editable
      delete_at @curpos, num # changed so only one event, and one undo
      set_modified 
      $multiplier = 0
    end
    # 
    # 2010-03-08 23:30 does not seem to be working well when backspacing at first char of line
    # FIXME should work as a unit, so one undo and one fire_handler, at least if on one line.
    def delete_prev_char num=($multiplier == 0 ? 1 : $multiplier)
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
      $multiplier = 0
    end
    # open a new line and add chars to it.
    # FIXME does not fire handler, thus won't undo
    def append_row lineno=@current_index, chars=""
        $log.debug "append row sapce:#{chars}."
      @list.insert lineno+1, chars
    end
    ##
    # delete character/s on current line
    def delete_at index=@curpos, howmany=1
      return -1 if !@editable 
      $log.debug "delete_at (characters) : #{@current_index} #{@buffer} #{index}"
      char = @buffer.slice!(@curpos,howmany)  # changed added ,1 and take char for event
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
      set_modified true
      fire_handler :CHANGE, InputDataEvent.new(@curpos,@curpos+howmany, self, :DELETE, @current_index, char)     #  2008-12-24 18:34 
    end
    def undo_handler(uh)
      @undo_handler = uh
    end
    ## THIS ONE SHOULD BE IN TEXTVIEW ALSO
    # saves current or n lines into kill ring, appending to earlier contents
    # Use yank (paste) or yank-pop to retrieve
    def kill_ring_save
      pointer = @current_index
      list = []
      repeatm {
        line =  @list[pointer] 
        list << line unless line.nil?
        pointer += 1
      }
      add_to_kill_ring list
    end
    ## THIS ONE SHOULD BE IN TEXTVIEW ALSO
    # add given line or lines to kill_ring
    def add_to_kill_ring list
      # directly referenceing kill_ring.  We need to OO it a bit, so we can change internals w'o breaking all.
      # FIXME
      if $append_next_kill
        # user requested this kill to be appened to last kill, so it can be yanked as one
        #$kill_ring.last << list
        last = $kill_ring.pop 
        case list
        when Array
          list.insert 0, last
          $kill_ring << list
        when String
          $kill_ring << [last, list]
        end
      else
        $kill_ring << list
      end
      $kill_ring_pointer = $kill_ring.size
      $append_next_kill = false
    end

    # pastes recent (last) entry of kill_ring.
    # This can be one or more lines. Please note that for us vimmer's yank means copy
    # but for emacsers it seems to mean paste. Aargh!!
    def yank where=@current_index
      return -1 if !@editable 
      return if $kill_ring.empty?
      row = $kill_ring.last
      index = where
      case row
      when Array
        #index = @current_index
        row.each{ |r|
          @list.insert index, r.dup
          index += 1
        }
        $kill_last_pop_size = row.size
      when String
        #@list[@current_index].insert row.dup
        #@list.insert @current_index, row.dup
        @list.insert index, row.dup
        $kill_last_pop_size = 1
      else
        raise "textarea yank got uncertain datatype from kill_ring  #{row.class} "
      end
      $kill_ring_pointer = $kill_ring.size - 1
      $kill_ring_index = @current_index # pops will replace data in this row, never an insert
      @repaint_required = true
      # XXX not firing anything here, so i can't undo. yet, i don't know whether a yank will
      # be followed by a yank-pop, in which case it will not be undone.
      # object row can be string or array - time to use INSERT_LINE so we are clear
      # row.length can be array's size or string length - beware
      fire_handler :CHANGE, InputDataEvent.new(0,row.length, self, :INSERT_LINE, @current_index, row)
    end

    # paste previous entries from kill ring
    # I am not totally clear on this, not being an emacs user. but seems you have to do C-y
    # once (yank) before you can do a yank pop. 
    def yank_pop
      return -1 if !@editable 
      return if $kill_ring.empty?
      mapped_key = @current_key # we are mapped to this
      # checking that user has done a yank on this row. We only replace on the given row, never
      # insert. But what if user edited after yank, Sheesh ! XXX
      if $kill_ring_index != @current_index
        Ncurses.beep
        return # error message required that user must yank first
      end
      # the real reason i put this into a loop is so that i can properly undo the
      # action later if required. I only need to store the final selection.
      # This also ensures the user doesn't wander off in between and come back.
      row = nil
      while true
        # remove lines from last replace, then insert
        index = @current_index
        $kill_last_pop_size.times {
          del = @list.delete_at index
        }
        row = $kill_ring[$kill_ring_pointer-$multiplier]
        $multiplier = 0
        index = @current_index
        case row
        when Array
          row.each{ |r|
            @list.insert index, r.dup
            index += 1
          }
          $kill_last_pop_size = row.size
        when String
          @list.insert index, row.dup
          $kill_last_pop_size = 1
        else
          raise "textarea yank_pop got uncertain datatype from kill_ring  #{row.class} "
        end

        $kill_ring_pointer -= 1
        if $kill_ring_pointer < 0
          # should be size, but that'll give an error. need to find a way!
          $kill_ring_pointer = $kill_ring.size - 1
        end
        @repaint_required = true
        my_win = @form || @parent_component.form # 2010-02-12 12:51 
        my_win.repaint
        ch = @graphic.getchar
        if ch != mapped_key
          @graphic.ungetch ch # seems to work fine
          return ch # XXX to be picked up by handle_key loop and processed
        end
      end
      # object row can be string or array - time to use INSERT_LINE so we are clear
      # row.length can be array's size or string length - beware
      fire_handler :CHANGE, InputDataEvent.new(0,row.length, self, :INSERT_LINE, @current_index, row)
      return 0
    end
    def append_next_kill
      $append_next_kill = true
    end
    # deletes count words on current line
    # Does not at this point go beyond the line
    def delete_word
      return -1 unless @editable
      $multiplier = 1 if !$multiplier or $multiplier == 0 
      line = @current_index
      pos = @curpos
      @delete_buffer = ""
      # currently only look in current line
      $multiplier.times {
        found = @buffer.index(/[[:punct:][:space:]]/, pos)
        break if !found
        $log.debug " delete_word: pos #{pos} found #{found} buff: #{@buffer} "
        @delete_buffer << @buffer.slice!(pos..found)
      }
      return if @delete_buffer == ""
      $log.debug " delete_word: delbuff #{@delete_buffer} "
      add_to_kill_ring @delete_buffer
      fire_handler :CHANGE, InputDataEvent.new(@curpos,@curpos+@delete_buffer.length, self, :DELETE, line, @delete_buffer)     #  2008-12-24 18:34 
      set_modified 
    end
    ##
    # deletes forward till the occurence of a character
    # it gets the char from the user
    # Should we pass in the character (and accept it as a separate func) ???
    def delete_forward
      return -1 unless @editable
      ch = @graphic.getchar
      return if ch < 0 || ch > 255
      char = ch.chr
      $multiplier = 1 if !$multiplier or $multiplier == 0 
      line = @current_index
      pos = @curpos
      tmpbuf = ""
      # currently only look in current line
      $multiplier.times {
        found = @buffer.index(char, pos)
        break if !found
        #$log.debug " delete_forward: pos #{pos} found #{found} buff: #{@buffer} "
        # ideally do this in one shot outside loop, but its okay here for now
        tmpbuf << @buffer.slice!(pos..found)
      }
      return if tmpbuf == ""
      @delete_buffer = tmpbuf
      $log.debug " delete_forward: delbuff #{@delete_buffer} "
      add_to_kill_ring @delete_buffer
      fire_handler :CHANGE, InputDataEvent.new(@curpos,@curpos+@delete_buffer.length, self, :DELETE, line, @delete_buffer)     #  2008-12-24 18:34 
      set_modified 
      $multiplier = 0
    end

end # end module
