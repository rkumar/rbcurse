# Provides the ability to scroll content, typically an array
# widget that includes may override on_enter_row and on_leave_row
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
    @toprow = @prow - @scrollatrow # ensure screen is filled when we show last. so clear not required
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
  def down
    #     $log.debug "inside down"
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
  def up # UP
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
  def space
    if @toprow + @scrollatrow+1 >= get_content().length
    else
      @toprow += @scrollatrow+1 # @rows-2 2008-11-13 23:41 put toprow here too
      $log.debug "space pr #{@prow}"
      @prow = @toprow
    end
  end
  def minus
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
    @toprow = @prow if @prow < @toprow   # ensre search could be 
    @toprow = @prow if @prow > @toprow + @scrollatrow   
    @winrow = @prow - @toprow
    # wont work first time - added 2008-11-26 20:56 
    if @oldprow != @prow
     $log.debug "going to call on leave and on enter"
      on_leave_row @oldprow if respond_to? :on_leave_row     # to be defined by widget that has included this
      on_enter_row @prow   if respond_to? :on_enter_row  # to be defined by widget that has included this
    end

    end
    def show_focus_on_row row0, tf=true
      color = tf ? $reversecolor : $datacolor
      r = row0+1 
      @datawidth ||= @width-2
      return if r > get_content().length
      @win.mvchgat(y=r+@row, x=1+@col, max=@datawidth, Ncurses::A_NORMAL, color, nil)
    end
    # after repaint
    def show_focus
      #show_focus_on_row(@oldprow, false)
      #show_focus_on_row(@prow)
      show_focus_on_row(@oldwinrow, false)
      show_focus_on_row(@winrow)
      # printstr @form.window, 23, 10, @prow
    end
    ## call from repaint
    # TODO show selected row in selectedcolor
    # - if user scrolls horizontally, use column as starting point
    def paint
#     $log.debug "called paint #{@toprow} #{@prow}"
      @content = get_content
      @content_rows = @content.length # rows can be added at any time
      win = get_window
      maxlen = @maxlen ||= @width-2
      0.upto(@height-2) {|r|
        if @toprow + r < @content_rows
          # this relates to selection of a row, as yet
          # check if any status of attribs for this row
          row_att = @list_attribs[@toprow+r] unless @list_attribs.nil?
          status = " "
          bgcolor = $datacolor
          if !row_att.nil?
            status = row_att.fetch(:status, " ")
            bgcolor = row_att[:bgcolor]
          end
          # sanitize
          content = @list[@toprow+r].chomp # don't display newline
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
          printstr @form.window, @row+r+1, @col+@left_margin-1, "%s" % status if @implements_selectable
          printstr @form.window, @row+r+1, @col+@left_margin, "%-*s" % [width,content]
          win.mvchgat(y=r+@row+1, x=@col+@left_margin, max=width, Ncurses::A_NORMAL, bgcolor, nil) unless bgcolor.nil?

        else
          # clear the displayed area
          printstr @form.window, @row+r+1, @col+@left_margin, " "*(@width-(@left_margin+1))
        end
      }
      show_focus if @show_focus
    end
    ## for user to know which row is being focussed on
    def focussed_index
      @prow
    end
    def scrollable_handle_key ch
      begin
        pre_key
        case ch
        when 32, ?\C-n
          space
        when ?\C-p
          minus
        when ?0
          goto_start
        when ?9
          goto_end
        when ?[
        when ?[
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
        else
          return :UNHANDLED
        end
      ensure
        post_key
      end
    end # handle_k listb

  end
