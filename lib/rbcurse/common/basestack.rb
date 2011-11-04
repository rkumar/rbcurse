# 
# Common stack flow functionality
# * Name: basestack.rb
# * Description: Classes that allow user to stack and flow components
#
# * Date: 30.10.11 - 12:57
# * Last update: 30.10.11 - 12:57
#
module RubyCurses
  module ModStack
    #
    # Base class for stacks and flows.
    # Will manage determining row col and width height of objects
    # Stacks place objects one below another. Flows place objects to the
    # right of the previous. Orientation can be reversed.
    #
  class BaseStack
    attr_accessor :components
    attr_reader :config
    attr_accessor :form
    def initialize config={}, components=[]
      @config = config
      config.each do |k, v|
        instance_variable_set "@#{k}", v
      end
      @components = components
      @calc_needed = true
    end
    # XXX if user sets later, we won't be checking the config
    # We check the actual variables which config sets in init
    %w[ parent_component width height weight row col orientation].each { |e|
      eval(
           "def #{e} 
              @config[:#{e}]
            end
            def #{e}=(val) 
              @config[:#{e}]=val
              instance_variable_set \"@#{e}\", val
              @calc_needed = true
            end"
          )
    }
    alias :parent :parent_component
    #alias :parent= :parent_component
    def repaint # stack
      $log.debug "XXX: stack repaint recalc #{@calc_needed} "
      @components.each { |e| e.form = @form unless e.form } #unless @calc_needed
      recalc if @calc_needed
      @components.each { |e| e.repaint }
    end
    def repaint_all x
      @calc_needed = true
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
      @calc_needed = false
      comp = self
      if comp.is_a? BaseStack
        check_coords comp
        @margin_left   ||= 0
        @margin_right  ||= 0
        @margin_top    ||= 0
        @margin_bottom ||= 0
        if comp.is_a? Stack
          r   = row + @margin_top
          rem = 0
          ht = height - (@margin_top + @margin_bottom)
          if @orientation == :bottom 
            mult = -1
            comps = @components.reverse
            r = row + height - @margin_bottom
    
          else
            mult = 1
            comps = @components
   
          end
          comps.each { |e| 
            # should only happen if expandable FIXME
            e.height = 0.01 * e.weight * (ht - (e.margin_top + e.margin_bottom)) 
            hround = e.height.floor
            rem += e.height - hround
            e.height = hround #- (@margin_top + @margin_bottom)
            # rounding creates a problem, since 0.5 gets rounded up and we can exceed bound
            # So i floor, and maintain the lost space, and add it back when it exceeds 1
            # This way the last components gets stretched to meet the end, which is required
            # when the height of the stack is odd and there's a left-over row
            if rem >= 1
              e.height += 1
              rem = 0
            end
            # Item level margins have not been accounted for when calculating weightages, and
            # should not be used on the weightage axis
            r += e.margin_top
            if @orientation == :bottom
              r += e.height * mult
              e.row = r 
            else
              e.row = r 
              r += e.height + 0
            end
            e.width = width - (@margin_left + @margin_right + e.margin_left + e.margin_right)
            e.col = col + @margin_left + e.margin_left # ??? XXX
            $log.debug "XXX: recalc stack #{e.widget.class} r:#{e.row} c:#{e.col} h:#{e.height} = we:#{e.weight} * h:#{height} "
            #e.col_offset = col_offset # ??? XXX
            check_coords e
            e.repaint_all(true)
            e.recalc if e.is_a? BaseStack
          }
        elsif comp.is_a? Flow
          c = col + @margin_left #+ col_offset
          rem = 0
          wd = width - (@margin_left + @margin_right)
          # right_to_left orientation
          if @orientation == :right
            mult = -1
            comps = @components.reverse
            c = col + width - @margin_right
            $log.debug "XXX:  ORIENT1f recalc #{@orientation} "
          else
            mult = 1
            comps = @components
            $log.debug "XXX:  ORIENT2f recalc #{@orientation} "
          end
          comps.each { |e| 
            e.width = e.weight * wd  * 0.01
            wround = e.width.floor
            rem += e.width - wround
            e.width = wround
            # see comment in prev block regarding remaininder
            if rem >= 1
              e.width += 1
              rem = 0
            end
            e.height = height - (@margin_top + @margin_bottom) #* weight * 0.01
            #e.height = e.height.round
            if @orientation == :right
              c += e.width * mult # mult 1 or -1
              e.col = c
            else
              e.col = c
              c += e.width * mult # mult 1 or -1
            end
            e.row = row + @margin_top
            check_coords e
            $log.debug "XXX: recalc flow #{e.widget.class} r:#{e.row} c:#{e.col} h:#{e.height} = we:#{e.weight} * w:#{width} "
            e.repaint_all(true)   # why not happening when we change row, hieght etc
            e.recalc if e.is_a? BaseStack
          }
        end
      else
        alert "in else recalc DOES NOT COME HERE "
        comp.col    = comp.parent.col
        comp.row    = comp.parent.row
        comp.height = comp.parent.height
        comp.width  = comp.parent.width
        $log.debug "XXX: recalc else #{comp.class} r #{comp.row} c #{comp.col} . h #{comp} height w #{comp.width} "
      end
    end
    # Traverses the comopnent tree and calculates weightages for all components
    # based on what has been specified by user
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
      case p
      when Flow
        # increase width of current and reduce from neighbor
        if ni
          n = p.components[ni]
          $log.debug "XXX: INC fl current #{ci}, total#{p.components.count}, next #{n} "

          c.width += 1
          n.width -= 1
          n.col   += 1
        end

      when Stack
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
      case p
      when Flow
        # increase width of current and reduce from neighbor
        if ni
          n = p.components[ni]
          $log.debug "XXX: INC fl current #{ci}, total#{p.components.count}, next #{n} "

          c.width -= 1
          n.width += 1
          n.col   -= 1
        end

      when Stack
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
    end
  end # class Base
  # A stack positions objects one below the other
  class Stack < BaseStack; end
  # A flow positions objects in a left to right
  class Flow  < BaseStack; end
  #
  # A wrapper over widget mostly because it adds weight and margins
  #
  class Item
    attr_reader :config, :widget
    attr_reader :margin_top, :margin_left, :margin_bottom, :margin_right
    def initialize config={}, widget
      @config = config
      config.each do |k, v|
        instance_variable_set "@#{k}", v
      end
      @margin_left   ||= 0
      @margin_right  ||= 0
      @margin_top    ||= 0
      @margin_bottom ||= 0
      @widget = widget
    end
    def weight;  @config[:weight]||100; end
    def weight=(val); @config[:weight]=val; end
    def repaint; @widget.repaint; end
    %w[ form parent parent_component width height row col row_offset col_offset focusable].each { |e|
      eval(
           "def #{e} 
              @widget.#{e} 
            end
            def #{e}=(val) 
              @widget.#{e}=val 
            end"
          )
    }
    def method_missing(sym, *args, &block)
      @widget.send sym, *args, &block
    end
  end # class Item

  # --------------------- module level ------------------------------#
    # General routin to traverse components and their components
    def traverse c, &block
      if c.is_a? BaseStack
        yield c
        c.components.each { |e| 
          yield e
        }
        c.components.each { |e| traverse(e, &block)  }
        @ctr -= 1
      else
      end
    end

    # traverse the components and their children
    #
    def each &block
      @components.each { |e| traverse e, &block }
    end
    # module level
    private
    def _stack type, config={}, &block
      case type
      when :stack
        s = Stack.new(config)
      when :flow
        s = Flow.new(config)
      end
      _add s
      @active << s
      yield_or_eval &block if block_given? 
      @active.pop
      # if active is empty then this is where we could calculate
      # percentatges and do recalc, thus making it independent
    end
    # module level
    private
    private
    def _add s
      if @active.empty?
        $log.debug "XXX:  ADDING TO components #{s} "
        unless s.is_a? BaseStack
          raise "No stack or flow to add to. Results may not be what you want"
        end
        @components << s
      else
        @active.last.components << s
      end
      __add s
    end

    # module level
    private
    public
    def stack config={}, &block
      _stack :stack, config, &block
    end
    def flow config={}, &block
      _stack :flow, config, &block
    end
    # module level
    private
    def add w, config={}
      i = Item.new config, w
      _add i
    end
    alias :add_widget :add
    # module level
    private
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
    # module level
    private
    # given an widget, return the item, so we can change weight or some other config
    def item_for widget
      each do |e|
        if e.is_a? Item
          if e.widget == widget
            return e
          end
        end
      end
      return nil
    end
    # module level
    # returns the parent (flow or stack) for a given widget
    #  allowing user to change configuration such as weight
    def parent_of widget
      f = item_for widget
      return f.config[:parent] if f
      return nil
    end
  end # mod modstack
end # mod
