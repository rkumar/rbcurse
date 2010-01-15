=begin
  * Name: SplitPane
  * $Id$
  * Description: allows user to split 2 components vertically or horizontally
  * Author: rkumar (arunachalesha)
  * file created 2009-10-27 19:20 
TODO 
  * Need to add events and property changed
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
      dsl_accessor :border_color
      dsl_accessor :border_attrib

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
      end
      def init_vars
          should_create_buffer(true) #if should_create_buffer().nil?
          @divider_location ||= 10
          @divider_offset ||= 1
          #@curpos = @pcol = @toprow = @current_index = 0
          # cascade_changes keeps the child exactly sized as per the pane which looks nice
          #+ but may not really be what you want.
          #@cascade_changes=true
          ## if this splp is increased (ht or wid) then expand the child
          @cascade_boundary_changes = true
          @orientation ||= :HORIZONTAL_SPLIT # added 2010-01-13 15:05 since not set

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
          @first_component      = comp;
          @first_component.parent_component = self ## added 2010-01-13 12:54 
          subpad                = create_buffer # added 2010-01-06 21:22  BUFFERED  (moved from repaint)
          @subform1             = RubyCurses::Form.new subpad # added  2010-01-06 21:22 BUFFERED  (moved from repaint)
          comp.set_form(@subform1) # added 2010 BUFFERED
          @subform1.parent_form = @form # added 2010 for cursor stuff BUFFERED
          ## These setting are quite critical, otherwise on startup
          ##+ it can create 2 tiled buffers.
          @first_component.row(1)  # this suddenly causes an initial extra blank which goes away
          @first_component.col(1)
          # if i set the above 2 to 0, it starts fine but then on any action loses the first row.
          # Just begun happeing suddenly! 2010-01-11 23:38 

          # 2010-01-11 22:32 dang, if component is like splitpane which sets in repaint
          # 2010-01-12 11:15 : for those who've created in constructor, i need to do this
          # so they don't print off. i need to find a way to have create_buffer pick an
          # explicit top and left.
          if !@first_component.get_buffer().nil?
            @first_component.get_buffer().set_screen_row_col(1, 1)  # check this out XXX
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
          subpad                = create_buffer # added 2010-01-06 21:22  BUFFERED  (moved from repaint)
          @subform2             = RubyCurses::Form.new subpad # added  2010-01-06 21:22 BUFFERED  (moved from repaint)
          comp.set_form(@subform2) # added 2010 BUFFERED
          @subform2.parent_form = @form # added 2010 for cursor stuff BUFFERED
          ## jeez, we;ve postponed create of buffer XX
          #@second_component.row(1)
          #@second_component.col(1)
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
          super
          return @height if val.empty?
          @height = val[0]
          if !@cascade_boundary_changes.nil?
            # must tell children if height changed which will happen in nested splitpanes
            # must adjust to components own offsets too
            if @first_component != nil 
              @first_component.height = @height - @row_offset + @divider_offset
              @first_component.repaint_all true
              $log.debug " set fc height to #{@first_component.height} "
            end
            if @second_component != nil 
              @second_component.height = @height - @row_offset + @divider_offset
              @second_component.repaint_all true
            end
            # junk added ib 2010-01-09 19:04 delete the next block
          #else
             ## if exceeding pane height, make fc get taller
            #if @first_component != nil 
              #$log.debug " fc height  #{@first_component.height}, pane: #{pane_ht}  "
              #pane_ht = @height - @row_offset + @divider_offset
              #if @first_component.height < pane_ht
                #@first_component.height = pane_ht
                #@first_component.repaint_all = true
                #$log.debug " set fc height to #{@first_component.height}, #{pane_ht}  "
              #end
            #end
          end
          @repaint_required = true
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
          $log.debug " SPLP width #{oldvalue}, #{@width}, #{delta} "
          @repaint_required = true
          if !@cascade_boundary_changes.nil?
            # must adjust to components own offsets too
            # NOTE: 2010-01-10 20:11 if we increase width by one, each time will both components get increased by one.
            if @orientation == :HORIZONTAL_SPLIT
              if @first_component != nil 
                old = @first_component.width 
                #@first_component.width = @width - @col_offset + @divider_offset
                @first_component.width += delta
                $log.debug " set fc width to #{@first_component.width}, old was #{old}  "
              end
              # added 2010-01-11 23:02  horiz 2c not displaying since width issue
              if @second_component != nil 
                old = @second_component.width 
                #@first_component.width = @width - @col_offset + @divider_offset
                @second_component.width += delta
                $log.debug " set 2c width to #{@second_component.width}, old was #{old}  "
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
                  $log.debug " set 2c width to #{@second_component.width} , old was #{old} "
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
          @repaint_required = true
          old_divider_location = @divider_location || 0
          # we first check against min_sizes
          # the calculation is repeated here, and in the actual change
          # so if modifying, be sure to do in both places.
          if rc > old_divider_location
            if @second_component != nil
              if @orientation == :VERTICAL_SPLIT
                # check second comps width
                if @width - (rc + @col_offset + @divider_offset+1) < @second_component.min_width
                  $log.debug " SORRY 2c min width prevents further resizing: #{@width} #{rc}"
                  return :ERROR
                end
              else
                # check second comps ht
                  $log.debug " YYYY SORRY 2c  H:#{@height} rc: #{rc} 2cmh: #{@second_component.name} "
                if @height - rc -2 < @second_component.min_height
                  $log.debug " SORRY 2c min height prevents further resizing"
                  return :ERROR
                end
              end
            end
          elsif rc < old_divider_location
            if @first_component != nil
              if @orientation == :VERTICAL_SPLIT
                # check first comps width
                $log.debug " fc min width #{rc}, #{@first_component.min_width} "

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
          @divider_location = rc
          if @first_component != nil

            ## added in case not set. it will be set to a sensible default
            @first_component.height ||= 0
            @first_component.width ||= 0
            
              $log.debug " set div location, setting first comp width #{rc}"
              if !@cascade_changes.nil?
                if @orientation == :VERTICAL_SPLIT
                  @first_component.width(rc-1) #+ @col_offset + @divider_offset
                  @first_component.height(@height-2) #+ @col_offset + @divider_offset
                else
                  @first_component.height(rc-1) #+ @col_offset + @divider_offset
                  @first_component.width(@width-2) #+ @col_offset + @divider_offset
                end
              else
                if @orientation == :VERTICAL_SPLIT
                  $log.debug " DOES IT COME HERE compare fc wt #{@first_component.width} to match #{rc}-1 "
                  # added 2010-01-09 19:00 increase fc  to avoid copywin crashing process
                  if @first_component.width < rc -1 then
                    $log.debug " INCRease fc wt #{@first_component.width} to match #{rc}-1 "
                    @first_component.width(rc-1) #+ @col_offset + @divider_offset
                    @first_component.repaint_all(true) if !@first_component.nil?
                    @repaint_required = true
                  end
                  ## added this condition 2010-01-11 21:44  again switching needs this
                  if @first_component.height < @height - 2 then
                    $log.debug " INCRease fc ht #{@first_component.height} to match #{@height}-2 "
                    @first_component.height(@height-2) #+ @col_offset + @divider_offset
                  end
                else
                  # added 2010-01-09 19:00 increase fc  to avoid copywin crashing process
                  if @first_component.height < rc -1 then
                    $log.debug " INCRease fc ht #{@first_component.height} to match #{rc}-1 "
                    @first_component.height(rc-1) #+ @col_offset + @divider_offset
                    @first_component.repaint_all(true) if !@first_component.nil?
                    @repaint_required = true
                  end
                  # added 2010-01-11 19:24 to match c2. Sometimes switching from V to H means
                  # fc's width needs to be expanded.
                  if @first_component.width < @width - 2 #+ @col_offset + @divider_offset
                    $log.debug " INCRease fc wi #{@first_component.width} to match #{@width}-2 "
                    @first_component.width = @width - 2 #+ @col_offset + @divider_offset
                    @first_component.repaint_all(true) 
                    @repaint_required = true
                  end
                end
              end
          end
          return if @second_component == nil

          ## added  2010-01-11 23:09  since some cases don't set, like splits within split.
            @second_component.height ||= 0
            @second_component.width ||= 0

          if @orientation == :VERTICAL_SPLIT
              @second_component.col = rc + @col_offset + @divider_offset
              @second_component.row = 1
              if !@cascade_changes.nil?
                @second_component.width = @width - (rc + @col_offset + @divider_offset + 1)
                @second_component.height = @height-2  #+ @row_offset + @divider_offset
              else
                # added 2010-01-09 22:49 to be tested XXX
                # In a vertical split, if widgets w and thus buffer w is less than
                #+ pane, a copywin can crash process, so we must expand component, and thus buffer
                $log.debug " 2c width does it come here? #{@second_component.width} < #{@width} -( #{rc}+#{@col_offset}+#{@divider_offset} +1 "
                if @second_component.width < @width - (rc + @col_offset + @divider_offset + 1)
                  $log.debug " YES 2c width "
                  @second_component.width = @width - (rc + @col_offset + @divider_offset + 1)
                  @second_component.repaint_all(true) 
                  @repaint_required = true
                end
              end
          else
              @second_component.row = rc + 1 #@row_offset + @divider_offset
              @second_component.col = 1
              if !@cascade_changes.nil?
                @second_component.width = @width - 2 #+ @col_offset + @divider_offset
                @second_component.height = @height - rc -2 #+ @row_offset + @divider_offset
              else
                if @second_component.height < @height-2  #+ @row_offset + @divider_offset
                  $log.debug " INCRease 2c ht #{@second_component.height} to match #{@height}-2 "
                  @second_component.height = @height-2  #+ @row_offset + @divider_offset
                  @second_component.repaint_all(true) 
                  @repaint_required = true
                end
                # # added 2010-01-10 15:36 still not expanding 
                if @second_component.width < @width - 2 #+ @col_offset + @divider_offset
                  $log.debug " INCRease 2c wi #{@second_component.width} to match #{@width}-2 "
                  @second_component.width = @width - 2 #+ @col_offset + @divider_offset
                  @second_component.repaint_all(true) 
                  @repaint_required = true
                end
              end
          end
          # i need to keep top and left sync for print_border which uses it UGH !!!
          if !@second_component.get_buffer().nil?
            @second_component.get_buffer().set_screen_row_col(@second_component.row, @second_component.col)
          end
          $log.debug " 2 set div location, rc #{rc} width #{@width} height #{@height}" 
          $log.debug " 2 set div location, setting r #{@second_component.row} "
          $log.debug " 2 set div location, setting c #{@second_component.col} "
          $log.debug " 2 set div location, setting w #{@second_component.width} "
          $log.debug " 2 set div location, setting h #{@second_component.height} "

      end

      # calculate divider location based on weight
      # Weight implies weight of first component, e.g. .70 for 70% of splitpane
      # @param wt [float, :read] weight of first component
      def set_resize_weight wt
          @repaint_required = true
          if @orientation == :VERTICAL_SPLIT
              rc = (@width||@preferred_width) * wt
          else
              rc = (@height||@preferred_height) * wt
          end
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
              rc = pw+1  ## added 1 2010-01-11 23:26 else divider overlaps comp
              @first_component.width ||= pw ## added 2010-01-11 23:19 
          else
              rc = ph+1  ## added 1 2010-01-11 23:26 else divider overlaps comp
              @first_component.height ||= ph ## added 2010-01-11 23:19 
          end
          set_divider_location rc
      end
      def repaint # splitpane
        safe_create_buffer
        # this is in case, not called by form
        # we need to clip components
        # note that splitpanes can be nested

        if @repaint_required
          # Note: this only if major change
          @graphic.wclear
          @first_component.repaint_all(true) if !@first_component.nil?
          @second_component.repaint_all(true) if !@second_component.nil?
        end
        if @repaint_required
          ## paint border and divider
          $log.debug "SPLP #{@name} repaint split H #{@height} W #{@width} "
          bordercolor = @border_color || $datacolor
          borderatt = @border_attrib || Ncurses::A_NORMAL
          #@graphic.print_border(0, 0, @height-1, @width-1, bordercolor, borderatt)
          @graphic.print_border(@row, @col, @height-1, @width, bordercolor, borderatt)
          rc = @divider_location

          @graphic.attron(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
          if @orientation == :VERTICAL_SPLIT
            $log.debug "SPLP #{@name} prtingign split vline 1, rc: #{rc} "
            @graphic.mvvline(1, rc, 0, @height-2)
          else
            $log.debug "SPLP #{@name} prtingign split hline  rc: #{rc} , 1 "
            @graphic.mvhline(rc, 1, 0, @width-2)
          end
          @graphic.attroff(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
        end
        if @first_component != nil
          $log.debug " SPLP repaint 1c ..."
          # this means that some components will create a buffer with default top and left of 0 the
          # first time. Is there no way we can tell FC what top and left to use.
          @first_component.repaint
          # earlier before repaint but bombs since some chaps create buffer in repaint
          @first_component.get_buffer().set_screen_row_col(1, 1)  # check this out XXX
          ## the next block is critical for when we switch from one orientation to the other
          ##+ We want first component to expand as much as possible
          if @orientation == :VERTICAL_SPLIT
            @first_component.get_buffer().set_screen_max_row_col(@height-2, @divider_location-1)
          else
            @first_component.get_buffer().set_screen_max_row_col(@divider_location-1, @width-2)
          end
          ret = @first_component.buffer_to_screen(@graphic)
          $log.debug " SPLP repaint fc ret = #{ret} "
        end
        if @second_component != nil
          $log.debug " SPLP repaint 2c ..."
          @second_component.repaint

          # we need to keep top and left of buffer synced with components row and col.
          # Since buffer has no link to comp therefore it can't check back.
          @second_component.get_buffer().set_screen_row_col(@second_component.row, @second_component.col)
          if @orientation == :VERTICAL_SPLIT
            @second_component.get_buffer().set_screen_max_row_col(@height-2, @width-2)
          else
            @second_component.get_buffer().set_screen_max_row_col(@height-2, @width-2)
          end

          ret = @second_component.buffer_to_screen(@graphic)
          $log.debug " SPLP repaint 2c ret = #{ret} "
        end
        @buffer_modified = true
        paint # has to paint border if needed, 
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
          end
      end
      ## Handles key for splitpanes
      ## By default, first component gets focus, not the SPL itself.
      ##+ Mostly passing to child, and handling child's left-overs.
      ## NOTE: How do we switch to the other outer SPL?
      def handle_key ch
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

            # this was added for a non-realistic test program with embedded splitpanes
            #+ but no component inside them. At least one can go from one outer to another.
            #+ In real life, this should not come.
            return :UNHANDLED
          end
        when ?\M-V.getbyte(0)
          self.orientation(:VERTICAL_SPLIT)
        when ?\M-H.getbyte(0)
          self.orientation(:HORIZONTAL_SPLIT)
        when ?\M--.getbyte(0)
          self.set_divider_location(self.divider_location-1)
        when ?\M-\+.getbyte(0)
          self.set_divider_location(self.divider_location+1)
        when ?\M-\=.getbyte(0)
          self.set_resize_weight(0.50)
        else
          return :UNHANDLED
        end
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
  end # class SplitPane
end # module
