=begin
  * Name: tabbed pane: can have multiple forms overlapping.
  * Description: 
  * Author: rkumar
  
  --------
  * Date:  2008-12-13 13:06 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'rubygems'
require 'ncurses'
require 'logger'
require 'lib/ver/ncurses'
require 'lib/ver/window'
require 'lib/rbcurse/rwidget'

include Ncurses
include RubyCurses
module RubyCurses
  extend self

  # TODO :  insert_tab, remove_tab, disable/hide tab
  # Hotkeys should be defined with ampersand, too.
  #
  # Multiple independent overlapping forms using the tabbed metaphor.
  class TabbedButton < RubyCurses::RadioButton
    def getvalue_for_paint
      @text
    end
    ## 
    # highlight abd selected colors and attribs should perhaps be in a
    # structure, so user can override easily
    def repaint  # tabbedbutton
#       $log.debug("BUTTon repaint : #{self.class()}  r:#{@row} c:#{@col} #{getvalue_for_paint}" )
        r,c = rowcol
        attribs = @attrs
        @highlight_foreground ||= $reversecolor
        @highlight_background ||= 0
        _state = @state
        _state = :SELECTED if @text_variable.value == @value 
        case _state
        when :HIGHLIGHTED
          bgcolor = @highlight_background
          color = @highlight_foreground
          bgcolor =  @bgcolor
          color =  @color
          attribs = Ncurses::A_BOLD
        when :SELECTED
          bgcolor =  @bgcolor
          color =  @color
          attribs = Ncurses::A_REVERSE
        else
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
        @form.window.printstring r, c, "%-*s" % [len, value], color, attribs
#       @form.window.mvchgat(y=r, x=c, max=len, Ncurses::A_NORMAL, bgcolor, nil)
        if @underline != nil
          # changed +1 to +0 on 2008-12-15 21:23 pls check.
          @form.window.mvchgat(y=r, x=c+@underline+0, max=1, Ncurses::A_BOLD|Ncurses::A_UNDERLINE, color, nil)
        end
    end
  end
  class TabbedPane
    include DSL
    include EventHandler
    dsl_accessor :row, :col
    dsl_accessor :height, :width
    def initialize win, aconfig={}, &block
      @parent = win
      @tabs ||= []
      @forms ||= []
      @bgcolor ||=  "black" # 0
      @color ||= "white" # $datacolor
      @attr = nil
      @current_form = nil
      @current_tab = nil
      @config = aconfig
      @config.each_pair { |k,v| variable_set(k,v) }
      instance_eval &block if block_given?
    end
    ##
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
    end
    def show
      repaint
    end
    def create_window
      # first create the main top window with the tab buttons on it.
      @layout = { :height => @height, :width => @width, :top => @row, :left => @col } 
      @window = VER::Window.new(@layout)
      @form = RubyCurses::Form.new @window
      @form.navigation_policy = :NON_CYCLICAL
      @current_form = @form
      @window.bkgd(Ncurses.COLOR_PAIR($datacolor));
      @window.box( 0, 0);
      @window.wrefresh
      Ncurses::Panel.update_panels
      col = 1
      @buttons = []
      ## create a button for each tab
      $tabradio = Variable.new
      @tabs.each do |tab|
        text = tab.text
        @buttons << RubyCurses::TabbedButton.new(@form) do
          text_variable $tabradio
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
        form.window = @window if form.window.nil? ## XXX
        panel = form.window.panel
        @buttons.last.command { Ncurses::Panel.top_panel(panel) 
          Ncurses::Panel.update_panels();
          Ncurses.doupdate();
          form.repaint
          @current_form = form
          @current_tab = form
        }
 
      end
      @form.repaint
    end
    def display_form form
      panel = form.window.panel
      Ncurses::Panel.top_panel(panel) 
      Ncurses::Panel.update_panels();
      Ncurses.doupdate();
      form.repaint
    end
    def create_tab_form tab
      layout = { :height => @height-2, :width => @width, :top => @row+2, :left => @col } 
      window = VER::Window.new(layout)
      form = RubyCurses::Form.new window
      form.navigation_policy = :NON_CYCLICAL
      window.bkgd(Ncurses.COLOR_PAIR($datacolor));
      window.box( 0, 0);
      window.mvprintw(1,1, tab.text.tr('&', ''))
      ##window.wrefresh
      ##Ncurses::Panel.update_panels
      return form
    end
    def handle_keys
      while (( ch=@window.getchar()) != KEY_F1)
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
          ret = @form.process_key ch, field
          @form.repaint
          #return :UNHANDLED if ret == :UNHANDLED
        end
        @current_form.window.wrefresh
        @window.refresh
      end
      destroy
    end
    def destroy
      @window.destroy
      @forms.each { |f| w = f.window; w.destroy unless w.nil? }
    end

    ##
    # nested class tab
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
