=begin
  * Name: ScrollForm - a form that can take more than the screen and focus only on what's visible
  *  This class originated in TabbedPane for the top button form which only scrolls
  *  horizontally and uses objects that have a ht of 1. Here we have to deal with
  * large objects and vertical scrolling.
  * Description: 
  * Author: rkumar
  
  --------
  * Date: 2010-03-16 11:32 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)


NOTE: 
    There are going to be tricky cases we have to deal with such as objects that start in the viewable
area but finish outside, or vice versa.
=end
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'

include Ncurses
include RubyCurses
module RubyCurses
  extend self
  class ScrollForm < RubyCurses::Form
    attr_accessor :pmincol # advance / scroll columns
    attr_accessor :pminrow # advance / scroll rows (vertically)
    attr_accessor :display_w # width of screen display
    attr_accessor :display_h # ht of screen display
    attr_accessor :scroll_unit
    attr_reader :orig_top, :orig_left
    attr_reader :window
    attr_accessor :name
    attr_reader :cols_panned, :rows_panned
    def initialize win, &block
      @target_window = win
      super
      @pminrow = @pmincol = 0
      @scroll_unit = 3
      @cols_panned = @rows_panned = 0
    end
    def set_layout(h, w, t, l)
      @pad_h = h
      @pad_w = w
      @top = @orig_top = t
      @left = @orig_left = l
    end
    def create_pad
      r = @top
      c = @left
      layout = { :height => @pad_h, :width => @pad_w, :top => r, :left => c } 
      @window = VER::Pad.create_with_layout(layout)
  
      @window.name = "Pad::ScrollPad" # 2010-02-02 20:01 
      @name = "Form::ScrollForm"
      return @window
    end
    ## ScrollForm handle key, scrolling
    def handle_key ch
      $log.debug " inside ScrollForm handlekey #{ch} "
      # do the scrolling thing here top left prow and pcol of pad to be done
      # # XXX TODO check whether we can scroll before incrementing esp cols_panned etc
      case ch
      when ?\M-l.getbyte(0)
        return false if !validate_scroll_col(@pmincol + @scroll_unit)
        @pmincol += @scroll_unit # some check is required or we'll crash
        @cols_panned -= @scroll_unit
        $log.debug " handled ch M-l in ScrollForm"
        @window.modified = true
        return 0
      when ?\M-h.getbyte(0)
        return false if !validate_scroll_col(@pmincol - @scroll_unit)
        @pmincol -= @scroll_unit # some check is required or we'll crash
        @cols_panned += @scroll_unit
        $log.debug " handled ch M-h in ScrollForm"
        @window.modified = true
        return 0
      when ?\M-n.getbyte(0)
        return false if !validate_scroll_row(@pminrow + @scroll_unit)
        @pminrow += @scroll_unit # some check is required or we'll crash
        @rows_panned -= @scroll_unit
        @window.modified = true
        $log.debug " M-n #{pminrow}  #{rows_panned} "
        #repaint
        return 0
      when ?\M-p.getbyte(0)
        return false if !validate_scroll_row(@pminrow - @scroll_unit)
        @pminrow -= @scroll_unit # some check is required or we'll crash
        @rows_panned += @scroll_unit
        @window.modified = true
        #repaint
        return 0
      end

      super
    end
    # maybe we should rename targetwindow to window
    #  and window to pad
    #  super may need target window
    def repaint
      $log.debug " scrollForm repaint calling parent #{@row} #{@col} "
      super
      prefresh
      @target_window.wmove @row+@rows_panned, @col+@cols_panned
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
      $log.debug "   ret = @window.prefresh( #{@pminrow} , #{@pmincol} , #{@top} , #{@left} , #{@top} + #{@display_h}, #{@left} + #{@display_w} ) "
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
    # this is typically called by putchar or putc in editable components like field.
    def setrowcol r, c
      $log.debug " SCROLL setrowcol #{r},  #{c} "
      # aha ! here's where i can check whether the cursor is falling off the viewable area
      cc = nil
      rr = nil
      if c
        cc = c + @cols_panned
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
      end
      if r
        rr = r+@rows_panned
      end
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

  # the return of the prodigals
  # The Expanding Heart
  # The coming together of all those who were


end # module
