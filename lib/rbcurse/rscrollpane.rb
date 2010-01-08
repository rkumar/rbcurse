=begin
  * Name: Scrollpane
  * Description: a scrollable widget allowing user to scroll and view
    parts of underlying object that typically are larger than screen area.
    Mainly, contains a viewport, scrollbars and manages viewport through usage
    of scrollbars.
    Also contains viewport for row and columns.
  * Author: rkumar 
TODO section:
  - add events, property changed etc
  - scrollbars to be classes
  * file created 2009-10-27 19:20 
  --------
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
#require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rviewport'

include Ncurses
include RubyCurses
module RubyCurses
  extend self

  ##
  # A scrollable box throgh which one can see portions of underlying object
  # such as textarea, table or a form, usually the underlying data is larger
  # than what can be displayed.
  # TODO - 
  
  class ScrollPane < Widget
    #dsl_property :height  # height of viewport
    #dsl_accessor :width  # already present in widget
    # row and col also present int widget
    #dsl_accessor :child  # component that is being viewed
    # viewport
    # row_viewport
    # column_viewport
    # horizontal scrollbar 0-NONE, 1=ALWAYS, 2=AS_NEEDED
    # vertical scrollbar 0-NONE, 1=ALWAYS, 2=AS_NEEDED

    def initialize form, config={}, &block
      @focusable = true
      @editable = false
      #@left_margin = 1
      @row = 0
      @col = 0
      super
      @row_offset = @col_offset = 1
      @orig_col = @col
      init_vars
      should_create_buffer true

      # create_b moved from repaint since we need to pass form to child component
      @subpad=create_buffer # added 2009-12-27 13:35 BUFFERED  (moved from repaint)
      @subform = RubyCurses::Form.new @subpad # added 2009-12-27 13:35 BUFFERED  (moved from repaint)

      # next line does not seem to have an effect.
      # @subform.set_parent_buffer(@graphic) # added 2009-12-28 19:38 BUFFERT (trying out for cursor)
    end
    ##
    # set child component being used in viewport
    # @see set_viewport_view
    def child ch
      if ch != nil

        ## setting a form is a formality to prevent bombing
        ##+ however, avoid setting main form, which will then try to
        ##+ traverse this object and print using its own coordinates
        ch.set_form(@subform) # added 2009-12-27 13:35 BUFFERED 
        @subform.parent_form=@form # added 2009-12-28 23:02 for cursor stuff BUFFERED

        ## the next line causes the cursor to atleast move on the screen when we do up and down
        ##+ although it is not within the scrollpane, but starting with 0 offset
        #ch.form=@form  # added 2009-12-28 15:37 BUFFERED SHOCKINGLY, i overwrite formso cursor can be updated

        set_viewport_view(ch)
      end
    end
    def init_vars
      #@curpos = @pcol = @toprow = @current_index = 0
      @hsb_policy = :AS_NEEDED
      @vsb_policy = :AS_NEEDED
      @repaint_required = true
      @repaint_border = true
      @row_outofbounds=0
      @col_outofbounds=0
    end
    # set the component to be viewed
    def set_viewport_view ch
      @viewport = Viewport.new nil
      @viewport.set_view ch
      @viewport.set_view_size(@height-2, @width-2) # XXX make it one less
      @viewport.set_view_position(1,1) # @row, @col
    end
    # return underlying viewport
    # in order to run some of its methods
    def get_viewport
      return @viewport
    end
    # Directly set the viewport.
    # Usually it is best to use set_viewport_view instead
    def set_viewport vp
      @viewport = vp
    end
    # sets the component to be used as a rowheader
    def set_rowheader_view ch
      @rowheader = Viewport.new
      @rowheader.set_view ch
    end
    # sets the component to be used as a column header
    def set_columnheader_view ch
      @columnheader = Viewport.new
      @columnheader.set_view ch
    end
    def set_view_size h,w
      # calling the property shoudl uniformally trigger fire_property_change
      @viewport.set_view_size h,w
      #height(h)
      #width(w)
      #fire_handler :PROPERTY_CHANGE, self # XXX should it be an event STATE_CHANGED with details
    end
    def set_view_position r,c
      ret = @viewport.set_view_position r,c
      @repaint_required = true if ret 
      #row(r)
      #col(c)
      #fire_handler :PROPERTY_CHANGE, self
      return ret
    end
    # @return [true, false] false if r,c not changed
    def increment_view_row num
      r = @viewport.row()
      c = @viewport.col()
      r += num
      ret = set_view_position r, c
      v_scroll_bar if ret
      return ret
    end
    # @return [true, false] false if r,c not changed
    def increment_view_col num
      r = @viewport.row()
      c = @viewport.col()
      c += num
      ret = set_view_position r, c
      h_scroll_bar if ret
      return ret
    end
    def repaint # scrollpane
      # viewports child should repaint onto pad
      # viewport then clips
      # this calls viewports refresh from its refresh
      if @screen_buffer == nil
        #$log.debug " SCRP calling create buffer"
        #@subpad=create_buffer
        #@subform = RubyCurses::Form.new @subpad
        #@viewport.child.set_form(@subform)
      end
      return unless @repaint_required
      $log.debug " SCRP scrollpane repaint"
        # TODO this only if major change
       if @repaint_border
        @graphic.wclear
        $log.debug " repaint scroll r #{@row} c #{@col}  h  #{@height} w #{@width} "
        bordercolor = @border_color || $datacolor
        borderatt = @border_attrib || Ncurses::A_NORMAL
        @graphic.print_border(@row, @col, @height-1, @width, bordercolor, borderatt)
        h_scroll_bar
        v_scroll_bar
        @repaint_border = false
       end
      return if @viewport == nil
      $log.debug "SCRP calling viewport repaint"
      @viewport.repaint # child's repaint should do it on its pad
      $log.debug "SCRP calling viewport b2s "
      ret = @viewport.buffer_to_screen(@graphic)
      $log.debug " rscollpane vp b2s ret = #{ret} "

      ## next line rsults in ERROR in log file, does increment rowcol
      ##+ but still not shown on screen.
      #@subform.repaint # should i really TRYthis out 2009-12-28 20:41  BUFFERED
      @buffer_modified = true
      paint # has to paint border if needed, and scrollbars
      # TODO
    end
    def getvalue
      # TODO
    end
    ## handle keys for scrollpane.
    # First hands key to child object
    # If unused, checks to see if it has anything mapped.
    # If not consumed, returns :UNHANDLED, else 0.
    def handle_key ch
      # if this gets key it should just hand it to child
      if @viewport != nil
        $log.debug "    calling child handle_key KEY"
        ret = @viewport.handle_key ch
        # XXX ret returns 0under normal circumstance, so will next line work ?
        # what i mean is if ret == 0
        @repaint_required = true if ret == 0  # added 2009-12-27 22:21 BUFFERED
        $log.debug "  ... child ret #{ret}"


        ## Here's the only option scrollpane has of checking whether the child has
        ##+ exceeded boundary BUFFERED 2009-12-29 23:12 
        #  TEMPORARILY COMMENTED WHILE TESTING SCROLL UP AND DOWN XXX
        #fr = @form.row
        #fc = @form.col
        #if fr >= @row + @height -2
          #@form.setrowcol @row + @height -2, fc
        #elsif fr < @row
          #@form.setrowcol @row, fc
        #end
        #if fc >= @col + @width -1
          #@form.setrowcol fr, @col + @width -1
        #end
        ##

        return ret if ret == 0
      end
      $log.debug " scrollpane gets KEY #{ch}"
      case ch
        when ?\M-n.getbyte(0)
          ## scroll down one row (currently one only)
          ret = _down
      when ?\M-p.getbyte(0)
          ## scroll up one row (currently one only)
        ret = _up
      when ?0.getbyte(0), ?\C-[.getbyte(0)
        goto_start #start of buffer # cursor_start
      when ?\C-].getbyte(0)
        goto_end # end / bottom cursor_end # TODO
      when ?\M-\<.getbyte(0)
        @height.times { _up ; }
      when ?\M-\>.getbyte(0)
        @height.times { _down ; }
      when KEY_DOWN
        ret = down
        #check_curpos
      when  ?\M-h.getbyte(0)
        ## scroll left one position
        ret = cursor_backward
        @subform.cols_panned = @subform.cols_panned+1  if ret
        @subform.col         = @form.col+1+@col_outofbounds if ret
        @form.setrowcol @form.row, @form.col+1+@col_outofbounds if ret 
        $log.debug " - SCRP setting col to #{@subform.col}, #{@subform.cols_panned},oo #{@col_outofbounds} fr:#{@form.col} "
      when  ?\M-l.getbyte(0)
        ## scroll right one position
        ret = cursor_forward
        @subform.cols_panned = @subform.cols_panned-1  if ret
        @subform.col         = @form.col-1+@col_outofbounds if ret
        @form.setrowcol @form.row, @form.col-1+@col_outofbounds if ret 
        $log.debug " - SCRP setting col to #{@subform.col}, #{@subform.cols_panned},oo #{@col_outofbounds} fr:#{@form.col} "
      when KEY_BACKSPACE, 127
        cursor_backward
      else
        return :UNHANDLED
      end
      return 0
    end
    def down
      increment_view_row(1)
    end
    def up
      increment_view_row(-1)
    end
    def cursor_forward
      increment_view_col(1)
    end
    def cursor_backward
      increment_view_col(-1)
    end
    def _down
      ## scroll down one row (currently one only)
      ret = down
      ## we've scrolled down, but we need  to keep the cursor where
      ##+ editing actually is. Isn't this too specific to textarea ?
      $log.debug " SCRP setting row to #{@form.row-1} upon scrolling down  "
      ## only move up the cursor if its within bounds
      #       if @form.row > @row
      @subform.rows_panned = @subform.rows_panned-1  if ret 
      @subform.row =@form.row-1+@row_outofbounds if ret 
      @form.setrowcol @form.row-1+@row_outofbounds, @form.col if ret 
      $log.debug " - SCRP setting row to #{@subform.row}, #{@subform.rows_panned},oo #{@row_outofbounds} fr:#{@form.row} "
      #       @row_outofbounds = @row_outofbounds-1 if ret and @row_outofbounds > 0
      #       else
      #         @row_outofbounds = @row_outofbounds-1 if ret
      #         $log.debug " SCRP setting refusing to scroll #{@form.row}, #{@row} upon scrolling down #{@row_outofbounds}  "
      #       end
    end
    def _up
          ## scroll up one row (currently one only)
        ret = up
        $log.debug " SCRP setting row to #{@form.row+1} upon scrolling up #{@row} #{@height}  "
   #     if @form.row < @row + @height
          @subform.rows_panned = @subform.rows_panned+1  if ret 
          @subform.row =@form.row+1+@row_outofbounds if ret 
          @form.setrowcol @form.row+1+@row_outofbounds, @form.col if ret 
          $log.debug " - SCRP setting row to #{@subform.row}, #{@subform.rows_panned},oo #{@row_outofbounds} fr:#{@form.row} "
   #       @row_outofbounds = @row_outofbounds+1 if ret and @row_outofbounds < 0
   #     else
   #       $log.debug " SCRP setting refusing to scroll #{@form.row}, #{@row} upon scrolling up  "
   #       @row_outofbounds = @row_outofbounds+1 if ret
   #     end
        #@form.setrowcol @form.row+1, @form.col if ret  # only if up succeeded
        #scroll_backward 
    end
    def on_enter
      #super 2010-01-02 18:53 leading to a stack overflow XXX ???
      set_form_row
    end
    # this is called once externally, on on_enter
    #+ after that its called internally only, which in this case is never
    def set_form_row
      #@form.row = @row + 1 unless @form.nil?
      if @viewport != nil
        #$log.debug "    calling scrollpane set_form_row"
        ret = @viewport.child.set_form_row # added 2009-12-27 23:23 BUFFERED
      end
      $log.debug " FORM SCRP #{@form} "
      $log.debug "SCRP set_form_row #{@form.row}  #{@form.col} "
    end

    ## this is called once only, on select_field by form.
    ##+ after that not at all.
    def rowcol
      r1 = @row #+@row_offset
      c1 = @col #+@col_offset

      r,c = @viewport.child.rowcol # added 2009-12-28 15:23 BUFFERED
      $log.debug "SCRP rowcol:  #{r1} + #{r} , #{c1} + #{c} "
      return r1+r, c1+c
    end

    def paint
      @repaint_required = false
    end
    def h_scroll_bar
      sz = (@viewport.width*1.00/@viewport.child().width)*@viewport.width
      #$log.debug " h_scroll_bar sz #{sz}, #{@viewport.width} #{@viewport.child().width}" 
      sz = sz.ceil
      return if sz < 1
      start = 1
      start = ((@viewport.col*1.00+@viewport.width)/@viewport.child().width)*@viewport.width
      start -= sz
      #$log.debug " h_scroll_bar start #{start}, #{@viewport.col} #{@viewport.width}" 
      start = start.ceil
      # # the problem with next 2 lines is that attributes of border could be overwritten
      # draw horiz line
      @graphic.mvwhline(@height-1, 1, ACS_HLINE, @width-2)
      # draw scroll bar
      sz.times{ |i| @graphic.mvaddch(@height-1, start+1+i, ACS_CKBOARD) }
    end
    def v_scroll_bar
      sz = (@viewport.height*1.00/@viewport.child().height)*@viewport.height
      #$log.debug " h_scroll_bar sz #{sz}, #{@viewport.width} #{@viewport.child().width}" 
      sz = sz.ceil
      return if sz < 1
      start = 1
      start = ((@viewport.row*1.00+@viewport.height)/@viewport.child().height)*@viewport.height
      start -= sz
      #$log.debug " h_scroll_bar start #{start}, #{@viewport.col} #{@viewport.width}" 
      start = start.ceil
      # # the problem with next 2 lines is that attributes of border could be overwritten
      # draw horiz line
      @graphic.mvwvline(1,@width-1, ACS_VLINE, @height-2)
      # draw scroll bar
      sz.times{ |i| @graphic.mvaddch(start+1+i, @width-1, ACS_CKBOARD) }
    end

  end # class ScrollPane
end # module
