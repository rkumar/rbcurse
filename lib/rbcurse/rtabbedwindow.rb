=begin
  * Name: tabbed pane: can have multiple forms overlapping.
  * Description:  This embeds a tabbedpane inside a window - a retake on tabbedwindow
  * Author: rkumar

  * Consists of a main window and form that contains the TabbedPane and several buttons
    below. 
    The tabbedpane itself contains a Form for the buttons, and then one form and Pad
    each for the tab. Check TabbedPane for details since it can change.

  --------
  * Date: 2011-10-17 3:38 PM 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'logger'
require 'rbcurse'
require 'rbcurse/rtabbedpane'

include RubyCurses
module RubyCurses
  extend self

  # TODO :  insert_tab, remove_tab, disable/hide tab
  # Hotkeys should be defined with ampersand, too.
  #
  class TabbedWindow
    include EventHandler
    dsl_accessor :row, :col
    dsl_accessor :height, :width
    dsl_accessor :button_type      # ok, ok_cancel, yes_no
    dsl_accessor :buttons           # used if type :custom
    attr_reader :selected_index
    def initialize win, aconfig={}, &block
      @parent = win
      @bgcolor ||=  "black" # 0
      @color ||= "white" # $datacolor
      @attr = nil

      @config = aconfig
      @config.each_pair { |k,v| variable_set(k,v) }
      instance_eval &block if block_given?
      @tp = nil
    end
    def tabbed_pane
      return @tp if @tp
      @layout = { :height => @height, :width => @width, :top => @row, :left => @col } 
      #@layout = { :height => 0, :width => 0, :top => 0, :left => 0 } 
      @window = VER::Window.new(@layout)
      @form = RubyCurses::Form.new @window
      @form.name = "TWindow"
      @form.navigation_policy = :CYCLICAL
      h = @layout[:height] == 0 ? FFI::NCurses.LINES-2 : @layout[:height]-2
      w = @layout[:width] == 0 ? FFI::NCurses.COLS : @layout[:width]-0
      h -= 0
      w -= 0
      r = 0 # @row-0
      c =0 # @col
      @tp = RubyCurses::TabbedPane.new @form, :height => h, :width =>w, :row => r, :col => c
      return @tp
    end
    #
    # I am honestly not sure what block anyone is gonna pass to Tab
    #  I confess i may have been even more ignorant than I am today. We
    #  could use the block here, pass form here, if component not given especially
    def add_tab text, component = nil, aconfig={}, &block
      @tp ||= tabbed_pane
      t = @tp.add_tab text, component, aconfig #, &block  # NOTE, not passing block there
      if block_given?
        yield @tp.form(t) 
      end
      return t
    end
    alias :tab :add_tab
    alias :new_tab :add_tab
    ##
    def repaint
    end
    def show
      # first create the main top window with the tab buttons on it.
      @window.bkgd(Ncurses.COLOR_PAIR($datacolor));
      @window.box( 0, 0);
      @window.wrefresh
      Ncurses::Panel.update_panels
      create_buttons
      @form.repaint
      #handle_keys
      # need to convey button pressed
    end
    def handle_keys
      begin
        while (( ch=@window.getchar()) != 999)
          break if ch == ?\C-q.getbyte(0) || @stop
          ret = @form.handle_key(ch)
          if ret == :UNHANDLED
            ret = @form.process_key ch, self # field
            @form.repaint
          end
          @window.wrefresh
          break if @stop  # 2011-10-21 somehow not coming out
        end
        return if @stop
      ensure
        destroy
      end
    end
    def destroy
      @window.destroy
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
      $log.debug "XXX: came to TW make buttons FORM= #{@form.name} "
      total = names.inject(0) {|total, item| total + item.length + 4}
      bcol = center_column total

      # this craps out when height is zero
      brow = @layout[:height]-2
      brow = FFI::NCurses.LINES-2 if brow < 0
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
      width = @layout[:width].ifzero( FFI::NCurses.COLS )
      return (width-textlen)/2
    end


  end # class TabbedWindow


end # module
