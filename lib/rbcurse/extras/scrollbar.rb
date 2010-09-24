require 'rbcurse/app'
include Ncurses
include RubyCurses

# This paints a vertical white bar given row and col, and length. It also calculates and prints
# a small bar over this based on relaetd objects list.length and current_index.
# Typically, after setup one would keep updating only current_index from the repaint method
# of caller or in the traversal event. This would look best if the listbox also has a reverse video border, or none.
# @example
#     lb = list_box ....
#     sb = Scrollbar.new @form, :row => lb.row, :col => lb.col, :length => lb.height, :list_length => lb.list.length, :current_index => 0
#      .... later as user traverses
#      sb.current_index = lb.current_index
#
# At a later stage, we will integrate this with lists and tables, so it will happen automatically.
#
# @since 1.2.0    UNTESTED
module RubyCurses
  class Scrollbar < Widget
    # row to start, same as listbox, required.
    dsl_property :row
    # column to start, same as listbox, required.
    dsl_property :col
    # how many rows is this (should be same as listboxes height, required.
    dsl_property :length
    # vertical or horizontal currently only VERTICAL
    dsl_property :orientation
    # to take changes or data, unused as of now
    dsl_property :parent
    # which row is focussed, current_index of listbox, required.
    dsl_property :current_index
    # how many total rows of data does the list have, same as @list.length, required.
    dsl_property :list_length


    def initialize form, config={}, &block

      # setting default first or else Widget will place its BW default
      #@color, @bgcolor = ColorMap.get_colors_for_pair $bottomcolor
      super
      @color_pair = get_color $datacolor, @color, @bgcolor
      @scroll_pair = get_color $bottomcolor, :green, :white
      @window = form.window
      @editable = false
      @focusable = false
      @row ||= 0
      @col ||= 0
      @repaint_required = true
      @orientation = :V
    end

    ##
    # XXX need to move wrapping etc up and done once. 
    def repaint
      raise ArgumentError, "current_index must be provided" unless @current_index
      raise ArgumentError, "list_length must be provided" unless @list_length
      my_win = @form ? @form.window : @target_window
      @graphic = my_win unless @graphic
      return unless @repaint_required

      # first print a right side vertical line
      bordercolor = @border_color || $datacolor
      borderatt = @border_attrib || Ncurses::A_REVERSE


      @graphic.attron(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
      @graphic.mvvline(@row+0, @col, 1, @length-0)
      @graphic.attroff(Ncurses.COLOR_PAIR(bordercolor) | borderatt)

      # now calculate and paint the scrollbar
      pht = @length
      listlen = @list_length * 1.0
      @current_index = 0 if @current_index < 0
      @current_index = listlen-1 if @current_index >= listlen
      sclen = (pht/listlen)* @length
      scloc = (@current_index/listlen)* @length
      scloc = (@length - sclen) if scloc > @length - sclen # don't exceed end
      @graphic.attron(Ncurses.COLOR_PAIR(@scroll_pair) | borderatt)
      r = @row + scloc
      c = @col + 0
      @graphic.mvvline(r, c, 1, sclen)
      @graphic.attroff(Ncurses.COLOR_PAIR(@scroll_pair) | borderatt)
      @repaint_required = false
    end
    ##
    ##
    # ADD HERE 
  end
end
App.new do
  r = 5
  len = 20
  hline :width => 20, :row => r, :attrib => Ncurses::A_REVERSE
  sb = Scrollbar.new @form, :row => r, :col => 20, :length => len, :list_length => 50, :current_index => 0
  hline :width => 20, :row => len+r
  keypress do |ch|
    case ch
    when :down
      sb.current_index += 1
    when :up
      sb.current_index -= 1
    end
  end
end
