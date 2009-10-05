#### ---------------------- ####
# CAUTION: This is the worst piece of code ever written, pls do not
# go further. I will remove this very soon.
# -- Shamefully yours.
#### ---------------------- ####
# Provides the ability to scroll content, typically an array
# widget that includes may override on_enter_row and on_leave_row
# This was essentially copied and modifed from the pad scroller
# i think i can redo it and make it much simpler XXX
module Scrollable
  def init_scrollable
    @toprow = @prow = @winrow = @pcol = 0
    @oldwinrow = @oldprow = @oldtoprow = 0
    @startrow = 1   # from where we start prniting, taking header row into account
    @cols = @width
    @left_margin ||= 2
    @show_focus = true if @show_focus.nil? 

#   @right_margin ||= @left_margin
#   @scrollatrow ||= @height-2
  end
  def goto_start
    @prow = 0
    @toprow = @prow
    @winrow = 0 
  end
  def goto_end
    @prow = get_content().length-1 
    #@toprow = @prow
    #@winrow = 0     # not putting this was cause prow < toprow !!
    @toprow = @prow - @scrollatrow   # ensure screen is filled when we show last. so clear not required
    @toprow = 0 if @toprow < 0
    ## except what if very few rows
    @winrow = @scrollatrow
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
  def down num=1
    #     $log.debug "inside down"
    num.times do 
    if @prow >= get_content().length-1
      #Ncurses.beep
      @message = "No more rows"
      return -1
    end
    if @winrow < @scrollatrow # 20
      @winrow += 1    # move cursor down
    else
      @toprow += 1    # scroll down a row
    end
    @prow += 1        # incr pad row
    end
  end
  def up num=1  # UP
    num.times do
    if @prow <= 0
      #Ncurses.beep
      @message = "This is the first row"
      @prow = 0
      return -1
    else
      @prow -= 1 
    end
    if @winrow > 0 
      @winrow -= 1
    else
      @toprow -= 1 if @toprow > 0
    end
    @toprow = @prow if @prow < @toprow
    end
  end
  def scroll_forward
    if @toprow + @scrollatrow+1 >= get_content().length
      # so cursor goes to last line
      @prow +=  get_content().length - @prow - 1 # XXX 2008-11-27 14:18 
    else
      @toprow += @scrollatrow+1 # @rows-2 2008-11-13 23:41 put toprow here too
      $log.debug "space pr #{@prow}"
      @prow = @toprow
    end
  end
  def scroll_backward
    if @prow <= 0
      @message = "This is the first row"
      @prow = 0
      #next
    else
      @prow -=  (@scrollatrow+1) #(@rows-2)
      @prow = 0 if @prow < 0
    end
    @toprow = @prow
  end
  def pre_key
    @oldprow = @prow
    @oldtoprow = @toprow
    @oldwinrow = @winrow
  end
  # prior to repaint. but after keypress
  def post_key
#    $log.debug "1 post_key w:#{@winrow} p:#{@prow} t:#{@toprow}"
    @toprow = @prow if @prow < @toprow   # ensre search could be 
    @toprow = @prow if @prow > @toprow + @scrollatrow   
    @winrow = @prow - @toprow
#    $log.debug "2 post_key w:#{@winrow} p:#{@prow} t:#{@toprow}"
    # wont work first time - added 2008-11-26 20:56 
    if @oldprow != @prow
     $log.debug "going to call on leave and on enter"
      on_leave_row @oldprow if respond_to? :on_leave_row     # to be defined by widget that has included this
      on_enter_row @prow   if respond_to? :on_enter_row  # to be defined by widget that has included this
    end
    #@form.row =  @winrow
    set_form_row

    end
  ##
  # caution, this now uses winrow not prow
    def show_focus_on_row row0, _prow, tf=true
     # color = tf ? $reversecolor : $datacolor
      # if cursor on row, reverse else normal
      attr = tf ? Ncurses::A_REVERSE : Ncurses::A_NORMAL
      color = @color_pair
      r = row0+1 
      #check if row is selected or not
      row_att = @list_attribs[_prow] unless @list_attribs.nil?
      if !row_att.nil?
        status = row_att.fetch(:status, " ")
        attr1 = row_att[:bgcolor] 
        color = attr1 unless attr1.nil?
      end
      @datawidth ||= @width-2
      return if r > get_content().length
      @form.window.mvchgat(y=r+@row, x=1+@col, max=@datawidth, attr, color, nil)
    end
    ##
    # unfocus the previous row cursor was on
    # and put focus on currrent row
    # Called after repaint
    def show_focus
      show_focus_on_row(@oldwinrow, @oldprow, false)
      show_focus_on_row(@winrow, @prow, true)
      # printstr @form.window, 23, 10, @prow
    end
    ## call from repaint
    # TODO i can simplif, i think
    # - if user scrolls horizontally, use column as starting point
    def paint
      #$log.debug "called paint t:#{@toprow} p:#{@prow} w:#{@winrow}"
      list  = get_content
      @content_rows = list.length # rows can be added at any time
      win = get_window
      maxlen = @maxlen ||= @width-2
      if @bgcolor.is_a? String and @color.is_a? String
        acolor = ColorMap.get_color(@color, @bgcolor)
      else
        acolor = $datacolor
      end
      @color_pair = acolor
      0.upto(@height-2) {|r|
        if @toprow + r < @content_rows
          # this relates to selection of a row, as yet
          # check if any status of attribs for this row
          row_att = @list_attribs[@toprow+r] unless @list_attribs.nil?
          status = " "
          #bgcolor = $datacolor
          bgcolor = nil
          if !row_att.nil?
            status = row_att.fetch(:status, " ")
            bgcolor = row_att[:bgcolor]
          end
          # sanitize
          content = list[@toprow+r].chomp # don't display newline
          content.gsub!(/\t/, '  ') # don't display tab
          content.gsub!(/[^[:print:]]/, '')  # don't display non print characters

          #content = content[0..maxlen-1] if !content.nil? && content.length > maxlen # only show maxlen
          if !content.nil? 
            if content.length > maxlen # only show maxlen
              content = content[@pcol..@pcol+maxlen-1] 
            else
              content = content[@pcol..-1]
            end
          end

          width = @width-(@left_margin+1)
          @form.window.printstring @row+r+1, @col+@left_margin-1, "%s" % status, acolor, @attr if @implements_selectable
          @form.window.printstring  @row+r+1, @col+@left_margin, "%-*s" % [width,content], acolor, @attr
          win.mvchgat(y=r+@row+1, x=@col+@left_margin, max=width, Ncurses::A_NORMAL, bgcolor, nil) unless bgcolor.nil?
          dollar = "|"
          dollar = "$" if list[@toprow+r][-1,1]=="\r"
          @form.window.printstring  @row+r+1, @col+@width-1, dollar, acolor, @attr

        else
          # clear the displayed area
          @form.window.printstring @row+r+1, @col+@left_margin, " "*(@width-(@left_margin+1)), acolor
          dollar = "|"
          @form.window.printstring  @row+r+1, @col+@width-1, dollar, acolor, @attr
        end
      }
      show_focus if @show_focus
    end
    ## for user to know which row is being focussed on
    def focussed_index
      @prow
    end
    # only to be used in single selection cases as focussed item FIXME.
    def selected_item
      get_content()[focussed_index()]
    end
    alias :current_index :focussed_index
    alias :selected_index :focussed_index
    def scrollable_handle_key ch
      begin
        pre_key
        case ch
        when ?\C-n.getbyte(0)
          scroll_forward
        when 32
          scroll_forward
        when ?\C-p.getbyte(0)
          scroll_backward
        when ?0.getbyte(0)
          goto_start
        when ?9.getbyte(0)
          goto_end
        when ?[.getbyte(0)
        when ?[.getbyte(0)
        when KEY_UP
          #select_prev_row
          up
        when KEY_LEFT
        when KEY_RIGHT
        when KEY_DOWN
          down
          # select_next_row
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
        post_key
      end
    end # handle_k listb
    ## 2008-12-18 18:03 
    # finds the next match for the char pressed
    # returning the index
    def next_match char
      data = get_content
      row = focussed_index
      currval = data[row].chomp
      row.upto(data.length-1) do |ix|
        val = data[ix].chomp
        if val[0,1] == char and val != currval
          return ix
        end
      end
      0.upto(row) do |ix|
        val = data[ix].chomp
        if val[0,1] == char and val != currval
          return ix
        end
      end
      return -1
    end
    ## 2008-12-18 18:03 
    # sets the selection to the next row starting with char
    def set_selection_for_char char
      ix = next_match char
      @prow = ix if ix != -1
      return ix
    end
    ##
    # 2008-12-18 18:05 
    # set focus on given index
    def set_focus_on arow
      return if arow > get_content().length-1 or arow < 0
      total = get_content().length
      @prow = arow
      sar = @scrollatrow + 1
      @toprow = (@prow / sar) * sar

      if total - @toprow < sar
        @toprow = (total - sar) 
      end
      @winrow = @prow - @toprow
    end

  end
