=begin
  * Name: Scrollpane
  * Description: a scrollable widget allowing user to scroll and view
    parts of underlying object that typically are larger than screen area.
    Mainly, contains a viewport, scrollbars and manages viewport through usage
    of scrollbars.
    Also contains viewport for row and columns.
  * Author: rkumar 
Todo section:
  - add events, property changed etc at least for scrolling - DONE
    SCrollpane normall should listen in to changes in viewport, however Scro calls those very methods
    and what's more, other classes would listen to SCR and not to VP.
  - scrollbars to be classes - shall we avoid over-engineering, and KISS
  - if scrollpane reduced it should also resize, as example inside splitpane.
  * file created 2009-10-27 19:20 
  * Added a call to child's set_form_col from set_form_row
Major changes 2010-02-11 19:51 to simplify version RFED16
  * Still need to clean up this and viewport. make as light as possible
  * If scrolling, no repainting should happen. Scrollpane could get the buffer
    and scroll itself. Or ensure that inner object does not rework...

  Pass handle_key to child, also repaint refer child.
  Avoid passing to viewport as this would slow down alot.

  NOTE: if a caller is interested in knowing what scrolling has happened, pls bind to :STATE_CHANGE, you will receive the viewport object. If you find this cumbersome, and wish to know only about scrolling, we can put in a scrolling event and inform of row or col scrolling. Or we can fire a property change with row or col increment.
  
  
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
  
  class ScrollPane < Widget
    # viewport
    # row_viewport
    # column_viewport
    # horizontal scrollbar 0-NONE, 1=ALWAYS, 2=AS_NEEDED
    # vertical scrollbar 0-NONE, 1=ALWAYS, 2=AS_NEEDED
    attr_accessor :cascade_changes  # should changes in size go down to child, default false

    def initialize form, config={}, &block
      @focusable = true
      @editable = false
      #@left_margin = 1
      @row = 0
      @col = 0
      super
      @row_offset = @col_offset = 1
      init_vars
    #  $log.debug " SCROLLPANE recvs form #{form.name}, #{form.window.name} " unless form.nil?


    end
    ##
    # set child component being used in viewport
    # @see set_viewport_view
    def child ch
      if ch != nil
        @child = ch # added 2010-02-11 15:28 we might do away with viewport, setting panned to child
        @child.rows_panned = @child.cols_panned = 0

        ch.parent_component = self # added 2010-01-13 12:55 so offsets can go down ?

        @child.should_create_buffer = true 
        @form.add_rows += 2 # related to scr_top  XXX What if form not set. i cannot keep accumulating
        update_child
        # -3 since we start row +1 to get indented by 1, also we use
        # height -1 in scrollpane, so we need -2 to indent, and one more
        # for row
        set_viewport_view(ch)
      end
    end
    ## 
    # update of child's coordinates, needs to be called whenever it
    # changes, so i need to call it before calling child's update
    # FIXME - this is become 2 calls, make it one - becoming expensive
    # if called often
    def update_child
      scr_top = 3 # for Pad, if Pad passed as in SplitPane
      scr_left = 1 # for Pad, if Pad passed as in SplitPane
      if @form.window.window_type == :WINDOW
        scr_top = @row + 1
        scr_left = @col + 1
        @child.row(@row+@row_offset)
        @child.col(@col+@col_offset)
      else
        # PAD case
        @child.row(scr_top)
        @child.col(scr_left)
      end
        @child.set_buffering(:target_window => @target_window || @form.window, :form => @form, :bottom => @height-3, :right => @width-3 )
        @child.set_buffering(:screen_top => scr_top, :screen_left => scr_left)
        # lets set the childs ext offsets
        $log.debug "SCRP #{name} adding (to #{@child.name}) ext_row_off: #{@child.ext_row_offset} +=  #{@ext_row_offset} +#{@row_offset}  "
        $log.debug "SCRP adding ext_col_off: #{@child.ext_col_offset} +=  #{@ext_col_offset} +#{@col_offset}  "
        ## 2010-02-09 18:58 i think we should not put col_offset since the col
        ## of child would take care of that. same for row_offset. XXX 
        @child.ext_col_offset += @ext_col_offset + @col + @col_offset - @screen_left # 2010-02-09 19:14 
        # added row and col setting to child RFED16 2010-02-17 00:22 as
        # in splitpane. seems we are not using ext_offsets now ? texta
        # and TV are not. and i've commented off from widget

        $log.debug " #{@child.ext_row_offset} +=  #{@ext_row_offset} + #{@row} -#{@screen_top}  "
        @child.ext_row_offset +=  @ext_row_offset  + @row   + @row_offset - @screen_top 
        # adding this since child's ht should not be less. or we have a
        # copywin failure
        @child.height ||= @height
        @child.width ||= @width
        if @child.height < @height
          @child.height = @height
        end
        if @child.width < @width
          @child.width = @width
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
      @border_width = 2
      @screen_top = 0
      @screen_left = 0
    end
    # set the component to be viewed
    def set_viewport_view ch
      @viewport = Viewport.new nil
      @viewport.set_view ch
      ## this -2 should depend on whether we are putting border/scrollbars or not.
      # -1 added on 2010-02-16 23:35 since we are red 1, and bw
      @viewport.set_view_size(@height-@border_width-0, @width-@border_width-0) # XXX make it one less
      @viewport.cascade_changes = @cascade_changes # added 2010-02-04 18:19 
      @viewport.bind(:STATE_CHANGE) { |e| view_state_changed(e) }
      @viewport.bind(:PROPERTY_CHANGE) { |e| view_property_changed(e) }
    end
    # return underlying viewport
    # in order to run some of its methods
    def get_viewport
      return @viewport
    end
    # Directly set the viewport.
    # Usually it is best to use set_viewport_view instead
    def set_viewport vp
      old = @viewport
      @viewport = vp
      fire_property_change "viewport", old, @viewport
    end
    # sets the component to be used as a rowheader TODO
    def set_rowheader_view ch
      old = @rowheader
      @rowheader = Viewport.new
      @rowheader.set_view ch
      fire_property_change "row_header", old, @rowheader
    end
    # sets the component to be used as a column header TODO
    def set_columnheader_view ch
      old = @columnheader
      @columnheader = Viewport.new
      @columnheader.set_view ch
      fire_property_change "column_header", old, @columnheader
    end
    def set_view_size h,w
      # calling the property shoudl uniformally trigger fire_property_change
      @viewport.set_view_size h,w
      #height(h)
      #width(w)
      #fire_handler :PROPERTY_CHANGE, self # XXX should it be an event STATE_CHANGED with details
    end
    ## seems i wrote this only so i could set repaint_required to true
    # However, now that VP calls state changed, that will happen XXX
    def set_view_position r,c
      ret = @viewport.set_view_position r,c
      if ret
        @repaint_required = true if ret 
    #    fire_property_change("view_position", 
      end
      return ret
    end
    # this method is registered with Viewport for changes
    def view_state_changed ev
      fire_handler :STATE_CHANGE, ev #???
      @repaint_required = true
    end
    # this method is registered with Viewport for changes to properties
    def view_property_changed ev
      fire_handler :PROPERTY_CHANGE, ev #???
      @repaint_required = true
    end
    # @return [true, false] false if r,c not changed
    def increment_view_row num
#x      r = @viewport.row() #- @viewport.top_margin
#x      c = @viewport.col() #- @viewport.left_margin
      r, c = @viewport.get_pad_top_left()
      $log.debug " SCR inc viewport currently :  r #{r} c #{c} "
      r += num
      ret = set_view_position r, c
      v_scroll_bar if ret
      return ret
    end
    # @return [true, false] false if r,c not changed
    def increment_view_col num
      r, c = @viewport.get_pad_top_left()
      #r = @viewport.row() #- @viewport.top_margin
      #c = @viewport.col() #- @viewport.left_margin
      c += num
      ret = set_view_position r, c
      h_scroll_bar if ret
      return ret
    end
    def repaint # scrollpane
      # viewports child should repaint onto pad
      # viewport then clips
      # this calls viewports refresh from its refresh
      return unless @repaint_required
      if @viewport
        update_child
        $log.debug "SCRP  #{@name} calling viewport repaint"
        #@viewport.repaint_all true # 2010-01-16 23:09 
        @viewport.repaint_required true # changed 2010-01-19 19:34 
        @viewport.repaint # child's repaint should do it on its pad
        $log.debug " #{@name}  SCRP scrollpane repaint #{@graphic.name} "
      end
        # TODO this only if major change
       if @repaint_border && @repaint_all # added 2010-01-16 20:15 
        #@graphic.wclear
        $log.debug " #{@name} repaint all scroll: r #{@row} c #{@col}  h  #{@height}-1 w #{@width} "
        bordercolor = @border_color || $datacolor
        borderatt = @border_attrib || Ncurses::A_NORMAL
        # NOTE - should be width-1 print_b reduces one from width, but
        # not height !

        @graphic.print_border_only(@row, @col, @height-1, @width, bordercolor, borderatt)
        h_scroll_bar
        v_scroll_bar
#x XXX       @viewport.repaint_all(true) unless @viewport.nil? # brought here 2010-01-19 19:34 
        #@repaint_border = false # commented off on 2010-01-16 20:15 so repaint_all can have effect
       end
      return if @viewport == nil
      $log.debug "SCRP   #{@name} calling viewport to SCRP  b2s #{@graphic.name}  "
      paint 
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
        return :UNHANDLED if @viewport.nil? # added 2010-02-02 12:44 
      if @viewport != nil
        $log.debug "    calling child handle_key #{ch} "
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

        return ret if ret != :UNHANDLED
      end
      ret = 0 # default return value
      ks = keycode_tos(ch)
      $log.debug " scrollpane gets KEY #{ch}, ks #{ks} "
      case ch
        when ?\M-n.getbyte(0)
          ## scroll down one row (unless multiplier set)
          ret = down
      when ?\M-p.getbyte(0)
          ## scroll up one row (unless multiplier set)
        ret = up
      #when ?0.getbyte(0), ?\C-[.getbyte(0)
        #goto_start #start of buffer # cursor_start
      #when ?\C-].getbyte(0)
        #goto_end # end / bottom cursor_end # TODO
      when ?\M-\<.getbyte(0)
        @height.times { up ; }
      when ?\M-\>.getbyte(0)
        @height.times { down ; }
      when KEY_DOWN
        ret = down
        #check_curpos
      when  ?\M-h.getbyte(0)
        ## scroll left one position
        repeatm {
          ret = cursor_backward
          @child.cols_panned = @child.cols_panned+1  if ret
          @form.setrowcol @form.row, @form.col+1+@col_outofbounds if ret 
        }
      when  ?\M-l.getbyte(0)
        ## scroll right one position
        repeatm {
          ret = cursor_forward
          @child.cols_panned = @child.cols_panned-1  if ret
          @form.setrowcol @form.row, @form.col-1+@col_outofbounds if ret 
        }
      when KEY_BACKSPACE, 127
        ret = cursor_backward
      #when ?\C-u.getbyte(0)
        ## multiplier. Series is 4 16 64
        #@multiplier = (@multiplier == 0 ? 4 : @multiplier *= 4)
        #return 0
      when ?\C-c.getbyte(0)
        $multiplier = 0
        return 0
      else
        return :UNHANDLED
      end
      ret = :UNHANDLED if !ret
      $multiplier = 0
      return ret # 0 2010-02-04 18:47 returning ret else repaint is happening when UNHANDLED
    end
    # private
    def _down
      increment_view_row(1)
    end
    # private
    def _up
      increment_view_row(-1)
    end
    def cursor_forward
      increment_view_col(1)
    end
    def cursor_backward
      increment_view_col(-1)
    end
    def down
      ## scroll down one row (currently one only)
      $log.debug " MULT DOWN #{$multiplier} "
      repeatm {
      ret = _down
      return unless ret # 2010-02-04 18:29 
      ## we've scrolled down, but we need  to keep the cursor where
      ##+ editing actually is. Isn't this too specific to textarea ?
      $log.debug " SCRP setting row to #{@form.row-1} upon scrolling down  "
      ## only move up the cursor if its within bounds
      #       if @form.row > @row
      @child.rows_panned = @child.rows_panned-1  if ret 
      @form.setrowcol @form.row-1+@row_outofbounds, @form.col if ret 
      }
    end
    def up
          ## scroll up one row (currently one only)
      repeatm {
        ret = _up
        return unless ret # 2010-02-04 18:29 
        $log.debug " SCRP setting row to #{@form.row+1} upon scrolling up R:#{@row} H:#{@height}  "
   #     if @form.row < @row + @height
          @child.rows_panned = @child.rows_panned+1  if ret 
          @form.setrowcol @form.row+1+@row_outofbounds, @form.col if ret 
      }
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
        ret = @viewport.child.set_form_col # added 2010-01-16 21:09 
      end
      $log.debug " FORM SCRP #{@form.name} "
      $log.debug "SCRP set_form_row #{@form.row}  #{@form.col} "
    end
    ## added 2010-02-09 10:17 
    # Sometimes some parent objects may just call this.
    # Would be better if they only called row and row called both ??? or is that less reliable
    # In any case we have to combine this someday!!
    def set_form_col
      #@form.row = @row + 1 unless @form.nil?
      if @viewport != nil
        #$log.debug "    calling scrollpane set_form_row"
        ret = @viewport.child.set_form_col # added 2010-01-16 21:09 
      end
      $log.debug " FORM SCRP #{@form.name} "
      $log.debug "SCRP set_form_col #{@form.row}  #{@form.col} "
    end

    ## this is called once only, on select_field by form.
    ##+ after that not at all.
    def rowcol
      r1 = @row #+@row_offset
      c1 = @col #+@col_offset
      return r1, c1 if @viewport.nil? # added 2010-02-02 12:41 

      r,c = @viewport.child.rowcol # added 2009-12-28 15:23 BUFFERED
      $log.debug "SCRP rowcol:  #{r1} + #{r} , #{c1} + #{c} "
      return r1+r, c1+c
    end

    def paint
      @repaint_required = false
      @repaint_all = false
    end
    def h_scroll_bar
      return if @viewport.nil?
      sz = (@viewport.width*1.00/@viewport.child().width)*@viewport.width
      #$log.debug " h_scroll_bar sz #{sz}, #{@viewport.width} #{@viewport.child().width}" 
      sz = sz.ceil
      return if sz < 1
      start = 1
      start = ((@viewport.col*1.00+@viewport.width)/@viewport.child().width)*@viewport.width
      start -= sz
      start = start.ceil
      # # the problem with next 2 lines is that attributes of border could be overwritten
      # draw horiz line
      r = @row #+ @ext_row_offset # 2010-02-11 11:57 RFED16
      c = @col #+ @ext_col_offset # 2010-02-11 11:57 RFED16
      $log.debug " h_scroll_bar start #{start}, r #{r} c #{c} h:#{@height} "
      @graphic.rb_mvwhline(r+@height-1, c+1, ACS_HLINE, @width-2)
      # draw scroll bar
      #sz.times{ |i| @graphic.mvaddch(r+@height-1, c+start+1+i, ACS_CKBOARD) }
      sz.times{ |i| @graphic.rb_mvaddch(r+@height-1, c+start+1+i, ACS_CKBOARD) }
    end
    def v_scroll_bar
        return if @viewport.nil?
      sz = (@viewport.height*1.00/@viewport.child().height)*@viewport.height
      #$log.debug " v_scroll_bar sz #{sz}, #{@viewport.width} #{@viewport.child().width}" 
      sz = sz.ceil
      return if sz < 1
      start = 1 
      start = ((@viewport.row*1.00+@viewport.height)/@viewport.child().height)*@viewport.height
      start -= sz
      r = @row #+ @ext_row_offset # 2010-02-11 11:57 RFED16
      c = @col #+ @ext_col_offset # 2010-02-11 11:57 RFED16
      $log.debug " v_scroll_bar start #{start}, col:#{@col} w:#{@width}, r #{r}+1 c #{c}+w-1 " 
      start = start.ceil
      # # the problem with next 2 lines is that attributes of border could be overwritten
      # draw verti line
      # this is needed to erase previous bar when shrinking
      #@graphic.mvwvline(r+1,c+@width-1, ACS_VLINE, @height-2)
      @graphic.rb_mvwvline(r+1,c+@width-1, ACS_VLINE, @height-2)
      # draw scroll bar
      #sz.times{ |i| @graphic.mvaddch(r+start+1+i, c+@width-1, ACS_CKBOARD) }
      sz.times{ |i| @graphic.rb_mvaddch(r+start+1+i, c+@width-1, ACS_CKBOARD) }
    end
    # set height
    # a container must pass down changes in size to it's children
    #  2010-02-04 18:06 - i am not sure about this. When viewport is set then it passes down 
    #  changes to child which user did not intend. Maybe in splitpane it is okay but other cases?
    #  Perhaps its okay if scrollpane gets larger than child, not otherwise.
    # added 2010-01-16 23:55 
      def height(*val)
          return @height if val.empty?
          oldvalue = @height || 0
          super
          @height = val[0]
          return if @viewport == nil
          delta = @height - oldvalue
          return if delta == 0
          @repaint_required = true
          @viewport.height += delta
      end
    # set width
    # a container must pass down changes in size to it's children
    # added 2010-01-16 23:55 
      def width(*val)
          return @width if val.empty?
          oldvalue = @width || 0
          super
          @width = val[0]
          return if @viewport == nil
          delta = @width - oldvalue
          return if delta == 0
          @repaint_required = true
          @viewport.width += delta
      end

  end # class ScrollPane
end # module
