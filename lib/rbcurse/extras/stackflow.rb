=begin
  * Name: rcontainer2.rb
          A version of Container that uses stacks and flows and later grids
          to place components
          This is not a form. Thus it can be safely placed as a widget
          without all the complicatinos of a form embedded inside another.
NOTE: Still experimental
  * Description   
  * Author: rkumar (http://github.com/rkumar/rbcurse/)
  * Date:  23.10.11 - 19:55
  * License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

  * Last update:  23.10.11
  == CHANGES
  == TODO 
    Resizing components
    If window or container resized then redo the calc again.
    RESET height only if expandable
    CLEANUP its a mess due to stacks and flows not being widgets.
    - exceeding 100 will result in exceeding container.
    - take care of margins
    - are two weights needed horiz and vertical ?
    - C-a C-e misbehaving in examples

=end

require 'rbcurse'

include RubyCurses
module RubyCurses
  extend self

  # This is a more advanced version of container
  # which allows user to stack or flow components, including
  # embedding stacks within flows and viceversa.


  class StackFlow < Widget

    dsl_accessor :suppress_borders            #to_print_borders
    dsl_accessor :border_attrib, :border_color
    dsl_accessor :title                       #set this on top
    dsl_accessor :title_attrib                #bold, reverse, normal
    # should container stack objects ignoring users row col
    # this is esp needed since App sets row and col which is too early
    # This is now the default value, till i can redo things
    #dsl_accessor :stack
    dsl_accessor :positioning                 # absolute, relative, stack
    attr_reader  :current_component

    def initialize form=nil, config={}, &block
      @suppress_borders = false
      @row_offset = @col_offset = 1
      @_events ||= []
      @stack = true
      @positioning = :stack
      @focusable = true
      @editable = false
      @components = [] # all components
      @focusables = [] # focusable components, makes checks easier
      @active     = []
      super

      init_vars
    end
    def init_vars
      @repaint_required = true
      @row_offset = @col_offset = 0 if @suppress_borders # FIXME supposed to use this !!
      @ctr = 0

      @internal_width = 2
      @internal_width = 1 if @suppress_borders
      @name ||= "AContainer"
      @first_time = true
      bind_key(?\M-1, :increase_current)
      bind_key(?\M-2, :decrease_current)
      #raise "NO components !" if @components.empty?
      #@components.each { |e| calc_weightages e }
      calc_weightages2(@components, self)

    end
    #stack :margin_top => 2, :margin_left => 1 do
    #class Stack < Struct.new(:margin_top, :margin_left, :width, :height, :components); end



    # NOTE: since we are handling the traversal, we delink the object from any
    # form's widgets array  that might have been added. Whenever a form is available,
    # we set it (without adding widget to it) so it can print using the form's window.
    # 
    # @param [Widget] to add
    def __add *items
      items.each do |c|  
        raise ArgumentError, "Nil component passed to add" unless c
        if c.is_a? Widget
          if c.form && c.form != @form
            $log.debug " removing widget VIMSPLIT #{c.class} wr:  #{c.row} row:#{@row} ht:#{@height} "
            c.form.remove_widget c
            c.form = nil
            # or should i just stack them myself and screw what you've asked for
          end
          # take it out of form's control. We will control it.
          if c.form
            c.form.remove_widget c
          end
          # shoot, what if at this point the container does not have a form
          attach_form c if @form
        end
        # most likely if you have created both container and widgets
        # inside app, it would have given row after container

        #@components << c
        if c.focusable
          @focusables << c 
          @current_component ||= c # only the first else cursor falls on last on enter
        end

      end # items each
      self
    end

    # When we get a form, we silently attach it to this object, without the form
    #  knowing. We don't want form managing this object.
    def attach_form c
      c.form = @form
      c.override_graphic @graphic
      c.parent_component = self
    end
    def widgets; @components; end
    # what of by_name


    # correct coordinates of comp esp if App has stacked them after this
    # container
    # It is best to use the simple stack feature. The rest could change at any time
    #  and is quite arbitrary. Some folks may set absolute locations if container
    #  is directly on a form, others may set relative locations if it is inside a 
    #  tabbed pane or other container. Thus, stacks are best
    def correct_component c
      raise "Form is still not set in RContainer" unless @form
      attach_form(c) unless c.form
      @last_row ||= @row + 1
      inset = 2
      # 2011-10-20 current default behaviour is to stack
      if @positioning == :stack
        c.row = @last_row
        c.col = @col + inset

        # do not advance row, save col for next row
        @last_row += 1
      elsif @positioning == :relative   # UNTESTED NOTE
        if (c.row || 0) <= 0
          $log.warn "c.row in RCONTAINER is #{c.row} "
          c.row = @last_row
          @last_row += 1
        elsif c.row > @row + @height -1
          $log.warn "c.row in RCONTAINER exceeds container.  #{c.row} "
          c.row -= @height - @row_offset
        else
          # this is where it should come
          c.row += @row + @row_offset
          @last_row = c.row + 1
        end
        if (c.col || 0) <= 0
          c.col = @col + inset + @col_offset
        elsif c.col > @col + @width -1
          c.col -= @width
        elsif c.col == @col
          c.col += @col_offset + inset
        else #f c.col < @col
          c.col += @col+@col_offset
        end
        $log.debug "XXX: CORRECT #{c.name}  r:#{c.row} c:#{c.col} "
      end
      @first_time = false
    end
    def check_component c
      raise "row is less than Rcontainer #{c.row} #{@row} " if c.row <= @row
      raise "col is less than Rcontainer #{c.col} #{@col} " if c.col <= @col
    end

    public
    # repaint object
    # called by Form, and sometimes parent component (if not form).
    def repaint # container2
      my_win = @form ? @form.window : @target_window
      @graphic = my_win unless @graphic
      raise " #{@name} NO GRAPHIC set as yet                 RCONTAINER paint " unless @graphic
      #@components.each { |e| correct_component e } if @first_time
      #recalc unless @calc_over
      # check if some have put weightages FIXME
      # add on height or w depending on if its stack or flow 
      r = @row + @row_offset
      c = @col + @col_offset
      # should this not happen only if repaint_required ?
      @components.each { |e| 
        e.parent_component = self
        e.row              = r
        e.col              = c
        # check that we are not trying to print outside bounds
        # by default we are stacking top level comps regardless of stack or flow
        #  otherwise too complicated
        if e.is_a? Stack 
          # using ||= allows us to use overrides given by user
          # but disallows us from calculating if size changes
            e.height           = (@height-2) * (e.weight * 0.01)
            e.height           = e.height.round
            e.width            = (@width-2) 
            if e.row + e.height >= @row + @height
              #alert "is exceeding #{e.row} #{e.height} > #{@row} + #{@height} "
              e.height = @height - e.row - 1
            end
            r += e.height
            $log.debug "XXX: STACK r:#{e.row} e.h: #{e.height} w:#{e.weight} h: #{@height} "
          #if e.type == :flow
            #e.height           ||= (@height-2) * (e.weight * 0.01)
            #e.height           = e.height.round
            #e.width            ||= (@width-2) 
            #r += e.height
          #elsif e.type == :stack
            #e.width            ||= (@width-2) * (e.weight * 0.01)
            #e.width            = e.width.round
            #e.height           ||= (@height-2)
            #c += e.width
          #end
        end
        check_coords e
        attach_form e unless e.form
      } # seeme one if printing out
      last = @components.last
      if last.row + last.height < @row + @height
        last.height += 1 # @row + @height - last.row + last.height
      end

      #return unless @repaint_required

      # if some major change has happened then repaint everything
      # if multiple components then last row and col needs to be stored or else overlap will happen FIXME
      if @repaint_required
        $log.debug " CONT2 repaint graphic #{@graphic}, size:#{@components.size} "
        print_borders unless @suppress_borders # do this once only, unless everything changes
        @components.each { |e| e.repaint_all(true); e.repaint }
      else
        @components.each { |e| e.repaint }
      end # if repaint_required

      @repaint_required = false
    end

    private
    def check_coords e  # container
      r = e.row
      c = e.col
      if r >= @row + @height
        $log.warn "XXX: WARN #{e.class} is out of bounds row #{r} "
        e.visible = false
      end
      if c >= @col + @width
        $log.warn "XXX: WARN #{e.class} is out of bounds col #{c} "
        e.visible = false
      end
      if e.row + e.height >= @height
        $log.warn "XXX: WARN #{e.class} is out of bounds row #{e.row} + h #{e.height} >= #{@height} "
        #e.visible = false
      end
      if e.col + e.width >= @width
        $log.warn "XXX: WARN #{e.class} is out of bounds col #{e.col} + w #{e.width} >= #{@width} "
        #e.visible = false
      end
    end
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
      $log.debug "RCONTAINER PRINTING TITLE at #{row} #{col} "
      @graphic.printstring( @row, @col+(@width-@title.length)/2, @title, @color_pair, @title_attrib) unless @title.nil?
    end

    public
    # called by parent or form, otherwise its private
    def handle_key ch
      $log.debug " RCONTAINER handle_key #{ch} "
      return if @components.empty?
      _multiplier = ($multiplier == 0 ? 1 : $multiplier )

      # should this go here 2011-10-19 
      unless @_entered
        $log.warn "XXX WARN: calling ON_ENTER since in this situation it was not called"
        on_enter
      end
      if ch == KEY_TAB
        $log.debug "RCONTAINER GOTO NEXT TAB"
        return goto_next_component
      elsif ch == KEY_BTAB
        return goto_prev_component
      end
      comp = @current_component
      $log.debug " RCONTAINER handle_key #{ch}: #{comp}" 
      if comp
        ret = comp.handle_key(ch) 
        $log.debug " RCONTAINER handle_key#{ch}: #{comp} returned #{ret} " 
        if ret != :UNHANDLED
          comp.repaint # NOTE: if we don;t do this, then it won't get repainted. I will have to repaint ALL
          # in repaint of this.
          return ret 
        end
        $log.debug "XXX RCONTAINER key unhandled by comp #{comp.name} "
      else
        $log.warn "XXX RCONTAINER key unhandled NULL comp"
      end
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
          @_entered = false
          return :UNHANDLED
        end
      end

      $multiplier = 0
      return 0
    end
    # Actually we should only go to current component if it accepted
    # a key stroke. if user tabbed thru it, then no point going back to
    # it. Go to first or last depending on TAB or BACKTAB otherwise.
    # NOTE: if user comes in using DOWN or UP, last traversed component will get the focus
    #
    def on_enter
      # if BTAB, the last comp XXX they must be focusable FIXME
      if $current_key == KEY_BTAB || $current_key == KEY_UP
        @current_component = @focusables.last
      elsif $current_key == KEY_TAB || $current_key == KEY_DOWN
        @current_component = @focusables.first
      else
        # let current component be, since an unhandled key may have resulted
        #  in on_enter being called again
      end
      return unless @current_component
      $log.debug " RCONTAINER came to ON_ENTER #{@current_component} "
      set_form_row
      @_entered = true
    end
    # we cannot be sure that this will be called especially if this is embedded 
    # inside some other component
    def on_leave
      @_entered = false
      super
    end
    def goto_next_component
      if @current_component != nil 
        leave_current_component
        if on_last_component?
          #@_entered = false
          return :UNHANDLED
        end
        @current_index = @focusables.index(@current_component)
        index = @current_index + 1
        f = @focusables[index]
        if f
          @current_index = index
          @current_component = f
          return set_form_row
        end
      end
      @_entered = false
      return :UNHANDLED
    end
    def goto_prev_component
      if @current_component != nil 
        leave_current_component
        if on_first_component?
          @_entered = false
          return :UNHANDLED
        end
        @current_index = @focusables.index(@current_component)
        index = @current_index -= 1
        f = @focusables[index]
        if f
          @current_index = index
          @current_component = f
          return set_form_row
        end
      end
      return :UNHANDLED
    end
    # private
    # XXX why are we calling 3 methods in a row, why not OE manages these 3
    # There's double calling going on.
    def set_form_row
      return :UNHANDLED if @current_component.nil?
      cc = @current_component
      $log.debug "CONT #{@name} set_form_row calling sfr for #{cc.name}, r #{cc.row} c: #{cc.col} "
      $log.debug " RCONTAINER on enter sfr #{@current_component.name}  #{@current_component} "

      # bug caught here. we were printing a field before it had been set, so it printed out
      ##@components.each { |e| correct_component e } if @first_time
      ##recalc unless @calc_over
      @current_component.on_enter
      @current_component.set_form_row # why was this missing in vimsplit. is it
      $log.debug "CONT2 #{@name} set_form_row calling sfr for #{cc.name}, r #{cc.row} c: #{cc.col} "
      # that on_enter does a set_form_row
      @current_component.set_form_col # XXX 
      @current_component.repaint # OMG this could happen before we've set row and col
      # XXX compo should do set_form_row and col if it has that
    end
    # 
    def set_form_col
      return if @current_component.nil?
      $log.debug " #{@name} RCONTAINER EMPTY set_form_col calling sfc for #{@current_component.name} "
      # already called from above.
      #@current_component.set_form_col 
    end
    # leave the component we are on.
    # This should be followed by all containers, so that the on_leave action
    # of earlier comp can be displayed, such as dimming components selections
    def leave_current_component
      begin
        @current_component.on_leave
      rescue FieldValidationException => fve
        alert fve.to_s
      end
      # NOTE this is required, since repaint will just not happen otherwise
      # Some components are erroneously repainting all, after setting this to true so it is 
      # working there. 
      @current_component.repaint_required true
      $log.debug " after on_leave RCONT XXX #{@current_component.focussed}   #{@current_component.name}"
      @current_component.repaint
    end

    # is focus on first component FIXME check  for focusable
    def on_first_component?
      @current_component == @focusables.first
    end
    # is focus on last component FIXME check  for focusable
    def on_last_component?
      @current_component == @focusables.last
    end
    # set focus on given component
    # Sometimes you have the handle to component, and you want to move focus to it
    def goto_component comp
      return if comp == @current_component
      leave_current_component
      @current_component = comp
      set_form_row
    end

    # Traverses the comopnent tree and calculates weightages for all components
    # based on what has been specified by user
    def DEPRECATEDcalc_weightages c
      if c.is_a? Stack
        #puts " #{@ctr} --> #{c.type}, wt: #{c.config[:weight]} "
        @ctr += 1
        wt  = 0
        cnt = 0
        sz = c.components.count
        $log.debug "XXX: calc COMP COUNT #{sz} "
        # calculate how much weightage has been given by user
        # so we can allocate average to other components
        c.components.each { |e| 
          if e.config[:weight]  
            wt += e.config[:weight]
            cnt += 1
          end
          $log.debug "XXX: INC setting parent #{c} to #{e} "
          e.config[:parent] = c
          e.config[:level] = @ctr
        }
        used = sz - cnt
        $log.debug "XXX: ADDING calc COMP COUNT #{sz} - #{cnt} "
        if used > 0
          avg = (100-wt)/used
          # Allocate average to other components
          c.components.each { |e| e.config[:weight] = avg unless e.config[:weight]  }
        end
        c.components.each { |e| calc_weightages e  }
        @ctr -= 1
      else
        #puts "#{@ctr} ... #{c} wt: #{c.config[:weight]}  "
      end
    end
    def calc_weightages2 components, parent
        #puts " #{@ctr} --> #{c.type}, wt: #{c.config[:weight]} "
        @ctr += 1
        wt  = 0
        cnt = 0
        sz = components.count
        $log.debug "XXX: calc COMP COUNT #{sz} "
        # calculate how much weightage has been given by user
        # so we can allocate average to other components
        components.each { |e| 
          if e.config[:weight]  
            wt += e.config[:weight]
            cnt += 1
          end
          $log.debug "XXX: INC setting parent #{parent} to #{e} "
          e.config[:parent] = parent
          e.config[:level] = @ctr
        }
        used = sz - cnt
        $log.debug "XXX: ADDING calc COMP COUNT #{sz} - #{cnt} "
        if used > 0
          avg = (100-wt)/used
          # Allocate average to other components
          components.each { |e| e.config[:weight] = avg unless e.config[:weight]  }
        end
        components.each { |e| calc_weightages2(e.components, e) if e.respond_to? :components  }
        @ctr -= 1
    end
    # General routin to traverse components and their components
    def traverse c, &block
      if c.is_a? Stack
        yield c
        #puts " #{@ctr} --> #{c.type}, wt: #{c.config[:weight]} "
        c.components.each { |e| 
          yield e
        }
        #c.components.each { |e| e.config[:weight] = avg unless e.config[:weight]  }
        c.components.each { |e| traverse(e, &block)  }
        @ctr -= 1
      else
        #puts "#{@ctr} ... #{c} wt: #{c.config[:weight]}  "
        #yield c
      end
    end

    def each &block
      @components.each { |e| traverse e, &block }
    end
    def _stack type, config={}, &block
      s = Stack.new(type,config)
      _add s
      @active << s
      yield_or_eval &block if block_given? 
      #instance_eval(&block) if block_given? 
      @active.pop
    end
    def _add s
      if @active.empty?
        $log.debug "XXX:  ADDING TO components #{s} "
        unless s.is_a? Stack
          raise "No stack or flow to add to. Results may not be what you want"
        end
        @components << s
      else
        @active.last.components << s
      end
      __add s
    end

    def stack config={}, &block
      $log.debug "XXX:  ADDING STACK "
      _stack :stack, config, &block
    end
    def flow config={}, &block
      _stack :flow, config, &block
    end
    def add w, config={}
      i = Item.new config, w
      _add i
    end
    alias :add_widget :add

    def increase_current
      c = @current_component
      p = c.config[:parent]
      $log.debug "XXX: INC increase current #{c} , #{p} "
      p.increase c
    end
    def decrease_current
      c = @current_component
      p = c.config[:parent]
      $log.debug "XXX: INC increase current #{c} , #{p} "
      p.decrease c
    end
    # ADD HERE ABOVe
  end # class
  class Stack 
    attr_accessor :components
    attr_reader :type
    attr_reader :config
    attr_accessor :form
    def initialize type, config={}, components=[]
      @type   = type
      @config = config
      @components = components
      @calc_over = false
    end
    %w[ parent_component width height weight row col row_offset col_offset].each { |e|
      eval(
           "def #{e} 
              @config[:#{e}]
            end
            def #{e}=(val) 
              @config[:#{e}]=val
            end"
          )
    }
    alias :parent :parent_component
    #alias :parent= :parent_component
    def repaint # stack
      $log.debug "XXX: stack repaint"
      @components.each { |e| e.form = @form unless e.form } #unless @calc_over
      recalc unless @calc_over
      @components.each { |e| e.repaint }
    end
    def repaint_all x
      @calc_over = false
    end
    def override_graphic gr
      @graphic = gr
    end
    def focusable; false; end
    # Calculates row col and width height
    # for each subc-omponent based on coords of Container
    # This is to be called only when the container has got its coordinates (i.e
    # Containers repaint). This should be in this objects repaint.
    def recalc
      @calc_over = true
      comp = self
      if comp.parent.is_a? Stack 
        alert "does NOT reachere here"
        if comp.parent.type == :stack
          comp.height = comp.parent.height * comp.weight * 0.01
          comp.height = comp.height.round
          comp.width  = comp.parent.width #* comp.parent.weight * 0.01 # ??? XXX 2011-10-25 
          comp.width   = comp.width.round
          comp.col    = comp.parent.col
          $log.debug "XXX: parent is stack #{comp.row},#{comp.col}. #{comp.width},#{comp.height} "
        #elsif comp.type == :flow
        elsif comp.parent.type == :flow
          comp.width   = comp.parent.width * comp.weight * 0.01
          comp.width   = comp.width.round
          comp.height  = comp.parent.height #* comp.parent.weight * 0.01 # ??? XXX Is there any ht weight ? 2011-10-25 
          comp.height = comp.height.round
          comp.row     = comp.parent.row
          $log.debug "XXX: parent is flow #{comp.row}, #{comp.col}. #{comp.width},#{comp.height} "
        end
      end
      if comp.is_a? Stack
        check_coords comp
        if @type == :stack
          r = row #+ row_offset
          rem = 0
          @components.each { |e| 
            # should only happen if expandable FIXME
            e.height = 0.01 * e.weight * height 
            hround = e.height.floor
            rem += e.height - hround
            e.height = hround
            # rounding creates a problem, since 0.5 gets rounded up and we can exceed bound
            # So i floor, and maintain the lost space, and add it back when it exceeds 1
            # This way the last components gets stretched to meet the end, which is required
            # when the height of the stack is odd and there's a left-over row
            if rem >= 1
              e.height += 1
              rem = 0
            end
            #$log.debug "XXX: recalc #{e.class} #{e.height} = #{e.weight} * #{height} "
            e.row = r
            r += e.height + 0
            e.width = width
            e.col = col # ??? XXX
            $log.debug "XXX: recalc stack #{e.widget.class} r:#{e.row} c:#{e.col} h:#{e.height} = we:#{e.weight} * h:#{height} "
            #e.col_offset = col_offset # ??? XXX
            check_coords e
            e.recalc if e.is_a? Stack
          }
        elsif @type == :flow
          c = col #+ col_offset
          rem = 0
          @components.each { |e| 
            e.width = e.weight * width  * 0.01
            wround = e.width.floor
            rem += e.width - wround
            e.width = wround
            # see comment in prev block regarding remaininder
            if rem >= 1
              e.width += 1
              rem = 0
            end
            e.height = height #* weight * 0.01
            #e.height = e.height.round
            e.col = c
            c += e.width + 0
            e.row = row
            check_coords e
            $log.debug "XXX: recalc flow #{e.widget.class} r:#{e.row} c:#{e.col} h:#{e.height} = we:#{e.weight} * w:#{width} "
            e.recalc if e.is_a? Stack
          }
        end
      else
        alert "in else recalc "
        comp.col    = comp.parent.col
        comp.row    = comp.parent.row
        comp.height = comp.parent.height
        comp.width  = comp.parent.width
        $log.debug "XXX: recalc else #{comp.class} r #{comp.row} c #{comp.col} . h #{comp} height w #{comp.width} "
      end
    end
    def check_coords e # stack
      r = e.row
      c = e.col
      if r >= row + height
        $log.warn "XXX: WARN e.class is out of bounds row #{r} "
        e.visible = false
      end
      if c >= col + width
        $log.warn "XXX: WARN e.class is out of bounds col #{c} "
        e.visible = false
      end
    end
    def increase c=@current_component
      p = self #c.parent_component
      ci = p.components.index(c)
      ni = ci + 1
      if p.components[ni].nil?
        ni = nil
      end
      case p.type
      when :flow
        # increase width of current and reduce from neighbor
        if ni
          n = p.components[ni]
          $log.debug "XXX: INC fl current #{ci}, total#{p.components.count}, next #{n} "

          c.width += 1
          n.width -= 1
          n.col   += 1
        end

      when :stack
        if ni
          n = p.components[ni]
          $log.debug "XXX: INC fl current #{ci}, total#{p.components.count}, next #{n} "

          c.height += 1
          n.height -= 1
          n.row   += 1
        end
        $log.debug "XXX: INC st current #{ci}, total#{p.components.count} "
      end

    end
    def decrease c=@current_component
      p = self #c.parent_component
      ci = p.components.index(c)
      ni = ci + 1
      if p.components[ni].nil?
        ni = nil
      end
      case p.type
      when :flow
        # increase width of current and reduce from neighbor
        if ni
          n = p.components[ni]
          $log.debug "XXX: INC fl current #{ci}, total#{p.components.count}, next #{n} "

          c.width -= 1
          n.width += 1
          n.col   -= 1
        end

      when :stack
        if ni
          n = p.components[ni]
          $log.debug "XXX: INC fl current #{ci}, total#{p.components.count}, next #{n} "

          c.height -= 1
          n.height += 1
          n.row   -= 1
        end
        $log.debug "XXX: INC st current #{ci}, total#{p.components.count} "
      end

    end
    def to_s
      @components
      #" #{@type} ::  #{@config} :: #{@components} "
      #" #{@type} ::  :: #{@components} "
    end
  end
  class Item 
    attr_reader :config, :widget
    def initialize config={}, widget
      @config = config
      @widget = widget
    end
    def weight;  @config[:weight]||100; end
    def weight=(val); @config[:weight]=val; end
    def repaint; @widget.repaint; end
    %w[ form parent parent_component width height row col row_offset col_offset focusable].each { |e|
      eval(
           "def #{e} 
      @widget.#{e} #if @widget.respond_to?:#{e} 
    end
    def #{e}=(val) 
      @widget.#{e}=val #if @widget.respond_to?:#{e} 
    end"
          )
    }
    def method_missing(sym, *args, &block)
      @widget.send sym, *args, &block
    end
  end
end # module

if __FILE__ == $PROGRAM_NAME
  require 'rbcurse/app'
  App.new do

    lb = Listbox.new nil, :list => ["ruby","perl","lisp","jaava", "c-blunt"] , :name => "mylist"
    lb1 = Listbox.new nil, :list => ["roger","borg","haas","tsonga", "kolya","delpotro"] , :name => "mylist1"

    lb2 = Listbox.new nil, :list => `gem list --local`.split("\n") , :name => "mylist2"

    alist = %w[ ruby perl python java jruby macruby rubinius rails rack sinatra pylons django cakephp grails] 
    str = "Hello people of this world.\nThis is a textbox.\nUse arrow keys, j/k/h/l/gg/G/C-a/C-e/C-n/C-p\n"
    str << alist.join("\n")
    require 'rbcurse/rtextview'
    tv = TextView.new nil, :name => "text"
    tv.set_content str
=begin
    f1 = field "name", :maxlen => 20, :display_length => 20, :bgcolor => :white, 
      :color => :black, :text => "abc", :label => " Name: ", :label_color_pair => @datacolor
    f2 = field "email", :display_length => 20, :bgcolor => :white, 
      :color => :blue, :text => "me@google.com", :label => "Email: ", :label_color_pair => @datacolor
    f3 = radio :group => :grp, :text => "red", :value => "RED", :color => :red
    f4 = radio :group => :grp, :text => "blue", :value => "BLUE", :color => :blue
    f5 = radio :group => :grp, :text => "green", :value => "GREEN", :color => :green
=end

    f1 = Field.new nil, :maxlen => 20, :display_length => 20, :bgcolor => :white, 
      :color => :black, :text => "abc", :label => " Name: ", :label_color_pair => @datacolor
    r = StackFlow.new @form, :row => 1, :col => 2, :width => 80, :height => 25, :title => "A container" do
      stack :margin_top => 2, :margin_left => 1 do
        add tv, :weight => 30, :margin_left => 2
        add lb, :weight => 30
        flow :weight => 30 do 
          add lb1, :weight => 40
          add lb2, :weight => 60
        end
        add f1
      end # stack
    end # r

    #r.add(f1)
    #r.add(f2)
    #r.add(f3,f4,f5)
    #sl = status_line

  end # app
end # if 
