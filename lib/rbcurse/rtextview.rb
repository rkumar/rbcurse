=begin
  * Name: TextView 
  * Description   View text in this widget.
  * Author: rkumar (arunachalesha)
  * file created 2009-01-08 15:23  
  * major change: 2010-02-10 19:43 simplifying the buffer stuff.
  * FIXME : since currently paint is directly doing copywin, there are no checks
    to prevent crashing or -1 when panning. We need to integrate it back to a call to Pad.
  * h_scroll printing off whle scrolling right.
  * unnecessary repainting when moving cursor, evn if no change in coords and data
  * on reentering cursor does not go to where it last was (test2.rb) - sure it used to.
TODO 
   * border, and footer could be objects (classes) at some future stage.
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
    #dsl_accessor :height  # height of viewport cmmented on 2010-01-09 19:29 since widget has method
    dsl_accessor :title   # set this on top
    dsl_accessor :title_attrib   # bold, reverse, normal
    dsl_accessor :footer_attrib   # bold, reverse, normal
    dsl_accessor :list    # the array of data to be sent by user
    dsl_accessor :maxlen    # max len to be displayed
    attr_reader :toprow    # the toprow in the view (offsets are 0)
#    attr_reader :prow     # the row on which cursor/focus is
    attr_reader :winrow   # the row in the viewport/window
    # painting the footer does slow down cursor painting slightly if one is moving cursor fast
    dsl_accessor :print_footer
    dsl_accessor :suppress_borders # added 2010-02-10 20:05 values true or false

    def initialize form, config={}, &block
      @focusable = true
      @editable = false
      @row = 0
      @col = 0
      @show_focus = false  # don't highlight row under focus
      @list = []
      super
      # ideally this should have been 2 to take care of borders, but that would break
      # too much stuff !
      @row_offset = @col_offset = 1 
      #@scrollatrow = @height-2
      @content_rows = @list.length
      @win = @graphic

      install_keys
      init_vars
    end
    def init_vars
      @curpos = @pcol = @toprow = @current_index = 0
      @repaint_all=true 
      ## 2010-02-10 20:20 RFED16 taking care if no border requested
      @suppress_borders ||= false
      @row_offset = @col_offset = 0 if @suppress_borders == true
      # added 2010-02-11 15:11 RFED16 so we don't need a form.
      @win_left = 0
      @win_top = 0
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
      @height - 3 # trying out 2009-10-31 15:22 XXX since we seem to be printing one more line
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
    ## returns the position where cursor was to be positioned by default
    # It may no longer work like that. 
    def rowcol
      return @row+@row_offset, @col+@col_offset
    end
    def wrap_text(txt, col = @maxlen)
      col ||= @width-2
      $log.debug "inside wrap text for :#{txt}"
      txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,
               "\\1\\3\n") 
    end
    ## print a border
    ## Note that print_border clears the area too, so should be used sparingly.
    def print_borders
      $log.debug " #{@name} print_borders,  #{@graphic.name} "
      color = $datacolor
      @graphic.print_border @row, @col, @height-1, @width, color #, Ncurses::A_REVERSE
      print_title
    end
    def print_title
      $log.debug " print_title #{@row}, #{@col}, #{@width}  "
      @graphic.printstring( @row, @col+(@width-@title.length)/2, @title, $datacolor, @title_attrib) unless @title.nil?
    end
    def print_foot
      @footer_attrib ||= Ncurses::A_REVERSE
      footer = "R: #{@current_index+1}, C: #{@curpos+@pcol}, #{@list.length} lines  "
      $log.debug " print_foot calling printstring with #{@row} + #{@height} -1, #{@col}+2"
      @graphic.printstring( @row + @height -1 , @col+2, footer, $datacolor, @footer_attrib) 
      @repaint_footer_required = false # 2010-01-23 22:55 
    end
    ### FOR scrollable ###
    def get_content
      @list
    end
    def get_window
      @graphic
    end
    ### FOR scrollable ###
    def repaint # textview
      if @screen_buffer.nil?
        safe_create_buffer
        @screen_buffer.name = "Pad::TV_PAD_#{@name}" unless @screen_buffer.nil?
        $log.debug " textview creates pad #{@screen_buffer} #{@name}"
      end

      return unless @repaint_required # 2010-02-12 19:08  TRYING
      paint if @repaint_required
      raise "TV 175 graphic nil " unless @graphic
      print_foot if @print_footer && @repaint_footer_required
      buffer_to_window
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
      when ?\C-n.getbyte(0)
        scroll_forward
      when ?\C-p.getbyte(0)
        scroll_backward
      when ?0.getbyte(0), ?\C-[.getbyte(0)
        goto_start #start of buffer # cursor_start
      when ?\C-].getbyte(0)
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
      when ?\C-a.getbyte(0)
        # take care of data that exceeds maxlen by scrolling and placing cursor at start
        set_form_col 0
        @pcol = 0
      when ?\C-e.getbyte(0)
        # take care of data that exceeds maxlen by scrolling and placing cursor at end
        blen = @buffer.rstrip.length
          set_form_col blen
=begin
        if blen < @maxlen
          set_form_col blen
        else
          @pcol = blen-@maxlen
          #wrong curpos wiill be reported
          set_form_col @maxlen-1
        end
=end
        # search related 
      when @KEY_ASK_FIND
        ask_search
      when @KEY_FIND_MORE
        find_more
      else
        #$log.debug("TEXTVIEW ch #{ch}")
        return :UNHANDLED
      end
      set_form_row
      return 0 # added 2010-01-12 22:17 else down arrow was going into next field
    end
    # newly added to check curpos when moving up or down
    def check_curpos
      @buffer = @list[@current_index]
      # if the cursor is ahead of data in this row then move it back
      if @pcol+@curpos > @buffer.length
        addcol((@pcol+@buffer.length-@curpos)+1)
        @curpos = @buffer.length 
        maxlen = (@maxlen || @width-2)

        # even this row is gt maxlen, i.e., scrolled right
        if @curpos > maxlen
          @pcol = @curpos - maxlen
          @curpos = maxlen-1 
        else
          # this row is within maxlen, make scroll 0
          @pcol=0
        end
        set_form_col 
      end
    end
    # set cursor on correct column tview
    def set_form_col col1=@curpos
      @cols_panned ||= 0
      @pad_offset ||= 0 # added 2010-02-11 21:54 since padded widgets get an offset.
      @curpos = col1
      maxlen = @maxlen || @width-2
      #@curpos = maxlen if @curpos > maxlen
      if @curpos > maxlen
        @pcol = @curpos - maxlen
        @curpos = maxlen - 1
      else
        @pcol = 0
      end
      ## changed on 2010-01-12 18:46 so carried upto topmost form
      #@form.col = @orig_col + @col_offset + @curpos
      #win_col=@form.window.left
      win_col = 0 # 2010-02-07 23:19 new cursor stuff
      #col = win_col + @orig_col + @col_offset + @curpos + @form.cols_panned
      ## 2010-01-13 18:19 trying col instead of orig, so that can work in splitpanes
      ##+ impact has to be seen elsewhere too !!! XXX
      col2 = win_col + @col + @col_offset + @curpos + @cols_panned + @pad_offset
      $log.debug "TV SFC #{@name} setting c to #{col2} #{win_col} #{@col} #{@col_offset} #{@curpos} "
      #@form.setrowcol @form.row, col
      setrowcol nil, col2
      # XXX 
      #@repaint_required = true
      @repaint_footer_required = true
    end
    def cursor_forward
      maxlen = @maxlen || @width-2
      if @curpos < @width and @curpos < maxlen-1 # else it will do out of box
        @curpos += 1
        addcol 1
      else
        @pcol += 1 if @pcol <= @buffer.length
      end
      set_form_col 
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41 
    end
    def addcol num
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41 
      if @form
        @form.addcol num
      else
        @parent_component.form.addcol num
      end
    end
    def addrowcol row,col
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41 
      if @form
      @form.addrowcol row, col
      else
        @parent_component.form.addrowcol num
      end
    end
    def cursor_backward
      if @curpos > 0
        @curpos -= 1
        set_form_col 
        #addcol -1
      elsif @pcol > 0 
        @pcol -= 1   
      end
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41 
    end
    # gives offset of next line, does not move
    def next_line
      @list[@current_index+1]
    end
    def do_relative_row num
      yield @list[@current_index+num] 
    end

    ## NOTE: earlier print_border was called only once in constructor, but when
    ##+ a window is resized, and destroyed, then this was never called again, so the 
    ##+ border would not be seen in splitpane unless the width coincided exactly with
    ##+ what is calculated in divider_location.
    def paint
      # not sure where to put this, once for all or repeat 2010-02-11 15:06 RFED16
      my_win = nil
      if @form
        my_win = @form.window
      else
        my_win = @target_window
      end
      @graphic = my_win unless @graphic
      #$log.warn "neither form not target window given!!! TV paint 368" unless my_win
      raise " #{@name} neither form, nor target window given TV paint " unless my_win
      raise " #{@name} NO GRAPHIC set as yet                 TV paint " unless @graphic
      @win_left = my_win.left
      @win_top = my_win.top

      print_borders if (@suppress_borders == false && @repaint_all) # do this once only, unless everything changes
      rc = row_count
      maxlen = @maxlen || @width-2
      $log.debug " #{@name} textview repaint width is #{@width}, height is #{@height} , maxlen #{maxlen}/ #{@maxlen}, #{@graphic.name} roff #{@row_offset} coff #{@col_offset}" 
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
            @graphic.printstring  r+hh, c, "%-*s" % [@width-2,content], acolor, @attr
            if @search_found_ix == tr+hh
              if !@find_offset.nil?
                # handle exceed bounds, and if scrolling
                if @find_offset1 < maxlen+@pcol and @find_offset > @pcol
                @graphic.mvchgat(y=r+hh, x=c+@find_offset-@pcol, @find_offset1-@find_offset, Ncurses::A_NORMAL, $reversecolor, nil)
                end
              end
            end

        else
          # clear rows
          @graphic.printstring r+hh, c, " " * (@width-2), acolor,@attr
        end
      end
      show_caret_func
      @table_changed = false
      @repaint_required = false
      @repaint_footer_required = true # 2010-01-23 22:41 
      @buffer_modified = true # required by form to call buffer_to_screen
      @repaint_all = false # added 2010-01-08 18:56 for redrawing everything

      # 2010-02-10 22:08 RFED16
    end
  end # class textview
end # modul
