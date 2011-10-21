=begin
  * Name: newtabbedpane.rb
  An attempt at a simple formless tabbedpane
    I am tired of tracking cursor issues
  * Description   
  * Author: rkumar (http://github.com/rkumar/rbcurse/)
  * Date: 2011-10-20 
  * License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
  * Last update:  Fri Oct 21 20:20:21 IST 2011

  == CHANGES
  == TODO 
     on start first buttons bottom should not be lined.
     Alt-1-9 to goto tabs
Title 
=end
require 'rbcurse'
##
module RubyCurses
  class NewTabbedPane < Widget
    dsl_property :title, :title_attrib
    # what kind of buttons, if this is a window, :ok :ok_camcel :ok_apply_cancel
    dsl_accessor :button_type
    attr_reader :button_row
    

    def initialize form=nil, config={}, &block
      @_events ||= []
      @_events.push(:PRESS)
      @button_gap = 2
      init_vars
      super
      @focusable = true
      @editable  = true
      @col_offset = 2
    end

    # Add a tab
    def tab title, config={}, &block
      @tab_titles << title
      @tab_components[title]=[]
      @tabs << Tab.new(title, self, config, &block)

    end
    alias :add_tab :tab


    def repaint
      @current_tab ||= 0
      @button_row ||=  @row + 2
      @separator_row = @button_row + 1 # hope we have it by now, where to print separator
      @separator_row0 = @button_row - 1 unless @button_row == @row + 1
      @separator_row2 = @row + @height - 3 # hope we have it by now, where to print separator
      #return unless @repaint_required
      if @buttons.empty?
        _create_buttons
        @components = @buttons.dup
        @components.push(*@tabs[@current_tab].items)
        create_action_buttons
        @components.push(*@action_buttons)
      elsif @tab_changed
        @components = @buttons.dup
        @components.push(*@tabs[@current_tab].items)
        @components.push(*@action_buttons)
        @tab_changed = false
      end
      # if some major change has happened then repaint everything
      if @repaint_required
        $log.debug " NEWTAB repaint graphic #{@graphic} "
        print_borders unless @suppress_borders # do this once only, unless everything changes
        print_separator1
        @components.each { |e| e.repaint_all(true); e.repaint }
      else
        @components.each { |e| e.repaint }
      end # if repaint_required
      print_border if (@suppress_borders == false && @repaint_all) # do this once only, unless everything changes
      @repaint_required = false
    end
    def handle_key ch
      $log.debug " CONTAINER handle_key #{ch} "
      return if @components.empty?
      _multiplier = ($multiplier == 0 ? 1 : $multiplier )

      # should this go here 2011-10-19 
      unless @_entered
        $log.warn "WARN: calling ON_ENTER since in this situation it was not called"
        on_enter
      end
      if ch == KEY_TAB
        $log.debug "CONTAINER GOTO NEXT"
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
        Ncurses.beep
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
          if on_a_button?
            return goto_first_item
          else
            return goto_next_component #unless on_last_component?
          end
        else 
          #@_entered = false
          return :UNHANDLED
        end
      end

      $multiplier = 0
      return 0
    end
    def on_enter
      # if BTAB, the last comp
      if $current_key == KEY_BTAB
        @current_component = @components.last
      else
        @current_component = @components.first
      end
      return unless @current_component
      $log.debug " CONTAINER came to ON_ENTER #{@current_component} "
      set_form_row
      @_entered = true
    end
    def on_leave
      @_entered = false
      super
    end
    # takes focus to first item (after buttons)
    def goto_first_item
      bc = @buttons.count
      c = @components[bc]
      if c
        leave_current_component
        @current_component = c
        set_form_row
      end
    end
    def goto_next_component
      if @current_component != nil 
        leave_current_component
        if on_last_component?
          @_entered = false
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
      return :UNHANDLED if @current_component.nil?
      $log.debug " CONTAINER on enter sfr #{@current_component} "
      @current_component.on_enter
      @current_component.set_form_row # why was this missing in vimsplit. is it
      # that on_enter does a set_form_row
      @current_component.set_form_col # XXX 
      @current_component.repaint
      # XXX compo should do set_form_row and col if it has that
    end
    # private
    def set_form_col
      return if @current_component.nil?
      $log.debug " #{@name} CONTAINER  set_form_col calling sfc for #{@current_component.name} "
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
    def on_a_button?
      @components.index(@current_component) < @buttons.count
    end
    # set focus on given component
    # Sometimes you have the handle to component, and you want to move focus to it
    def goto_component comp
      return if comp == @current_component
      leave_current_component
      @current_component = comp
      set_form_row
    end

    def _handle_key ch
      map_keys unless @keys_mapped
      ret = process_key ch, self
      @multiplier = 0
      return :UNHANDLED if ret == :UNHANDLED
      return 0
    end

    # Put all the housekeeping stuff at the end
    private
    def init_vars
      @buttons        = []
      @tabs           = []
      @tab_titles     = []
      @tab_components = {}
      @bottombuttons  = []
      #
      # I'll keep current tabs comps in this to simplify
      @components     = []      
      @_entered = false
    end

    def map_keys
      @keys_mapped = true
      #bind_key(?q, :myproc)
      #bind_key(32, :myproc)
    end

    def _create_buttons
      $log.debug "XXX: INSIDE create_buttons col_offset #{@col_offset} "
      v = Variable.new
      r = @button_row # @row + 1
      col = @col + @col_offset
      @tabs.each_with_index { |t, i| 
        txt = t.text
        @buttons << TabButton.new(nil) do 
          variable v
          text  txt
          name  txt
          #value txt
          row  r
          col col
          surround_chars ['','']
          selected_background 'green'
          selected_foreground 'white'

        end
        b = @buttons.last
        b.command do
          set_current_tab i
        end
        b.form = @form
        b.override_graphic  @graphic
        col += txt.length + @button_gap
      }
    end # _create_buttons
    def set_current_tab t
      return if @current_tab == t
      @current_tab = t
      goto_component @components[t]
      @tab_changed = true
      @repaint_required = true
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
    def print_separator1

      width       = @width
      height      = @height-1 
      window      = @graphic 
      startcol    = @col
      startrow    = @row
      @color_pair = get_color($datacolor)
      r           = @separator_row
      c           = @col + @col_offset

      urcorner    = []
      #window.printstring r, c, '-' * (@width-2), @color_pair, @attr
      window.mvwhline( r, @col+1, Ncurses::ACS_HLINE, @width-2)
      @buttons.each_with_index do |b, i|
        l = b.text.length 
        if b.selected?
          if false #c == @col + @col_offset
            cc = c
            ll = l+1
          else
            cc = c-1 
            ll = l+2
          end
          #rr = r -1 #unless rr == @col
          window.printstring r, cc, " "*ll, @color_pair, @attr
          #window.printstring r, cc-1, FFI::NCurses::ACS_HLINE.chr*ll, @color_pair, @attr
          #window.printstring r-2, cc, FFI::NCurses::ACS_HLINE.chr*ll, @color_pair, @attr
          window.mvwaddch r, cc-1, FFI::NCurses::ACS_LRCORNER unless cc-1 <= @col
          window.mvwaddch r, c+l+1, FFI::NCurses::ACS_LLCORNER
        else
          window.mvwaddch r, c+l+1, FFI::NCurses::ACS_BTEE
        end

        #window.printstring r-2, c, FFI::NCurses::ACS_HLINE*l, @color_pair, @attr
        #tt = b.text
        #window.printstring r, c, tt, @color_pair, @attr
        c += l + 1
        #window.mvwaddch r, c, '+'.ord
        window.mvwaddch r-1, c, FFI::NCurses::ACS_VLINE
        window.mvwaddch r-2, c, FFI::NCurses::ACS_URCORNER #ACS_TTEE
        #window.mvwaddch r-2, c+1, '/'.ord
        urcorner << c
        c+=@button_gap
      end
      window.mvwhline( @separator_row0, @col + 1, Ncurses::ACS_HLINE, c-@col-1-@button_gap)
      window.mvwhline( @separator_row2, @col + 1, Ncurses::ACS_HLINE, @width-2)
      urcorner.each do |c| 
        window.mvwaddch r-2, c, FFI::NCurses::ACS_URCORNER #ACS_TTEE
      end
    end
    def print_title
      return unless @title
      _title = @title
      if @title.length > @width - 2
        _title = @title[0..@width-2]
      end
      @graphic.printstring( @row, @col+(@width-_title.length)/2, _title, 
                           @color_pair, @title_attrib) unless @title.nil?
    end

    #
    # create the buttons at the bottom OK/ APPLY/ CANCEL

    def create_action_buttons
      case @button_type.to_s.downcase
      when "ok"
        make_buttons ["&OK"]
      when "ok_cancel" #, "input", "list", "field_list"
        make_buttons %w[&OK &Cancel]
      when "ok_apply_cancel" #, "input", "list", "field_list"
        make_buttons %w[&OK &Apply &Cancel]
      when "yes_no"
        make_buttons %w[&Yes &No]
      when "yes_no_cancel"
        make_buttons ["&Yes", "&No", "&Cancel"]
      when "custom"
        raise "Blank list of buttons passed to custom" if @buttons.nil? or @buttons.size == 0
        make_buttons @buttons
      else
        $log.warn "No buttontype passed for creating tabbedpane. Not creating any"
        #make_buttons ["&OK"]
      end
    end
    def make_buttons names
      @action_buttons = []
      $log.debug "XXX: came to TW make buttons FORM= #{@form.name} "
      total = names.inject(0) {|total, item| total + item.length + 4}
      bcol = center_column total

      # this craps out when height is zero
      brow = @row + @height-2
      brow = FFI::NCurses.LINES-2 if brow < 0
      button_ct=0
      names.each_with_index do |bname, ix|
        text = bname
        #underline = @underlines[ix] if !@underlines.nil?

        button = Button.new nil do
          text text
          name bname
          row brow
          col bcol
          #underline underline
          highlight_background $reversecolor 
          color $datacolor
          bgcolor $datacolor
        end
        @action_buttons << button 
        button.form = @form
        button.override_graphic  @graphic
        index = button_ct
        button.command { |form| @selected_index = index; @stop = true; 
          throw(:close, @selected_index)
        
        }
        button_ct += 1
        bcol += text.length+6
      end
    end
    def center_column textlen
      width = @col + @width
      return (width-textlen)/2
    end

    ## ADD ABOVE
  end # class

  class Tab
    attr_accessor :text
    attr_reader :config
    attr_reader :items
    attr_accessor :parent_component
    attr_accessor :index
    attr_accessor :button  # so you can set an event on it 2011-10-4 
    attr_accessor :row_offset  
    attr_accessor :col_offset 
    def initialize text, parent_component,  aconfig={}, &block
      @text   = text
      @items  = []
      @config = aconfig
      @parent_component = parent_component
      @row_offset ||= 2
      @col_offset ||= 2
      @config.each_pair { |k,v| variable_set(k,v) }
      instance_eval &block if block_given?
    end
    def item widget
      widget.form = @parent_component.form
      widget.override_graphic @parent_component.form.window
      # these will fail if TP put inside some other container. NOTE
      widget.row ||= 0
      widget.col ||= 0
      if widget.kind_of?(Container) || widget.respond_to?(:width)
        widget.width ||= @parent_component.width-3
      end
      if widget.kind_of?(Container) || widget.respond_to?(:height)
        widget.height ||= @parent_component.height-3
      end
      # i don't know button_offset as yet
      widget.row += @row_offset + @parent_component.row  + 1
      widget.col += @col_offset + @parent_component.col
      @items << widget
    end
  end # class tab
  class TabButton < RadioButton
    attr_accessor :display_tab_on_traversal
    def getvalue_for_paint
      @text
    end
    def selected?
      @variable.value == @value 
    end

  end

end # module
if __FILE__ == $PROGRAM_NAME
  require 'rbcurse/app'
  require 'rbcurse/rcontainer'
  App.new do
    #r = Container.new nil, :row => 1, :col => 2, :width => 40, :height => 10, :title => "A container"
    r = Container.new nil, :suppress_borders => true
    f1 = field "name", :maxlen => 20, :display_length => 20, :bgcolor => :white, 
      :color => :black, :text => "abc", :label => ' Name: '
    f2 = field "email", :display_length => 20, :bgcolor => :white, 
      :color => :blue, :text => "me@google.com", :label => 'Email: '
    f3 = radio :group => :grp, :text => "red", :value => "RED", :color => :red
    f4 = radio :group => :grp, :text => "blue", :value => "BLUE", :color => :blue
    f5 = radio :group => :grp, :text => "green", :value => "GREEN", :color => :green
    r.add(f1)
    r.add(f2)
    r.add(f3,f4,f5)
    NewTabbedPane.new @form, :row => 3, :col => 5, :width => 60, :height => 20 do
      title "User Setup"
      button_type :ok_apply_cancel
      tab "&Profile" do
        item Field.new nil, :row => 2, :col => 2, :text => "enter your name", :label => ' Name: '
        item Field.new nil, :row => 3, :col => 2, :text => "enter your email", :label => 'Email: '
      end
      tab "&Settings" do
        item CheckBox.new nil, :row => 2, :col => 2, :text => "Use HTTPS", :mnemonic => 'u'
        item CheckBox.new nil, :row => 3, :col => 2, :text => "Quit with confirm", :mnemonic => 'q'
      end
      tab "&Term" do
        radio = Variable.new
        item RadioButton.new nil, :row => 2, :col => 2, :text => "&xterm", :value => "xterm", :variable => radio
        item RadioButton.new nil, :row => 3, :col => 2, :text => "sc&reen", :value => "screen", :variable => radio
        radio.update_command() {|rb| ENV['TERM']=rb.value }
      end
      tab "Conta&iner" do
        item r
      end

    end
  end # app

end
