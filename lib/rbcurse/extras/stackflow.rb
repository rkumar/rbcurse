=begin
  * Name: stackflow.rb
          A version of Container that uses stacks and flows and later grids
          to place components
          This is not a form. Thus it can be safely placed as a widget
          without all the complicatinos of a form embedded inside another.
NOTE: Still experimental
  * Description   
  * Author: rkumar (http://github.com/rkumar/rbcurse/)
  * Date:  23.10.11 - 19:55
  * License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

  * Last update:  30.10.11 - 12:55

  == CHANGES
     Have moved most things out to a module ModStack, so this is sort of just 
     a skeletal container
    x take care of margins
    Resizing components
    If window or container resized then redo the calc again.
    Flow to have option of right to left orientation
  == TODO 
    - If user specifies width, height then to be accounted when calculating weight. Also,
      in such cases we must try not to overwrite h/w when calculating.
    - changing an objects config not easy since it is stored in item, user may not have
      handle to item
    - weightx weighty
    - RESET height only if expandable
    - exceeding 100 will result in exceeding container.
    - C-a C-e misbehaving in examples

=end

require 'rbcurse'
require 'rbcurse/common/bordertitle'
require 'rbcurse/common/basestack'

include RubyCurses
module RubyCurses
  extend self

  # This is a more advanced version of container
  # which allows user to stack or flow components, including
  # embedding stacks within flows and viceversa.


  class StackFlow < Widget

    include BorderTitle
    include ModStack
    # should container stack objects ignoring users row col
    # this is esp needed since App sets row and col which is too early
    # This is now the default value, till i can redo things
    #dsl_accessor :stack
    attr_reader  :current_component
    attr_reader  :components

    def initialize form=nil, config={}, &block
      @suppress_borders = false
      @row_offset = @col_offset = 1
      @_events ||= []
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
      @row_offset = @col_offset = 0 if @suppress_borders 
      @ctr = 0

      @internal_width = 2
      @internal_width = 1 if @suppress_borders
      @name ||= "a_stackflow"
      bind_key(?\M-1, :increase_current)
      bind_key(?\M-2, :decrease_current)
      #raise "NO components !" if @components.empty?
      calc_weightages2(@components, self) # FIXME this needs to move to basestack

    end


    # NOTE this is called by basestack so it cannot be here FIXME

    # NOTE: since we are handling the traversal, we delink the object from any
    # form's widgets array  that might have been added. Whenever a form is available,
    # we set it (without adding widget to it) so it can print using the form's window.
    # 
    # @param [Widget] to add
    private
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
    public
    def widgets; @components; end
    # what of by_name



    # repaint object
    # called by Form, and sometimes parent component (if not form).
    def repaint # stackflow
      my_win = @form ? @form.window : @target_window
      @graphic = my_win unless @graphic
      raise " #{@name} NO GRAPHIC set as yet                 RCONTAINER paint " unless @graphic
      # actually at this level we don't have margins set -- not yet.
      @margin_left   ||= 0
      @margin_right  ||= 0
      @margin_top    ||= 0
      @margin_bottom ||= 0
      r  = @row + @row_offset + @margin_top
      c  = @col + @col_offset + @margin_left
      ht = @height-2-(@margin_top + @margin_bottom)
      wd = @width -2-(@margin_left + @margin_right)
      # should this not happen only if repaint_required ?
      @components.each { |e| 
        e.parent_component = self
        e.row              = r
        e.col              = c
        # check that we are not trying to print outside bounds
        # by default we are stacking top level comps regardless of stack or flow
        #  otherwise too complicated
        if e.is_a? BaseStack 
          # using ||= allows us to use overrides given by user
          # but disallows us from calculating if size changes
            e.height           = (ht) * (e.weight * 0.01)
            e.height           = e.height.round 
            e.width            = wd 
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
      # override widget
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
