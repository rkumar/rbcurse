require 'rbcurse'

# This is a horizontal scroller, to scroll a list of options much like
# vim often does on the statusline. I'd like to use it for scrolling
# menus or buttons like on TabbedPanes to avoid another Form.

# You may bind to the ENTER_ROW event to chagne some data elsewhere,
# or the PRESS event. In this case, PRESS will refer to pressing the
# space bar or ENTER. There is <em>no</em> LIST_SELECTION event for that.



module RubyCurses

  # Horizontal list scrolling and selection.
  #
  #    == Example
  #    require 'rbcurse/extras/horizlist'
  #    require 'fileutils'
  #    l = HorizList.new @form, :row => 5, :col => 5, :width => 80 
  #    list = Dir.glob("*")
  #    l.list(list)

  class HorizList < Widget

    def initialize form, config={}, &block
      super
      @_events.push(*[:ENTER_ROW, :LEAVE_ROW, :PRESS])
      @focusable = true
      init_vars
      @list = []
      @toprow = 0

      # last printed index
      @last_index = 0

      # item on which cursor is
      @current_index = 0
    end
    def init_vars
    end
    # alias :text :getvalue # NEXT VERSION

    def map_keys
      @keys_mapped = true
      bind_keys([KEY_RIGHT, ?l, ?.], :next_item)
      bind_keys([KEY_LEFT, ?h,?,], :previous_item)
      bind_keys([10,13,32]){ fire_action_event }
      bind_keys([?\M-l,?>, KEY_DOWN], :scroll_right)
      bind_keys([?\M-h,?<, KEY_UP], :scroll_left)
    end
    def list(strings)
      @list = strings
    end
    def add item
      @list << item
    end
    def repaint
      return unless @repaint_required
      @window ||= @form.window
      $log.debug "XXX:HORIZ REPAINT Ci #{@current_index}, TR #{@toprow} "
      $status_message.value = " #{@current_index}, TR #{@toprow} "
      @window.printstring @row, @col, " "* @width, @color_pair || $reversecolor
      c = @col + 1
      t = @toprow
      @list.each_with_index { |e, i| 
        next if i < t # sucks for large lists
        break if c + e.length >= @width + @col
        att = @attrib || FFI::NCurses::A_NORMAL
        if i == @current_index
          att = FFI::NCurses::A_REVERSE if i == @current_index
          acolor = @focussed_color_pair ||  get_color($datacolor,'green', 'white') 
        else
          acolor = @color_pair
        end
        @window.printstring @row, c, e, acolor  || $reversecolor, att
        c += e.length + 2
        @last_index = i
        break if c >= @width + @col
      }
      @repaint_required = false
    end
    def handle_key ch
      map_keys unless @keys_mapped
      ret = process_key ch, self
      @multiplier = 0
      return :UNHANDLED if ret == :UNHANDLED
    end
    def previous_item num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
    
      return :NO_PREVIOUS_ROW if @current_index == 0 
      @old_toprow = @toprow
      @oldrow = @current_index
      @current_index -= num
      @current_index = 0 if @current_index < 0
      bounds_check
      $multiplier = 0
      if @current_index < @toprow
        @toprow = @current_index
      end
      @toprow = 0 if @toprow < 0
      @repaint_required = true
    end
    def next_item num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
      rc = row_count
      return :NO_NEXT_ROW if @current_index == rc-1  # changed 2011-10-5 so process can do something
      @old_toprow = @toprow
      @oldrow = @current_index
      @current_index += num 
      @current_index = rc - 1 if @current_index >= rc
      @toprow = @current_index if @current_index > @last_index
      bounds_check
      $multiplier = 0
      @repaint_required = true
    end
    def scroll_right
      rc = row_count
      return :NO_NEXT_ROW if @current_index == rc-1  # changed 2011-10-5 so process can do something
      @old_toprow = @toprow
      @oldrow = @current_index

      @current_index = @last_index + 1

      @current_index = rc - 1 if @current_index >= rc
      @toprow = @current_index if @current_index > @last_index
      bounds_check
      $multiplier = 0
      @repaint_required = true
    end
    def scroll_left
      return :NO_PREVIOUS_ROW if @current_index == 0 
      @old_toprow = @toprow
      @oldrow = @current_index
      @current_index = @toprow - 4
      @current_index = 0 if @current_index < 0
      bounds_check
      $multiplier = 0
      if @current_index < @toprow
        @toprow = @current_index
      end
      @toprow = 0 if @toprow < 0
      @repaint_required = true
    end
    def row_count; @list.size; end
    def bounds_check
      @row_changed = false
      if @oldrow != @current_index
        on_leave_row @oldrow if respond_to? :on_leave_row     # to be defined by widget that has included this
        on_enter_row @current_index   if respond_to? :on_enter_row  # to be defined by widget that has included this
        set_form_row
        @row_changed = true
      end
      if @old_toprow != @toprow # only if scrolling has happened should we repaint
        @repaint_required = true 
        @widget_scrolled = true
      end
    end
    def on_enter
      if @list.nil? || @list.size == 0
        Ncurses.beep
        return :UNHANDLED
      end
      super  
      on_enter_row @current_index
      set_form_row
      true
    end
    def on_enter_row arow
      fire_handler :ENTER_ROW, self
      @repaint_required = true
    end
    def on_leave_row arow
      fire_handler :LEAVE_ROW, self
    end
    def fire_action_event
      require 'rbcurse/ractionevent'
      fire_handler :PRESS, ActionEvent.new(self, :PRESS, text)
    end
    def current_value
      @list[@current_index]
    end
    alias :text :current_value
    ##
  end # class
end # module
if __FILE__ == $PROGRAM_NAME
  require 'rbcurse/app'

  App.new do
    require 'rbcurse/extras/horizlist'
    require 'fileutils'
    l = HorizList.new @form, :row => 5, :col => 5, :width => 80 
    list = Dir.glob("*")
    l.list(list)
    l.bind(:PRESS){ |eve| alert "You pressed #{eve.text} " }
    sl = status_line
    sl.command do
      " Status:  #{$status_message} "
    end
  end

  
end
