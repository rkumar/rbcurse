=begin
  * Name: tabbed pane: can have multiple forms overlapping.
  * Description: 
  * starting a new version using pads 2009-10-25 12:05 
  * Author: rkumar
  
  --------
  * Date:  2009-10-25 12:05 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

NOTE: Line 610 in rwidget.rb copy_pad_to_win was written for tabbedpanes
but did not let a splitpane print its comp fully if SPLP's width was increased
I've commented out that line, if you face an error in printing, check that line.
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
  # NOTE:I don't think this uses set_form_row or bothers with the cursor
  #+ since it manages highlighting etc on its own. 2009-12-29 13:30 

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
        when :SELECTED
       $log.debug("TabbedBUTTon repaint : SELECTED #{bgcolor}, #{color}")
          bgcolor =  @bgcolor
          color =  @color
          attribs = Ncurses::A_REVERSE
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
#       $log.debug("button repaint : r:#{r} c:#{c} col:#{color} bg #{bgcolor} v: #{value} ")
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
  end
  ## 
  # extending Widget from 2009-10-08 18:45 
  # It should extend Widget so we can pop it in a form. In fact it should be in a form,
  #  we should not have tried to make it standalone like messagebox.
  #  This is the main TabbedPane widget that will be slung into a form
  class TabbedPane < Widget
  #  include DSL - widget does
  #  include EventHandler - widget does
    #attr_reader :visible
    #dsl_accessor :row, :col
    dsl_accessor :height, :width
    dsl_accessor :button_type      # ok, ok_cancel, yes_no
    dsl_accessor :buttons           # used if type :custom
    attr_reader :selected_index
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
      should_create_buffer true # added 2010-01-10 22:54 
    end
    ##
    # This is a public, user called method for creating a new tab
    # This will be called several times for one TP.
    # when adding tabs, you may use ampersand in text to create hotkey
    def add_tab text, aconfig={}, &block
      #create a button here and block is taken care of in button's instance
      #or push this for later creation.
      @tabs << Tab.new(text, aconfig, &block)
      tab = @tabs.last
      @forms << create_tab_form(tab)
      tab.form = @forms.last
      return tab
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
    def repaint
      @window || create_window
      @window.show
      set_buffer_modified()
    end
    def show
      repaint
    end
    def create_window
      set_buffer_modified()
      # first create the main top window with the tab buttons on it.
      $log.debug "create_window R #{@row}, C #{@col} #{@height} #{@width} "
      @layout = { :height => @height, :width => @width, :top => @row, :left => @col } 
      #@layout = { :height => 2, :width => @width, :top => @row, :left => @col } 
      #@window = VER::Window.new(@layout)
      #@window = @parentwin.derwin(@height, @width, @row, @col)
      #@window = @parentwin.derwin(@layout)
      @window = safe_create_buffer # trying this out.
      $log.debug("WINDOW PAD #{@window}")
      ## seems this form is for the tabbed buttons on top XXX
      @form = RubyCurses::Form.new @window
      @form.navigation_policy = :NON_CYCLICAL
      @current_form = @form
      @window.bkgd(Ncurses.COLOR_PAIR($datacolor));
      @window.box( 0, 0);
      #@parentwin.get_window().touchwin()
      ##### XXX @window.wrefresh
      Ncurses::Panel.update_panels
      col = 1
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
          row 1
          col col
        end
        col += text.length+4
#       @forms << create_tab_form(tab)
#       form = @forms.last
        form = tab.form
        form.set_parent_buffer(@window)
#        form.window = @window if form.window.nil? ## XXX
#        panel = form.window.panel rescue Ncurses::Panel.new_panel(form.window)

        @buttons.last.command { 
=begin
          Ncurses::Panel.top_panel(panel) 
          Ncurses::Panel.update_panels();
          Ncurses.doupdate();
          form.repaint
=end
          $log.debug " calling display form from button press"
          display_form(form)
          @current_form = form
          @current_tab = form
        }
 
      end
      @form.repaint #  This paints the outer form not inner
      @window.wrefresh ## ADDED  2009-11-02 23:29 
      @buttons.first().fire # make the first form active to start with.
    end
    def display_form form
      pad = form.window
      $log.debug " before pad copy "
      #ret = pad.wrefresh # overridden to prefresh.
      pad.set_backing_window(@graphic)
      ret = pad.copy_pad_to_win
      $log.debug " after pad copy #{ret} "
      form.repaint #   added 2009-11-03 23:27  paint widgets in inside form
      @window.wrefresh
    end
    def create_tab_form tab
      layout = { :height => @height-2, :width => @width, :top => 2, :left => 0 } 
      #layout = { :height => @height-2, :width => @width, :top => @row+0, :left => @col+0 } 
      #window = VER::Window.new(layout)
      #window = @parentwin.derwin(@height-2, @width, @row+2, @col)
      #window = @parentwin.derwin(layout)
      # create a pad but it must behave like a window at all times 2009-10-25 12:25  XXX
      window = VER::Pad.create_with_layout(layout)
      #window = safe_create_buffer() # DARN, this overwrites higher one, if at all created.
      # needed to be at tab level, but that's not a widget
      form = RubyCurses::Form.new window # we now pass a pad and hope for best
      form.navigation_policy = :NON_CYCLICAL
      window.bkgd(Ncurses.COLOR_PAIR($datacolor));
      window.box( 0, 0);
      ## this prints the tab name on top left
      window.mvprintw(1,1, tab.text.tr('&', ''))
      ##window.wrefresh
      ##Ncurses::Panel.update_panels
      return form
    end
    ##
    # added 2009-10-08 19:39 so it can be placed in a form
    def handle_key(ch)
        @current_form ||= @form
          $log.debug " handle_key in tabbed pane got : #{ch}"
        ret = @current_form.handle_key(ch)
          $log.debug " -- form.handle_key in tabbed pane got ret : #{ret}"
        case ret
        when :NO_NEXT_FIELD
          if @current_form != @form
            @current_form = @form
            #@current_form.select_field -1
            @current_form.req_first_field
            #ret = @current_form.handle_key(ch)
          else
            if !@current_tab.nil?
            @current_form = @current_tab
            $log.debug " calling display form from handle_key NO_NEXT_FIELD"
            display_form @current_form
            @current_form.req_first_field
            #@current_form.select_field -1
            #ret = @current_form.handle_key(ch)
            end
          end
        when :NO_PREV_FIELD
          if @current_form != @form
            $log.debug " 1 no prev field - going to button "
            @current_form = @form
            @current_form.req_last_field
          else
            if !@current_tab.nil?
            @current_form = @current_tab
            $log.debug " calling display form from handle_key NO_PREV_FIELD"
            display_form @current_form
            @current_form.req_last_field
            end
          end
        when :UNHANDLED
          $log.debug " unhandled in tabbed pane #{ch}"
          ret = @form.process_key ch, self # field
          #### XXX @form.repaint
          return ret if ret == :UNHANDLED
        end
        #@current_form.window.wrefresh # calling pad refresh XXX
            $log.debug " calling display form from handle_key OUTSIDE LOOP commented off"
        ##### XXX display_form(@current_form)
        ###### XXX@window.refresh
    end
    # this was used when we had sort of made this into a standalone popup
    # now since we want to embed inside a form, we have to use handle_key
    def handle_keys

            $log.debug " rtabbedpane: handle_keys to be deprecated "
      begin
      while (( ch=@window.getchar()) != 999)
        if ch == ?\C-q
          @selected_index = -1  # this signifies cancel by ?C-q
          @stop = true
          return
        end
        return if @stop
        @current_form ||= @form
        ret = @current_form.handle_key(ch)
        case ret
        when :NO_NEXT_FIELD
          if @current_form != @form
            @current_form = @form
            #@current_form.select_field -1
            @current_form.req_first_field
            #ret = @current_form.handle_key(ch)
          else
            if !@current_tab.nil?
            @current_form = @current_tab
            display_form @current_form
            @current_form.req_first_field
            #@current_form.select_field -1
            #ret = @current_form.handle_key(ch)
            end
          end
        when :NO_PREV_FIELD
          if @current_form != @form
            $log.debug " 1 no prev field - going to button "
            @current_form = @form
            @current_form.req_last_field
          else
            if !@current_tab.nil?
            @current_form = @current_tab
            display_form @current_form
            @current_form.req_last_field
            end
          end
        when :UNHANDLED
          $log.debug " unhandled in tabbed pane #{ch}"
          ret = @form.process_key ch, self # field
          @form.repaint
          #return :UNHANDLED if ret == :UNHANDLED
        end
        return if @stop
        ##### XXX @current_form.window.wrefresh
        @window.refresh
      end
      ensure
        destroy
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
      attr_accessor :form
      def initialize text, aconfig={}, &block
        @text = text
        @config = aconfig
        @config.each_pair { |k,v| variable_set(k,v) }
        instance_eval &block if block_given?
      end
      # private
      def variable_set var, val
        var = "@#{var}"
        instance_variable_set(var, val) 
      end
      def repaint
        

      end
    end

  end # class Tabbedpane


end # module
