=begin
  * Name: SplitPane
  * $Id$
  * Description: allows user to split 2 components vertically or horizontally
  * Author: rkumar (arunachalesha)
TODO 
  * file created 2009-10-27 19:20 
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
      # TODO when splitpanes width or height changed, it must inform its children
      #  to take care of nested splitpanes

      def initialize form, config={}, &block
          @focusable = true
          @editable = false
          #@left_margin = 1
          @row = 0
          @col = 0
          super
          @row_offset = @col_offset = 1
          #@orig_col = @col
          # this does result in a blank line if we insert after creating. That's required at 
          # present if we wish to only insert
          #create_buffer = postponed since we may not have width and height
          init_vars
      end
      def init_vars
        should_create_buffer true
          @divider_location ||= 10
          @divider_offset ||= 1
          #@curpos = @pcol = @toprow = @current_index = 0
      end

      ## 
      #  Sets the first component (top or left)
      #  
      # @param [String] comp comment
      # @return [true, false] comment

      def first_component(comp)
          @first_component      = comp;
          subpad                = create_buffer # added 2010-01-06 21:22  BUFFERED  (moved from repaint)
          @subform1             = RubyCurses::Form.new subpad # added  2010-01-06 21:22 BUFFERED  (moved from repaint)
          comp.set_form(@subform1) # added 2010 BUFFERED
          @subform1.parent_form = @form # added 2010 for cursor stuff BUFFERED
          ## jeez, we;ve postponed create of buffer XX
          #@first_component.get_buffer().top=1; @row
          #@first_component.get_buffer().left=1; @col
          @first_component.row(1)
          @first_component.col(1)
      end # first_component
      ## 
      #  Sets the second component (bottom or right)
      #  
      # @param [String] comp comment
      # @return [true, false] comment

      def second_component(comp)
          @second_component = comp;
          subpad                = create_buffer # added 2010-01-06 21:22  BUFFERED  (moved from repaint)
          @subform2             = RubyCurses::Form.new subpad # added  2010-01-06 21:22 BUFFERED  (moved from repaint)
          comp.set_form(@subform2) # added 2010 BUFFERED
          @subform2.parent_form = @form # added 2010 for cursor stuff BUFFERED
          ## jeez, we;ve postponed create of buffer XX
          #@second_component.row(1)
          #@second_component.col(1)
      end # second_component
      ##
      #
      # change height of splitpane
      # @param val [int] new height of splitpane
      # @return [int] old ht if nil passed
      def height(*val)
          super
          return @height if val.empty?
          @height = val[0]
          # must tell children if height changed which will happen in nested splitpanes
          # must adjust to components own offsets too
          if @first_component != nil 
              @first_component.height = @height - @col_offset + @divider_offset
          end
          if @second_component != nil 
              @second_component.height = @height - @col_offset + @divider_offset
          end
          @repaint_required = true
      end
      ##
      # change width of splitpane
      # @param val [int, nil] new width of splitpane
      # @return [int] old width if nil passed
      def width(*val)
          super
          return @width if val.empty?
          # must tell children if height changed which will happen in nested splitpanes
          @width = val[0]
          @repaint_required = true
          # must adjust to components own offsets too
          if @first_component != nil 
              @first_component.width = @width - @col_offset + @divider_offset
          end
          if @second_component != nil 
              @second_component.width = @width - @col_offset + @divider_offset
          end
      end
      # set location of divider (row or col depending on orientation)
      # internally sets the second components row or col
      # also to set widths or heights
      # Check minimum sizes are not disrespected
      # @param rc [int] row or column to place divider
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
              $log.debug " set div location, setting first comp width #{rc}"
              if @orientation == :VERTICAL_SPLIT
                  @first_component.width(rc-1) #+ @col_offset + @divider_offset
                  @first_component.height(@height-2) #+ @col_offset + @divider_offset
              else
                  @first_component.height(rc-1) #+ @col_offset + @divider_offset
                  @first_component.width(@width-2) #+ @col_offset + @divider_offset
              end
          end
          return if @second_component == nil
          if @orientation == :VERTICAL_SPLIT
              @second_component.col = rc + @col_offset + @divider_offset
              @second_component.row = 1
              @second_component.width = @width - (rc + @col_offset + @divider_offset + 1)
              @second_component.height = @height-2  #+ @row_offset + @divider_offset
          else
              @second_component.row = rc + 1 #@row_offset + @divider_offset
              @second_component.col = 1
              @second_component.width = @width - 2 #+ @col_offset + @divider_offset
              @second_component.height = @height - rc -2 #+ @row_offset + @divider_offset
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
      def reset_to_preferred_sizes
        return if @first_component.nil?
          @repaint_required = true
          ph, pw = @first_component.get_preferred_size
          if @orientation == :VERTICAL_SPLIT
              rc = pw
          else
              rc = ph
          end
          set_divider_location rc
      end
      def repaint # splitpane
        safe_create_buffer
          # this is in case, not called by form
          # we need to clip components
          # note that splitpanes can be nested

          if @repaint_required
            # TODO this only if major change
              @graphic.wclear
              $log.debug " #{@name} repaint split H #{@height} W #{@width} "
              bordercolor = @border_color || $datacolor
              borderatt = @border_attrib || Ncurses::A_NORMAL
              #@graphic.print_border(0, 0, @height-1, @width-1, bordercolor, borderatt)
              @graphic.print_border(@row, @col, @height-1, @width, bordercolor, borderatt)
              rc = @divider_location

              @graphic.attron(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
              if @orientation == :VERTICAL_SPLIT
                $log.debug "#{@name} prtingign split vline 1, rc: #{rc} "
                  @graphic.mvvline(1, rc, 0, @height-2)
              else
                $log.debug "#{@name} prtingign split hline  rc: #{rc} , 1 "
                  @graphic.mvhline(rc, 1, 0, @width-2)
              end
              @graphic.attroff(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
          end
          #@first_component.row=@row+1
          #@first_component.col=@col+1
          if @first_component != nil
              $log.debug " SPLP repaint 1c ..."
              @first_component.repaint
              ret = @first_component.buffer_to_screen(@graphic)
              $log.debug " SPLP repaint fc ret = #{ret} "
          end
          if @second_component != nil
              $log.debug " SPLP repaint 2c ..."
              @second_component.repaint

              # we need to keep top and left of buffer synced with components row and col.
              # Since buffer has no link to comp therefore it can't check back.
              @second_component.get_buffer().set_screen_row_col(@second_component.row, @second_component.col)

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
      ## most likely should just return an unhandled and not try being intelligent
      def handle_key ch
          # TODO
          # if this gets key it should just hand it to child
        @current_component ||= @first_component
        if @current_component != nil 
          ret = @current_component.handle_key ch
          return ret if ret == 0
        end
        $log.debug " splitpane gets KEY #{ch}"
        case ch
        when ?\M-w.getbyte(0)
          if @current_component == @first_component
            @current_component = @second_component
          else
            @current_component = @first_component
          end
          @form.setrowcol(*@current_component.rowcol)
        else
          return :UNHANDLED
        end
        return 0
      end
      def paint
          @repaint_required = false
      end
  end # class SplitPane
end # module
