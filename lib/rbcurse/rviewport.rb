=begin
  * Name: Viewport
  * $Id$
  * Description: a viewport thru which you see an underlying form or widget. Scrolling
    the viewport reveals new sections of the underlying object.
  * Author: rkumar arunachala
TODO 
  * file created  2009-10-27 18:05 
Major change 2010-02-11 23:32 
  * removed buffering, was totally unnecessary
  * FIXME avoid repaint and handle_keys totally, let scrollpane talk to child.
    Do we really need this ?
    If we do strip it down to its major function - nothign extraneous. Currently its a huge layer in between.
  --------
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
#require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rchangeevent'

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
    # row and col also present int widget
    dsl_accessor :child  # component that is being viewed
    attr_accessor :cascade_changes
    #attr_reader :top_margin, :left_margin

    def initialize form, config={}, &block
      @focusable = false
      @editable = false
      #@top_margin = @left_margin = 1 # 2010-02-06 23:27  reduce in scrollpane
      @row = 1 # 1 # 0 2010-02-06 22:46 so we don't write on scrollpanes border
      @col = 1 # 1 #  0 2010-02-06 22:47 
      super
      #@row_offset = @col_offset = 1
      #@orig_col = @col
      init_vars
    end
    def init_vars
      #@curpos = @pcol = @toprow = @current_index = 0
      should_create_buffer = true
      @border_width = 2
    end
    # set the component to be viewed
    def set_view ch
      @child = ch
    end
    def set_view_size h,w
      # calling the property shoudl uniformally trigger fire_property_change
      $log.debug " setting viewport to h #{h} , w #{w} "
      height(h)
      width(w)
      fire_state_changed
      #fire_handler :PROPERTY_CHANGE, self # XXX should it be an event STATE_CHANGED with details
    end
    ##
    # Set the row and col of the child, that the viewport starts displaying.
    # Used to initialize the view, and later if scrolling.
    # Initially would be set to 0,0. 
    #
    def set_view_position r,c
      return false if r < 0 or c < 0
      # 2010-02-04 19:29 TRYING -2 for borders
      $log.debug " set_view if #{r} +1+ #{@height} - #{@border_width} )} >=#{@child.height} "
      # 2010-02-12 15:33 XXX made > into >= and added +1 since -1 in set_buffering
      # testscrollp was crashing out when child height exceeded
      if r+ (@height+1-@border_width) >= @child.height
      # basically r + (:bottom - :screen_top) < @child.height
      #if r+ (@height) >= @child.height
        $log.debug " set_view_position : trying to exceed ht #{r} + #{@height} > #{@child.height}  returned false"
        return false
      end
      # testscrollp was printing junk on right end. Why the 1? 
      if c+ (@width+1-@border_width) >=@child.width
      #if c+ (@width) >=@child.width
        $log.debug " set_view_position : trying to exceed width #{c} + #{@width} . returned false"
        return false
      end
      $log.debug " VP row #{@row} col #{@col}, now will be #{r} , #{c} "
      row(r) # commnting off 2010-02-06 22:47 
      col(c) # commnting off 2010-02-06 22:47 
      # next call sets pminrow and pmincol 
      $log.debug " VP setting child buffer pmin to #{r} #{c} "
      @child.get_buffer().set_pad_top_left(r, c)
      # replaced this on 2010-02-26 11:49 HOPE IT WORKS XXX
      #@child.fire_property_change("row", r, r) # XXX quick dirty, this should happen
      @child.repaint_required(true)
      @repaint_required = true
      #fire_handler :PROPERTY_CHANGE, self
      fire_state_changed
      return true
    end
    # instead of using row and col to increment, try using this, since this is what's actually incremented.
    def get_pad_top_left
        p = @child.get_buffer()
        return p.pminrow, p.pmincol
    end
    def repaint # viewport
      return unless @repaint_required
      # should call child's repaint onto pad
      # then this should return clipped pad
       $log.debug "VP calling child #{@child.name}  repaint"
     #x  @graphic.wclear # required otherwise bottom of scrollpane had old rows still repeated. 2010-01-17 22:51 
      @child.repaint_all
      @child.repaint
      paint
    end
    def getvalue
      # TODO ???
    end
    ## most likely should just return an unhandled and not try being intelligent
    # should viewport handle keys or should parent do so directly to child
    def handle_key ch
      # if this gets key it should just hand it to child
      if @child != nil
        ret = @child.handle_key ch
        # 2010-01-19 19:26 commenting off repaint to see.
        return :UNHANDLED if ret == :UNHANDLED
        # moved below return so only if table handles
        @repaint_required=true # added 2009-12-27 22:25 BUFFERED WHY ??
      else
        return :UNHANDLED
      end
      return 0
      #$log.debug "TV after loop : curpos #{@curpos} blen: #{@buffer.length}"
    end
    def paint
      @repaint_required = false
      @repaint_all = false
    end
    # set height
    # a container must pass down changes in size to it's children
    #+ 2010-02-04 18:06 - i am not sure about this. When viewport is set then it passes down 
    #+ changes to child which user did not intend. Maybe in splitpane it is okay but other cases?
    #+ Perhaps its okay if scrollpane gets larger than child, not otherwise.
    # added 2010-01-16 23:55 
      def height(*val)
          return @height if val.empty?
          oldvalue = @height || 0
          super
          @height = val[0]
          return if @child == nil
          delta = @height - oldvalue
          return if delta == 0
          @repaint_required = true
          if @child.height.nil?
             @child.height = @height
             $log.warn " viewport setting child #{@child.name} to default h of #{@height} -- child is usually larger. "
          else
              if @cascade_changes
                  $log.debug "warn!! viewport adding #{delta} to child ht #{child.height} "
                  @child.height += delta
              end
          end
      end
    # set width
    # a container must pass down changes in size to it's children
    # added 2010-01-16 23:55 
      def width(*val)
          return @width if val.empty?
          oldvalue = @width || 0
          super
          @width = val[0]
          return if @child == nil
          delta = @width - oldvalue
          return if delta == 0
          @repaint_required = true
          # another safeguard if user did not enter. usesomething sensible 2010-01-17 15:23 
          if @child.width.nil?
             @child.width = @width
             $log.warn " viewport setting child #{@child.name} to default w of #{@width}. Usually child is larger. "
          else
              ## sometime we are needless increasing. this happens when we set viewport and
              ##+ child has been set. Or may do only if scrollpane is getting larger than child
              ##+ largely a situation with splitpanes.
              if @cascade_changes
                  $log.debug "warn!! viewport adding #{delta} to child wt #{child.width} "
                  @child.width += delta
              end
          end
      end
      # should this be in widget ?
      # inform listeners that state has changed
      def fire_state_changed
        @sce = ChangeEvent.new(self) if @sce.nil?
        fire_handler :STATE_CHANGE, @sce
      end
  end # class viewport
end # module
