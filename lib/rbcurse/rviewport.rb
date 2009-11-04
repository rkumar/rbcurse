=begin
  * Name: Viewport
  * $Id$
  * Description: a viewport thru which you see an underlying form or widget. Scrolling
    the viewport reveals new sections of the underlying object.
  * Author: rkumar (arunachalesha)
TODO 
  * file created  2009-10-27 18:05 
  --------
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
#require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'

include Ncurses
include RubyCurses
module RubyCurses
  extend self

  ##
  # A viewport or porthole throgh which one can see portions of underlying object
  # such as textarea, table or a form, usually the underlying data is larger
  # than what can be displayed and thus must be seen through a viewport.
  # TODO - 
  
  class Viewport < Widget
    #dsl_property :height  # height of viewport
    #dsl_accessor :width  # already present in widget
    # row and col also present int widget
    dsl_accessor :child  # component that is being viewed

    def initialize form, config={}, &block
      @focusable = false
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
    end
    def init_vars
      #@curpos = @pcol = @toprow = @current_index = 0
    end
    # set the component to be viewed
    def set_view ch
      @child = ch
    end
    def set_view_size h,w
      # calling the property shoudl uniformally trigger fire_property_change
      height(h)
      width(w)
      #fire_handler :PROPERTY_CHANGE, self # XXX should it be an event STATE_CHANGED with details
    end
    ##
    # Set the row and col of the child, that the viewport starts displaying.
    # Used to initialize the view, and later if scrolling.
    # Initially would be set to 0,0. 
    #
    def set_view_position r,c
      return false if r < 0 or c < 0
      if r+ @height > @child.height
        $log.debug " set_view_position : trying to exceed ht #{r} + #{@height}  returned"
        return false
      end
      if c+ @width > @child.width
        $log.debug " set_view_position : trying to exceed width #{c} + #{@width} . returned"
        return false
      end
      row(r)
      col(c)
      @child.get_buffer().set_pad_top_left(r, c)
      @child.fire_property_change("row", r, r) # XXX quick dirty, this should happen
      @repaint_required = true
      #fire_handler :PROPERTY_CHANGE, self
      return true
    end
    def repaint # viewport
      if @screen_buffer == nil
        create_buffer
      end
      return unless @repaint_required
      # should call child's repaint onto pad
      # then this should return clipped pad
       $log.debug "VP calling child repaint"
      @child.repaint
      # copy as much of child's buffer to own as per dimensions
      # @child.get_buffer().set_screen_row_col(@child.row, @child.col)
       $log.debug "VP calling child b2s"
#        @graphic.printstring(@row+1,@col+6, "VIEWP", $datacolor)
#        @child.get_buffer().printstring(@row+5,@col+8, "CHILD", $datacolor)
      ret = @child.buffer_to_screen(@graphic)
#        @graphic.printstring(@row+3,@col+6, "VIEWPORT", $datacolor)
      @buffer_modified = true
      paint
      # TODO
    end
    def getvalue
      # TODO
    end
    ## most likely should just return an unhandled and not try being intelligent
    # should viewport handle keys or should parent do so directly to child
    def handle_key ch
      # TODO
      # if this gets key it should just hand it to child
      if @child != nil
        ret = @child.handle_key ch
        return :UNHANDLED if ret == :UNHANDLED
      else
        return :UNHANDLED
      end
      return 0
      #$log.debug "TV after loop : curpos #{@curpos} blen: #{@buffer.length}"
    end
    def paint
      @repaint_required = false
    end
  end # class viewport
end # module
