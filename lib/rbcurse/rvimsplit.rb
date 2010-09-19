# This is a new kind of splitpane, inspired by the vim editor.
# I was deeply frustrated with the Java kind of splitpane,
# which requires splitpanes within splitpanes to get several split.
# This is an attempt at getting many splits, keeping them at one level
# and keeping the interface as simple as possible, with minimal input
# from user.
# It usually takes a listbox or textview or textarea.
# It can also take an array, or string or hash.
# It supports moving the split, and increasing or decreasing the current box to some extent.
# Typically if the split is vertical, add stacks the components, one below the other.
# If horizontal, if will flow the components, to the right of previous. This can be overriden by passing 
# type as :STACK or :FLOW.
# See examples/testvimsplit.rb
#
# This does not support changing the orientation at run time, that's nice for demos, but a pain
# to get right, and results in a lot of extra code, meaning more bugs.
# TODO: create a class that contains component array and a pointer so it can give next/prev
# i am tired of maintaining this everywhere.
require 'rbcurse'
require 'rbcurse/rlistbox'
require 'rbcurse/rtextview'

include RubyCurses
module RubyCurses
  extend self
  class Coord < Struct.new(:row, :col, :h, :w); end
  class Split < Struct.new(:which, :type, :weight, :add_weight); end
  class VimSplit < Widget

    # split orientation :V or :H
    dsl_accessor :orientation 
    # min and max weight of main split. do not allow user to exceed these
    dsl_accessor :min_weight, :max_weight
    def initialize form, config={}, &block
      if config[:width] == :EXPAND
        config[:width] = Ncurses.COLS - config[:col]
      end
      if config[:orientation] == nil
        config[:orientation] = :HORIZONTAL_SPLIT
      else
        # if first char is V or H then fill it in.
        char = config[:orientation].to_s[0,1].upcase
        if char == "V"
          config[:orientation] = :VERTICAL_SPLIT
        else
          config[:orientation] = :HORIZONTAL_SPLIT
        end
      end
      @max_weight ||= 0.8
      @min_weight ||= 0.2
      super
      @to_print_borders = 1
      @focusable = true
      @editable = false
      @row_offset = @col_offset = 1
      @components = [] # all components
      @c1 =[] # first split's comps
      @c2 =[] # second split's comps
      # coordinates of a split, i calculate and increment row col as i go.
      @c1rc = nil # TODO create once only
      @c2rc = nil

      @ch = {}

      init_vars
      bind_key([?\C-w,?o], :goto_other_split)  
      bind_key([?\C-w,?\C-w], :goto_other_split)  
      bind_key([?\C-w,?-], :decrease_weight)  
      bind_key([?\C-w,?+], :increase_weight)  
      bind_key([?\C-w,?i], :increase_weight)  
      bind_key([?\C-w,?6], :increase_current_component)
      bind_key([?\C-w,?5], :decrease_current_component)
    end
    def init_vars
      @repaint_required = true
      # seems it works with false also, so do we really need it to be true ?
      # whe true was giving a seg fault on increasing child window by 0.05
      @_child_buffering = false # private, internal. not to be changed by callers.
    end
    # uses intelligent default a vertical split would prefer stacks and
    # a horizontal split would go with flows
    # @param [Widget, Array, String, Hash, Variable] to add
    # @param [:FIRST, :SECOND]
    def add c, which, weight=:AUTO, type=:AUTO
      if type == :AUTO
        if v?
          type = :STACK
        else
          type = :FLOW
        end
      end
      _add type, c, which, weight
      return self
    end
    # set the weight of outer split
    def weight(*val)
      if val.empty?
        return @weight
      else
        # raise ArgumentError
        newval = val[0]
        # this is since, using numeric multipliers he can go beyond, so lets give him the best
        if val[0] < @min_weight 
          newval = @min_weight
        elsif val[0] > @max_weight
          newval = @max_weight
        end 
        oldvalue = @weight
        @weight = newval
        fire_property_change(:weight, oldvalue, @weight)
      end
      self
    end
    # stack components, one over another, useful in a vertical split
    # @param [Widget] component
    # @param [:FIRST :SECOND] first or second split
    # @param [Float, nil, :AUTO] weight of object, nil for last will expand it to full
    #     :AUTO will give equal weight to all
    def stack c, which, weight
      _add :STACK, c, which, weight
      return self
    end
    # place components on right of previous. Useful in horizontal split
    def flow c, which, weight
      _add :FLOW, c, which, weight
      return self
    end
    private
    def _add type, c, which, weight
      raise ArgumentError "which must be :FIRST or :SECOND" if which != :FIRST && which != :SECOND
      if weight.nil? || weight == :AUTO || (weight > 0 && weight <= 1.0)
      else
        raise ArgumentError "weight must be >0 and <=1.0 or nil or :AUTO"
      end
      if c.is_a? Widget
        $log.debug " XXXX VIM is a widget"
      else
        case c
        when Array
          lb = Listbox.new nil, :list => c , :name => "list#{@components.size}"
          c = lb
        when String
          lb = TextView.new nil, :name => "text#{@components.size}"
          lb.set_content c
          c = lb
        when Hash
          lb = Listbox.new nil, :list => c.keys , :name => "list#{@components.size}"
          c = lb
        when Variable
          # TODO
        end
      end
      c.parent_component = self
      c.should_create_buffer = @_child_buffering 
      c.ext_row_offset += @ext_row_offset + @row #- @subform1.window.top #0# screen_row
      c.ext_col_offset += @ext_col_offset + @col #-@subform1.window.left # 0# screen_col

      @components << c
      if which == :FIRST
        @c1 << c
      else
        @c2 << c
      end
      #@ch[c] = [which, type, weight]
      @ch[c] = Split.new(which, type, weight)
      @repaint_required = true
    end
    def split_info_for(c = @current_component)
      @ch[c]
    end
    # get the current split focus is on
    # @return [:FIRST, :SECOND] which split are we on
    def current_split
      split_info_for(@current_component).which
    end
    def other_split
      which = current_split
      return which == :FIRST ? :SECOND : :FIRST
    end
    def components_for which
      return which == :FIRST ? @c1 : @c2
    end

    public
    # repaint object
    # called by Form, and sometimes parent component (if not form).
    def repaint
      safe_create_buffer # 2010-01-04 12:36 BUFFERED moved here 2010-01-05 18:07 
      return unless @repaint_required
      # not sure where to put this, once for all or repeat 2010-02-17 23:07 RFED16
      my_win = @form ? @form.window : @target_window
      @graphic = my_win unless @graphic
      #$log.warn "neither form not target window given!!! TV paint 368" unless my_win
      raise " #{@name} neither form, nor target window given TV paint " unless my_win
      raise " #{@name} NO GRAPHIC set as yet                 TV paint " unless @graphic
      @win_left = my_win.left
      @win_top = my_win.top

      $log.debug " VIM repaint graphic #{@graphic} "
      print_borders if @to_print_borders == 1 # do this once only, unless everything changes
      r,c = rowcol

      bordercolor = @border_color || $datacolor
      borderatt = @border_attrib || Ncurses::A_NORMAL


      @graphic.attron(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
      if v?
        rc = (@width * @weight).to_i
        $log.debug "SPLP #{@name} prtingign split vline divider 1, rc: #{rc}, h:#{@height} - 2 "
        @graphic.mvvline(@row+1, rc+@col, 0, @height-2)
        #@c1rc = Coord.new(@row,@col, @height -2, rc)
        #@c2rc = Coord.new(@row,rc+@col,@height-2, @width - rc)
        # TODO don;t keep recreating, if present, reset values
        @c1rc = Coord.new(@row,@col, @height -0, rc)
        @c2rc = Coord.new(@row,rc+@col,@height-0, @width - rc)
      else
        rc = (@height * @weight).to_i
        $log.debug "SPLP #{@name} prtingign split hline divider rc: #{rc} , 1 , w:#{@width} - 2"
        @graphic.mvhline(rc+@row, @col+1, 0, @width-2)
        #@neat = true
        if @neat
          a = 1
          @c1rc = Coord.new(@row+a,@col+a, rc-a, @width-2)
          @c2rc = Coord.new(@row+rc+a,@col+a, @height-rc-2, @width - 2)
        else
          # flush
          a = 0
          @c1rc = Coord.new(@row+a,@col+a, rc, @width-0)
          @c2rc = Coord.new(@row+rc+a,@col+a, @height-rc, @width - 0)
        end
      end
      @graphic.attroff(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
      @components.each { |e| e.repaint_all(true) }
      $log.debug " XXX VIM REPAINT ALL "
      [@c1,@c2].each_with_index do |c,i| 
        rca = @c1rc
        if i == 1
          $log.debug " XXX VIM moving to second"
          rca = @c2rc
        end
        totalw = 0 # accumulative weight
        totalwd = 0 # accumulative weight for width (in case someone switches)
        totalht = 0 # accumulative weight for height (in case someone switches)
        sz = c.size
        auto = 1.0/sz
        c.each do |e| 
          r    = rca.row
          c    = rca.col
          info = @ch[e] 
          type = info.type
          wt   = info.weight
          wt = auto if wt == :AUTO
          if info.add_weight && wt
            $log.debug " XXX before adding #{wt} "
            wt += info.add_weight if info.add_weight
            $log.debug " added XXXX #{wt}, #{info.add_weight} to #{c} "
          end
          #totalw += wt if wt
          #if wt.nil?
            #wt = 1 - totalw
          #end
          e.row = r
          e.col = c
          if type == :STACK
            if wt.nil?
              wt = 1 - totalht
            end
            $log.debug " e #{e.class}, #{e.name}  "
#            e.width = rca.w # changed 2010 dts  
            e.width = (rca.w * (1 - totalwd)).to_i
            e.height = ((rca.h * wt).to_i)
            rca.row += e.height
            totalht += wt if wt
          else
            if wt.nil?
              wt = 1 - totalwd
            end
            #e.height = rca.h
            e.height = (rca.h * (1- totalht)).to_i
            e.width = ((rca.w * wt).to_i)
            rca.col += e.width
            totalwd += wt if wt
          end
          e.set_buffering(:target_window => @target_window || @form.window, :bottom => e.height-1, :right => e.width-1, :form => @form )
          e.set_buffering(:screen_top => e.row, :screen_left => e.col)
          $log.debug " XXXXX VIMS R #{e.row} C #{e.col} H #{e.height} W #{e.width} "
          e.repaint
        end
      end
      #end # repaint_re
      # NOTE: at present one cannot change from flow to stack inside a pane

      @repaint_required = false
      @buffer_modified = true # required by form to call buffer_to_screen BUFFERED
      buffer_to_window # 
    end
    def v?
      @orientation == :VERTICAL_SPLIT
    end
    def h?
      !@orientation == :VERTICAL_SPLIT
    end

    private
    def print_borders
      width = @width
      height = @height-1 # 2010-01-04 15:30 BUFFERED HEIGHT
      window = @graphic  # 2010-01-04 12:37 BUFFERED
      startcol = @col 
      startrow = @row 
      @color_pair = get_color($datacolor)
      #$log.debug "rlistb #{name}: window.print_border #{startrow}, #{startcol} , h:#{height}, w:#{width} , @color_pair, @attr "
      window.print_border startrow, startcol, height, width, @color_pair, @attr
      print_title
    end
    def print_title
      @graphic.printstring( @row, @col+(@width-@title.length)/2, @title, @color_pair, @title_attrib) unless @title.nil?
    end

    public
    # called by parent or form, otherwise its private
    def handle_key ch
      _multiplier = ($multiplier == 0 ? 1 : $multiplier )
      if ch == KEY_TAB
        return goto_next_component
      elsif ch == KEY_BTAB
        return goto_prev_component
      end
      comp = @current_component
      $log.debug " VIMSPL handle_k #{ch}: #{comp}" 
      if comp
        ret = comp.handle_key(ch) 
        if ret != :UNHANDLED
          comp.repaint # NOTE: if we don;t do this, then it won't get repainted. I will have to repaint ALL
          # in repaint of this.
          return ret 
        end
      end
      $log.debug "XXX VIM unahdled by comp #{comp.name} "
      case ch
      when ?\C-c.getbyte(0)
        $multiplier = 0
        return 0
      when ?0.getbyte(0)..?9.getbyte(0)
        $log.debug " VIM coming here to set multiplier #{$multiplier} "
        $multiplier *= 10 ; $multiplier += (ch-48)
        return 0
      end
      ret = process_key ch, self
      # allow user to map left and right if he wants
      if ret == :UNHANDLED
        case ch
        when KEY_UP
          # form will pick this up and do needful
          return goto_prev_component #unless on_first_component?
        when KEY_LEFT
          # if i don't check for first component, key will go back to form,
          # but not be processes. so focussed remain here, but be false.
          # In case of returnign an unhandled TAB, on_leave will happen and cursor will move to 
          # previous component outside of this.
          return goto_prev_component unless on_first_component?
        when KEY_RIGHT
          return goto_next_component unless on_last_component?
        when KEY_DOWN
          return goto_next_component #unless on_last_component?
        else 
          return :UNHANDLED
        end
      end

      $multiplier = 0
      return 0
    end
    # private
    def on_enter
      # TODO if BTAB the last comp
      if $current_key == KEY_BTAB
        @current_component = @components.last
      else
        @current_component = @components.first
      end
      $log.debug " VIM came to on_enter #{@current_component} "
      set_form_row
    end
    def goto_next_component
      if @current_component != nil 
        leave_current_component
        if on_last_component?
          return :UNHANDLED
        end
        @current_index = @components.index(@current_component)
        @current_index += 1
        @current_component = @components[@current_index] 
        #@current_component.on_enter
      end
      return set_form_row
    end
    def goto_prev_component
      if @current_component != nil 
        leave_current_component
        if on_first_component?
          return :UNHANDLED
        end
        @current_index = @components.index(@current_component)
        @current_index -= 1
        @current_component = @components[@current_index] 
        # shoot if this this put on a form with other widgets
        # we would never get out, should return nil -1 in handle key
      end
      set_form_row
      return 0
    end
    # private
    def set_form_row
      #return :UNHANDLED if @current_component.nil?
      $log.debug " VIM on enter sfr #{@current_component} "
      @current_component.on_enter
      @current_component.set_form_col # XXX 
      @current_component.repaint
      # XXX compo should do set_form_row and col if it has that
    end
    # private
    def set_form_col
      return if @current_component.nil?
      $log.debug " #{@name} set_form_col calling sfc for #{@current_component.name} "
      @current_component.set_form_col 
    end
    # leave the component we are on.
    # This should be followed by all containers, so that the on_leave action
    # of earlier comp can be displayed, such as dimming components selections
    def leave_current_component
      @current_component.on_leave
      # NOTE this is required, since repaint will just not happen otherwise
      # Some components are erroneously repainting all, after setting this to true so it is 
      # working there. 
      @current_component.repaint_required true
      $log.debug " after on_leave VIMS XXX #{@current_component.focussed}   #{@current_component.name}"
      @current_component.repaint
    end

    # is focus on first component
    def on_first_component?
      @current_component == @components.first
    end
    # is focus on last component
    def on_last_component?
      @current_component == @components.last
    end
    def goto_other_split
      c = components_for(other_split)
      leave_current_component
      @current_component = c.first
      set_form_row
    end
    # decrease the weight of the split
    def decrease_weight
      _multiplier = ($multiplier == 0 ? 1 : $multiplier )
      weight(weight - 0.1*_multiplier)
    end
    # increase the weight of the split
    def increase_weight
      _multiplier = ($multiplier == 0 ? 1 : $multiplier )
      weight(weight + 0.1*_multiplier)
    end
    def decrease_current_component
      info = split_info_for
      info.add_weight = 0 if info.add_weight.nil?
      if info.add_weight > 0.0
        info.add_weight = info.add_weight - 0.05
      end
      @repaint_required = true
    end
    def increase_current_component
      info = split_info_for
      info.add_weight = 0 if info.add_weight.nil?
      if info.add_weight < 0.3
        info.add_weight = info.add_weight + 0.05
      end
      $log.debug " XXX modifed add_weight to #{info.add_weight} "
      @repaint_required = true
    end

    # ADD HERE ABOVe
  end # class
end # module
