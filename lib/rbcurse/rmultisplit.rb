=begin
  * Name: MultiSplit
  * Description: allows user to create multiple splits
  * This diverges from the standard SplitPane which allowed one split only.
    This is inspired by the column-browse patter as in when we view rdoc in a browser.
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
require 'ncurses'
require 'logger'
require 'rbcurse'

include Ncurses
include RubyCurses
module RubyCurses
  extend self

  ##
  # A MultiSplit allows user to split N components vertically or horizontally.
  # such as 3 listboxes, each dependent on what is selected in previous.
  # This is the column-browse pattern, as in ruby's rdoc when seen in a browser.
  # Also, this can be used for directory browsing, as in OSX Finder.
  # At some point, it should be possible to keep adding components, and to scroll
  # back and forth, so we can have more components than are visible.
  #
  # @since 1.1.5
  # TODO - 
  #  - user specify max panes to show (beyond that hide and pan)
  #  - how many can be created
  #  - to squeeze panes and fit all or hide and pan
  #  - allow resize of panes
  #  - allow orientation change or not
  #  - some anamoly reg LEAVE and ENTER from last object
  
  class MultiSplit < Widget
      dsl_property :orientation  # :VERTICAL_SPLIT or :HORIZONTAL_SPLIT
      attr_reader :divider_location  # XXX
      attr_reader :resize_weight     # XXX
      attr_writer :last_divider_location
      dsl_accessor :border_color
      dsl_accessor :border_attrib
      # if no components have been added at time of repainting
      #+ we could use this. This idea if that a user may want to 
      #+ show blank splits.
      dsl_accessor :split_count
      # should we allow adding more than split_count
      # currently, we don't scroll, we narrow what is shown
      dsl_accessor :unlimited
      attr_accessor :one_touch_expandable # boolean, default true  # XXX

      def initialize form, config={}, &block
          @focusable = true
          @editable = false
          @row = 0
          @col = 0
          @split_count = nil
          # this is the list of components
          @components = []
          # need to recalculate offsets and dimensions of all comps since new one added
          # to be done once in repaint, and whenever a new one added (in repaint)
          @recalc_required = true
          super
          @row_offset = @col_offset = 1
          @orig_col = @col
          @use_absolute = true; # set to true if not using subwins XXX CLEAN THIS
          init_vars
      end
      def init_vars
          @divider_location ||= 10
          @divider_offset ||= 0
          
          # cascade_changes keeps the child exactly sized as per the pane which looks nice
          #+ but may not really be what you want.
          @cascade_changes=true
          ## if this splp is increased (ht or wid) then expand the child
          @cascade_boundary_changes = true
          @orientation ||= :HORIZONTAL_SPLIT # added 2010-01-13 15:05 since not set

          # true means will request child to create a buffer, since cropping will be needed
          @_child_buffering = true # private, internal. not to be changed by callers.
          @one_touch_expandable = true
          @is_expanding = false

          bind_key([?\C-w, ?o], :expand)
          bind_key([?\C-w, ?1], :expand)
          bind_key([?\C-w, ?2], :unexpand)
          bind_key([?\C-w, ?x], :exchange)

      end
      ## 
      # adds a component to the multisplit
      # @param [widget] a widget object to stack in a pane
      def add comp
        # for starters to make life simple, we force user to specify how many splits
        # This is largely because i don;t know much about the buffering thing, is it still
        # needed here or what. If we can postpone it, then we can compute this in a loop 
        # in repaint
        raise "split_count must be given first. How many splits there will be." unless @split_count
        # until we hide those outside bounds, or are able to scroll, lets not allow add if
        # exceeds
        if @components.size >= @split_count
          if @unlimited
            @split_count = @components.size + 1
          else
            Ncurses.beep
            return
          end
        end
        @recalc_required = true
        @components = [] if @components.nil?
        @components << comp
        comp.parent_component = self 
        comp.should_create_buffer = @_child_buffering 
        # next 2 not sure, is it for first only
        comp.ext_row_offset += @ext_row_offset + @row #- @subform1.window.top #0# screen_row
        comp.ext_col_offset += @ext_col_offset + @col #-@subform1.window.left # 0# screen_col
        # but we've not calculated height and width !
        index = @components.size
        # temporarily just to get old code running
        # what if component removed XXX
        case index
        when 0
          @first_component = comp
        when 1
          @second_component = comp
        end
        compute_component comp, index
        comp.set_buffering(:target_window => @target_window || @form.window, :bottom => comp.height-1, :right => comp.width-1, :form => @form )
        comp.set_buffering(:screen_top => @row, :screen_left => @col)
        comp.min_height ||= 5
        comp.min_width ||= 5
      end
      ##
      # compute component dimensions in one place
      # @param [widget] a widget 
      # @param [Fixnum] offset in list of components
      def compute_component comp, index
        if @orientation == :HORIZONTAL_SPLIT
          @comp_height = (@height / @split_count) - 1
          @comp_width = @width
          h = @comp_height
          w = @comp_width
          r = @row + ( h * index)
          c = @col
          comp.height = h
          comp.width = w
          comp.row = r
          comp.col = c
        else
          @comp_height = @height
          @comp_width = (@width / @split_count) - 0
          h = @comp_height 
          w = @comp_width
          c = @col + ( w * index)
          r = @row
          comp.height = h
          comp.width = w
          comp.row = r
          comp.col = c
        end
        comp
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
                e.set_buffering(:bottom => e.height-1)
              end
            else
              e = @components.first
              e.height += delta
              e.set_buffering(:bottom => e.height-1)
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
                e.set_buffering(:right => e.width-1)
              end
            else
              # any change in width must effect col of others too ! 2010-08-31 21:57 AUG2010
              # which is why this should be done in repaint and not here
              rc = @divider_location
              # ## next change should only happen if sc w < ...
              # if @second_component.width < @width - (rc + @col_offset + @divider_offset + 1)
              last = @components.last
              last.width += delta
            end
          end
      end
      # set location of divider (row or col depending on orientation)
      # internally sets the second components row or col
      # also to set widths or heights
      # Check minimum sizes are not disrespected
      # @param rc [int] row or column to place divider
      #  2010-01-09 23:07 : added sections to prevent a process crash courtesy copywin
      #+ when pane size exceeds buffer size, so in these cases we increase size of component
      #+ and therefore buffer size. Needs to be tested for VERTICAL.
      # If this returns :ERROR, caller may avoid repainting form needlessly.
      # We may give more meaningful error retval in future. TODO
      def XXset_divider_location rc
        $log.debug " SPLP #{@name} setting divider to #{rc} "
        # add a check for out of bounds since no buffering
          v = 1 # earlier 2
        if @orientation == :HORIZONTAL_SPLIT
          if rc < v || rc > @height - v
            return :ERROR
          end
        else
          if rc < v || rc > @width - v
            return :ERROR
          end
        end
        @repaint_required = true
          old_divider_location = @divider_location || 0
          # we first check against min_sizes
          # the calculation is repeated here, and in the actual change
          # so if modifying, be sure to do in both places.
          if !@is_expanding # if expanding then i can't check against min_width
          if rc > old_divider_location
            if @second_component != nil
              if @orientation == :VERTICAL_SPLIT
                # check second comps width
                if @width - (rc + @col_offset + @divider_offset+1) < @second_component.min_width
                  $log.debug " #{@name}  SORRY 2c min width prevents further resizing: #{@width} #{rc}"
                  return :ERROR
                end
              else
                # check second comps ht
                  $log.debug " YYYY SORRY 2c  H:#{@height} rc: #{rc} 2cmh: #{@second_component.name} "
                if @height - rc -2 < @second_component.min_height
                  $log.debug " #{@name}  SORRY 2c min height prevents further resizing"
                  return :ERROR
                end
              end
            end
          elsif rc < old_divider_location
            if @first_component != nil
               $log.debug " #{@name}  fc min width #{rc}, #{@first_component.min_width} "
              if @orientation == :VERTICAL_SPLIT
                # check first comps width

                if rc-1 < @first_component.min_width
                  $log.debug " SORRY fc min width prevents further resizing"
                  return :ERROR
                end
              else
                if rc-1 < @first_component.min_height
                  $log.debug " SORRY fc min height prevents further resizing"
                  return :ERROR
                end
              end
            end
          end
          end # expanding
          @is_expanding = false
          @old_divider_location = @divider_location
          @divider_location = rc
          if @first_component != nil

            ## added in case not set. it will be set to a sensible default
            @first_component.height ||= 0
            @first_component.width ||= 0
            
              $log.debug " #{@name}  set div location, setting first comp width #{rc}"
              if !@cascade_changes.nil?
                if @orientation == :VERTICAL_SPLIT
                  @first_component.width(rc-0) #+ @col_offset + @divider_offset
                  @first_component.height(@height-0) #2+ @col_offset + @divider_offset
                else
                  @first_component.height(rc+0) #-1) #1+ @col_offset + @divider_offset
                  @first_component.width(@width-0) #2+ @col_offset + @divider_offset
                end
              else
                if @orientation == :VERTICAL_SPLIT
                  $log.debug " DOES IT COME HERE compare fc wt #{@first_component.width} to match #{rc}-1 "
                  # added 2010-01-09 19:00 increase fc  to avoid copywin crashing process
                  if @first_component.width < rc -0 then
                    $log.debug " INCRease fc wt #{@first_component.width} to match #{rc}-1 "
                    @first_component.width(rc-0) #+ @col_offset + @divider_offset
                    @first_component.repaint_all(true) if !@first_component.nil?
                    @repaint_required = true
                  end
                  ## added this condition 2010-01-11 21:44  again switching needs this
                  a = 0 #2
                  if @first_component.height < @height - a then
                    $log.debug " INCRease fc ht #{@first_component.height} to match #{@height}- #{a} "
                    @first_component.height(@height-a) #+ @col_offset + @divider_offset
                  end
                else
                  # added 2010-01-09 19:00 increase fc  to avoid copywin crashing process
                  a = 0 #1
                  if @first_component.height < rc -a then
                    $log.debug " INCRease fc ht #{@first_component.height} to match #{rc}-1 "
                    @first_component.height(rc-a) #+ @col_offset + @divider_offset
                    @first_component.repaint_all(true) if !@first_component.nil?
                    @repaint_required = true
                  end
                  # added 2010-01-11 19:24 to match c2. Sometimes switching from V to H means
                  # fc's width needs to be expanded.
                  if @first_component.width < @width - 1 #+ @col_offset + @divider_offset
                    $log.debug " INCRease fc wi #{@first_component.width} to match #{@width}-2 "
                    @first_component.width = @width - 1 #+ @col_offset + @divider_offset
                    @first_component.repaint_all(true) 
                    @repaint_required = true
                  end
                end
              end
              $log.debug " #{@name} TA set C1 H W RC #{@first_component.height} #{@first_component.width} #{rc} "
              @first_component.set_buffering(:bottom => @first_component.height-1, :right => @first_component.width-1, :form => @form )
          end
          if !@second_component.nil?

          ## added  2010-01-11 23:09  since some cases don't set, like splits within split.
          @second_component.height ||= 0
          @second_component.width ||= 0

          if @orientation == :VERTICAL_SPLIT
              #@second_component.col = rc + @col_offset + @divider_offset
              #@second_component.row = 0 # 1
              @second_component.col = @col + rc #+ @col_offset + @divider_offset
              @second_component.row = @row # 1
              if !@cascade_changes.nil?
                #@second_component.width = @width - (rc + @col_offset + @divider_offset + 1)
                #@second_component.height = @height-2  #+ @row_offset + @divider_offset
                @second_component.width = @width - rc #+ @col_offset + @divider_offset + 1)
                @second_component.height = @height-0  #+ @row_offset + @divider_offset
              else
                # added 2010-01-09 22:49 to be tested XXX
                # In a vertical split, if widgets w and thus buffer w is less than
                #+ pane, a copywin can crash process, so we must expand component, and thus buffer
                $log.debug " #{@name}  2c width does it come here? #{@second_component.name} #{@second_component.width} < #{@width} -( #{rc}+#{@col_offset}+#{@divider_offset} +1 "
                if @second_component.width < @width - rc #+ @col_offset + @divider_offset + 1)
                  $log.debug " YES 2c width "
                  @second_component.width = @width - rc #+ @col_offset + @divider_offset + 1)
                  @second_component.repaint_all(true) 
                  @repaint_required = true
                end
                # adding 2010-01-17 19:33 since when changing to VERT, it was not expanding
                if @second_component.height < @height-0  #+ @row_offset + @divider_offset
                   $log.debug " JUST ADDED 2010-01-17 19:35 HOPE DOES NOT BREAK ANYTHING "
                   @second_component.height = @height-0  #+ @row_offset + @divider_offset
                end
              end
          else
            #rc += @row
             ## HORIZ SPLIT
            offrow = offcol = 0
              #@second_component.row = offrow + rc + 0 #1 #@row_offset + @divider_offset
              #@second_component.col = 0 + offcol # was 1
            offrow = @row; offcol = @col
              @second_component.row = offrow + rc + 0 #1 #@row_offset + @divider_offset
              $log.debug "C2 Horiz row #{@second_component.row} = #{offrow} + #{rc} "
              @second_component.col = 0 + offcol # was 1
              if !@cascade_changes.nil?
                #@second_component.width = @width - 2 #+ @col_offset + @divider_offset
                #@second_component.height = @height - rc -2 #+ @row_offset + @divider_offset
                @second_component.width = @width - 0 #+ @col_offset + @divider_offset
                @second_component.height = @height - rc -0 #+ @row_offset + @divider_offset
              else
                 # added 2010-01-16 19:14 -rc since its a HORIZ split
                 #  2010-01-16 20:45 made 2 to 3 for scrollpanes within splits!!! hope it doesnt
                 #  break, and why 3. 
                 # 2010-01-17 13:33 reverted to 2. 3 was required since i was not returning when error in set_screen_max.
                if @second_component.height < @height-rc-1 #2  #+ @row_offset + @divider_offset
                  $log.debug " #{@name}  INCRease 2c #{@second_component.name}  ht #{@second_component.height} to match #{@height}-2- #{rc}  "
                  @second_component.height = @height-rc-1  #2 #+ @row_offset + @divider_offset
                  @second_component.repaint_all(true) 
                  @repaint_required = true
                end
                # # added 2010-01-10 15:36 still not expanding 
                if @second_component.width < @width - 2 #+ @col_offset + @divider_offset
                  $log.debug " #{@name}  INCRease 2c #{@second_component.name}  wi #{@second_component.width} to match #{@width}-2 "
                  @second_component.width = @width - 2 #+ @col_offset + @divider_offset
                  @second_component.repaint_all(true) 
                  @repaint_required = true
                end
              end
          end
          # i need to keep top and left sync for print_border which uses it UGH !!!
          if !@second_component.get_buffer().nil?
            # now that TV and others are creating a buffer in repaint we need another way to set
            #$log.debug " setting second comp row col offset - i think it doesn't come here till much later "
            #XXX @second_component.get_buffer().set_screen_row_col(@second_component.row+@ext_row_offset+@row, @second_component.col+@ext_col_offset+@col)
            # 2010-02-13 09:15 RFED16
            @second_component.get_buffer().set_screen_row_col(@second_component.row, @second_component.col)
          end
            #@second_component.set_buffering(:screen_top => @row, :screen_left => @col)
            #@second_component.set_buffering(:screen_top => @row+@second_component.row, :screen_left => @col+@second_component.col)
            #@second_component.set_buffering(:screen_top => @row+@second_component.row, :screen_left => @col+@second_component.col)
          $log.debug "sdl: #{@name} setting C2 screen_top n left to #{@second_component.row}, #{@second_component.col} "
          @second_component.set_buffering(:screen_top => @second_component.row, :screen_left => @second_component.col)
          @second_component.set_buffering(:bottom => @second_component.height-1, :right => @second_component.width-1, :form => @form )
          #@second_component.ext_row_offset = @row + @ext_row_offset
          #@second_component.ext_col_offset = @col + @ext_col_offset
          $log.debug " #{@name}  2 set div location, rc #{rc} width #{@width} height #{@height}" 
          $log.debug " 2 set div location, setting r #{@second_component.row}, #{@ext_row_offset}, #{@row} "
          $log.debug " 2 set div location, setting c #{@second_component.col}, #{@ext_col_offset}, #{@col}  "
          $log.debug " C2 set div location, setting w #{@second_component.width} "
          $log.debug " C2 set div location, setting h #{@second_component.height} "

          end
          fire_property_change("divider_location", old_divider_location, @divider_location)

      end

      # calculate divider location based on weight
      # Weight implies weight of first component, e.g. .70 for 70% of splitpane
      # @param wt [float, :read] weight of first component
      def XXset_resize_weight wt
        raise ArgumentError if wt < 0 or wt >1
          @repaint_required = true
          oldvalue = @resize_weight
          @resize_weight = wt
          if @orientation == :VERTICAL_SPLIT
              rc = (@width||@preferred_width) * wt
          else
              rc = (@height||@preferred_height) * wt
          end
          fire_property_change("resize_weight", oldvalue, @resize_weight)
          rc = rc.ceil
          set_divider_location rc
      end
      ##
      # resets divider location based on preferred size of first component
      # @return :ERROR if min sizes failed
      # You may want to check for ERROR and if so, resize_weight to 0.50
      def XXreset_to_preferred_sizes
        return if @first_component.nil?
          @repaint_required = true
          ph, pw = @first_component.get_preferred_size
          if @orientation == :VERTICAL_SPLIT
             pw ||= @width/2-1  # added 2010-01-16 12:31 so easier to use, 1 to 2 2010-01-16 22:13 
              rc = pw+1  ## added 1 2010-01-11 23:26 else divider overlaps comp
              @first_component.width ||= pw ## added 2010-01-11 23:19 
          else
             ph ||= @height/2 - 0 # 1  # added 2010-01-16 12:31 so easier to use
              rc = ph+0 #1  ## added 1 2010-01-11 23:26 else divider overlaps comp
              @first_component.height ||= ph ## added 2010-01-11 23:19 
          end
          #set_divider_location rc TODO
      end
      def update_components # UNUSED XXX
        @components.each_with_index do |comp,index| 
          compute_component comp, index 
          comp.set_buffering(:screen_top => comp.row, :screen_left => comp.col)
        end
      end
      def repaint # multisplitpane
        if @graphic.nil?
          @graphic = @target_window || @form.window
          raise "graphic nil in rsplitpane #{@name} " unless @graphic
        end

        if @repaint_required
          @components.each { |e| e.repaint_all(true) }
        end
        if @repaint_required
          ## paint border and divider
          $log.debug "SPLP #{@name} repaint split H #{@height} W #{@width} "
          bordercolor = @border_color || $datacolor
          borderatt = @border_attrib || Ncurses::A_NORMAL
          absrow = abscol = 0
          if @use_absolute
            absrow = @row
            abscol = @col
          end
          if @use_absolute
            $log.debug " #{@graphic} calling print_border #{@row} #{@col} "
            @graphic.print_border(@row, @col, @height-1, @width-1, bordercolor, borderatt)
          else
            $log.debug " #{@graphic} calling print_border 0,0"
            @graphic.print_border(0, 0, @height-1, @width-1, bordercolor, borderatt)
          end
          #rc = @divider_location
          rc = -1

          @graphic.attron(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
          # 2010-02-14 18:23 - non buffered, have to make relative coords into absolute
          #+ by adding row and col
            count = @components.nil? ? @split_count : @components.size
            count = @components.empty? ? @split_count : @components.size
          if @orientation == :VERTICAL_SPLIT
            @comp_height ||= @height
            @comp_width ||= (@width / @split_count) - 1
            $log.debug "SPLP #{@name} prtingign split vline divider 1, rc: #{rc}, h:#{@height} - 2 "
            #@graphic.mvvline(absrow+1, rc+abscol, 0, @height-2)
            (1...count).each(){|i| @graphic.mvvline(absrow+1, (i*@comp_width)+abscol, 0, @height-2) }
            # TODO put vlines here

          else
            @comp_height ||= (@height / @split_count) - 1
            @comp_width ||= @width
            #$log.debug "SPLP #{@name} prtingign split hline divider rc: #{rc} , 1 , w:#{@width} - 2"
            #@graphic.mvhline(rc+absrow, abscol+1, 0, @width-2)
            # XXX in next line -2 at end was causing an overlap into final border col, 
            # this need correction in splitpane XXX
            (1...count).each(){|i| @graphic.mvhline((i*@comp_height)+absrow, abscol+1, 0, @width-3) }
            # TODO put hlines here
          end
          @graphic.attroff(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
        end
        ## XXX do not paint what is outside of bounds. See tabbedpane or scrollform
        @components.each_with_index do |comp,index| 
          compute_component comp, index
          comp.set_buffering(:screen_top => comp.row, :screen_left => comp.col)
          comp.repaint 
        end
        @graphic.wrefresh # 2010-02-14 20:18 SUBWIN ONLY ??? what is this doing here ? XXX
        paint 
      end
      def getvalue
          # TODO
      end
      def _switch_component
          if @current_component != nil 
            @current_index += 1
            @current_component = @components[@current_index] 
            unless @current_component
              @current_index = 0
              @current_component = @components[@current_index] 
            end
            set_form_row
          else
            # this happens in one_tab_expand
            #@current_component = @second_component if @first_component.nil?
            #@current_component = @first_component if @second_component.nil?
            # XXX not sure what to do here, will it come
            @current_index = 0
            @current_component = @components[@current_index] 
            set_form_row
          end
      end
      ## Handles key for splitpanes
      ## By default, first component gets focus, not the SPL itself.
      ##+ Mostly passing to child, and handling child's left-overs.
      ## NOTE: How do we switch to the other outer SPL?
      def handle_key ch
        _multiplier = ($multiplier == 0 ? 1 : $multiplier )
        @current_component ||= @first_component
        @current_index ||= 0
        ## 2010-01-15 12:57 this helps me switch between highest level 
        ## However, i should do as follows:
        ## If tab on second component, return UNHA so form can take to next field
        ## If B_tab on second comp, switch to first
        ## If B_tab on first comp, return UNHA so form can take to prev field
        if ch == 9
           _switch_component
           return 0
        end

        if @current_component != nil 
          ret = @current_component.handle_key ch
          return ret if ret != :UNHANDLED
        else
          ## added 2010-01-07 18:59 in case nothing in there.
          $log.debug " SPLP #{@name} - no component installed in splitpane"
          #return :UNHANDLED
        end
        $log.debug " splitpane #{@name} gets KEY #{ch}"
        case ch
        when ?\M-w.getbyte(0)
           # switch panes
          if @current_component != nil 
            if @current_component == @first_component
              @current_component = @second_component
            else
              @current_component = @first_component
            end
            set_form_row
          else
           _switch_component
           return 0
            # if i've expanded bottom pane, tabbed to opposite higher level, tabbing back
            # brings me to null first pane and i can't go to second, so switch
            # this was added for a non-realistic test program with embedded splitpanes
            #+ but no component inside them. At least one can go from one outer to another.
            #+ In real life, this should not come.

            return :UNHANDLED
          end
        when ?\M-V.getbyte(0)
          self.orientation(:VERTICAL_SPLIT)
          @repaint_required = true
        when ?\M-H.getbyte(0)
          self.orientation(:HORIZONTAL_SPLIT)
          @repaint_required = true
        when ?\M--.getbyte(0)
          self.set_divider_location(self.divider_location-_multiplier)
        when ?\M-\+.getbyte(0)
          self.set_divider_location(self.divider_location+_multiplier)
        when ?\M-\=.getbyte(0)
          self.set_resize_weight(0.50)
        #when ?\C-u.getbyte(0)
          ## multiplier. Series is 4 16 64
          #@multiplier = (@multiplier == 0 ? 4 : @multiplier *= 4)
          #return 0
        when ?\C-c.getbyte(0)
          $multiplier = 0
          return 0
        else
          # check for bindings, these cannot override above keys since placed at end
          ret = process_key ch, self
          return :UNHANDLED if ret == :UNHANDLED
        end
        $multiplier = 0
        return 0
      end
      def paint
          @repaint_required = false
      end
      def on_enter
        return if @components.nil?
        @current_component = @components.first
        set_form_row
      end
      def set_form_row
        if !@current_component.nil?
          $log.debug " #{@name} set_form_row calling sfr for #{@current_component.name} "
          @current_component.set_form_row 
          @current_component.set_form_col 
        end
      end
      # added 2010-02-09 10:10 
      # sets the forms cursor column correctly
      # earlier the super was being called which missed out on child's column.
      # Note: splitpane does not use the cursor, so it does not know where cursor should be displayed,
      #+ the child has to decide where it should be displayed.
      def set_form_col
         if !@current_component.nil?
            $log.debug " #{@name} set_form_col calling sfc for #{@current_component.name} "
            @current_component.set_form_col 
         end
      end
      private
      #def _other_component
        #if @current_component == @first_component
          #return @second_component
        #end
        #return @first_component
      #end
      ## expand a split to maximum. This is the one_touch_expandable feature
      # Currently mapped to C-w 1 (mnemonic for one touch), or C-w o (vim's only)
      # To revert, you have to unexpand
      # Note: basically, i nil the component that we don't want to see
      def expand
        @is_expanding = true # this is required so i don't check for min_width later
        $log.debug " callign expand "
        if @current_component == @first_component
          @saved_component = @second_component
          @second_component = nil
          if @orientation == :VERTICAL_SPLIT
            set_divider_location @width - 1
          else
            set_divider_location @height - 1
          end
          $log.debug " callign expand 2 nil #{@divider_location}, h:#{@height} w: #{@width}  "
        else
          @saved_component = @first_component
          @first_component = nil
          set_divider_location 1
          $log.debug " callign expand 1 nil #{@divider_location}, h:#{@height} w: #{@width}  "
        end
        @repaint_required = true
      end
      # after expanding one split, revert to original  - actually i reset, rather than revert
      # This only works after expand has been done
      def unexpand
        $log.debug " inside unexpand "
        return unless @saved_component
        if @first_component.nil?
          @first_component = @saved_component
        else
          @second_component = @saved_component
        end
        @saved_component = nil
        @repaint_required = true
        reset_to_preferred_sizes
      end

      # exchange 2 splits, bound to C-w x
      def exchange
        tmp = @first_component
        @first_component = @second_component
        @second_component = tmp
        @repaint_required = true
        reset_to_preferred_sizes
      end
  end # class SplitPane
end # module
