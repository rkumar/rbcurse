require 'rbcurse/app'
#include Ncurses # FFI 2011-09-8 
include RubyCurses

# This paints a vertical white bar given row and col, and length. It also calculates and prints
# a small bar over this based on relaetd objects list.length and current_index.
# Typically, after setup one would keep updating only current_index from the repaint method
# of caller or in the traversal event. This would look best if the listbox also has a reverse video border, or none.
# @example
#     lb = list_box ....
#     sb = Scrollbar.new @form, :row => lb.row, :col => lb.col, :length => lb.height, :list_length => lb.row_count, :current_index => 0
#      .... later as user traverses
#      sb.current_index = lb.current_index
#     sb = Scrollbar.new @form, :parent => list
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
    # initialize based on parent's values
    dsl_property :parent
    # which row is focussed, current_index of listbox, required.
    dsl_property :current_index
    # how many total rows of data does the list have, same as @list.length, required.
    dsl_property :list_length

    # TODO: if parent passed, we shold bind to ON_ENTER and get current_index, so no extra work is required.

    def initialize form, config={}, &block

      # setting default first or else Widget will place its BW default
      #@color, @bgcolor = ColorMap.get_colors_for_pair $bottomcolor
      super
      @color_pair = get_color $datacolor, @color, @bgcolor
      @scroll_pair = get_color $bottomcolor, :green, :white
      @window = form.window
      @editable = false
      @focusable = false
      @repaint_required = true
      @orientation = :V
      if @parent
        @parent.bind :ENTER_ROW do |p|
          # parent must implement row_count, and have a @current_index
          raise StandardError, "Parent must implement row_count" unless p.respond_to? :row_count
          self.current_index = p.current_index
          @repaint_required = true  #requred otherwise at end when same value sent, prop handler
          # will not be fired (due to optimization).
        end
      end
    end

    ##
    # repaint the scrollbar
    # Taking the data from parent as late as possible in case parent resized, or 
    # moved around by a container.
    def repaint
      if @parent
        @row = @parent.row+1
        @col = @parent.col + @parent.width - 1
        @length = @parent.height - 2
        @list_length = @parent.row_count 
        @current_index ||= @parent.current_index
        @border_attrib ||= @parent.border_attrib
      end
      raise ArgumentError, "current_index must be provided" unless @current_index
      raise ArgumentError, "list_length must be provided" unless @list_length
      my_win = @form ? @form.window : @target_window
      @graphic = my_win unless @graphic
      return unless @repaint_required

      # first print a right side vertical line
      #bc = $bottomcolor  # dark blue
      bc = $datacolor
      bordercolor = @border_color || bc
      borderatt = @border_attrib || Ncurses::A_REVERSE


      @graphic.attron(Ncurses.COLOR_PAIR(bordercolor) | borderatt)
      $log.debug " XXX SCROLL #{@row} #{@col} #{@length} "
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
      if @current_index == @list_length - 1
        scloc = @length - sclen + 1
      end
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
if __FILE__ == $PROGRAM_NAME
  App.new do
    r = 5
    len = 20
    list = []
    0.upto(100) { |v| list << "#{v} scrollable data" }
    lb = list_box "A list", :list => list
    #sb = Scrollbar.new @form, :row => r, :col => 20, :length => len, :list_length => 50, :current_index => 0
    rb = Scrollbar.new @form, :parent => lb
    #hline :width => 20, :row => len+r
    #keypress do |ch|
      #case ch
      #when :down
        #sb.current_index += 1
      #when :up
        #sb.current_index -= 1
      #end
    #end
  end
end
