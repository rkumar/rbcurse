require 'rbcurse/app'
include Ncurses
include RubyCurses

# This is a horizontal or vertical bar (like a scrollbar), at present attached to a
# widget that is focusable, and allows user to press arrow keys.
# It highlights on focus, the caller can expand and contract components in a container
# or even screen, based on arrow movements. This allows for a visual resizing of components.
# TODO : We can consider making it independent of objects, or allow for a margin so it does not write
# over the object. Then it will be always visible.
# TODO: if lists and tables, can without borders actually adjust then putting this independent
# would make even more sense, since it won't eat an extra line.
#
# @example
#     lb = list_box ....
#      rb = Grabbar.new @form, :parent => lb, :side => :right
#
# At a later stage, we will integrate this with lists and tables, so it will happen automatically.
#
# @since 1.2.0    UNTESTED
module RubyCurses
  class DragEvent < Struct.new(:source, :type); end
  class Grabbar < Widget
    # row to start, same as listbox, required.
    dsl_property :row
    # column to start, same as listbox, required.
    dsl_property :col
    # how many rows is this (should be same as listboxes height, required.
    dsl_property :length
    # vertical or horizontal currently only VERTICAL
    dsl_property :side
    # initialize based on parent's values
    dsl_property :parent
    # which row is focussed, current_index of listbox, required.
    # how many total rows of data does the list have, same as @list.length, required.
    dsl_accessor :next

    # TODO: if parent passed, we shold bind to ON_ENTER and get current_index, so no extra work is required.

    def initialize form, config={}, &block

      # setting default first or else Widget will place its BW default
      #@color, @bgcolor = ColorMap.get_colors_for_pair $bottomcolor
      super
      @height = 1
      @color_pair = get_color $datacolor, @color, @bgcolor
      @scroll_pair = get_color $bottomcolor, :green, :white
      #@window = form.window
      @editable = false
      @focusable = true
      @repaint_required = true
      @_events.push(:DRAG_EVENT)
      unless @parent
        raise ArgumentError, "row col and length should be provided" if !@row || !@col || !@length
      end
      #if @parent
        #@parent.bind :ENTER_ROW do |p|
          ## parent must implement row_count, and have a @current_index
          #raise StandardError, "Parent must implement row_count" unless p.respond_to? :row_count
          #self.current_index = p.current_index
          #@repaint_required = true  #requred otherwise at end when same value sent, prop handler
          ## will not be fired (due to optimization).
        #end
      #end
    end

    ##
    # repaint the scrollbar
    # Taking the data from parent as late as possible in case parent resized, or 
    # moved around by a container.
    def repaint
      woffset = 2
      coffset = 1
      if @parent
        woffset = 0 if @parent.suppress_borders
        @border_attrib ||= @parent.border_attrib
        case @side
        when :right
          @row = @parent.row+1
          @col = @parent.col + @parent.width - 1
          @length = @parent.height - woffset
        when :left
          @row = @parent.row+1
          @col = @parent.col+0 #+ @parent.width - 1
          @length = @parent.height - woffset
        when :top
          @row = @parent.row+0
          @col = @parent.col + @parent.col_offset #+ @parent.width - 1
          @length = @parent.width - woffset
        when :bottom
          @row = @parent.row+@parent.height-0 #1
          @col = @parent.col+@parent.col_offset #+ @parent.width - 1
          @length = @parent.width - woffset
        end
      else
        # row, col and length should be passed
      end
      my_win = @form ? @form.window : @target_window
      @graphic = my_win unless @graphic
      raise "graphic is nil in grabbar, perhaps form was nil when creating" unless @graphic
      return unless @repaint_required

      # first print a right side vertical line
      #bc = $bottomcolor  # dark blue
      bc = $datacolor
      bordercolor = @border_color || bc
      borderatt = @border_attrib || Ncurses::A_REVERSE
      if @focussed 
        bordercolor = $promptcolor || bordercolor
      end

      borderatt = convert_attrib_to_sym(borderatt) if borderatt.is_a? Symbol

      @graphic.attron(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
      $log.debug " XXX SCROLL #{@row} #{@col} #{@length} "
      case @side
      when :right, :left
        @graphic.mvvline(@row, @col, 1, @length)
      when :top, :bottom
        @graphic.mvhline(@row, @col, 1, @length)
      end
      @graphic.attroff(Ncurses.COLOR_PAIR(bordercolor) | borderatt)

      @repaint_required = false
    end
    def convert_attrib_to_sym attr
      case attr
      when 'reverse'
        Ncurses::A_REVERSE
      when 'bold'
        Ncurses::A_BOLD
      when 'normal'
        Ncurses::A_NORMAL
      when 'blink'
        Ncurses::A_BLINK
      when 'underline'
        Ncurses::A_UNDERLINE
      else
        Ncurses::A_REVERSE
      end
    end
    def handle_key ch
      case @side
      when :right, :left
        case ch
        when KEY_RIGHT
          fire_handler :DRAG_EVENT, DragEvent.new(self, ch)
        when KEY_LEFT
          fire_handler :DRAG_EVENT, DragEvent.new(self, ch)
        else
          return :UNHANDLED
        end
      when :top, :bottom
        case ch
        when KEY_UP
          fire_handler :DRAG_EVENT, DragEvent.new(self, ch)
        when KEY_DOWN
          fire_handler :DRAG_EVENT, DragEvent.new(self, ch)
        else
          return :UNHANDLED
        end
      end
      @repaint_required = true
    end
    def on_enter
      # since it is over border of component, we need to repaint
      @focussed = true
      @repaint_required = true
      repaint
    end
    def on_leave
      @focussed = false
      @repaint_required = true
      repaint
      if @parent
        # since it is over border of component, we need to clear
        @parent.repaint_required 
        # if we don't paint now, parent paints over other possible grabbars
        @parent.repaint
      end
    end
    def set_form_row
      r,c = rowcol
      setrowcol r, c
    end
    # set the cursor on first point of bar
    def set_form_col
      # need to set it to first point, otherwise it could be off the widget
      r,c = rowcol
      setrowcol r, c
      #noop
    end
    ##
    ##
    # ADD HERE 
    end # class
end # module
if __FILE__ == $PROGRAM_NAME
  App.new do
    r = 5
    len = 20
    list = []
    0.upto(100) { |v| list << "#{v} scrollable data" }
    lb = list_box "A list", :list => list, :row => 2, :col => 2
    #sb = Scrollbar.new @form, :row => r, :col => 20, :length => len, :list_length => 50, :current_index => 0
    rb = Grabbar.new @form, :parent => lb, :side => :right
    rb.bind :DRAG_EVENT do |e|
      message "got an event #{e.type} "
      case e.type
      when KEY_RIGHT
        lb.width += 1
      when KEY_LEFT
        lb.width -= 1
      end
      lb.repaint_required
    end
    rb1 = Grabbar.new @form, :parent => lb, :side => :left
    rb1.bind :DRAG_EVENT do |e|
      message " 2 got an event #{e.type} "
    end
    #hline :width => 20, :row => len+r
    #keypress do |ch|
      #case ch
      #when :down
        #sb.current_index += 1
      #when :up
        #sb.current_index -= 1
      #end
    #end
  end
end
