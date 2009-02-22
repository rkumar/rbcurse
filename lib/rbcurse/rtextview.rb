=begin
  * Name: TextView 
  * $Id$
  * Description   View text in this widget.
  * Author: rkumar (arunachalesha)
TODO 
  * file created 2009-01-08 15:23  
  --------
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/listscrollable'

include Ncurses
include RubyCurses
module RubyCurses
  extend self

  ##
  # A viewable read only box. Can scroll. 
  # Intention is to be able to change content dynamically - the entire list.
  # Use set_content to set content, or just update the list attrib
  # TODO - 
  #      - searching, goto line - DONE
  class TextView < Widget
    include ListScrollable
    dsl_accessor :height  # height of viewport
    dsl_accessor :title   # set this on top
    dsl_accessor :title_attrib   # bold, reverse, normal
    dsl_accessor :footer_attrib   # bold, reverse, normal
    dsl_accessor :list    # the array of data to be sent by user
    dsl_accessor :maxlen    # max len to be displayed
    attr_reader :toprow    # the toprow in the view (offsets are 0)
#    attr_reader :prow     # the row on which cursor/focus is
    attr_reader :winrow   # the row in the viewport/window
    dsl_accessor :print_footer

    def initialize form, config={}, &block
      @focusable = true
      @editable = false
      @left_margin = 1
      @row = 0
      @col = 0
      @show_focus = false  # don't highlight row under focus
      @list = []
      super
      @row_offset = @col_offset = 1
      @orig_col = @col
      # this does result in a blank line if we insert after creating. That's required at 
      # present if we wish to only insert
      @scrollatrow = @height-2
      @content_rows = @list.length
      @win = @form.window
      #init_scrollable
      print_borders
      @maxlen ||= @width-2
      install_keys
      init_vars
    end
    def init_vars
      @curpos = @pcol = @toprow = @current_index = 0
    end
    ## 
    # send in a list
    # e.g.         set_content File.open("README.txt","r").readlines
    # set wrap at time of passing :WRAP_NONE :WRAP_WORD
    def set_content list, wrap = :WRAP_NONE
      @wrap_policy = wrap
      if list.is_a? String
        if @wrap_policy == :WRAP_WORD
          data = wrap_text list
          @list = data.split("\n")
        else
          @list = list.split("\n")
        end
      elsif list.is_a? Array
        if @wrap_policy == :WRAP_WORD
          data = wrap_text list.join(" ")
          @list = data.split("\n")
        else
          @list = list
        end
      else
        raise "set_content expects Array not #{list.class}"
      end
    end
    ## display this row on top
    def top_row(*val)
      if val.empty?
        @toprow
      else
        @toprow = val[0] || 0
        #@prow = val[0] || 0
      end
      @repaint_required = true
    end
    ## ---- for listscrollable ---- ##
    def scrollatrow
      @height - 2
    end
    def row_count
      @list.length
    end
    ##
    # returns row of first match of given regex (or nil if not found)
    def find_first_match regex
      @list.each_with_index do |row, ix|
        return ix if !row.match(regex).nil?
      end
      return nil
    end
    def rowcol
      #$log.debug "textarea rowcol : #{@row+@row_offset+@winrow}, #{@col+@col_offset}"
      #return @row+@row_offset+@winrow, @col+@col_offset
      #return @row+@row_offset+@winrow, @col+@col_offset
      return @row+@row_offset, @col+@col_offset
    end
    def wrap_text(txt, col = @maxlen)
      $log.debug "inside wrap text for :#{txt}"
      txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,
               "\\1\\3\n") 
    end
    def print_borders
      window = @form.window
      color = $datacolor
      window.print_border @row, @col, @height, @width, color
      print_title
=begin
      hline = "+%s+" % [ "-"*(width-((1)*2)) ]
      hline2 = "|%s|" % [ " "*(width-((1)*2)) ]
      window.printstring(row=startrow, col=startcol, hline, color)
      print_title
      (startrow+1).upto(startrow+height-1) do |row|
        window.printstring( row, col=startcol, hline2, color)
      end
      window.printstring( startrow+height, col=startcol, hline, color)
=end
  
    end
    def print_title
      @form.window.printstring( @row, @col+(@width-@title.length)/2, @title, $datacolor, @title_attrib) unless @title.nil?
    end
    def print_foot
      @footer_attrib ||= Ncurses::A_REVERSE
      footer = "R: #{@current_index+1}, C: #{@curpos+@pcol}, #{@list.length} lines  "
      @form.window.printstring( @row + @height, @col+2, footer, $datacolor, @footer_attrib) 
    end
    ### FOR scrollable ###
    def get_content
      @list
    end
    def get_window
      @form.window
    end
    ### FOR scrollable ###
    def repaint # textview
      return unless @repaint_required
      paint
      print_foot if @print_footer
    end
    def getvalue
      @list
    end
    # textview
    # [ ] scroll left right DONE
    def handle_key ch
      @buffer = @list[@current_index]
      if @buffer.nil? and row_count == 0
        @list << "\r"
        @buffer = @list[@current_index]
      end
      return if @buffer.nil?
      #$log.debug " before: curpos #{@curpos} blen: #{@buffer.length}"
      if @curpos > @buffer.length
        addcol((@buffer.length-@curpos)+1)
        @curpos = @buffer.length
        set_form_col 
      end
      #$log.debug "TV after loop : curpos #{@curpos} blen: #{@buffer.length}"
      #pre_key
      case ch
      when ?\C-n
        scroll_forward
      when ?\C-p
        scroll_backward
      when ?0, ?\C-[
        goto_start #start of buffer # cursor_start
      when ?\C-]
        goto_end # end / bottom cursor_end
      when KEY_UP
        #select_prev_row
        ret = up
        check_curpos
        #addrowcol -1,0 if ret != -1 or @winrow != @oldwinrow                 # positions the cursor up 
        #@form.row = @row + 1 + @winrow
      when KEY_DOWN
        ret = down
        check_curpos
        #@form.row = @row + 1 + @winrow
      when KEY_LEFT
        cursor_backward
      when KEY_RIGHT
        cursor_forward
      when KEY_BACKSPACE, 127
        cursor_backward
      when 330
        cursor_backward
      when ?\C-a
        # take care of data that exceeds maxlen by scrolling and placing cursor at start
        set_form_col 0
        @pcol = 0
      when ?\C-e
        # take care of data that exceeds maxlen by scrolling and placing cursor at end
        blen = @buffer.rstrip.length
        if blen < @maxlen
          set_form_col blen
        else
          @pcol = blen-@maxlen
          #wrong curpos wiill be reported
          set_form_col @maxlen-1
        end
        # search related added on 2009-02-15 21:36 
      when @KEY_ASK_FIND
        ask_search
      when @KEY_FIND_MORE
        find_more
      else
        #$log.debug("TEXTVIEW XXX ch #{ch}")
        return :UNHANDLED
      end
      #post_key
      # XXX 2008-11-27 13:57 trying out
      set_form_row
    end
    # newly added to check curpos when moving up or down
    def check_curpos
      @buffer = @list[@current_index]
      # if the cursor is ahead of data in this row then move it back
      if @pcol+@curpos > @buffer.length
        addcol((@pcol+@buffer.length-@curpos)+1)
        @curpos = @buffer.length 

        # even this row is gt maxlen, i.e., scrolled right
        if @curpos > @maxlen
          @pcol = @curpos - @maxlen
          @curpos = @maxlen-1 
        else
          # this row is within maxlen, make scroll 0
          @pcol=0
        end
        set_form_col 
      end
    end
    # set cursor on correct column tview
    def set_form_col col=@curpos
      @curpos = col
      @curpos = @maxlen if @curpos > @maxlen
      @form.col = @orig_col + @col_offset + @curpos
      @repaint_required = true
    end
    def cursor_forward
      if @curpos < @width and @curpos < @maxlen-1 # else it will do out of box
        @curpos += 1
        addcol 1
      else
        # XXX 2008-11-26 23:03 trying out
        @pcol += 1 if @pcol <= @buffer.length
      end
      set_form_col 
      @repaint_required = true
    end
    def addcol num
      @repaint_required = true
      @form.addcol num
    end
    def addrowcol row,col
      @repaint_required = true
      @form.addrowcol row, col
    end
    def cursor_backward
      if @curpos > 0
        @curpos -= 1
        set_form_col 
        #addcol -1
      elsif @pcol > 0 # XXX added 2008-11-26 23:05 
        @pcol -= 1   
      end
      @repaint_required = true
    end
    # gives offset of next line, does not move
    def next_line
      @list[@current_index+1]
    end
    def do_relative_row num
      yield @list[@current_index+num] 
    end
    def paint
      print_borders if @to_print_borders == 1 # do this once only, unless everything changes
      rc = row_count
      maxlen = @maxlen ||= @width-2
      tm = get_content
      tr = @toprow
      acolor = get_color $datacolor
      h = scrollatrow()
      r,c = rowcol
      0.upto(h) do |hh|
        crow = tr+hh
        if crow < rc
            #focussed = @current_index == crow ? true : false 
            #selected = is_row_selected crow
            content = tm[crow].chomp
            content.gsub!(/\t/, '  ') # don't display tab
            content.gsub!(/[^[:print:]]/, '')  # don't display non print characters
            if !content.nil? 
              if content.length > maxlen # only show maxlen
                content = content[@pcol..@pcol+maxlen-1] 
              else
                content = content[@pcol..-1]
              end
            end
            #renderer = get_default_cell_renderer_for_class content.class.to_s
            #renderer = cell_renderer()
            #renderer.repaint @form.window, r+hh, c+(colix*11), content, focussed, selected
            #renderer.repaint @form.window, r+hh, c, content, focussed, selected
            @form.window.printstring  r+hh, c, "%-*s" % [@width-2,content], acolor, @attr
            if @search_found_ix == tr+hh
              if !@find_offset.nil?
                # handle exceed bounds, and if scrolling
                if @find_offset1 < maxlen+@pcol and @find_offset > @pcol
                @form.window.mvchgat(y=r+hh, x=c+@find_offset-@pcol, @find_offset1-@find_offset, Ncurses::A_NORMAL, $reversecolor, nil)
                end
              end
            end

        else
          # clear rows
          @form.window.printstring r+hh, c, " " * (@width-2), acolor,@attr
        end
      end
      @table_changed = false
      @repaint_required = false
    end
  end # class textview
end # modul
