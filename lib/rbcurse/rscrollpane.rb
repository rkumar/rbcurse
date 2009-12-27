=begin
  * Name: Scrollpane
  * Description: a scrollable widget allowing user to scroll and view
    parts of underlying object that typically are larger than screen area.
    Mainly, contains a viewport, scrollbars and manages viewport through usage
    of scrollbars.
    Also contains viewport for row and columns.
  * Author: rkumar 
TODO section:
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
      #@row_offset = @col_offset = 1
      #@orig_col = @col
      # this does result in a blank line if we insert after creating. That's required at 
      # present if we wish to only insert
      init_vars
      # create_b moved from repain since we need to pass form to child component
      @subpad=create_buffer # added 2009-12-27 13:35 BUFFERED  (moved from repaint)
      @subform = RubyCurses::Form.new @subpad # added 2009-12-27 13:35 BUFFERED  (moved from repaint)
    end
    # set child component being used in viewport
    # @see set_viewport_view
    def child ch
      ch.set_form(@subform) # nothing is shown, something is missing added 2009-12-27 13:35 BUFFERED 
      if ch != nil
        set_viewport_view(ch)
      end
    end
    def init_vars
      #@curpos = @pcol = @toprow = @current_index = 0
      @hsb_policy = :AS_NEEDED
      @vsb_policy = :AS_NEEDED
      @repaint_required = true
      @repaint_border = true
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
        # TODO this only if major change
       if @repaint_border
        @graphic.wclear
        $log.debug " repaint scroll r #{@row} c #{@col}  h  #{@height} w #{@width} "
        bordercolor = @border_color || $datacolor
        borderatt = @border_attrib || Ncurses::A_NORMAL
        #@graphic.print_border(0, 0, @height-1, @width-1, bordercolor, borderatt)
        @graphic.print_border(@row, @col, @height-1, @width, bordercolor, borderatt)
#        @graphic.printstring(@row+1,@col+1, "SCROLLA", $datacolor)
        h_scroll_bar
        v_scroll_bar
        @repaint_border = false
       end
      return if @viewport == nil
      $log.debug "SCRP calling viewport repaint"
      @viewport.repaint # child's repaint should do it on its pad
      # @viewport.get_buffer().set_screen_row_col(@viewport.row, @viewport.col)
      $log.debug "SCRP calling viewport b2s "
      ret = @viewport.buffer_to_screen(@graphic)
      $log.debug " rscollpane vp b2s ret = #{ret} "
#      @graphic.printstring(@row+2,@col+2, "SCREOLL", $datacolor)

      @buffer_modified = true
      paint # has to paint border if needed, and scrollbars
      # TODO
    end
    def getvalue
      # TODO
    end
    ## most likely should just return an unhandled and not try being intelligent
    def handle_key ch
      # TODO
      # if this gets key it should just hand it to child
      if @viewport != nil
        $log.debug "    calling child handle_key KEY"
        ret = @viewport.handle_key ch
        @repaint_required = true if ret  # added 2009-12-27 22:21 BUFFERED
        $log.debug "  ... child ret #{ret}"
        return ret if ret == 0
      end
      $log.debug " scrollpane gets KEY #{ch}"
      case ch
        when ?\M-n.getbyte(0)
        ret = down
        #scroll_forward # TODO
      when ?\M-p.getbyte(0)
        ret = up
        #scroll_backward # TODO
      when ?0.getbyte(0), ?\C-[.getbyte(0)
        goto_start #start of buffer # cursor_start
      when ?\C-].getbyte(0)
        goto_end # end / bottom cursor_end # TODO
      when KEY_UP
        #select_prev_row
        ret = up
        #check_curpos
      when KEY_DOWN
        ret = down
        #check_curpos
      when KEY_LEFT
        cursor_backward
      when KEY_RIGHT
        cursor_forward
      when KEY_BACKSPACE, 127
        cursor_backward
      end

       $log.debug " scrollpane gets KEY #{ch}"
      # if this gets key it should just hand it to child
      if @viewport != nil
        $log.debug "    calling child handle_key KEY"
        ret = @viewport.handle_key ch
        @repaint_required = true if ret  # added 2009-12-27 22:21 BUFFERED
        $log.debug "  ... child ret #{ret}"
        return :UNHANDLED if ret == :UNHANDLED
      else
        $log.debug "  ... handle_key child nil KEY"
        return :UNHANDLED
      end
      return 0
      #$log.debug "TV after loop : curpos #{@curpos} blen: #{@buffer.length}"
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
=begin
    def on_enter   # TODO ???
      super
      set_form_row
    end
    def set_form_row   # TODO ???
      @form.row = @row + 1 unless @form.nil?
    end
=end

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
