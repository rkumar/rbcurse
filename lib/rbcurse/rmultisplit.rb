=begin
  * Name: MultiSplit
  * Description: allows user to create multiple splits
  * This diverges from the standard SplitPane which allowed one split only.
    This is inspired by the column-browse pattern as in when we view rdoc in a browser.
    A user does not need to create multiple split panes embedded inside each other, we
    don't have that kind of space, and expanding can be tricky since there is no mouse 
    to select panes. Mostly, this makes creating apps with this pattern easy for user.


  * NOTE that VERTICAL_SPLIT means the *divider* is vertical.
  * Author: rkumar (arunachalesha)
  * file created  2010-08-31 20:18 
Todo: 
  --------
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
#require 'rubygems'
#require 'ncurses'
require 'logger'
require 'rbcurse'

#include Ncurses # FFI 2011-09-8 
include RubyCurses
module RubyCurses
  extend self

  ##
  # A MultiSplit allows user to split N components vertically or horizontally.
  # such as 3 listboxes, each dependent on what is selected in previous.
  # This is the column-browse pattern, as in ruby's rdoc when seen in a browser.
  # Also, this can be used for directory browsing, as in OSX Finder.
  # One can keep adding components, and scroll
  # back and forth, so we can have more components than are visible. See testmultispl.rb
  # for a demo of this.
  #
  # This class allows for adding components in one direction, vertical or horizontal. It differs
  # from Vimsplit in that you can have offscreen windows and scroll through. Vimsplit shows
  # all windows but allows stacking and flowing of components.
  #
  # @since 1.1.5
  # TODO - 
  #  [ ] Don't print title if width less than title XXX or truncate - listbox
  #  x user specify max panes to show (beyond that hide and pan)
  #  x how many can be created
  #  - to squeeze panes and fit all or hide and pan
  #  x allow resize of panes
  #  - allow orientation change or not
  #  x some anamoly reg LEAVE and ENTER from last object
  #  x should we not be managing on_enter of listboxes when tabbing ?
  #  x how many panes to show, max to create
  #  x increase size - currently i recalc each time!
  #  x print more marker
  #  - allow user to specify preferred sizes and respect that
  #  x don't move to an empty list, can have a crash
  #  
  
  class MultiSplit < Widget
      dsl_property :orientation  # :VERTICAL_SPLIT or :HORIZONTAL_SPLIT
      dsl_accessor :border_color
      dsl_accessor :border_attrib
      # if no components have been added at time of repainting
      #+ we could use this. This idea if that a user may want to 
      #+ show blank splits.
      dsl_property :split_count
      # should we allow adding more than split_count
      # currently, we don't scroll, we narrow what is shown
      dsl_accessor :unlimited
      # allow user to resize components, default true
      dsl_accessor :allow_resizing # XXX unused
      # allow user to flip / exhange 2 components or not, default false
      dsl_accessor :allow_exchanging # XXX unused
      # when focus reenters this component, should it focus
      # on first internal component, or last focused component.
      # True means it will focus on first component (or last, if backtabbing)
      dsl_accessor :cyclic_behavior
      # maximum to show, if less than split_count then scrolling
      dsl_property :max_visible
      attr_reader :components
      # should borders be suppressed or printed
      dsl_accessor :suppress_borders

      #attr_accessor :one_touch_expandable # boolean, default true  # XXX

      def initialize form, config={}, &block
          @focusable = true
          @editable = false
          @cyclic_behavior = true
          @row = 0
          @col = 0
          @split_count = nil
          # this is the list of components
          @components = []
          # need to recalculate offsets and dimensions of all comps since new one added
          # to be done once in repaint, and whenever a new one added (in repaint)
          @recalc_required = true
          @row_offset = @col_offset = 1
          @suppress_borders = false
          super
          @orig_col = @col
          @use_absolute = true; # set to true if not using subwins XXX CLEAN THIS
          init_vars
      end
      def init_vars  #:nodoc:
          @_first_column_print = 0 # added 2009-10-07 11:25 
          @max_visible ||= @split_count
          @_last_column_print = @_first_column_print + @max_visible - 1
          
          # cascade_changes keeps the child exactly sized as per the pane which looks nice
          #+ but may not really be what you want.
          @cascade_changes=true
          ## if this splp is increased (ht or wid) then expand the child
          @cascade_boundary_changes = true
          @orientation ||= :HORIZONTAL_SPLIT # added 2010-01-13 15:05 since not set

          # true means will request child to create a buffer, since cropping will be needed
          # FIXME: if true then increases in size are not having effect !!!
          @_child_buffering = false # private, internal. not to be changed by callers.
          #@one_touch_expandable = true
          #@is_expanding = false
          @row_offset = @col_offset = 0 if @suppress_borders

          #bind_key([?\C-w, ?o], :expand)
          #bind_key([?\C-w, ?1], :expand)
          #bind_key([?\C-w, ?2], :unexpand)
          #bind_key([?\C-w, ?x], :exchange)
          bind_key(?w, :goto_next_component)
          bind_key(?b, :goto_prev_component)
          bind_key([?\C-w, ?-], :decrease)
          bind_key([?\C-w, ?+], :increase)
          bind_key([?\C-w, ?=], :same)

      end
      ## 
      # adds a component to the multisplit
      # When you add a component to a container such as multisplit, be sure
      # you create it with a nil form object, or else the main form will try to manage it.
      # Containers typically manage their own components such as navigation and they
      # give it the form/graphic object they were created with.
      # @param [widget] a widget object to stack in a pane
      def add comp
        # for starters to make life simple, we force user to specify how many splits
        # This is largely because i don;t know much about the buffering thing, is it still
        # needed here or what. If we can postpone it, then we can compute this in a loop 
        # in repaint
        raise "split_count must be given first. How many splits there will be." unless @split_count
        $log.debug " multisplit:  Adding a component #{@components.size}  "

        # until we hide those outside bounds, or are able to scroll, lets not allow add if
        # exceeds
        if @components.size >= @split_count
          if @unlimited
            #@split_count = @components.size + 1
            # calc of width depending on ths
          else
            Ncurses.beep
            return
          end
        end
        @recalc_required = true
        @components = [] if @components.nil?
        @components << comp
        #comp.height = nil # nuking listboxes height since it gets calculated
        comp.parent_component = self 
        # dang ! this can go out of bounds ! XXX tab goes out
        index = @components.size - 1 # expected as base 0 in compute
        #index = @max_visible - 1 if index > @max_visible - 1
        # all this ado to prevent cursor going out in the first display
        # when index exceeds visible, since compute now uses running balance
        if index > @max_visible - 1
          # we copy the coords of the previous one
          prev = @components[index-1]
          comp.row = prev.row
          comp.col = prev.col
          comp.width = prev.width
          comp.height = prev.height
        else
          compute_component comp, index
        end
        comp.set_buffering(:target_window => @target_window || @form.window, :bottom => comp.height-1, :right => comp.width-1, :form => @form ) # removed on 2011-09-29 
        comp.min_height ||= 5
        comp.min_width ||= 5
        return self
      end
      alias :<< :add

      def [](index)
        raise "MultiSplit: Please add components first" unless @components
        @components[index]
      end
      def size
        @components.size
      end
      alias :length :size
      ##
      # compute component dimensions in one place
      # @param [widget] a widget 
      # @param [Fixnum] offset in list of components 
      # XXX if called from outside balance can have last value !!!
      # FIXME for last component, take as much as is left height or width
      # otherwise odd figures will leave on row unoccupied
      def compute_component comp, index
        @balance ||= 0
        if @orientation == :HORIZONTAL_SPLIT
          # XXX NOT TESTED TODO
          @comp_height = (@height / @split_count) - 0
          @comp_width = @width
          h = @comp_height
          if @recalc_required
            comp.height = h  # listboxes etal calculate a height so that will stand !! XXX
          else
            comp.height ||= h  # listboxes etal calculate a height so that will stand !! XXX
          end
          w = @comp_width
          #r = @row + ( comp.height * index)
          r = @row + @balance
          if r > @row + @height
            r = @row + @height
          end
          #alert "r #{@row} h #{@height} ::: comp row #{r} h #{h} bal:#{@balance} "
          @balance += comp.height
          c = @col
          comp.width = w
          comp.row = r
          comp.col = c
        else
          @comp_height = @height
          @comp_width = (@width / @split_count) - 0
          h = @comp_height 
          w = @comp_width
          if @recalc_required
            comp.width = w
          else
            comp.width ||= w
          end
          #c = @col + ( w * index) # this makes them all equal
          c = @col + @balance
          if c > @col + @width
            c = @col + @width
          end
          $log.debug "XXXX index #{index} , w #{comp.width} , c = #{c} , bal #{@balance} c+w:#{@col+@width} "
          #if index < @max_visible - 1
            @balance += comp.width
          #end
          r = @row
          comp.height = h
          comp.row = r
          comp.col = c
          #$log.debug " XXXX index  r c #{r} #{c} "
        end
        comp
      end
      def increase 
        _multiplier = ($multiplier == 0 ? 1 : $multiplier )
        delta = _multiplier
        c = @current_component 
        n = get_next_component
        n = get_prev_component unless n 
        return unless n
        if @orientation == :HORIZONTAL_SPLIT
          if n.height > 3 + delta
            c.height += delta
            n.height -= delta
          end
        else
          if n.width > 3 + delta
            c.width += delta
            n.width -= delta
          end
        end
        @repaint_required = true
        self
      end
      # decrease size of current component. 
      # if last one, then border printing exceeds right boundary. values look okay
      # dunno why XXX FIXME
      def decrease 
        _multiplier = ($multiplier == 0 ? 1 : $multiplier )
        delta = _multiplier
        $log.debug "XXXX decrease got mult #{$_multiplier} "
        c = @current_component 
        # if decreasing last component then increase previous
        # otherwise always increase the next
        n = get_next_component || get_prev_component 
        return unless n # if no other, don't allow
        if @orientation == :HORIZONTAL_SPLIT
          c.height -= delta
          n.height += delta
          # TODO
        else
          if c.width > 3 + delta
            c.width -= delta
            n.width += delta
          end
        end
        @repaint_required = true
        self
      end
      def same
        @components.each do |comp| 
          comp.height = @comp_height
          comp.width = @comp_width
        end
        @repaint_required = true
        self
      end
      # @return [widget] next component or nil if no next
      def get_next_component
        return @components[@current_index+1] 
      end
      # @return [widget] prev component or nil if no next
      def get_prev_component
        return nil if @current_index == 0
        return @components[@current_index-1] 
      end
      ##
      #
      # change height of splitpane
      # @param val [int] new height of splitpane
      # @return [int] old ht if nil passed
      def height(*val)
          return @height if val.empty?
          oldvalue = @height || 0
          super
          @height = val[0]
          return if @components.nil? || @components.empty?
          delta = @height - oldvalue
          @repaint_required = true
          if !@cascade_boundary_changes.nil?
            # must tell children if height changed which will happen in nested splitpanes
            # must adjust to components own offsets too
            if @orientation == :VERTICAL_SPLIT
              @components.each do |e| 
                e.height += delta
              end
            else
              e = @components.first
              e.height += delta
            end
          end
      end
      ##
      # change width of splitpane
      # @param val [int, nil] new width of splitpane
      # @return [int] old width if nil passed
      # NOTE: if VERTICAL, then expand or contract only second
      # If HORIZ then expand / contract both
      # Actually this is very complicated since reducing should take into account min_width
      def width(*val)
          return @width if val.empty?
          # must tell children if height changed which will happen in nested splitpanes
          oldvalue = @width || 0
          super
          @width = val[0]
          delta = @width - oldvalue
          $log.debug " SPLP #{@name} width #{oldvalue}, #{@width}, #{delta} "
          @repaint_required = true
          if !@cascade_boundary_changes.nil?
            # must adjust to components own offsets too
            # NOTE: 2010-01-10 20:11 if we increase width by one, each time will both components get increased by one.
            if @orientation == :HORIZONTAL_SPLIT
              @components.each do |e| 
                e.width += delta
              end
            else
              # any change in width must effect col of others too ! 2010-08-31 21:57 AUG2010
              # which is why this should be done in repaint and not here
              # ## next change should only happen if sc w < ...
              # if @second_component.width < @width - (rc + @col_offset + @divider_offset + 1)
              last = @components.last
              last.width += delta
            end
          end
      end
      ##
      # resets divider location based on preferred size of first component
      # @return :ERROR if min sizes failed
      # You may want to check for ERROR and if so, resize_weight to 0.50
      def reset_to_preferred_sizes
        alert "TODO THIS reset_to "
        return if @components.nil?
        @repaint_required = true
      end
      # recalculates components and calls repaint
      def update_components #   #:nodoc:
        @balance = 0
        @max_visible ||= @split_count
        @_first_column_print ||= 0
        @_last_column_print = @_first_column_print + @max_visible - 1
        $log.debug " XXXX #{@_first_column_print} , last print #{@_last_column_print} "
        @components.each_with_index do |comp,index| 
          next if index < @_first_column_print
          break if index > @_last_column_print
          compute_component comp, index 
          comp.set_buffering(:target_window => @target_window || @form.window, :form => @form ) # 2011-09-29 
          #comp.set_buffering(:target_window => @target_window || @form.window, :bottom => comp.height-1, :right => comp.width-1, :form => @form )
          comp.repaint
        end
        #@balance = 0
        @recalc_required = false
      end
      def repaint # multisplitpane  #:nodoc:
        if @graphic.nil?
          @graphic = @target_window || @form.window
          raise "graphic nil in rsplitpane #{@name} " unless @graphic
        end

        if @repaint_required
          # repaint all ?
          @components.each { |e| e.repaint_all(true) }
        end
        if @repaint_required
          ## paint border and divider
          $log.debug "MULTISPLP #{@name} repaint split H #{@height} W #{@width} "
          bordercolor = @border_color || $datacolor
          borderatt = @border_attrib || Ncurses::A_NORMAL
          absrow = abscol = 0
          if @use_absolute
            absrow = @row
            abscol = @col
          end
          if @use_absolute
            $log.debug " #{@graphic} #{name} calling print_border #{@row} #{@col} #{@height}-1 #{@width}-1 "
            @graphic.print_border(@row, @col, @height-1, @width-1, bordercolor, borderatt) if !@suppress_borders
          else
            $log.debug " #{@graphic} calling print_border 0,0"
            @graphic.print_border(0, 0, @height-1, @width-1, bordercolor, borderatt) unless @suppress_borders
          end
          rc = -1

          @graphic.attron(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
          # 2010-02-14 18:23 - non buffered, have to make relative coords into absolute
          #+ by adding row and col
            count = @components.nil? ? @split_count : @components.size
            count = @components.empty? ? @split_count : @components.size
          if @orientation == :VERTICAL_SPLIT
            @comp_height ||= @height
            @comp_width ||= (@width / @split_count) - 0
            $log.debug "SPLP #{@name} prtingign split vline divider 1, rc: #{rc}, h:#{@height} - 2 "
            #@graphic.mvvline(absrow+1, rc+abscol, 0, @height-2)
      #      (1...count).each(){|i| @graphic.mvvline(absrow+1, (i*@comp_width)+abscol, 0, @height-2) }
            # TODO put vlines here
            # commented off since it uses fixed values and we are increaseing and dec

          else
            @comp_height ||= (@height / @split_count) - 1
            @comp_width ||= @width
            #$log.debug "SPLP #{@name} prtingign split hline divider rc: #{rc} , 1 , w:#{@width} - 2"
            #@graphic.mvhline(rc+absrow, abscol+1, 0, @width-2)
            # XXX in next line -2 at end was causing an overlap into final border col, 
            # this need correction in splitpane XXX
            #(1...count).each(){|i| @graphic.mvhline((i*@comp_height)+absrow, abscol+1, 0, @width-3) }
            # TODO put hlines here
          end
          @graphic.attroff(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
        update_components
        _print_more_columns_marker true
        @graphic.wrefresh # 2010-02-14 20:18 SUBWIN ONLY ??? what is this doing here ? XXX
        else
          # repaint only those components that may have changed
          @components.each { |e| e.repaint }
        end
        ## XXX do not paint what is outside of bounds. See tabbedpane or scrollform
        #paint 
        @repaint_required = false
      end
      def getvalue  #:nodoc:
          # TODO
      end
      # take focus to next pane (component in it)
      # if its the last, return UNHANDLED so form can take to next field
      # @return [0, :UNHANDLED] success, or last component

      def goto_next_component
        if @current_component != nil 
          @current_component.on_leave
          if on_last_component?
            return :UNHANDLED
          end
          @current_index += 1
          @current_component = @components[@current_index] 
          # is it visible
          #@current_index.between?(_first_column_print, _last_column_print)
          if @current_index > @_last_column_print
            # TODO need to check for exceeding
            @_first_column_print += 1
            @_last_column_print += 1
            @repaint_required = true
          end
          # shoot if this this put on a form with other widgets
          # we would never get out, should return nil -1 in handle key
          unless @current_component
            $log.debug " CAME HERE unless @current_component setting to first"
            raise " CAME HERE unless @current_component setting to first"
            @current_index = 0
            @current_component = @components[@current_index] 
          end
        else
          # this happens in one_tab_expand
          #@current_component = @second_component if @first_component.nil?
          #@current_component = @first_component if @second_component.nil?
          # XXX not sure what to do here, will it come
          $log.debug " CAME HERE in else clause MSP setting to first"
          raise" CAME HERE in else clause MSP setting to first"
          @current_index = 0
          @current_component = @components[@current_index] 
        end
        return set_form_row
      end

      # take focus to prev pane (component in it)
      # if its the first, return UNHANDLED so form can take to prev field
      # @return [0, :UNHANDLED] success, or first component
      def goto_prev_component
        if @current_component != nil 
          @current_component.on_leave
          if on_first_component?
            return :UNHANDLED
          end
          @current_index -= 1
          @current_component = @components[@current_index] 
          if @current_index < @_first_column_print
            # TODO need to check for zero
            @_first_column_print -= 1
            @_last_column_print -= 1
            @repaint_required = true
          end
          # shoot if this this put on a form with other widgets
          # we would never get out, should return nil -1 in handle key
          unless @current_component
            @current_index = 0
            @current_component = @components[@current_index] 
          end
        else
          # this happens in one_tab_expand
          #@current_component = @second_component if @first_component.nil?
          #@current_component = @first_component if @second_component.nil?
          # XXX not sure what to do here, will it come
          @current_index = 0
          @current_component = @components[@current_index] 
        end
        set_form_row
        return 0
      end
      def on_first_component?
        @current_component == @components.first
      end
      def on_last_component?
        @current_component == @components.last
      end
      ## Handles key for splitpanes
      ## By default, first component gets focus, not the SPL itself.
      ##+ Mostly passing to child, and handling child's left-overs.
      # please use bind_key for all mappings.
      # Avoid adding code in here. Let this be generic
      def handle_key ch  #:nodoc:
        _multiplier = ($multiplier == 0 ? 1 : $multiplier )
        @current_component ||= @first_component
        @current_index ||= 0
        ## 2010-01-15 12:57 this helps me switch between highest level 
        ## However, i should do as follows:
        ## If tab on second component, return UNHA so form can take to next field
        ## If B_tab on second comp, switch to first
        ## If B_tab on first comp, return UNHA so form can take to prev field
        if ch == KEY_TAB
           return goto_next_component
           #return 0
        elsif ch == KEY_BTAB
           return goto_prev_component
        end

        if @current_component != nil 
          ret = @current_component.handle_key ch
          return ret if ret != :UNHANDLED
        else
          ## added 2010-01-07 18:59 in case nothing in there.
          $log.debug " SPLP #{@name} - no component installed in splitpane"
          #return :UNHANDLED
        end
        $log.debug " mmplitpane #{@name} gets KEY #{ch}"
        case ch
        when ?\C-c.getbyte(0)
          $multiplier = 0
          return 0
        when ?0.getbyte(0)..?9.getbyte(0)
          $multiplier *= 10 ; $multiplier += (ch-48)
          return 0
        end
        ret = process_key ch, self
        return :UNHANDLED if ret == :UNHANDLED

        $multiplier = 0
        return 0
      end
      def paint  #:nodoc:
        #@repaint_required = false
      end
      # this is executed when the component gets focus
      # and will happen each time on traversal
      # Used to place the focus on correct internal component
      # and place cursor where component should have it.
      # User can press tab, to come here, or it could be first field of form,
      # or he could press a mnemonic.
      def on_enter
        return if @components.nil?
        # cyclic means it always lands into first comp just as in rdoc
        # otherwise it will always land in last visited component
        if @cyclic_behavior
          # if user backtabbed in place him on last comp
          # else place him in first. 
          if $current_key == KEY_BTAB
            @current_component = @components[@_last_column_print]
            @current_index     = @_last_column_print
          else
            @current_component = @components[@_first_column_print]
            @current_index     = @_first_column_print
          end
        end
        @current_component ||= @components.first
        set_form_row
      end
      # sets cursor on correct row, col
      # should we raise error or throw exception if can;t enter
      def set_form_row  #:nodoc:
        if !@current_component.nil?
          c=@current_component 
          $log.debug "XXXXX #{@name} set_form_row calling sfr for #{@current_component.name}, #{c.row}, #{c.col}  "
          #@current_component.set_form_row 
          # trigger the on_enter handler
          # my god XXX this assumes a listbox !! FIXME
          # on enter should return a false or error so we don't proceed
          # or throw exception
          if @current_component.row_count > 0
            @current_component.on_enter # typically on enter does a set_form_row
            # XXX  another assumption that is has this !!!
            @current_component.set_form_col 
            return 0
          end
          #
        end
        return :UNHANDLED
      end
      # added 2010-02-09 10:10 
      # sets the forms cursor column correctly
      # earlier the super was being called which missed out on child's column.
      # Note: splitpane does not use the cursor, so it does not know where cursor should be displayed,
      #+ the child has to decide where it should be displayed.
      def set_form_col  #:nodoc:
        return if @current_component.nil?
        #$log.debug " #{@name} set_form_col calling sfc for #{@current_component.name} "
        @current_component.set_form_col 
      end
      ## expand a split to maximum. This is the one_touch_expandable feature
      # Currently mapped to C-w 1 (mnemonic for one touch), or C-w o (vim's only)
      # To revert, you have to unexpand
      # Note: basically, i nil the component that we don't want to see
      def expand
        return unless @one_touch_expandable
        # TODO
        #@is_expanding = true # this is required so i don't check for min_width later
        #$log.debug " callign expand "
        #if @current_component == @first_component
          #@saved_component = @second_component
          #@second_component = nil
          #if @orientation == :VERTICAL_SPLIT
            #set_divider_location @width - 1
          #else
            #set_divider_location @height - 1
          #end
          #$log.debug " callign expand 2 nil #{@divider_location}, h:#{@height} w: #{@width}  "
        #else
          #@saved_component = @first_component
          #@first_component = nil
          #set_divider_location 1
          #$log.debug " callign expand 1 nil #{@divider_location}, h:#{@height} w: #{@width}  "
        #end
        #@repaint_required = true
      end
      # after expanding one split, revert to original  - actually i reset, rather than revert
      # This only works after expand has been done
      def unexpand
        #$log.debug " inside unexpand "
        #return unless @saved_component
        #if @first_component.nil?
          #@first_component = @saved_component
        #else
          #@second_component = @saved_component
        #end
        #@saved_component = nil
        #@repaint_required = true
        #reset_to_preferred_sizes
      end

      # exchange 2 splits, bound to C-w x
      # TODO 
      def exchange
        alert "TODO"
        #tmp = @first_component
        #@first_component = @second_component
        #@second_component = tmp
        #@repaint_required = true
        #reset_to_preferred_sizes
      end
      def tile
        return unless @tiling_allowed
        # TODO
      end
      private
      def _print_more_columns_marker tf
        # this marker shows that there are more columns to right
        tf = @_last_column_print < @components.size - 1
        marker = tf ?  Ncurses::ACS_CKBOARD : Ncurses::ACS_HLINE
        #@graphic.mvwaddch @row+@height-1, @col+@width-2, marker
        @graphic.mvwaddch @row+@height-1, @col+@width-3, marker
        # show if columns to left or not
        marker = @_first_column_print > 0 ?  Ncurses::ACS_CKBOARD : Ncurses::ACS_HLINE
        @graphic.mvwaddch @row+@height-1, @col+@_first_column_print+1, marker
      end
  end # class 
end # module
