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
require 'rbcurse/extras/divider'
require 'rbcurse/extras/focusmanager'

include RubyCurses
module RubyCurses
  extend self
  class Coord < Struct.new(:row, :col, :h, :w); end
  # Split contains info for a component added. weight is preferred weight
  # and can contain value :AUTO. act_weight has the weight calculated.
  # Often, last component can be nil, remainder will be assigned to it.
  class Split < Struct.new(:which, :type, :weight, :act_weight); end
  class ResizeEvent < Struct.new(:source, :type); end

  # A simpler replacement for the java-esque SplitPane. This can take multiple splits
  # and does not require splits within splits as SplitPane does.
  # This is less functional, but should be easier to use, setup and hack.
  class VimSplit < Widget

    # split orientation :V or :H
    dsl_accessor :orientation 
    # min and max weight of main split. do not allow user to exceed these
    dsl_accessor :min_weight, :max_weight
    dsl_accessor :suppress_borders #to_print_borders
    dsl_accessor :border_attrib, :border_color
    attr_reader :current_component
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
      @min_weight ||= 0.1 # earlier 0.2 but i wanted 0.15, someone may want 0.05 ??
      @suppress_borders = false
      @_use_preferred_sizes = true
      @row_offset = @col_offset = 1
      # type can be :INCREASE, :DECREASE, :EXPAND, :UNEXPAND :EQUAL
      @_events ||= []
      @_events.push :COMPONENT_RESIZE_EVENT
      @_events.push :DRAG_EVENT
      super
      @focusable = true
      @editable = false
      @components = [] # all components
      @c1 =[] # first split's comps
      @c2 =[] # second split's comps
      # coordinates of a split, i calculate and increment row col as i go.
      @c1rc = nil # TODO create once only
      @c2rc = nil

      # hash, keyed on component, contains Split (which side, flow or stack, weight)
      @ch = {}
      @weight ||= 0.50

      init_vars
      bind_key([?\C-w,?o], :expand)  
      bind_key([?\C-w,?1], :expand)  
      bind_key([?\C-w,?2], :unexpand)  
      bind_key([?\C-w,?\C-w], :goto_other_split)  
      bind_key([?\C-w,?-], :decrease_height)  
      bind_key([?\C-w,?+], :increase_height)  
      bind_key([?\C-w,?<], :decrease_width)  
      bind_key([?\C-w,?>], :increase_width)  
      bind_key([?\C-w,?i], :increase_weight)  
      bind_key([?\C-w,?d], :decrease_weight)  
      bind_key([?\C-w,?6], :increase_current_component)
      bind_key([?\C-w,?5], :decrease_current_component)
      # this needs to be set at application level
      bind_key(FFI::NCurses::KEY_F3) {RubyCurses::FocusManager.toggle_focusable}
    end
    def init_vars
      @repaint_required = true
      @recalculate_splits = true # convert weight to size
      @row_offset = @col_offset = 0 if @suppress_borders # FIXME supposed to use this !!

      @internal_width = 2
      @internal_width = 1 if @suppress_borders

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
      #return self # lets return component created for christ's sake and keep it simple
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
        # orientation can be nil, so we cannot calculate rc here
        #if v?
          #@rc = (@width * @weight).to_i
        #else
          #@rc = (@height * @weight).to_i
        #end
        @rc = nil # so recalculated in repaint
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
      #return self # lets return component created for christ's sake and keep it simple
    end
    # place components on right of previous. Useful in horizontal split
    def flow c, which, weight
      _add :FLOW, c, which, weight
      #return self # lets return component created for christ's sake and keep it simple
    end
    private
    def _add type, c, which, weight
      raise ArgumentError, "Nil component passed to add" unless c
      raise ArgumentError, "which must be :FIRST or :SECOND" if which != :FIRST && which != :SECOND
      # trying out wt of 0 means it will see height of object and use that.
      if weight.nil? || weight == :AUTO || (weight >= 0 && weight <= 1.0)
      else
        raise ArgumentError, "weight must be >0 and <=1.0 or nil or :AUTO"
      end
      if c.is_a? Widget
        if c.form && c.form != @form
          $log.debug " removing widget VIMSPLIT #{c.class} "
          c.form.remove_widget c
          c.form = nil
        end
        #$log.debug " XXXX VIM is a widget"
      else
        case c
        when Array
          lb = Listbox.new nil, :list => c , :name => "list#{@components.size}"
          c = lb
        when String
          require 'rbcurse/rtextview'
          lb = TextView.new nil, :name => "text#{@components.size}"
          lb.set_content c
          c = lb
        when Hash
          lb = Listbox.new nil, :list => c.keys , :name => "list#{@components.size}"
          c = lb
        when Variable
          # TODO
        else
          if c == :grabbar || c == :divider
            side = :bottom
            case type
            when :STACK
              side = :bottom
            when :FLOW
              side = :left
            end
            c = Divider.new nil, :parent => @components.last, :side => side
            c.focusable(false)
            RubyCurses::FocusManager.add c
            c.bind :DRAG_EVENT do |ev|
              source = ev.source
              case ev.type
              when KEY_UP
                # CHECK BOUNDS TODO 
                # TODO what about KEY_LEFT and RIGHT ?
                if source.next_component && source.next_component.row > 1 && source.parent.height > 1
                  source.parent.height -= 1
                  source.next_component.height +=1
                  source.next_component.row -= 1
                  source.parent.repaint_required
                  source.next_component.repaint_required
                  source.parent.repaint
                  source.next_component.repaint
                end
              when KEY_DOWN
                # CHECK BOUNDS TODO check with appemail.rb
                if source.next_component && source.next_component.height > 1
                  source.parent.height += 1
                  source.next_component.height -=1
                  source.next_component.row += 1
                  source.parent.repaint_required
                  source.next_component.repaint_required
                  source.parent.repaint
                  source.next_component.repaint
                end
              end
            end
          end
        end
      end
      c.parent_component = self

      @components << c
      if which == :FIRST
        @c1 << c
      else
        @c2 << c
      end
      #@ch[c] = [which, type, weight]
      @ch[c] = Split.new(which, type, weight)
      @repaint_required = true
      return c
    end
    public
    def split_info_for(c = @current_component)
      @ch[c]
    end
    # get the current split focus is on
    # @return [:FIRST, :SECOND] which split are we on
    def current_split
      split_info_for(@current_component).which
    end
    # returns the other split.
    def other_split
      which = current_split
      return which == :FIRST ? :SECOND : :FIRST
    end
    # returns list of components for FIRST or SECOND split
    def components_for which
      return which == :FIRST ? @c1 : @c2
    end

    public
    # repaint object
    # called by Form, and sometimes parent component (if not form).
    def repaint
      my_win = @form ? @form.window : @target_window
      @graphic = my_win unless @graphic
      raise " #{@name} NO GRAPHIC set as yet                 VIMSPLIT paint " unless @graphic

      #return unless @repaint_required
      @recalculate_splits = true if @rc.nil?

      # if some major change has happened then repaint everything
      if @repaint_required
        $log.debug " VIM repaint graphic #{@graphic} "
        print_borders unless @suppress_borders # do this once only, unless everything changes
        r,c = rowcol

        bordercolor = @border_color || $datacolor
        borderatt = @border_attrib || Ncurses::A_NORMAL


        @graphic.attron(Ncurses.COLOR_PAIR(bordercolor) | borderatt)

        ##  The following calculations are only calcing the 2 split areas
        ##   and divider locations based on V or H and weight.

        @gbwid ||= 0    # grabbar width
        roffset = 1
        loffset = 2
        if @suppress_borders
          loffset = roffset = 0
        end
        # vertical split 
        if v?
          @rc ||= (@width * @weight).to_i
          rc = @rc            # divider location
          $log.debug "SPLP #{@name} prtingign split vline divider 1, rc: #{rc}, h:#{@height} - 2 "
          unless @vb             # if grabbar not created
            @gbwid = 1
            _create_divider
          else                   # created, so set it
            @vb.row @row+roffset
            @vb.col rc+@col
            #@vb.repaint
          end
          #@graphic.mvvline(@row+1, rc+@col, 0, @height-2)
          # TODO don;t keep recreating, if present, reset values
          ## calculate cordinated of both split areas/boxes
          @c1rc = Coord.new(@row,@col, @height -0, rc-@gbwid)
          @c2rc = Coord.new(@row,rc+@col+@gbwid,@height-0, @width - rc-@gbwid)
        else #  horizontal split
          @rc ||= (@height * @weight).to_i
          rc = @rc         # dividers row col location
          $log.debug "SPLP #{@name} prtingign split hline divider rc: #{rc} , 1 , w:#{@width} - 2"
          unless @vb
            @gbwid = 1
            _create_divider
          else
            #@vb = Divider.new nil, :row => @row+rc-1, :col => @col+1, :length => @width-loffset, :side => :bottom
            @vb.row @row+@rc-1
            @vb.col @col+roffset
            #@vb.repaint # getting wiped out by vimsplit ?
          end
          #@graphic.mvhline(rc+@row, @col+1, 0, @width-@internal_width)
          #@neat = true
          if @neat
            a = 1
            @c1rc = Coord.new(@row+a,@col+a, rc-a, @width-@internal_width)
            @c2rc = Coord.new(@row+rc+a,@col+a, @height-rc-2, @width - @internal_width)
          else
            # flush against border
          #@c1rc = Coord.new(@row,@col, @height -0, rc-@gbwid)
          #@c2rc = Coord.new(@row,rc+@col+@gbwid,@height-0, @width - rc-@gbwid)
            a = 0
            @c1rc = Coord.new(@row,@col, rc-@gbwid, @width)
            @c2rc = Coord.new(@row+rc, @col, @height-rc-@gbwid, @width)
          end
        end
        @graphic.attroff(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
        @components.each { |e| e.repaint_all(true) }
        $log.debug " XXX VIM REPAINT ALL "
        # FIXME do this only once, or when major change happends, otherwise
        # i cannot increase decrease size on user request.
        recalculate_splits @_use_preferred_sizes if @recalculate_splits
        # vimsplit often overwrites this while divider is being moved so we must
        # again call it.
        @vb.repaint if @vb
      else
        # only repaint those that are needing repaint
        # 2010-09-22 18:09 its possible somenoe has updated an internal
        # component, but this container does not know. So we've got to call
        # repaint on all components, only those which are changed will
        # actually be repainted
        @components.each { |e| e.repaint }
      end # if repaint_required
      # NOTE: at present one cannot change from flow to stack inside a pane

      @repaint_required = false
    end
    def v?
      @orientation == :VERTICAL_SPLIT
    end
    def h?
      !@orientation == :VERTICAL_SPLIT
    end
    # convert weight to  height and length
    # we should only do this once, or if major change
    # otherwise changes that user may have effected in size will be lost
    # NOTE: this resets all components to preferred weights (given when component was added. 
    # If user has resized components
    # then those changes in size will be lost.
    def reset_to_preferred_size  
      recalculate_splits use_preferred_sizes=true
    end
    def recalculate_splits use_preferred_sizes=false 
      @recalculate_splits = false
      [@c1,@c2].each_with_index do |c,i| 
        rca = @c1rc
        if i == 1
          #$log.debug " XXX VIM moving to second"
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
          e.row = r
          e.col = c
          if type == :STACK
            # store actual weight that was calculated, so if user reduces or increases
            # we can use this, although ... we have no method that uses actual weights
            # NOTE: If calling program increases one comp's weight, will have to reduce other.
            info.act_weight = wt

            e.width = (rca.w * (1 - totalwd)).to_i
            # recaclulate height only in this case, otherwise we will overwrite changes
            # made by user
            if use_preferred_sizes
              if wt != 0
                if wt
                  e.height = ((rca.h * wt).to_i)
                else
                  a = 0
                  a = 1 if @suppress_borders
                  e.height = rca.h - rca.row + a # take exactly rows left
                end
                # else use its own height
              end
            end
            rca.row += e.height
            totalht += wt if wt
          else
            # TODO THIS PART AS PER ABOVE CASE ,  TO TEST
            # this is a horizontal split or flow
            info.act_weight = wt
            #e.height = rca.h
            e.height = (rca.h * (1- totalht)).to_i
            if use_preferred_sizes
              if wt != 0
                if wt
                  e.width = ((rca.w * wt).to_i)
                else
                  a = 0
                  a = 1 if @suppress_borders
                  e.width = rca.w - rca.col + a # take exactly rows left
                end
              end
            end
            rca.col += e.width
            totalwd += wt if wt
          end
          e.set_buffering(:target_window => @target_window || @form.window, :bottom => e.height-1, :right => e.width-1, :form => @form ) # removed on 2011-09-29 
          $log.debug " XXXXX VIMS R #{e.row} C #{e.col} H #{e.height} W #{e.width} "
          e.repaint
          e._object_created = true # added 2010-09-16 13:02 now prop handlers can be fired
        end
      end
      @_use_preferred_sizes = false
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
      $log.debug " VIMSPLIT handle_key #{ch} "
      _multiplier = ($multiplier == 0 ? 1 : $multiplier )
      if ch == KEY_TAB
        $log.debug " GOTO NEXT"
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
      $log.debug "XXX VIM key unhandled by comp #{comp.name} "
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
          return goto_next_component #unless on_last_component?
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
        # FIXME last is not focusable, then ??
        @current_component = @components.last
      else
        @current_component = @components.first
      end
      $log.debug " VIM came to on_enter #{@current_component} "
      set_form_row
    end
    def on_leave
      super
    end
    def goto_next_component
      if @current_component != nil 
        leave_current_component
        if on_last_component?
          return :UNHANDLED
        end
        @current_index = @components.index(@current_component)
        index = @current_index + 1
        index.upto(@components.length-1) do |i|
          f = @components[i]
          if f.focusable
            @current_index = i
            @current_component = f
            return set_form_row
          end
        end
      end
      return :UNHANDLED
    end
    def goto_prev_component
      if @current_component != nil 
        leave_current_component
        if on_first_component?
          return :UNHANDLED
        end
        @current_index = @components.index(@current_component)
        index = @current_index -= 1
        index.downto(0) do |i|
          f = @components[i]
          if f.focusable
            @current_index = i
            @current_component = f
            return set_form_row
          end
        end
      end
      return :UNHANDLED
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
    # set focus on given component
    # Sometimes you have the handle to component, and you want to move focus to it
    def goto_component comp
      return if comp == @current_component
      leave_current_component
      @current_component = comp
      set_form_row
    end
    # decrease the weight of the split
    def decrease_weight
      _multiplier = ($multiplier == 0 ? 1 : $multiplier )
      weight(weight - 0.05*_multiplier)
    end
    # increase the weight of the split
    def increase_weight
      _multiplier = ($multiplier == 0 ? 1 : $multiplier )
      weight(weight + 0.05*_multiplier)
    end
    # FIXME - i can only reduce if i've increased
    def decrease_current_component
      info = split_info_for
      #info.add_weight = 0 if info.add_weight.nil?
      #if info.add_weight > 0.0
        #info.add_weight = info.add_weight - 0.05
      #end
      e = ResizeEvent.new @current_component, :DECREASE
      fire_handler :COMPONENT_RESIZE_EVENT, e
      #@repaint_required = true
    end
    # fires handler to request app to resize component
    # @param [:INCREASE, :DECREASE]
    # @param [:HEIGHT, :WIDTH]
    def resize_component incdec, hw  #:nodoc:
      type = incdec.to_s + '_' + hw.to_s
      #info = split_info_for
      #info.add_weight = 0 if info.add_weight.nil?
      e = ResizeEvent.new @current_component, type.to_sym
      fire_handler :COMPONENT_RESIZE_EVENT, e
      #@repaint_required = true
    end
    # fires handler to request app to resize current component
    # 
    def decrease_height
      resize_component :DECREASE, :HEIGHT
    end
    # fires handler to request app to resize current component
    def decrease_width
      resize_component :DECREASE, :WIDTH
    end
    # fires handler to request app to resize current component
    def increase_width
      resize_component :INCREASE, :WIDTH
    end
    # fires handler to request app to resize current component
    def increase_height
      resize_component :INCREASE, :HEIGHT
    end
    def increase_current_component
      info = split_info_for
      #info.add_weight = 0 if info.add_weight.nil?
      #if info.add_weight < 0.3
        #info.add_weight = info.add_weight + 0.05
      #end
      e = ResizeEvent.new @current_component, :INCREASE
      fire_handler :COMPONENT_RESIZE_EVENT, e
      #@repaint_required = true
    end
    # calling application need to handle this, since it knows
    # how many windows its has and what the user would mean
    def expand # maximize 
      e = ResizeEvent.new @current_component, :EXPAND
      fire_handler :COMPONENT_RESIZE_EVENT, e
    end
    # calling application need to handle this, since it knows
    # how many windows its has and what the user would mean
    def unexpand
      e = ResizeEvent.new @current_component, :UNEXPAND
      fire_handler :COMPONENT_RESIZE_EVENT, e
    end

    private
    def _create_divider
      return if @vb
      roffset = 1
      loffset = 2
      if @suppress_borders
        loffset = roffset = 0
      end
      rc = @rc
      if v?
        @vb = Divider.new nil, :row => @row+roffset, :col => rc+@col-1, :length => @height-loffset, :side => :right
      else
        @vb = Divider.new nil, :row => @row+rc-1, :col => @col+1, :length => @width-loffset, :side => :bottom
      end
      @vb.focusable(false)
      RubyCurses::FocusManager.add @vb
      @vb.parent_component = self
      @components << @vb
      @vb.set_buffering(:target_window => @target_window || @form.window, :form => @form ) # removed on 2011-09-29 
      @vb.bind :DRAG_EVENT do |ev|
        if v?
          case ev.type
          when KEY_RIGHT
            $log.debug "VIMSPLIT RIGHT "
            if @rc < @width - 3
              @recalculate_splits = true
              @rc += 1
              @repaint_required = true # WHY ! Did prop handler not fire ?
            end
          when KEY_LEFT
            if @rc > 3
              @recalculate_splits = true
              @repaint_required = true
              @rc -= 1 
            end
          end
        else
          # horizontal
          case ev.type
          when KEY_DOWN
            if @rc < @height - 3
              @recalculate_splits = true
              @rc += 1
              @repaint_required = true # WHY ! Did prop handler not fire ?
            end
          when KEY_UP
            if @rc > 3
              @recalculate_splits = true
              @repaint_required = true
              @rc -= 1 
            end
          end
        end # v?
      end
    end

    # ADD HERE ABOVe
  end # class
end # module
