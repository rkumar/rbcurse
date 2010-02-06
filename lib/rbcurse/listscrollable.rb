# Provides the ability to scroll content, typically an array
# widget that includes may override on_enter_row and on_leave_row
# Caller should have
#   row_count()
#   scrollatrow() typically @height - 2 (unless a header row, then -3)
#   @current_index (row of current index, starting with 0 usually)
#   @toprow : set to 0 for starters, top row to be displayed
#   @pcol (used for horiz scrolling, starts at 0)
#
module ListScrollable
  attr_reader :search_found_ix, :find_offset, :find_offset1
  attr_accessor :show_caret # 2010-01-23 23:06 our own fake insertion point
  def previous_row
    @oldrow = @current_index
    @current_index -= 1 if @current_index > 0
    bounds_check
  end
  alias :up :previous_row
  def next_row
    @oldrow = @current_index
    rc = row_count
    @current_index += 1 if @current_index < rc
    bounds_check
  end
  alias :down :next_row
  def goto_bottom
    @oldrow = @current_index
    rc = row_count
    @current_index = rc -1
    bounds_check
  end
  alias :goto_end :goto_bottom
  def goto_top
    @oldrow = @current_index
    @current_index = 0
    bounds_check
  end
  alias :goto_start :goto_top
  def scroll_backward
    @oldrow = @current_index
    h = scrollatrow()
    @current_index -= h 
    bounds_check
  end
  def scroll_forward
    @oldrow = @current_index
    h = scrollatrow()
    rc = row_count
    # more rows than box
    if h < rc
      @toprow += h+1 #if @current_index+h < rc
      @current_index = @toprow
    else
      # fewer rows than box
      @current_index = rc -1
    end
    #@current_index += h+1 #if @current_index+h < rc
    bounds_check
  end

  ##
  # please set oldrow before calling this. Store current_index as oldrow before changing. NOTE
  def bounds_check
    h = scrollatrow()
    rc = row_count
    #$log.debug " PRE CURR:#{@current_index}, TR: #{@toprow} RC: #{rc} H:#{h}"
    @current_index = 0 if @current_index < 0  # not lt 0
    @current_index = rc-1 if @current_index >= rc and rc>0 # not gt rowcount
    @toprow = rc-h-1 if rc > h and @toprow > rc - h - 1 # toprow shows full page if possible
    # curr has gone below table,  move toprow forward
    if @current_index - @toprow > h
      @toprow = @current_index - h
    elsif @current_index < @toprow
      # curr has gone above table,  move toprow up
      @toprow = @current_index
    end
    #$log.debug " POST CURR:#{@current_index}, TR: #{@toprow} RC: #{rc} H:#{h}"
    if @oldrow != @current_index
      #$log.debug "going to call on leave and on enter"
      on_leave_row @oldrow if respond_to? :on_leave_row     # to be defined by widget that has included this
      on_enter_row @current_index   if respond_to? :on_enter_row  # to be defined by widget that has included this
    end
    set_form_row
    #set_form_col 0 # added 2009-02-15 23:33  # this works for lists but we don't want this in TextArea's
    @repaint_required = true
  end
  # the cursor should be appropriately positioned
  def set_form_row
    r,c = rowcol
    orig_row=@form.row
    
    ## the next is in case the form is not starting at 0,0.
    ## However, this typically happens if its a form within another container such as scrollpane
    ##+ in which case setting the form row has no effect. We need to set the main forms
    ##+ row, which sucks. 
    win_row=@form.window.top
    #win_col=@form.window.left
    row = win_row + r + (@current_index-@toprow)  + @form.rows_panned
    $log.debug " #{@name} LIST set_form_row #{row} , ci #{@current_index} , toprow #{@toprow} (orig #{orig_row} )"
    $log.debug "  - LIST set_form_row win_row: #{win_row} , r #{r} , c= #{c} "

    ## 2009-12-28 23:05 TRYING OUT but i really can't do this everywhere. BUFFERED
    ## this needs to percolate up a heirarchy.
    ## 2010-01-05 21:09 changed c to nil, since c is not cursor col pos but where printing starts, i think
    #@form.setrowcol row, nil
    #setformrowcol row, nil
    setrowcol row, nil
    show_caret_func
  end
  ## In many situations like placing a textarea or textview inside a splitpane 
  ##+ or scrollpane there have been issues getting the cursor at the right point, 
  ##+ since there are multiple buffers. Finally in tabbedpanes, i am pretty 
  ##+ lost getting the correct position, and i feel we should set the cursor 
  ##+ internally once and for all. So here's an attempt

  # paint the cursor ourselves on the widget, rather than rely on getting to the top window with
  # the correct coordinates. I do need to erase cursor too. Can be dicey, but is worth the attempt.
  def show_caret_func
      return unless @show_caret
      # trying highlighting cursor 2010-01-23 19:07 TABBEDPANE TRYING
      # TODO take into account rows_panned etc ?
      r,c = rowcol
      yy = r + @current_index - @toprow - @form.window.top
      xx = @form.col # how do we know what value has been set earlier ?
      #yy = @row_offset if yy < @row_offset # sometimes r is 0, we are missing something in tabbedpane+scroll
      #xx = @col_offset if xx < @col_offset
      #xx = 0 if xx < 0

      $log.debug " #{@name} printing CARET at #{yy},#{xx}: fr: #{@form.row} fwt:- #{@form.window.top} r:#{@row} tr:-#{@toprow} ci:#{@current_index}  "
      if !@oldcursorrow.nil?
          @graphic.mvchgat(y=@oldcursorrow, x=@oldcursorcol, 1, Ncurses::A_NORMAL, $datacolor, NIL)
      end
      @oldcursorrow = yy
      @oldcursorcol = xx
      @graphic.mvchgat(y=yy, x=xx, 1, Ncurses::A_NORMAL, $reversecolor, nil)
      @buffer_modified = true
  end
  def right
    @hscrollcols ||= @cols/2
    @pcol += @hscrollcols if @pcol + @hscrollcols < @padcols
    #   window_erase @win XXX
  end
  def left
    @hscrollcols ||= @cols/2
    @pcol -= @hscrollcols if @pcol > 0
    @pcol = 0 if @pcol < 0
  end
  # not that saving content_rows is buggy since we add rows.
  ##
  # caution, this now uses winrow not prow
  ## for user to know which row is being focussed on
  def focussed_index
    @current_index # 2009-01-07 14:35 
  end
  # only to be used in single selection cases as focussed item FIXME.
  # best not to use, as can be implementation dep, use current_index
  def selected_item
    get_content()[focussed_index()]
  end
  #alias :current_index :focussed_index
  alias :selected_index :focussed_index
  def OLDscrollable_handle_key ch
    begin
      ###pre_key # 2009-01-07 13:23 
      case ch
      when ?\C-n.getbyte(0)
        scroll_forward
      when 32
        scroll_forward
      when ?\C-p.getbyte(0)
        scroll_backward
      when ?0.getbyte(0)
        #goto_start
        goto_top
      when ?9.getbyte(0)
        #goto_end
        goto_bottom
      when KEY_UP
        #select_prev_row
        #up
        #$log.debug " GOT KEY UP NEW SCROLL"
        previous_row
      when KEY_LEFT
      when KEY_RIGHT
      when KEY_DOWN
        #down
        #$log.debug " GOT KEY DOWN NEW SCROLL"
        next_row
      when KEY_ENTER, 10, 13
        if respond_to? :fire
          fire
        end
      when ?A.getbyte(0)..?Z.getbyte(0), ?a.getbyte(0)..?z.getbyte(0)
        ret = set_selection_for_char ch.chr
      else
        return :UNHANDLED #if ret == -1
      end
    ensure
      #post_key
    end
  end # handle_k listb
  ## 2008-12-18 18:03 
  # finds the next match for the char pressed
  # returning the index
  def next_match char
    data = get_content
    row = focussed_index + 1
    row.upto(data.length-1) do |ix|
      val = data[ix].chomp rescue return  # 2010-01-05 15:28 crashed on trueclass
      #if val[0,1] == char #and val != currval
      if val[0,1].casecmp(char) == 0 #AND VAL != CURRval
        return ix
      end
    end
    row = focussed_index - 1
    0.upto(row) do |ix|
      val = data[ix].chomp
      #if val[0,1] == char #and val != currval
      if val[0,1].casecmp(char) == 0 #and val != currval
        return ix
      end
    end
    return -1
  end
  ## 2008-12-18 18:03 
  # sets the selection to the next row starting with char
  def set_selection_for_char char
    @oldrow = @current_index
    ix = next_match char
    @current_index = ix if ix && ix != -1
    bounds_check
    return ix
  end

  ##
  # ensures that the given row is focussed
  # new version of older one that was not perfect.
  # 2009-01-17 13:25 
  def set_focus_on arow
    @oldrow = @current_index
    @current_index = arow
    bounds_check if @oldrow != @current_index
  end
  ##
  # 2008-12-18 18:05 
  # set focus on given index
  def OLDset_focus_on arow
    return if arow > row_count()-1 or arow < 0
    @oldrow = @current_index
    total = row_count()
    @current_index = arow
    sar = scrollatrow + 1
    @toprow = (@current_index / sar) * sar

    #$log.debug "1 set_focus #{total}, sar #{sar}, toprow #{@toprow}, current_index #{@current_index}"
    if total - @toprow < sar
      @toprow = (total - sar) 
    end
    #$log.debug "2 set_focus #{total}, sar #{sar}, toprow #{@toprow}, current_index #{@current_index}"
    set_form_row # 2009-01-17 12:44 
    @repaint_required = true
    #bounds_check
  end
    def install_keys
=begin
      @KEY_ASK_FIND_FORWARD ||= ?\M-f.getbyte(0)
      @KEY_ASK_FIND_BACKWARD ||= ?\M-F.getbyte(0)
      @KEY_FIND_NEXT ||= ?\M-g.getbyte(0)
      @KEY_FIND_PREV ||= ?\M-G.getbyte(0)
=end
      @KEY_ASK_FIND ||= ?\M-f.getbyte(0)
      @KEY_FIND_MORE ||= ?\M-g.getbyte(0)
    end
    def ask_search
      options = ["Search backwards", "case insensitive", "Wrap around"]
      sel,regex,hash =  get_string_with_options("Enter regex to search", 20, @last_regex||"", "checkboxes"=>options, "checkbox_defaults"=>[@search_direction_prev,@search_case,@search_wrap])
      return if sel != 0
      @search_direction_prev =  hash[options[0]]
      @search_case = hash[options[1]]
      @search_wrap = hash[options[2]]
      if @search_direction_prev == true
        ix = _find_prev regex, @current_index
      else
        ix = _find_next regex, @current_index
      end
      if ix.nil?
        alert("No matching data for: #{regex}")
      else
        set_focus_on(ix)
        set_form_col @find_offset1
        @cell_editor.component.curpos = (@find_offset||0) if @cell_editing_allowed
      end
    end
    def find_more
      if @search_direction_prev 
        find_prev
      else
        find_next
      end
    end
    # find forwards
    # Using this to start a search or continue search
    def _find_next regex=@last_regex, start = @search_found_ix 
      raise "No previous search" if regex.nil?
      #$log.debug " _find_next #{@search_found_ix} : #{@current_index}"
      fend = @list.size-1
      if start != fend
      start += 1 unless start == fend
      @last_regex = regex
      @search_start_ix = start
      regex = Regexp.new(regex, Regexp::IGNORECASE) if @search_case
      start.upto(fend) do |ix| 
        row = @list[ix]
        m=row.match(regex)
        if !m.nil?
          @find_offset = m.offset(0)[0]
          @find_offset1 = m.offset(0)[1]
          @search_found_ix = ix
          return ix 
        end
      end
      end
      fend = start-1
      start = 0
      if @search_wrap
        start.upto(fend) do |ix| 
          row = @list[ix]
          m=row.match(regex)
          if !m.nil?
            @find_offset = m.offset(0)[0]
            @find_offset1 = m.offset(0)[1]
            @search_found_ix = ix
            return ix 
          end
        end
      end
      return nil
    end
    def find_next
        ix = _find_next
        regex = @last_regex 
        if ix.nil?
          alert("No more matching data for: #{regex}")
        else
          set_focus_on(ix) 
          set_form_col @find_offset1
        @cell_editor.component.curpos = (@find_offset||0) if @cell_editing_allowed
        end
    end
    def find_prev
        ix = _find_prev
        regex = @last_regex 
        if ix.nil?
          alert("No previous matching data for: #{regex}")
        else
          set_focus_on(ix)
          set_form_col @find_offset
          @cell_editor.component.curpos = (@find_offset||0) if @cell_editing_allowed
        end
    end
    ##
    # find backwards
    # Using this to start a search or continue search
    def _find_prev regex=@last_regex, start = @search_found_ix 
      raise "No previous search" if regex.nil?
      #$log.debug " _find_prev #{@search_found_ix} : #{@current_index}"
      if start != 0
      start -= 1 unless start == 0
      @last_regex = regex
      @search_start_ix = start
      regex = Regexp.new(regex, Regexp::IGNORECASE) if @search_case
      start.downto(0) do |ix| 
        row = @list[ix]
        m=row.match(regex)
        if !m.nil?
          @find_offset = m.offset(0)[0]
          @find_offset1 = m.offset(0)[1]
          @search_found_ix = ix
          return ix 
        end
      end
      end
      fend = start-1
      start = @list.size-1
      if @search_wrap
        start.downto(fend) do |ix| 
          row = @list[ix]
          m=row.match(regex)
          if !m.nil?
            @find_offset = m.offset(0)[0]
          @find_offset1 = m.offset(0)[1]
            @search_found_ix = ix
            return ix 
          end
        end
      end
      return nil
    end

end
