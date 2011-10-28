=begin
  * Name: A container that manages components placed in it but
          is not a form. Thus it can be safely placed as a widget
          without all the complicatinos of a form embedded inside another.
          NOTE: Still experimental
  * Description   
  * Author: rkumar (http://github.com/rkumar/rbcurse/)
  * Date:  21.10.11 - 00:29
  * License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

  * Last update:  23.10.11 - 00:29
  == CHANGES
      Focusables so we don't focus on label
  == TODO 
       How to put blank lines in stack - use a blank label

     - The contaomers and multis need to do their own on_enter and on_leave
       management, they cannot rely on some other container doing it.
       We can only rely on handle_key being called. HK should determine
        whether any set_form row etc needs to be done.
     - Should have its own stack and flow
=end

require 'rbcurse'

include RubyCurses
module RubyCurses
  extend self

  # This is an attempt at having a container which can contain multiple
  # widgets without being a form itself. Having forms within forms
  # complicates code too much, esp cursor positioning. e.g. tabbedpane

  class Container < Widget

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
      super
      @focusable = true
      @editable = false
      @components = [] # all components
      @focusables = [] # focusable components, makes checks easier

      init_vars
    end
    def init_vars
      @repaint_required = true
      @row_offset = @col_offset = 0 if @suppress_borders # FIXME supposed to use this !!

      @internal_width = 2
      @internal_width = 1 if @suppress_borders
      @name ||= "AContainer"
      @first_time = true

    end

    # NOTE: since we are handling the traversal, we delink the object from any
    # form's widgets array  that might have been added. Whenever a form is available,
    # we set it (without adding widget to it) so it can print using the form's window.
    # 
    # @param [Widget] to add
    def add *items
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

        @components << c
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
    alias :add_widget :add
    def widgets; @components; end
    # what of by_name


    # correct coordinates of comp esp if App has stacked them after this
    # container
    # It is best to use the simple stack feature. The rest could change at any time
    #  and is quite arbitrary. Some folks may set absolute locations if container
    #  is directly on a form, others may set relative locations if it is inside a 
    #  tabbed pane or other container. Thus, stacks are best
    def correct_component c
      raise "Form is still not set in Container" unless @form
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
          $log.warn "c.row in CONTAINER is #{c.row} "
          c.row = @last_row
          @last_row += 1
        elsif c.row > @row + @height -1
          $log.warn "c.row in CONTAINER exceeds container.  #{c.row} "
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
      raise "row is less than container #{c.row} #{@row} " if c.row <= @row
      raise "col is less than container #{c.col} #{@col} " if c.col <= @col
    end

    public
    # repaint object
    # called by Form, and sometimes parent component (if not form).
    def repaint
      my_win = @form ? @form.window : @target_window
      @graphic = my_win unless @graphic
      raise " #{@name} NO GRAPHIC set as yet                 CONTAINER paint " unless @graphic
      @components.each { |e| correct_component e } if @first_time
      #@components.each { |e| check_component e } # seeme one if printing out

      #return unless @repaint_required

      # if some major change has happened then repaint everything
      if @repaint_required
        $log.debug " VIM repaint graphic #{@graphic} "
        print_borders unless @suppress_borders # do this once only, unless everything changes
        @components.each { |e| e.repaint_all(true); e.repaint }
      else
        @components.each { |e| e.repaint }
      end # if repaint_required

      @repaint_required = false
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
      $log.debug "CONTAINER PRINTING TITLE at #{row} #{col} "
      @graphic.printstring( @row, @col+(@width-@title.length)/2, @title, @color_pair, @title_attrib) unless @title.nil?
    end

    public
    # called by parent or form, otherwise its private
    def handle_key ch
      $log.debug " CONTAINER handle_key #{ch} "
      return if @components.empty?
      _multiplier = ($multiplier == 0 ? 1 : $multiplier )

      # should this go here 2011-10-19 
      unless @_entered
        $log.warn "XXX WARN: calling ON_ENTER since in this situation it was not called"
        on_enter
      end
      if ch == KEY_TAB
        $log.debug "CONTAINER GOTO NEXT TAB"
        return goto_next_component
      elsif ch == KEY_BTAB
        return goto_prev_component
      end
      comp = @current_component
      $log.debug " CONTAINER handle_key #{ch}: #{comp}" 
      if comp
        ret = comp.handle_key(ch) 
        $log.debug " CONTAINER handle_key#{ch}: #{comp} returned #{ret} " 
        if ret != :UNHANDLED
          comp.repaint # NOTE: if we don;t do this, then it won't get repainted. I will have to repaint ALL
          # in repaint of this.
          return ret 
        end
        $log.debug "XXX CONTAINER key unhandled by comp #{comp.name} "
      else
        $log.warn "XXX CONTAINER key unhandled NULL comp"
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
      else
        @current_component = @focusables.first
      end
      return unless @current_component
      $log.debug " CONTAINER came to ON_ENTER #{@current_component} "
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
        f = @focusables[i]
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
      $log.debug " CONTAINER on enter sfr #{@current_component.name}  #{@current_component} "

      # bug caught here. we were printing a field before it had been set, so it printed out
      @components.each { |e| correct_component e } if @first_time
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
      $log.debug " #{@name} CONTAINER EMPTY set_form_col calling sfc for #{@current_component.name} "
      # already called from above.
      #@current_component.set_form_col 
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

    # ADD HERE ABOVe
  end # class
end # module

if __FILE__ == $PROGRAM_NAME
  require 'rbcurse/app'
  App.new do
    f1 = field "name", :maxlen => 20, :display_length => 20, :bgcolor => :white, 
      :color => :black, :text => "abc", :label => " Name: ", :label_color_pair => @datacolor
    f2 = field "email", :display_length => 20, :bgcolor => :white, 
      :color => :blue, :text => "me@google.com", :label => "Email: ", :label_color_pair => @datacolor
    f3 = radio :group => :grp, :text => "red", :value => "RED", :color => :red
    f4 = radio :group => :grp, :text => "blue", :value => "BLUE", :color => :blue
    f5 = radio :group => :grp, :text => "green", :value => "GREEN", :color => :green
    stack :margin_top => 2, :margin => 2 do
    r = container :row => 1, :col => 2, :width => 80, :height => 20, :title => "A container" 
    r.add(f1)
    r.add(f2)
    r.add(f3,f4,f5)
    sl = status_line
    end # stack
  
  end # app
end # if 
