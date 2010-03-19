=begin
  * Name: SplitPane
  * $Id$
  * Description: allows user to split 2 components vertically or horizontally
  * NOTE that VERTICAL_SPLIT means the *divider* is vertical.
  * Author: rkumar (arunachalesha)
  * file created 2009-10-27 19:20 
  * major change: Feb 2010, removed buffers
Todo: 
  * TODO remove components

  * XXX Does SPLP need to listen for changes in children
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
  # A SplitPane allows user to split 2 components vertically or horizontally.
  # such as textarea, table or a form, usually the underlying data is larger
  # than what can be displayed.
  # @since 0.1.3
  # TODO - 
  
  class SplitPane < Widget
      #dsl_property :height  # added to widget and here as method
      #dsl_accessor :width  # already present in widget
      # row and col also present int widget
      #dsl_accessor :first_component  # top or left component that is being viewed
      #dsl_accessor :second_component  # right or bottom component that is being viewed
      dsl_property :orientation  # :VERTICAL_SPLIT or :HORIZONTAL_SPLIT
      attr_reader :divider_location  # 
      attr_reader :resize_weight
      attr_writer :last_divider_location
      dsl_accessor :border_color
      dsl_accessor :border_attrib
      attr_accessor :one_touch_expandable # boolean, default true 

      def initialize form, config={}, &block
          @focusable = true
          @editable = false
          #@left_margin = 1
          @row = 0
          @col = 0
          super
          @row_offset = @col_offset = 1
          @orig_col = @col
          @use_absolute = true; # set to true if not using subwins XXX
          init_vars
          @subwin_created = true # set to true if you don't want subwins created
          @@ctr ||= 0
        if @@ctr == 0
        if @subwin_created == false
          #layout = { :height => @height, :width => @width, :top => @row, :left => @col }
          layout = { :height => @height-1, :width => @width-1, :top => @row+1, :left => @col+1 }
          @graphic = @graphic._subwin(layout)
          fw = form.window 
          raise "graphic nil #{@name} " unless @graphic
          $log.debug " SUBWIN CREATED "
          @subwin_created = true
          @target_window = @graphic
          @@ctr += 1
          @use_absolute = false
          bordercolor = @border_color || $datacolor
          borderatt = @border_attrib || Ncurses::A_NORMAL
        end
        end
      end
      def init_vars
          #should_create_buffer(true) #if should_create_buffer().nil?
          @divider_location ||= 10
          #@divider_offset ||= 1
          @divider_offset ||= 0
          #@curpos = @pcol = @toprow = @current_index = 0
          
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
      #  Sets the first component (top or left)
      #  
      # @param [String] comp comment
      # @return [true, false] comment
      #
      # XXX This originally working fine if the child was also a splitpane
      # Now with other comps, it works fine with them if they create a buffer in const
      # but now SPLP bombs since it creates a buffer in repaint.

      def first_component(comp)
          screen_col = 1
          screen_row = 1 # offset for copying pad 2010-02-09 19:02 
          @first_component      = comp;
          @first_component.parent_component = self ## added 2010-01-13 12:54 
          ## These setting are quite critical, otherwise on startup
          ##+ it can create 2 tiled buffers.
          a = 0 # =1
          @first_component.row(@row + a)  
          @first_component.col(@col + a)
          comp.should_create_buffer = @_child_buffering 
          # adding ext_offsets 2010-02-09 13:39 
          # setting the form is again adding top and left which are the row and col from here.
          $log.debug "SPLP exp_row #{@name}, #{comp}  #{comp.ext_row_offset} += #{@ext_row_offset} + #{@row}   "
          $log.debug "SPLP exp_col  #{@name}  #{comp.ext_col_offset} += #{@ext_col_offset} + #{@col}   "
#XXX          comp.ext_row_offset += @ext_row_offset + @row - @subform1.window.top #0# screen_row
#XXX          comp.ext_col_offset += @ext_col_offset + @col -@subform1.window.left # 0# screen_col
          comp.ext_row_offset += @ext_row_offset + @row #- @subform1.window.top #0# screen_row
          comp.ext_col_offset += @ext_col_offset + @col #-@subform1.window.left # 0# screen_col

          ## trying out 2010-01-16 12:11 so component does not have to set size
          # The suggestd heights really depend on orientation.
           a = 0 # = 2
          if @orientation == :HORIZONTAL_SPLIT
             @first_component.height ||= @first_component.preferred_height || @height/2 - 1 #1
             @first_component.width ||= @first_component.preferred_width || @width - a
          else
             @first_component.height ||= @first_component.preferred_height || @height - a
             @first_component.width ||= @first_component.preferred_width || @width/2 -1
          end
          #layout = { :height => @height-1, :width => @width-1, :top => @row, :left => @col }
          comp.set_buffering(:target_window => @target_window || @form.window, :bottom => comp.height-1, :right => comp.width-1, :form => @form )
          comp.set_buffering(:screen_top => @row, :screen_left => @col)
          @first_component.min_height ||= 5
          @first_component.min_width ||= 5


          # if i set the above 2 to 0, it starts fine but then on any action loses the first row.
          # Just begun happeing suddenly! 2010-01-11 23:38 

          # 2010-01-11 22:32 dang, if component is like splitpane which sets in repaint
          # 2010-01-12 11:15 : for those who've created in constructor, i need to do this
          # so they don't print off. i need to find a way to have create_buffer pick an
          # explicit top and left.
          if !@first_component.get_buffer().nil?
            @first_component.get_buffer().set_screen_row_col(screen_row, screen_col)  # check this out XXX
            #@first_component.get_buffer().top=1;  # 2010-01-08 13:24 trying out
            #@first_component.get_buffer().left=1;  # 2010-01-08 13:24 trying out
          end
          @current_component ||= @first_component # added 2010-01-13 15:39 
      end # first_component
      ## 
      #  Sets the second component (bottom or right)
      #  
      # @param [String] comp comment
      # @return [true, false] comment

      def second_component(comp)
          @second_component = comp;
          @second_component.parent_component = self ## added 2010-01-13 12:54 
          comp.should_create_buffer = @_child_buffering 
          ## jeez, we;ve postponed create of buffer XX
          ## trying out 2010-01-16 12:11 so component does not have to set size
          # The suggestd heights really depend on orientation.
          if @orientation == :HORIZONTAL_SPLIT
            @second_component.row(@row+@divider_location)
            @second_component.col(@col+@col_offset)
             @second_component.height ||= @second_component.preferred_height || @height/2 - 1 #1
             @second_component.width ||= @second_component.preferred_width || @width - 0 # 2
          else
            @second_component.row(@row+@row_offset)
            @second_component.col(@col+@divider_location)
             @second_component.height ||= @second_component.preferred_height || @height - 0 # 2
             @second_component.width ||= @second_component.preferred_width || @width/2 -4 # 1 to 4 2010-01-16 22:10  TRYING COULD BREAK STUFF testsplit3a;s right splitpane
    # added 2010-01-16 23:55 
          end
          comp.ext_row_offset += @ext_row_offset + @row
          $log.debug "SPLP exp_col #{@name} 2 #{comp}:  #{comp.ext_col_offset} += #{@ext_col_offset} + #{@col}  "
          comp.ext_col_offset += @ext_col_offset + @col 
          layout = { :height => @height-1, :width => @width-1, :top => comp.row, :left => comp.col }
          comp.set_buffering(:target_window => @target_window || @form.window, :bottom => comp.height-1, 
                             :right => comp.width-1, :form => @form )
          $log.debug " setting c2 screen_top n left to #{@row} #{@col} "
          @second_component.set_buffering(:screen_top => @row, :screen_left => @col)
          @second_component.min_height ||= 5 # added 2010-01-16 12:37 
          @second_component.min_width ||= 5 # added 2010-01-16 12:37 
      end # second_component

      ## faster access to the 2 components
      def c1; @first_component; end
      def c2; @second_component; end

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
          return if @first_component.nil? or @second_component.nil?
          delta = @height - oldvalue
          @repaint_required = true
          if !@cascade_boundary_changes.nil?
            # must tell children if height changed which will happen in nested splitpanes
            # must adjust to components own offsets too
            if @orientation == :VERTICAL_SPLIT
              @first_component.height += delta
              @second_component.height += delta
              # RFED16 2010-02-16 20:44 whenever we change dimensions need to update
              # buffering_params since we are not using Pad's buffer_to_screen
              @second_component.set_buffering(:bottom => @second_component.height-1)
              @first_component.set_buffering(:bottom => @first_component.height-1)
            else
              @second_component.height += delta
              @second_component.set_buffering(:bottom => @second_component.height-1)
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
              if @first_component != nil 
                old = @first_component.width 
                #@first_component.width = @width - @col_offset + @divider_offset
                @first_component.width += delta
                $log.debug "width() #{@name} set fc width to #{@first_component.width}, old was #{old}  "
                @first_component.set_buffering(:right => @first_component.width-1)
              end
              # added 2010-01-11 23:02  horiz 2c not displaying since width issue
              if @second_component != nil 
                old = @second_component.width 
                #@first_component.width = @width - @col_offset + @divider_offset
                @second_component.width += delta
                @second_component.set_buffering(:right => @second_component.width-1)
                $log.debug "width()  #{@name} set 2c width to #{@second_component.width}, old was #{old}  "
              end
            else
              rc = @divider_location
              # ## next change should only happen if sc w < ...
              #  2010-01-11 22:11 
              # if @second_component.width < @width - (rc + @col_offset + @divider_offset + 1)
              if @second_component != nil 
                if @second_component.width < @width - (rc + @col_offset + @divider_offset + 1)
                  old = @second_component.width 
                  #@second_component.width = @width - @col_offset + @divider_offset
                  @second_component.width += delta
                  @second_component.set_buffering(:right => @second_component.width-1)
                  $log.debug "width() #{@name}  set 2c width to #{@second_component.width} , old was #{old} "
                end
              end
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
      def set_divider_location rc
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
      def set_resize_weight wt
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
      def reset_to_preferred_sizes
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
          set_divider_location rc
      end
      def update_first_component
        $log.debug " #{@name} update+first dl: #{@divider_location} "
        return if @divider_location == 0
        @first_component.row(@row)
        @first_component.col(@col)
        $log.debug "UCF #{@name} #{@first_component.row} #{@first_component.col} "
        @first_component.set_buffering(:screen_top => @first_component.row, :screen_left => @first_component.col)
      end
      def update_second_component
        $log.debug " #{@name} update+secoond dl: #{@divider_location} "
        return if @divider_location == 0
          if @orientation == :HORIZONTAL_SPLIT
            @second_component.row(@row+@divider_location)
            @second_component.col(@col)
          else
            @second_component.row(@row)
            @second_component.col(@col+@divider_location)
          end
          $log.debug "UCS #{@name} #{@second_component.row} #{@second_component.col} "
          @second_component.set_buffering(:screen_top => @second_component.row, :screen_left => @second_component.col)
      end
      def repaint # splitpane
        if @graphic.nil?
          @graphic = @target_window || @form.window
          raise "graphic nil in rsplitpane #{@name} " unless @graphic
        end
#XXX        safe_create_buffer
        # this is in case, not called by form
        # we need to clip components
        # note that splitpanes can be nested

        if @repaint_required
          # Note: this only if major change
#XXX          @graphic.wclear
          @first_component.repaint_all(true) if !@first_component.nil?
          @second_component.repaint_all(true) if !@second_component.nil?
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
          rc = @divider_location

          @graphic.attron(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
          # 2010-02-14 18:23 - non buffered, have to make relative coords into absolute
          #+ by adding row and col
          if @orientation == :VERTICAL_SPLIT
            $log.debug "SPLP #{@name} prtingign split vline divider 1, rc: #{rc}, h:#{@height} - 2 "
            @graphic.mvvline(absrow+1, rc+abscol, 0, @height-2)
          else
            $log.debug "SPLP #{@name} prtingign split hline divider rc: #{rc} , 1 , w:#{@width} - 2"
            @graphic.mvhline(rc+absrow, abscol+1, 0, @width-2)
          end
          @graphic.attroff(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
        end
        if @first_component != nil
          $log.debug " SPLP #{@name}  repaint 1c ..."
          # this means that some components will create a buffer with default top and left of 0 the
          # first time. Is there no way we can tell FC what top and left to use.
          update_first_component
          @first_component.repaint
          # earlier before repaint but bombs since some chaps create buffer in repaint
#XXX          @first_component.get_buffer().set_screen_row_col(1, 1)  # check this out XXX
          ## the next block is critical for when we switch from one orientation to the other
          ##+ We want first component to expand as much as possible
          if @orientation == :VERTICAL_SPLIT
#XXX            @first_component.get_buffer().set_screen_max_row_col(@height-2, @divider_location-1)
          else
#XXX            @first_component.get_buffer().set_screen_max_row_col(@divider_location-1, @width-2)
          end
#XXX          ret = @first_component.buffer_to_screen(@graphic)
#XXX          $log.debug " SPLP repaint  #{@name} fc ret = #{ret} "
        end
        if @second_component != nil
          $log.debug " SPLP repaint #{@name}  2c ... dl: #{@divider_location} "
          # this is required since c2 gets its row and col only after divider has been set
          update_second_component
          @second_component.repaint unless @divider_location == 0

          # we need to keep top and left of buffer synced with components row and col.
          # Since buffer has no link to comp therefore it can't check back.
#XXX          @second_component.get_buffer().set_screen_row_col(@second_component.row, @second_component.col)
          if @orientation == :VERTICAL_SPLIT
#XXX            @second_component.get_buffer().set_screen_max_row_col(@height-2, @width-2)
          else
#XXX            @second_component.get_buffer().set_screen_max_row_col(@height-2, @width-2)
          end

#XXX          ret = @second_component.buffer_to_screen(@graphic)
#XXX          $log.debug " SPLP repaint #{@name}  2c ret = #{ret} "
        end
#XXX        @buffer_modified = true
        @graphic.wrefresh # 2010-02-14 20:18 SUBWIN ONLY ??? what is this doing here ? XXX
        paint 
        # TODO
      end
      def getvalue
          # TODO
      end
      def _switch_component
          if @current_component != nil 
            if @current_component == @first_component
              @current_component = @second_component
            else
              @current_component = @first_component
            end
            set_form_row
          else
            # this happens in one_tab_expand
            @current_component = @second_component if @first_component.nil?
            @current_component = @first_component if @second_component.nil?
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
