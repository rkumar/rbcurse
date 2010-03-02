=begin
  * Name: tabbed pane: can have multiple forms overlapping.
  * Description: 
  * A tabbed pane, mostly based (iirc) on the Terminal Preferences in OSX PPC 10.5.x
  * Starting a new version using pads 2009-10-25 12:05 
  * Author: rkumar
  
  --------
  * Date:  2009-10-25 12:05 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)


  * 2010-02-28 09:47 - major cleanup and rewrite. 
    - Allow adding of component (in addition to form)
    - Tab should handle_key and repaint based on compo or form
    - Ideally, even form should be created and managed itself, why should TP have to repaint it?

NOTE: 
    Tp now does not create a form by default, since awefun you may want to just put in one component.
    Pls use tp.form(tab) to get a form associated with the tab.
=end
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'

include Ncurses
include RubyCurses
module RubyCurses
  extend self

  # TODO :  insert_tab, remove_tab, disable/hide tab
  # Hotkeys should be defined with ampersand, too.
  # 2010-02-21 13:44 When switching tabs, cursor needs to be re-established
  # Need to handle more tabs than can be displayed.
  # NOTE:I don't think this uses set_form_row or bothers with the cursor
  #+ since it manages highlighting etc on its own. 2009-12-29 13:30 
  #
  # TODO Option for highlighted tab shoud be displayed
  # TODO can down arrow from buttons take us into form
  # TODO up arrow from first field take us into buttons

  # Multiple independent overlapping forms using the tabbed metaphor.
  class TabbedButton < RubyCurses::RadioButton
    def getvalue_for_paint
      @text
    end
    ## 
    # highlight abd selected colors and attribs should perhaps be in a
    # structure, so user can override easily
    def repaint  # tabbedbutton
       $log.debug("TabbedBUTTon repaint : #{self.class()}  r:#{@row} c:#{@col} #{getvalue_for_paint}" )
        r,c = rowcol
        attribs = @attrs
        @highlight_foreground ||= $reversecolor
        @highlight_background ||= 0
        _state = @state
        _state = :SELECTED if @variable.value == @value 
        case _state
        when :HIGHLIGHTED
       $log.debug("TabbedBUTTon repaint : HIGHLIGHTED #{bgcolor}, #{color}")
          bgcolor = @highlight_background
          color = @highlight_foreground
          bgcolor =  @bgcolor
          color =  @color
          attribs = Ncurses::A_BOLD
          setrowcol r,c  # show cursor on highlighted as we tab through
          ## but when tabbing thru selected one, then selected one doesn't show cursor
        when :SELECTED
       $log.debug("TabbedBUTTon repaint : SELECTED #{bgcolor}, #{color}")
          bgcolor =  @bgcolor
          color =  @color
          attribs = Ncurses::A_REVERSE
          if @state == :HIGHLIGHTED
            setrowcol r,c  # show cursor on highlighted as we tab through
          end
        else
       $log.debug("TabbedBUTTon repaint : ELSE #{bgcolor}, #{color}")
          bgcolor =  @bgcolor
          color =  @color
        end
        #bgcolor = @state==:HIGHLIGHTED ? @highlight_background : @bgcolor
        #color = @state==:HIGHLIGHTED ? @highlight_foreground : @color
        if bgcolor.is_a? String and color.is_a? String
          color = ColorMap.get_color(color, bgcolor)
        end
        value = getvalue_for_paint
       $log.debug("button repaint : r:#{r} #{@graphic.top}  c:#{c} #{@graphic.left} col:#{color} bg #{bgcolor} v: #{value} ")
        len = @display_length || value.length
        # paint the tabs name in approp place with attribs
        #@form.window.printstring r, c, "%-*s" % [len, value], color, attribs
        @graphic.printstring r+@graphic.top, c+@graphic.left, "%-*s" % [len, value], color, attribs
#       @form.window.mvchgat(y=r, x=c, max=len, Ncurses::A_NORMAL, bgcolor, nil)
         # underline for the top tab buttons.
        if @underline != nil
          # changed +1 to +0 on 2008-12-15 21:23 pls check.
          @graphic.mvchgat(y=r, x=c+@underline+0, max=1, Ncurses::A_BOLD|Ncurses::A_UNDERLINE, color, nil)
        end
    end
    # trying to give the option so as we tab through buttons, the relevant tab opens
    # but this is getting stuck on a tab and not going on
    # fire() is causing the problem
    # fire takes the focus into tab area so the next TAB goes back to first button
    # due to current_tab = tab (so next key stroke goes to tab)
    def on_enter
      $log.debug " overridden on_enter of tabbedbutton #{@name} "
      super
      $log.debug " calling fire overridden on_enter of tabbedbutton"
      fire if @display_tab_on_traversal
    end
    # In order to get tab display as we traverse buttons, we need to tamper with KEY_DOWN
    # since that's the only way of getting down to selected tab in this case.
    def handle_key ch
      case ch
      when  KEY_DOWN
        # form will not do a next_field, it will ignore this
        return :NO_NEXT_FIELD
      when KEY_RIGHT
        @form.select_next_field
      when KEY_LEFT
        @form.select_prev_field
      when KEY_ENTER, 10, 13, 32  # added space bar also
        if respond_to? :fire
          fire
        end
      else
        # all thrse will be re-evaluated by form
        return :UNHANDLED
      end
    end
 
  end
  ## 
  # extending Widget from 2009-10-08 18:45 
  # It should extend Widget so we can pop it in a form. In fact it should be in a form,
  #  we should not have tried to make it standalone like messagebox.
  #  This is the main TabbedPane widget that will be slung into a form
  class TabbedPane < Widget
    TAB_ROW_OFFSET = 2 # what row should tab start on (was 4 when printing subheader)
    TAB_COL_OFFSET = 0 # what col should tab start on (to save space, flush on left)
    dsl_accessor :button_type      # ok, ok_cancel, yes_no
    dsl_accessor :buttons           # used if type :custom
    attr_reader :selected_index
    attr_reader :current_tab
    attr_reader :window
    def initialize form, aconfig={}, &block
      super
      @parent = form
      @parentwin = form.window
      @visible = true
      @focusable= true
      @tabs ||= []
      @forms ||= []
      #@bgcolor ||=  "black" # 0
      #@color ||= "white" # $datacolor
      @attr = nil
      @current_form = nil
      @current_tab = nil
      @config = aconfig
      #@config.each_pair { |k,v| variable_set(k,v) }
      #instance_eval &block if block_given?
      @col_offset = 2;  @row_offset = 1 # added 2010-01-10 22:54 
  #    @manages_cursor = true # redundant, remove
    end
    ##
    # This is a public, user called method for creating a new tab
    # This will be called several times for one TP.
    # when adding tabs, you may use ampersand in text to create hotkey
    def add_tab text, component = nil, aconfig={}, &block
      #create a button here and block is taken care of in button's instance
      #or push this for later creation.
      @tabs << Tab.new(text, self, aconfig, &block)
      tab = @tabs.last
      tab.component = component unless component.nil?
      #tab.parent_component = self
      # just temoprarily 
      #if component.nil?
        #@forms << create_tab_form(tab)
        #tab.form = @forms.last
      #end
      return tab
    end
    ## return a form for use by program - if you want to put multiple items
    # Otherwise just use add_component
    # private - can't use externally
    def configure_component component
        #component.set_form @parent <<--- definitely NOT
        component.form = @parent
        component.rows_panned = component.cols_panned = 0
        component.parent_component = self # added 2010-02-27  so offsets can go down ?
        component.should_create_buffer = true 
        component.row = @row + TAB_ROW_OFFSET # 2
        component.col = @col + TAB_COL_OFFSET

        # current_form likely to be nil XXX
        scr_top = component.row # for Pad, if Pad passed as in SplitPane
        scr_left = component.col # for Pad, if Pad passed as in SplitPane
        ho = TAB_ROW_OFFSET + 2 # 5
        component.set_buffering(:target_window => @target_window || @parentwin, :form => @current_form, :bottom => @height-ho, :right => @width-2, :screen_top => scr_top, :screen_left => scr_left)
        # if left nil, then we expand the comp
        component.height ||= @height - (ho - 1) # 1 keeps lower border inside by 1
        component.width ||= @width - 0 # 0 keeps it flush on right border


    end
    ## create a form for tab, if multiple components are to be placed inside tab.
    #  Tabbedpane has no control over placement and width etc of what's inside a form
    def form tab
      if tab.form.nil?
        @forms << create_tab_form(tab)
        tab.form = @forms.last
      end
      return tab.form
    end

    ## returns the index of the current / selected tab
    ## @returns 0.. index of selected tab
    def selected_tab_index
      @tabs.index(@current_tab)
    end

    # private
    def variable_set var, val
        var = "@#{var}"
        instance_variable_set(var, val) 
    end
    # private
    def configure(*val , &block)
      case val.size
      when 1
        return @config[val[0]]
      when 2
        @config[val[0]] = val[1]
        variable_set(val[0], val[1]) 
      end
      instance_eval &block if block_given?
    end
    ## this is a really wierd repaint method. 
    # First time it creates the TP window/form which contains the buttons.
    # In future calls it really doesn't do anything.
    # Deos it have nothing to paint, no borders to redraw, no repaint_required ???
    def repaint
      $log.debug " tabbedpane repaint "
      @window || create_window
      $log.debug " tabbedpane repaint #{@window.name} "
      @window.show
      #x set_buffer_modified()
    end
    def show
      repaint
    end
    ## This form is for the tabbed buttons on top
    def create_window
      set_buffer_modified() # required still ??
      # first create the main top window with the tab buttons on it.
      $log.debug " TPane create_buff Top #{@row}, Left #{@col} H #{@height} W #{@width} "
      #$log.debug " parentwin #{@parentwin.left} #{@parentwin.top} "
      r = @row
      c = @col
      #@layout = { :height => @height, :width => @width, :top => r, :left => c } 
      ## We will use the parent window, and not a pad. We will write absolute coordinates.
      @window = @parentwin
      @form = RubyCurses::Form.new @window
      #@window.name = "Window::TPTOPPAD" # 2010-02-02 20:01 
      @form.name = "Form::TPTOPFORM"
      $log.debug("TP WINDOW TOP ? PAD MAIN FORM W:#{@window.name},  F:#{@form.name} ")
      @form.parent_form = @parent ## 2010-01-21 15:55 TRYING OUT BUFFERED
      @form.navigation_policy = :NON_CYCLICAL
      #xx @current_form = @form
      color = $datacolor
      @window.print_border @row, @col, @height-1, @width, color #, Ncurses::A_REVERSE
      
      Ncurses::Panel.update_panels
      col = @col + 1
      @buttons = []
      ## create a button for each tab
      $tabradio = Variable.new
      @tabs.each do |tab|
        text = tab.text
        @buttons << RubyCurses::TabbedButton.new(@form) do
          variable $tabradio
          text text
          name text
          value text
          row r + 1
          col col
        end
        col += text.length+4
        form = tab.form
        form.set_parent_buffer(@window) if form

        b = @buttons.last
        b.command(b) { 
          $log.debug " calling display form from button press #{b.name} #{b.state} "
          # form.rep essentially sees that buttons get correct attributes
          # when triggering M-<char>. This button should get highlighted.
          @form.repaint unless b.state == :HIGHLIGHTED
          tab.repaint
          if @display_tab_on_traversal
            # set as old tab so ONLY on going down this becomes current_tab
            @old_tab = tab
          else
            # next line means next key is IMMED  taken by the tab not main form
            @current_tab = tab
          end
        }
 
      end
      @form.repaint #  This paints the outer form not inner
      @window.wrefresh ## ADDED  2009-11-02 23:29 
      @old_tab = @tabs.first
      @buttons.first().fire unless @buttons.empty? # make the first form active to start with.
    end
    ##
    def create_tab_form tab
        mtop = 0
        mleft = 0
        bottom_offset = 2 # 0 will overwrite bottom line, 1 will make another line for inner form
      layout = { :height => @height-(mtop+bottom_offset), :width => @width, :top => mtop, :left => mleft } 
      # create a pad but it must behave like a window at all times 2009-10-25 12:25 
      window = VER::Pad.create_with_layout(layout)

      # needed to be at tab level, but that's not a widget
      form = RubyCurses::Form.new window # we now pass a pad and hope for best
      $log.debug " pad created in TP create_tab_form: #{window.name} , form #{form.name}  "
      $log.debug " hwtl: #{layout[:height]} #{layout[:width]} #{layout[:top]} #{layout[:left]} "
      ## added 2010-01-21 15:46 to pass cursor up
      form.parent_form = @parent
      form.navigation_policy = :NON_CYCLICAL
      window.bkgd(Ncurses.COLOR_PAIR($datacolor));
      window.box( 0, 0);
      window.mvwaddch(0, 0, Ncurses::ACS_LTEE) # beautify the corner 2010-02-06 19:35 
      window.mvwaddch(0, @width-1, Ncurses::ACS_RTEE)

      # XXX TODO this wastes space we should ditch it.
      ## this prints the tab name on top left
      window.mvprintw(1,1, tab.text.tr('&', '')) if @print_subheader
      window.name = "Tab::TAB-#{tab.text}" # 2010-02-02 19:59 
      form.name = "Form::TAB-#{tab.text}" # 2010-02-02 19:59 
      form.add_cols=@col
      form.add_rows=@row
      return form
    end
    ##
    # added 2009-10-08 19:39 so it can be placed in a form
    # @form is the top button form
    # XXX stop this nonsense about current_form and current_tab
    # TP should only be concerned with tabs. what happens inside is none of its business
    def handle_key(ch)
      @current_tab ||= @form # first we cycle buttons
          $log.debug " handle_key in tabbed pane got : #{ch}"
          # needs to go to component
          ret = @current_tab.handle_key(ch)
          $log.debug " -- form.handle_key in tabbed pane got ret : #{ret} , #{@current_tab} , #{ch} "

          # components will usually return UNHANDLED for a tab or btab
          # We need to convert it so the main form can use it
          if @current_tab != @form
          if ret == :UNHANDLED
            if ch == 9 #or ch == KEY_DOWN
              ret = :NO_NEXT_FIELD
            elsif ch == 353 #or ch == KEY_UP # btab
              ret = :NO_PREV_FIELD
            end
          end
          else
            # key down pressed in top form, go to tab
            if ch == KEY_DOWN
              ret = :NO_NEXT_FIELD
            end
          end

        case ret
        when :NO_NEXT_FIELD
          if @current_tab != @form
            ## if no next field on a subform go to first button of main form
            @old_tab = @current_tab
            @current_tab = @form
            @form.req_first_field
            #@form.select_next_field
          else
            # on top button panel - no more buttons, go to tabs first field
            @current_tab = @old_tab
            @current_tab.set_focus :FIRST
          end
        when :NO_PREV_FIELD
          if @current_tab != @form
            $log.debug "TP 1 no prev field - going to last button "
            @old_tab = @current_tab
            @current_tab = @form
            @form.req_last_field
          else
            # on top button panel - no prev buttons, go to tabs last field
            @current_tab = @old_tab
            @current_tab.set_focus :LAST
            end
        when :UNHANDLED
          $log.debug " unhandled in tabbed pane #{ch}"
          ret = @form.process_key ch, self # field
    
          return ret if ret == :UNHANDLED
        end
    end
    ##
    # ensure that the pads are being destroyed, although we've not found a way.
    def destroy
      @window.destroy
      @forms.each { |f| w = f.window; w.destroy unless w.nil? }
    end
    def create_buttons
      case @button_type.to_s.downcase
      when "ok"
        make_buttons ["&OK"]
      when "ok_cancel" #, "input", "list", "field_list"
        make_buttons %w[&OK &Cancel]
      when "yes_no"
        make_buttons %w[&Yes &No]
      when "yes_no_cancel"
        make_buttons ["&Yes", "&No", "&Cancel"]
      when "custom"
        raise "Blank list of buttons passed to custom" if @buttons.nil? or @buttons.size == 0
        make_buttons @buttons
      else
        $log.debug "No buttontype passed for creating tabbedpane. Using default (OK)"
        make_buttons ["&OK"]
      end
    end
    def make_buttons names
      total = names.inject(0) {|total, item| total + item.length + 4}
      bcol = center_column total

      brow = @layout[:height]-2
      button_ct=0
      names.each_with_index do |bname, ix|
        text = bname
        #underline = @underlines[ix] if !@underlines.nil?

        button = Button.new @form do
          text text
          name bname
          row brow
          col bcol
          #underline underline
          highlight_background $reversecolor 
          color $datacolor
          bgcolor $datacolor
        end
        index = button_ct
        button.command { |form| @selected_index = index; @stop = true; $log.debug "Pressed Button #{bname}";}
        button_ct += 1
        bcol += text.length+6
      end
    end
    def center_column textlen
      width = @layout[:width]
      return (width-textlen)/2
    end

    ##
    # nested class tab
    # A user created tab, with its own form
    class Tab
      attr_reader :text
      attr_reader :config
      attr_reader :component
      attr_accessor :form
      attr_accessor :parent_component
      def initialize text, parent_component,  aconfig={}, &block
        @text = text
        @config = aconfig
        @parent_component = parent_component
        @config.each_pair { |k,v| variable_set(k,v) }
        instance_eval &block if block_given?
      end
      ## add a single component to the tab
      # Calling this a second time will overwrite the existing component
      def component=(component)
        raise "Component cannot be null" unless component
        raise "Component already associated with a form. Do not pass form in constructor." unless component.form.nil?
        $log.debug " calling configure component "
        @parent_component.configure_component component
        @component = component
      end
      def remove_component
        @component = nil
      end
      # private
      def variable_set var, val
        var = "@#{var}"
        instance_variable_set(var, val) 
      end
      # tab should handle key instead of TP.
      # Pass to component or form
      def handle_key ch
        kh = @component || @form
        ret = kh.handle_key(ch)
        # forms seem to returning a nil when the pad has been updated. We need to copy it
        ret ||= 0
        if ret == 0 
          @component.repaint if @component
          display_form false if @form
        end
        # XXX i need to call repaint of compoent if updated !!
        return ret
      end
      def repaint # Tab
        if @form
          display_form
        elsif @component
          # we ask the component to paint its buffer only, no actual repainting
          redraw
        else
          # pls use tp.form(tab) to get form explicity.
          # It could come here if tab precreated and user is yet to assign a component.
          # or has removed component and not yet set a new one.
          $log.error "Got neither component nor form."
          $log.error "Programmer error. A change in Tabbedpane requires you to create form explicitly using form = tpane.form(tab) syntax"
        end
      end
      # force a redraw of a component when tabs changed
      def redraw
        # this kinda stuff should be inside widget or some util class
        c = @component
        if c.is_double_buffered?
          c.set_buffer_modified
          c.buffer_to_window
        else
          # force a repaint, if not buffered object e.g scrollpane.
          $log.debug " TP: forcing repaint of non-buffered object #{c}  "
          c.repaint_all
          c.repaint
        end
      end
      ## Set focus on a component or form field when a user has tabbed off the last or first button
      def set_focus first_last
          if !@form.nil?
            # move to first field of existing form
            #@current_form = @current_tab.form # 2010-02-27 20:22 
            $log.debug " calling display form from handle_key NO_NEXT_FIELD: #{first_last} "
            first_last == :FIRST ? @form.req_first_field : @form.req_last_field
            display_form
          else 
            # move to component
            #@current_form = @current_tab.component # temp HACK 2010-02-27 23:24 
            @component.set_form_row
            @component.set_form_col
          end
      end
    # On a tabbed button press, this will display the relevant form
    # On why I am directyl calling copywin and not using copy_pad_to_win etc
    #+ those require setting top and left. However, while printing a pad, top and left are reduced and so 
    #+ must be absolute r and c. But inside TP, objects have a relative coord. So the print functions
    #+ were failing silently, and i was wondering why nothing was printing.
    # XXX move this tab in tab.repaint and let tab decide based on component or form
    # if component then pad = component.get_buffer
    def display_form flag = true
      return if @form.nil? 
      form = @form
      if form.is_a? RubyCurses::Form  # tempo XXX since there are components
        pad = form.window
      else
        return
        pad = form.get_buffer() # component
      end
      pc = @parent_component
      form.repaint if flag #   added 2009-11-03 23:27  paint widgets in inside form
      $log.debug " TP display form before pad copy: #{pad.name}, set_backing: #{form}: #{form.name} parent: #{@parent_component} : #{pc.row} , #{pc.col}. #{pc.height} , #{pc.width}: repaint flag #{flag}   "
      ret = -1
      pminr = pminc = 0
      r = pc.row + 2
      c = pc.col + 0
      border_width = 0
      maxr = pc.height() - 3
      maxc = pc.width() - 1
      $log.debug " ret = pad.copywin(pc.window.get_window, #{pminr}, #{pminc}, #{r}, #{c}, r+ #{maxr} - border_width, c+ #{maxc} -border_width,0). W:#{pc.window}, #{pc.window.get_window} "
      ret = pad.copywin(pc.window.get_window, pminr, pminc, r, c, r+maxr-border_width, c+maxc-border_width,0)
      $log.debug " display form after pad copy #{ret}. #{form.name} "
    end

    end # class Tab

  end # class Tabbedpane


end # module
