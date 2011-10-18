=begin
  * Name: tabbed pane: can have multiple forms overlapping.
  * Description: 
  * A tabbed pane, mostly based (iirc) on the Terminal Preferences in OSX PPC 10.5.x
  * Starting a new version using pads 2009-10-25 12:05 

   2011-10-18 : removed ScrollForm since it would not print if window was not at 0,0 top left.


  * Author: rkumar
  
  --------
  * Date:  2009-10-25 12:05 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

  * 2010-02-28 09:47 - major cleanup and rewrite. 
    - Allow adding of component (in addition to form)
    - Ideally, even form should be created and managed itself, why should TP have to repaint it?

NOTE: 
    Tp now does not create a form by default, since awefun you may want to just put in one component.
    Pls use tp.form(tab) to get a form associated with the tab.
    You may add as many tabs as you wish. To scroll tabs, traverse into the tab form and use the usual scroll keys M-l and M-h to scroll left and right.
  #
  # TODO :  disable/hide tab ???
=end
require 'logger'
require 'rbcurse'
#require 'rbcurse/rscrollform' # tried, shows in all cases teh buttons but never gets control

KEY_TAB = 9
KEY_BTAB = 353
#include Ncurses # FFI 2011-09-8 
include RubyCurses
module RubyCurses
  extend self

  Event = Struct.new( :tab, :index, :event)

  # Multiple independent overlapping forms using the tabbed metaphor.
  class TabbedButton < RubyCurses::RadioButton
    attr_accessor :display_tab_on_traversal
    def getvalue_for_paint
      @text
    end
    def selected?
        @variable.value == @value 
    end
    ## 
    # highlight abd selected colors and attribs should perhaps be in a
    # structure, so user can override easily
    def repaint  # tabbedbutton
       $log.debug("TabbedBUTTon repaint : #{self.class()} fn:#{@form.name}  r:#{@row} c:#{@col} #{getvalue_for_paint} gt #{@form.window.top}  gl #{@form.window.left}" )
        r,c = rowcol
        attribs = @attrs
        @highlight_foreground ||= $reversecolor
        @highlight_background ||= $reversecolor # 0 
        _state = @state
        _state = :SELECTED if @variable.value == @value 
        case _state
        when :HIGHLIGHTED
          $log.debug("TabbedBUTTon repaint : HIGHLIGHTED #{bgcolor}, #{color}, v: #{@value}" )
          bgcolor = @highlight_background
          color = @highlight_foreground
          bgcolor = @bgcolor
          color =  "red" #@color
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
       $log.debug("button repaint : r:#{r} #{@graphic.top}  c:#{c} #{@graphic.left} color:#{color} bg #{bgcolor} v: #{value}, g: #{@graphic} ")
        len = @display_length || value.length
        # paint the tabs name in approp place with attribs
        #@form.window.printstring r, c, "%-*s" % [len, value], color, attribs
        #@graphic.printstring r+@graphic.top, c+@graphic.left, "%-*s" % [len, value], color, attribs
        #@graphic.printstring r-@graphic.top, c-@graphic.left, "%-*s" % [len, value], color, attribs

        ro =  @graphic.top
        co =  @graphic.left
        ro =  0
        co =  0
        # NOTE after removing scrollform I've replaced check of graphic with 0, Note if we revert
        if _state == :HIGHLIGHTED
          @graphic.printstring r+ro, c-1+co, ">",  color, @attrs unless c-1 < 0 #@graphic.left
          #@graphic.printstring r, c+len+1, "<",  color, @attrs
        else
          @graphic.printstring r+ro, c-1+co, " ",  color, @attrs unless c-1 < 0 #@graphic.left
          #@graphic.printstring r, c+len+1, " ",  color, @attrs
        end
        @graphic.printstring r+ro, c+co, "%-*s" % [len, value], color, attribs
        @graphic.modified = true
#       @form.window.mvchgat(y=r, x=c, max=len, Ncurses::A_NORMAL, bgcolor, nil)
         # underline for the top tab buttons.
        if @underline != nil
          # 2011-10-17 cmmented
          r -= @graphic.top # because of pad, remove if we go back to windows
          c -= @graphic.left # because of pad, remove if we go back to windows
          @graphic.mvchgat(y=r, x=c+@underline+0, max=1, Ncurses::A_BOLD|Ncurses::A_UNDERLINE, color, nil)
        end
    end
    # trying to give the option so as we tab through buttons, the relevant tab opens
    # but this is getting stuck on a tab and not going on
    # fire() is causing the problem
    # fire takes the focus into tab area so the next TAB goes back to first button
    # due to current_tab = tab (so next key stroke goes to tab)
    def on_enter
      $log.debug " overridden on_enter of tabbedbutton #{@name}, foc #{@focussed}  "
      super
      #@state = :HIGHLIGHTED if @focussed
      $log.debug " overridden on_enter of tabbedbutton #{@name} state #{@state}, foc #{@focussed}  "
      $log.debug " calling fire overridden on_enter of tabbedbutton" if @display_tab_on_traversal
      fire if @display_tab_on_traversal
    end
    # In order to get tab display as we traverse buttons, we need to tamper with KEY_DOWN
    # since that's the only way of getting down to selected tab in this case.
    def handle_key ch # tabbed button
      case ch
      when  KEY_DOWN
        # form will not do a next_field, it will ignore this
        @state = :NORMAL # 2011-10-5 
        @form.repaint
        return :NO_NEXT_FIELD
      when KEY_RIGHT
        ret =  @form.select_next_field
        ret = @form.select_first_field if ret == :NO_NEXT_FIELD
        return ret
      when KEY_LEFT
        ret =  @form.select_prev_field
        ret = @form.select_last_field if ret == :NO_PREV_FIELD
        return ret
      when KEY_ENTER, 10, 13, 32  # added space bar also
        if respond_to? :fire
          fire
        end
      else
        # all thrse will be re-evaluated by form
        return :UNHANDLED
      end
    end
    0
  end
  ## 
  # extending Widget from 2009-10-08 18:45 
  # It should extend Widget so we can pop it in a form. In fact it should be in a form,
  #  we should not have tried to make it standalone like messagebox.
  #  This is the main TabbedPane widget that will be slung into a form
  class TabbedPane < Widget
    TAB_ROW_OFFSET = 3 # what row should tab start on (was 4 when printing subheader)
    TAB_COL_OFFSET = 0 # what col should tab start on (to save space, flush on left)
    dsl_accessor :button_type      # ok, ok_cancel, yes_no
    dsl_accessor :buttons           # used if type :custom
    
    # set to true if you want tabs to show as you traverse the tab buttons
    dsl_accessor :display_tab_on_traversal

    # creates a scrollable form so many buttons can be placed
    #  NOTE: this only works in a root window, I can't figure out why.
    dsl_accessor :scrolling_allowed

    attr_reader :selected_index
    attr_reader :current_tab
    attr_reader :window
    def initialize form, aconfig={}, &block
      @scrolling_allowed = false
      super
      @parent = form
      @parentwin = form.window
      @visible = true
      @focusable= true
      @tabs ||= []
      @forms ||= []
      @attr = nil
      @current_form = nil
      @current_tab = nil
      @config = aconfig
      @col_offset = 2;  @row_offset = 1 # added 2010-01-10 22:54 
      @recreate_buttons = true
      install_keys
      @_events.push(*[:OPEN, :INSERT, :DELETE])
      @on_main_form = true # 2011-10-4 we need to know this i think
    end
    def install_keys
      @form.bind_key([?d, ?d]) { ix = highlighted_tab_index; repeatm { remove_tab(ix) } }
      @form.bind_key(?u) { undelete_tab; }
      @form.bind_key(?p) { paste_tab 0; } # paste before or at position
      @form.bind_key(?P) { paste_tab 1; } # paste deleted tab after this one
      @form.bind_key([?c, ?w]) { change_label }
      @form.bind_key(?C) { change_label }
    end
    ##
    # This is a public, user called method for appending a new tab
    # This will be called several times for one TP.
    # when adding tabs, you may use ampersand in text to create hotkey
    # XXX adding a tab later does not influence buttons array,
    def add_tab text, component = nil, aconfig={}, &block
      index = @tabs.size
      tab = insert_tab text, component, index, aconfig, &block
      return tab
    end
    alias :add :add_tab

    ## insert a component at given index
    # index cannnot be greater than size of tab count
    def insert_tab text, component, index, aconfig={}, &block
      $log.debug " TAB insert #{text} at #{index} "
      @tabs[index] = Tab.new(text, self, aconfig, &block)
      tab = @tabs[index]

      # trying out setting current tab when created  2011-10-4 
      #  This situation happens when someone externally is setting data
      #  in a tab and calling its repaint. When user presses DOWN from button
      #  it was crashing. Old tab is the tab you see below. current_tab takes on 
      #  either form or old_tab to distinguish whether we are on top buttons or
      #  inside a tab.
      @old_tab = tab

      tform = form(tab) # this could go inside Tab constructor now 2011-10-4 
      #tab.component = component unless component.nil? # changed on 2011-10-3  CLEAN
      #component.form = tform unless component.nil? # changed on 2011-10-3  CLEAN
      component.set_form( tform) unless component.nil? # changed on 2011-10-3 
      configure_component component unless component.nil?
      tab.index = index # so i can undelete !!!
      fire_event tab, index, :INSERT
      @recreate_buttons = true
      return tab
    end
    ## remove given tab based on index
    # This does not unbind the key mapping, FIXME
    # Currently, can be invoked by 'dd' over highlighted button
    # XXX can append to deleted_tabs, then on insert or paste insert with splat.
    def remove_tab index
      @recreate_buttons = true
      $log.debug " inside remove_tab with #{index}, #{@tabs.size} "
      @deleted_tab = @tabs.delete_at(index) unless @tabs.size < index
      # note this is the index it was at. 
      fire_event @deleted_tab, index, :DELETE
    end
    ## 
    # Move this fun stuff to a util class. TODO
    # If tab deleted accidentally, undelete it
    # Okay, i just can stop myself from having a little fun
    def undelete_tab
      return unless @deleted_tab
      @recreate_buttons = true
      @tabs.insert(@deleted_tab.index, @deleted_tab)
      fire_event @deleted_tab, @deleted_tab.index, :INSERT
      @deleted_tab = nil
      $log.debug " undelete over #{@tabs.size} "
    end
    def paste_tab pos
      return unless @deleted_tab
      ix = highlighted_tab_index
      return if ix == -1
      @recreate_buttons = true
      @deleted_tab.index = ix + pos
      @tabs.insert(@deleted_tab.index, @deleted_tab)
      fire_event @deleted_tab, @deleted_tab.index, :INSERT
      @deleted_tab = nil
      $log.debug " paste over #{@tabs.size} #{ix} + #{pos} "
    end

    ##
    # prompts for a new label for a tab - taking care of mnemonics if ampersand present
    # Currently, mapped to 'C' and 'cw' when cursor is on a label
    # Perhaps some of this kind of utility stuff needs to go into a util class.
    #
    def change_label
      ix = highlighted_tab_index
      return if ix < 0
      prompt = "Enter new label: "
      label = @buttons[ix].text
      config = {}
      config[:default] = label.dup
      maxlen = 10
      ret, str = rbgetstr(@graphic, $error_message_row, $error_message_col, prompt, maxlen, config)
      if ret == 0 and str != "" and str != label
        @tabs[ix].text = str
        @buttons[ix].text(str)
        @recreate_buttons = true
      end
    end
    ##
    # returns the index of the tab cursor is on (not the one that is selected)
    # @return [0..] index, or -1 if some error
    def highlighted_tab_index
      @form.widgets.each_with_index{ |w, ix| 
        return ix if w.state == :HIGHLIGHTED
      }
      return -1
    end
    def selected_tab_index
      @form.widgets.each_with_index{ |w, ix| 
        return ix if w.selected?
      }
      return -1
    end
    ## remove all tabs
    def remove_all
      if !@buttons.empty?
        @buttons.each {|e| @form.remove_widget(e) }
      end
      @buttons = []
      @tabs = []
      @recreate_buttons = true
    end

    ## return a form for use by program - if you want to put multiple items
    # Otherwise just use add_component
    # private - can't use externally
    def configure_component component
        #component.set_form @parent <<--- definitely NOT
        #component.form = @parent # changed on 2011-10-2 
        component.rows_panned = component.cols_panned = 0
        component.parent_component = self # added 2010-02-27  so offsets can go down ?

        $log.debug "XXX: TABBED #{@row} #{@col} #{@height} #{@width} "
        component.row ||= 0 # 2011-10-3 @row + TAB_ROW_OFFSET # 2
        component.col ||= 0 #@col + TAB_COL_OFFSET
        component.width  ||= @width #@col + TAB_COL_OFFSET
        component.height  ||= @height - 2 #@col + TAB_COL_OFFSET
        $log.debug "XXX: TABBED #{component.row} #{component.col} #{component.height} #{component.width} "

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
      if !tab.has_form?
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
      _recreate_buttons if @recreate_buttons
      $log.debug " tabbedpane repaint #{@window.name} "
      @window.show
      @window.wrefresh # trying out FFI 2011-09-19 since form not being refreshed
      #x set_buffer_modified()
    end
    def show
      repaint
    end
    ## recreate all buttons
    # We call this if even one is added : adv is we can space out accordinagly if the numbers increase
    # We could also expand the pad here.
    # Test it out with removing tabs to.
    # XXX have to remove buttons from the form
    def _recreate_buttons
      $log.debug " inside recreate_buttons: #{@tabs.size} "
      r = @row
      col = @col + 1
      @buttons ||= []
      #
      # NOTE: since we remove buttons, setting any events on them is useless !
      #
      if !@buttons.empty?
        @buttons.each {|e| @form.remove_widget(e) }
      end
      @buttons = []
      button_gap = 4
      # the next line necessitates a clear on the pad
      #  button_gap = 1 if @tabs.size > 6 # quick dirty fix, we need something that checks fit
      # we may also need to truncate text to fit

      @buttonpad.wclear if @buttonpad # 2011-10-18 
      ## create a button for each tab
      $tabradio = Variable.new # so we know which is highlighted
      # 2011-10-17 seems objects on this form do not get windows offset
      wco = @window.left
      wro = @window.top
      @tabs.each do |tab|
        text = tab.text
        $log.debug " TABS EACH #{text}, #{wro} #{wco} "
        @buttons << RubyCurses::TabbedButton.new(@form) do
          variable $tabradio
          text text
          name text
          value text
          row r + 1 #+ wro
          col col #+ wco
        end
        col += text.length + button_gap
        # if col exceeds pad_w then we need to expand pad
        # but here we don't know that a pad is being used
        $log.debug " button col #{col} " 
#        form = tab.form # changed 2011  2011-09-26 
        form = form(tab)
        form.set_parent_buffer(@window) if form

        b = @buttons.last
        b.display_tab_on_traversal = @display_tab_on_traversal # 2011-10-4 
        tab._button(b) # too late, user needs this when tab is created FIXME
        b.command(b, @form) { 
          $log.debug " calling tab.repaint,button_form_repaint from button press #{b.name} #{b.state} "
          # form.rep essentially sees that buttons get correct attributes
          # when triggering M-<char>. This button should get highlighted.
          tab.repaint

          # the on_leave of current button does not get fired, so it gets
          #   left in a HIGHLIGHTED state, so two can show highlighted at the same time 2011-10-5 
          #
          @form.widgets.each { |tb| @form.on_leave(tb) if tb.state == :HIGHLIGHTED }

          button_form_repaint #( b.state == :HIGHLIGHTED )
          if @display_tab_on_traversal
            # set as old tab so ONLY on going down this becomes current_tab
            @old_tab = tab
          else
            # next line means next key is IMMED  taken by the tab not main form
            @current_tab = tab
          end
          $log.debug "TAB : form #{tab.form}, #{tab.form.widgets.first} "
          c = tab.form.widgets.first
          c.set_form_row; c.set_form_col
          fire_event tab, tab.index, :OPEN
        }
      end
      @recreate_buttons = false
      # make the buttons visible now, not after next handle_key
      @form.repaint
    end
    ## This form is for the tabbed buttons on top
    def create_window
      set_buffer_modified() # required still ??
      # first create the main top window with the tab buttons on it.
      $log.debug " TPane create_buff Top #{@row}, Left #{@col} H #{@height} W #{@width} "
      #$log.debug " parentwin #{@parentwin.left} #{@parentwin.top} "

      r = @row
      c = @col
      # NOTE: I had to remove ScrollForm since it would not work if 
      #  window was not root window. This means I cannot have more buttons
      #  than fit on screen.


      # tried out proper ScrollForm, it shows the buttons but does not take
      # cursor there or show cursor there at all.

      scrolling = @scrolling_allowed
      if scrolling
        @form = ScrollForm.new(@parentwin)
        # 2011-10-18 trying to see why buttons won't print if window is not 0,0
        #@form.parent_form = @parent # 2011-10-18 trying out why buttons not coming at correct place
        #@form.add_cols = @parent.window.left
        #@form.add_rows = @parent.window.top
        offset = 1
        @form.set_layout(1, @width, @row+offset, @col+offset)
        @form.display_h = 1
        @form.display_w = @width-3
        @buttonpad = @form.create_pad
        @buttonpad.name = "Window::TPTOPPAD" # 2010-02-02 20:01 

      else
        @form = Form.new(@parentwin)
      end


      ## We will use the parent window, and not a pad. We will write absolute coordinates.
      @window = @parentwin
      color = $datacolor
      # border around button bar. should this not be in scrollform as a border ? XXX
      @window.print_border @row, @col, 2, @width, color #, Ncurses::A_REVERSE
      @form.name = "Form::TPTOPFORM"
      $log.debug("TP WINDOW TOP ? PAD MAIN FORM W:#{@window.name},  F:#{@form.name} ")
      @form.parent_form = @parent ## 2010-01-21 15:55 TRYING OUT BUFFERED
      @form.navigation_policy = :NON_CYCLICAL
      
      Ncurses::Panel.update_panels
      _recreate_buttons
 
      @old_tab = @tabs.first
      @old_tab.repaint if @old_tab
      button_form_repaint true
      @window.wrefresh ## ADDED  2009-11-02 23:29 
      #@buttons.first().fire unless @buttons.empty? # make the first form active to start with.
      #@current_tab = nil # 2011-10-3 otherwise keys go to this form in the beginning
      @current_tab = @form # 2011-10-4 buttons form should be first
    end
    # 
    # Handle placing control in first or last button. 
    # R
    def on_enter
      if $current_key == KEY_BTAB
        c = @form.widgets.count-1
        @form.select_field c
      else
        @form.select_field 0
      end
    end
    def button_form_repaint flag = true
      $log.debug " INSIDE button_form_repaint #{flag} "
      if flag
        # repaint form and refresh pad
        @form.repaint
      else
        # only refresh pad 
        # - 2011-09-19 I don't think this is called, prolly give an error
        @form.prefresh
      end
    end

    ##
    # This creates a form for the tab, in case we wish to put many components in it.
    # Else just pass single components in add_tab.
    # @params tab tab just created for which a form is required
    # @return form - a pad based form
    def create_tab_form tab

      mtop          = 0
      mleft         = 0
      bottom_offset = 2 # 0 will overwrite bottom line, 1 will make another line for inner form
      layout = { :height => @height-(mtop+bottom_offset), :width => @width, :top => mtop, :left => mleft } 
      window = VER::Pad.create_with_layout(layout)

      form = RubyCurses::Form.new window
      
      form.parent_form = @parent
      form.add_cols    = @col + 0
      form.add_rows    = @row + 2
     
    
      form.navigation_policy = :NON_CYCLICAL
      window.bkgd(Ncurses.COLOR_PAIR($datacolor));
      window.box(0, 0);
      window.mvwaddch(0, 0, Ncurses::ACS_LTEE) # beautify the corner 2010-02-06 19:35 
      window.mvwaddch(0, @width-1, Ncurses::ACS_RTEE)
      window.mvwaddch(layout[:height]-1, 0, Ncurses::ACS_LTEE) # beautify the corner 2010-02-06 19:35 
      window.mvwaddch(layout[:height]-1, @width-1, Ncurses::ACS_RTEE)

      ## this prints the tab name on top left
      window.mvprintw(1,1, tab.text.tr('&', '')) if @print_subheader
      window.name = "Tab::TAB-#{tab.text}" 
      form.name = "Form::TAB-#{tab.text}" 
      return form
    end
    ##
    # added 2009-10-08 19:39 so it can be placed in a form
    # @form is the top button form
    # XXX stop this nonsense about current_form and current_tab
    # TP should only be concerned with tabs. what happens inside is none of its business
    def handle_key(ch) # tabbed pane TP


      if @current_tab == @form         # on main form
        return :UNHANDLED if ch == ?\M-\C-i.getbyte(0) # alt-tab to exit
        ret = @form.handle_key ch
        $log.debug "TP HNDLE KEY got ret #{ret}, ch #{ch} "
        ret ||= :UNHANDLED
        if ret == :UNHANDLED
          $log.warn "unhandled key in TP main #{ch} "
          case ch
          when KEY_RIGHT, KEY_LEFT, KEY_TAB, KEY_BTAB
          when KEY_UP
          when KEY_DOWN
          when KEY_TAB
          when KEY_BTAB
          end
        elsif ret == :NO_NEXT_FIELD
          case ch
          when KEY_TAB
            return :UNHANDLED
          when KEY_RIGHT, KEY_DOWN, ?j.getbyte(0)

            @current_tab = @old_tab 
            if @current_tab
              @current_tab.set_focus :FIRST
            else
              alert "Need to press enter on button"
              if @current_tab.nil? ##or @current_tab.is_a?  Form
                w = @form.widgets.first
                w.fire if w.respond_to? :fire
              end
            end
            return 0
          when KEY_UP
          when KEY_BTAB
          end
          return ret
        elsif ret == :NO_PREV_FIELD
          case ch
          when KEY_LEFT, KEY_BTAB, ?k.getbyte(0)
            $log.debug "LEFT BTAB when no previous field"
            return :UNHANDLED
          end
          return ret
        end
        return 0
      end
      
        $log.debug " handle_key in tabbed pane got : #{ch},  #{@current_tab}, f: #{@form}  "
      @current_tab ||= @form # first we cycle buttons
        $log.debug " handle_key in tabbed pane got : #{ch}, giving to #{@current_tab} "
      # needs to go to component
      ret = @current_tab.handle_key(ch)
        $log.debug " -- form.handle_key in tabbed pane got ret : #{ret} , #{@current_tab} , #{ch} "

      # components will usually return UNHANDLED for a tab or btab
      # We need to convert it so the main form can use it
      if @current_tab != @form
          if ret == :UNHANDLED
            if ch == KEY_TAB #or ch == KEY_DOWN
              ret = :NO_NEXT_FIELD
            elsif ch == KEY_BTAB or ch == ?k.getbyte(0) #or ch == KEY_UP # btab
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
          #alert "came to no nex field" # CLEAN
          if @current_tab != @form
            #alert "case 1 no next field req first" # changed on 2011-10-2  # 2011-10-04 16:12:34
            ## if no next field on a subform go to first button of main form
            @old_tab = @current_tab
            @current_tab = @form
            @form.req_first_field
         
          else
            # on top button panel - no more buttons, go to tabs first field
            if @old_tab # in case of empty tabbed pane old_tab was nil
            #alert "case 2 no next field set focus" # CLEANUP # 2011-10-04 16:12:46
              @current_tab = @old_tab
              @current_tab.set_focus :FIRST
            end
          end
        when :NO_PREV_FIELD
          if @current_tab != @form
            $log.debug "TP 1 no prev field - going to last button "
            @old_tab = @current_tab
            @current_tab = @form
            @form.req_last_field
          else
            # on top button panel - no prev buttons, go to tabs last field
            if @old_tab # in case of one tab
              @current_tab = @old_tab
              @current_tab.set_focus :LAST
            end
          end
        when :UNHANDLED
          $log.debug " unhandled in tabbed pane #{ch}"
          ret = @form.process_key ch, self # field
    
          return ret if ret == :UNHANDLED
        end
        if @buttonpad && @buttonpad.modified
          button_form_repaint
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
      $log.debug "XXX: came to TP make lower buttons FORM #{@form.name}  "
      total = names.inject(0) {|total, item| total + item.length + 4}
      bcol = center_column total

      brow = @layout[:height]-2 # check for < 0
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
      width = @layout[:width] # check for  0 XXX
      return (width-textlen)/2
    end
    def fire_event tab, index, event
      # experimenting with structs, earlier we've used classes
      if @tabbedpane_event.nil?
        @tabbedpane_event = Event.new
      end
      @tabbedpane_event.tab = tab
      @tabbedpane_event.index = index
      @tabbedpane_event.event = event
      fire_handler event, @tabbedpane_event
    end

    ##
    # nested class tab
    # A user created tab, with its own form
    class Tab
      attr_accessor :text
      attr_reader :config
      attr_reader :component # 2011-10-4 DEPRECATED
      #attr_accessor :form
      attr_accessor :parent_component
      attr_accessor :index
      attr_accessor :button  # so you can set an event on it 2011-10-4 
      def initialize text, parent_component,  aconfig={}, &block
        @text = text
        @config = aconfig
        @parent_component = parent_component
        @config.each_pair { |k,v| variable_set(k,v) }
        instance_eval &block if block_given?
      end
      ## add a single component to the tab
      # Calling this a second time will overwrite the existing component
      # @deprecated since 2011-10-4 1.3.1
      def component=(component)
        @form.add_widget component
        raise "Component cannot be null" unless component
        raise "Component already associated with a form. Do not pass form in constructor." unless component.form.nil?
        $log.debug " calling configure component "
        @parent_component.configure_component component
        #@component = component # changed on 2011-10-3 
      end
      # @deprecated since 2011-10-4 1.3.1
      def remove_component
        @form.widgets.pop # 2011-10-4 
        #@component = nil
      end
      # private
      def variable_set var, val
        var = "@#{var}"
        instance_variable_set(var, val) 
      end
      # tab should handle key instead of TP.
      # Pass to component or form
      def handle_key ch # Tab
        #kh = @component || @form 2011-10-4 
        kh = @form
       $log.debug "DEBUG : handle_key Tab giving key to ( #{kh} ) "
        ret = kh.handle_key(ch)
       $log.debug "DEBUG : handle_key Tab ( #{kh} )got ret #{ret} "
        # forms seem to returning a nil when the pad has been updated. We need to copy it
        ret ||= 0
        if ret == :UNHANDLED
          $log.debug "tab handle_key returns UNHANDLED" if $log.debug? 
          #alert "Inside unhandled case, tab's for did not handle key"
          #@component.repaint if @component
          #@form.window.refresh
          #$log.debug "DEBUG calling display form(false) from handle_key XXXX" if @form
          #display_form false if @form # this caused others to go blank 2011-09-26 
        elsif ret != :UNHANDLED # FFI trying out, since forms with components not displaying changes
          display_form false if @form #  required for multi field forms, not single ones
        end
        # XXX i need to call repaint of compoent if updated !!
        return ret
      end
      def repaint # Tab
        if @form
          $log.debug "DEBUG calling display form(true) from repaint XXX" if $log.debug?
          display_form
        else
          # pls use tp.form(tab) to get form explicity.
          # It could come here if tab precreated and user is yet to assign a component.
          # or has removed component and not yet set a new one.
          $log.error "Got neither component nor form."
          $log.error "Programmer error. A change in Tabbedpane requires you to create form explicitly using form = tpane.form(tab) syntax"
        end
      end
      ## Set focus on a component or form field when a user has tabbed off the last or first button
      def set_focus first_last
          if !@form.nil?
            # move to first field of existing form
            #@current_form = @current_tab.form # 2010-02-27 20:22 
            $log.debug " calling display form(true) from handle_key NO_NEXT_FIELD: #{first_last} "
            first_last == :FIRST ? @form.req_first_field : @form.req_last_field
            display_form
            if @form.widgets.count == 1 # not working trying to get cursor to show in first form.
              component = @form.widgets.first
              component.set_form_row
              component.set_form_col
            end
          else 
            raise "Form nil. Component cannot be directly added any longer. Pls use form"
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
      end
      pc = @parent_component
      form.repaint if flag #   added 2009-11-03 23:27  paint widgets in inside form
      $log.debug " TP display form(#{flag})  before pad copy: #{pad.name}, set_backing: #{form}: #{form.name} parent: #{@parent_component} : #{pc.row} , #{pc.col}. #{pc.height} , #{pc.width}: repaint flag #{flag}   "
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
      #pad.mvhline( 0,0, Ncurses::ACS_HLINE, pad.width-1)
      pad.mvwaddch(0, 0, Ncurses::ACS_LTEE) # beautify the corner 2010-02-06 19:35 
      pad.mvwaddch(0, pad.width-1, Ncurses::ACS_RTEE)
    end

    # 2011-09-19 @since 1.3.0 changed so that calling form throws an exception
    # if it's nil. Please use Tabbedpane's form() to get a form. This throws an exception
    # so i can catch old programs that use the incorrect method
    def form(*val)
      if val.empty?
        return @form if @form
        raise "Form is nil. You may be using deprecated method. Use @tp.form, not @tab.form"
      else
        #raise ArgumentError "form should be ... " if val[0] ...
        oldvalue = @form
        @form = val[0]
      end
      self
    end
    # used by TP to set form
    def form=(val)
      @form = val
    end
    # used by TP to check form, since the other methods throws an exception
    def has_form?
      !@form.nil?
    end

    # @private avoid external use
    def _button(b)
      @button = b
    end
    end # class Tab

  end # class Tabbedpane

  ## An extension of Form that only displays and focuses on visible widgets
  #  This is minimal, and is being expanded upon as a separate class in rscrollform.rb
  #
  class ScrollForm < RubyCurses::Form
    attr_accessor :pmincol # advance / scroll columns
    attr_accessor :pminrow # advance / scroll rows (vertically)
    attr_accessor :display_w
    attr_accessor :display_h
    attr_accessor :scroll_ctr
    attr_reader :orig_top, :orig_left
    attr_reader :window
    attr_accessor :name
    attr_reader :cols_panned, :rows_panned
    def initialize win, &block
      @target_window = win
      super
      @pminrow = @pmincol = 0
      @scroll_ctr = 2
      @cols_panned = @rows_panned = 0
    end

    def set_layout(h, w, t, l)
      @pad_h = h
      @pad_w = w
      @top   = t
      @left  = l
      @top += @target_window.top
      @left += @target_window.left
      @orig_top = @top
      @orig_left = @left
    end
    def create_pad
      r = @top
      c = @left
      layout = { :height => @pad_h, :width => @pad_w, :top => r, :left => c } 
      @window = VER::Pad.create_with_layout(layout)

      @window.name = "Pad::ScrollPad"
      @name        = "Form::ScrollForm"
      return @window
    end

    ## ScrollForm handle key, scrolling
    def handle_key ch
      #alert("SCROLLFORM #{ch} , ai: #{@active_index} , #{get_current_field.name} ")
      $log.debug " inside ScrollForm handlekey #{ch} "
      # do the scrolling thing here top left prow and pcol of pad to be done
      # # XXX TODO check whether we can scroll before incrementing esp cols_panned etc
      case ch
      when ?\M-l.getbyte(0)
        return false if !validate_scroll_col(@pmincol + @scroll_ctr)
        @pmincol += @scroll_ctr # some check is required or we'll crash
        @cols_panned -= @scroll_ctr
        $log.debug " handled ch M-l in ScrollForm"
        @window.modified = true
        return 0
      when ?\M-h.getbyte(0)
        return false if !validate_scroll_col(@pmincol - @scroll_ctr)
        @pmincol -= @scroll_ctr # some check is required or we'll crash
        @cols_panned += @scroll_ctr
        $log.debug " handled ch M-h in ScrollForm"
        @window.modified = true
        return 0
      when ?\M-n.getbyte(0)
        return false if !validate_scroll_row(@pminrow + @scroll_ctr)
        @pminrow += @scroll_ctr # some check is required or we'll crash
        @rows_panned -= @scroll_ctr
        @window.modified = true
        return 0
      when ?\M-p.getbyte(0)
        return false if !validate_scroll_row(@pminrow - @scroll_ctr)
        @pminrow -= @scroll_ctr # some check is required or we'll crash
        @rows_panned += @scroll_ctr
        @window.modified = true
        return 0
      end
      case ch
      when ?j.getbyte(0)
        ch = KEY_DOWN
      when ?k.getbyte(0)
        ch = KEY_BTAB
        @window.ungetch(KEY_BTAB)
        return 0
      when ?h.getbyte(0)
        ch = KEY_LEFT
      when ?l.getbyte(0)
        ch = KEY_RIGHT
      end

      super 
    end
    def repaint
      $log.debug " scrollForm repaint calling parent"
      super
      prefresh
      @window.modified = false
    end
    def prefresh
      ## reduce so we don't go off in top+h and top+w
      $log.debug "  start ret = @buttonpad.prefresh( #{@pminrow} , #{@pmincol} , #{@top} , #{@left} , top + #{@display_h} left + #{@display_w} ) "
      if @pminrow + @display_h > @orig_top + @pad_h
        $log.debug " if #{@pminrow} + #{@display_h} > #{@orig_top} +#{@pad_h} "
        $log.debug " ERROR 1 "
        #return -1
      end
      if @pmincol + @display_w > @orig_left + @pad_w
      $log.debug " if #{@pmincol} + #{@display_w} > #{@orig_left} +#{@pad_w} "
        $log.debug " ERROR 2 "
        return -1
      end
      # actually if there is a change in the screen, we may still need to allow update
      # but ensure that size does not exceed
      if @top + @display_h > @orig_top + @pad_h
      $log.debug " if #{@top} + #{@display_h} > #{@orig_top} +#{@pad_h} "
        $log.debug " ERROR 3 "
        return -1
      end
      if @left + @display_w > @orig_left + @pad_w
      $log.debug " if #{@left} + #{@display_w} > #{@orig_left} +#{@pad_w} "
        $log.debug " ERROR 4 "
        return -1
      end
      # maybe we should use copywin to copy onto @target_window
      $log.debug "   ret = @buttonpad.prefresh( #{@pminrow} , #{@pmincol} , #{@top} , #{@left} , #{@top} + #{@display_h}, #{@left} + #{@display_w} ) "
      omit = 0
      # this works but if want to avoid copying border
      ret = @window.prefresh(@pminrow, @pmincol, @top, @left, @top + @display_h , @left + @display_w)

      $log.debug " ret = #{ret} "
      # need to refresh the form after repaint over
    end
    def validate_scroll_row minrow
       return false if minrow < 0
      if minrow + @display_h > @orig_top + @pad_h
        $log.debug " if #{minrow} + #{@display_h} > #{@orig_top} +#{@pad_h} "
        $log.debug " ERROR 1 "
        return false
      end
      return true
    end
    def validate_scroll_col mincol
      return false if mincol < 0
      if mincol + @display_w > @orig_left + @pad_w
      $log.debug " if #{mincol} + #{@display_w} > #{@orig_left} +#{@pad_w} "
        $log.debug " ERROR 2 "
        return false
      end
      return true
    end
    # when tabbing through buttons, we need to account for all that panning/scrolling goin' on
    # Either of r or c can be nil (usually one will be)
    def setrowcol r, c
      # aha ! here's where i can check whether the cursor is falling off the viewable area
      if c
      if c+@cols_panned < @orig_left
        # this essentially means this widget (button) is not in view, its off to the left
        $log.debug " setrowcol OVERRIDE #{c} #{@cols_panned} < #{@orig_left} "
        $log.debug " aborting settrow col for now"
        return
      end
      if c+@cols_panned > @orig_left + @display_w
        # this essentially means this button is not in view, its off to the right
        $log.debug " setrowcol OVERRIDE #{c} #{@cols_panned} > #{@orig_left} + #{@display_w} "
        $log.debug " aborting settrow col for now"
        return
      end
      end # if c
      rr = r.nil? ? nil : r+@rows_panned
      cc = c.nil? ? nil : c+@cols_panned
      super rr, cc
    end
    def add_widget w
      super
      #$log.debug " inside add_widget #{w.name}  pad w #{@pad_w} #{w.col} "
      if w.col >= @pad_w
        @pad_w += 10 # XXX currently just a guess value, we need length and maybe some extra
        @window.wresize(@pad_h, @pad_w)
      end
    end
    ## Is a component visible, typically used to prevent traversal into the field
    # @returns [true, false] false if components has scrolled off
    def visible? component
      r, c = component.rowcol
      return false if c+@cols_panned < @orig_left
      return false if c+@cols_panned > @orig_left + @display_w
      # XXX TODO for rows UNTESTED for rows
      return false if r + @rows_panned < @orig_top
      return false if r + @rows_panned > @orig_top + @display_h

      return true
    end
    # returns index of first visible component. Currently using column index
    # I am doing this for horizontal scrolling presently
    # @return [index, -1] -1 if none visible, else index/offset
    def first_visible_component_index
      @widgets.each_with_index do |w, ix|
        return ix if visible?(w)
      end
      return -1
    end
    def last_visible_component_index
      ret = -1
      @widgets.each_with_index do |w, ix|
        $log.debug " reverse last vis #{ix} , #{w} : #{visible?(w)} "
        ret = ix if visible?(w)
      end
      return ret
    end
    def req_first_field
      select_field(first_visible_component_index)
    end
    def req_last_field
      select_field(last_visible_component_index)
    end
    def focusable?(w)
      w.focusable and visible?(w)
    end

  end # class ScrollF


end # module
