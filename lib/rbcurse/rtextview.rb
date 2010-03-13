=begin
  * Name: TextView 
  * Description   View text in this widget.
  * Author: rkumar (arunachalesha)
  * file created 2009-01-08 15:23  
  * major change: 2010-02-10 19:43 simplifying the buffer stuff.
  * FIXME : since currently paint is directly doing copywin, there are no checks
    to prevent crashing or -1 when panning. We need to integrate it back to a call to Pad.
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
  #      - goto line - DONE
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

    def initialize form = nil, config={}, &block
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
      $error_message_row ||= 23
      $error_message_col ||= 1
      # currently i scroll right only if  current line is longer than display width, i should use 
      # longest line on screen.
      @longest_line = 0 # the longest line printed on this page, used to determine if scrolling shd work

      bind_key([?g,?g]){ goto_start } # mapping double keys like vim
      bind_key([?',?']){ goto_last_position } # vim , goto last row position (not column)
      bind_key(?/, :ask_search)
      bind_key(?n, :find_more)
      bind_key([?\C-x, ?>], :scroll_right)
      bind_key([?\C-x, ?<], :scroll_left)
      bind_key(?r) { getstr("Enter a word") }
      bind_key(?m, :disp_menu)
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

      #return unless @repaint_required # 2010-02-12 19:08  TRYING - won't let footer print for col move
      paint if @repaint_required
    #  raise "TV 175 graphic nil " unless @graphic
      print_foot if @print_footer && @repaint_footer_required
      buffer_to_window
    end
    def getvalue
      @list
    end
    # textview
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
      # We can improve later
      case ch
      when ?\C-n.getbyte(0), 32
        scroll_forward
      when ?\C-p.getbyte(0)
        scroll_backward
      when ?\C-[.getbyte(0), ?t.getbyte(0)
        goto_start #start of buffer # cursor_start
      when ?\C-].getbyte(0), ?G.getbyte(0)
        goto_end # end / bottom cursor_end
      when KEY_UP, ?k.getbyte(0)
        #select_prev_row
        ret = up
        check_curpos
        
      when KEY_DOWN, ?j.getbyte(0)
        ret = down
        check_curpos
      when KEY_LEFT, ?h.getbyte(0)
        cursor_backward
      when KEY_RIGHT, ?l.getbyte(0)
        cursor_forward
      when KEY_BACKSPACE, 127, 330
        cursor_backward
      when ?\C-a.getbyte(0) #, ?0.getbyte(0)
        # take care of data that exceeds maxlen by scrolling and placing cursor at start
        @repaint_required = true if @pcol > 0 # tried other things but did not work
        set_form_col 0
        @pcol = 0
      when ?\C-e.getbyte(0), ?$.getbyte(0)
        # take care of data that exceeds maxlen by scrolling and placing cursor at end
        # This use to actually pan the screen to actual end of line, but now somewhere
        # it only goes to end of visible screen, set_form probably does a sanity check
        blen = @buffer.rstrip.length
        set_form_col blen
        # search related 
      when @KEY_ASK_FIND
        ask_search
      when @KEY_FIND_MORE
        find_more
      when ?0.getbyte(0)..?9.getbyte(0)
        # FIXME the assumption here was that if numbers are being entered then a 0 is a number
        # not a beg-of-line command.
        # However, after introducing universal_argument, we can enters numbers using C-u and then press another
        # C-u to stop. In that case a 0 should act as a command, even though multiplier has been set
        if ch == ?0.getbyte(0) and $multiplier == 0
          # copy of C-a - start of line
          @repaint_required = true if @pcol > 0 # tried other things but did not work
          set_form_col 0
          @pcol = 0
          return 0
        end
        # storing digits entered so we can multiply motion actions
        $multiplier *= 10 ; $multiplier += (ch-48)
        return 0
      #when ?\C-u.getbyte(0)
        ## multiplier. Series is 4 16 64
        #@multiplier = (@multiplier == 0 ? 4 : @multiplier *= 4)
        #return 0
      when ?\M-l.getbyte(0) # just added 2010-03-05 not perfect
        scroll_right # scroll data horizontally 
      when ?\M-h.getbyte(0)
        scroll_left
      when ?\C-c.getbyte(0)
        $multiplier = 0
        return 0
      else
        # check for bindings, these cannot override above keys since placed at end
        begin
          ret = process_key ch, self
        rescue => err
          $error_message = err
          @form.window.print_error_message
          $log.error " TEXTVIEW ERROR #{err} "
          $log.debug(err.backtrace.join("\n"))
        end
        return :UNHANDLED if ret == :UNHANDLED
      end
      $multiplier = 0 # you must reset if you've handled a key. if unhandled, don't reset since parent could use
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
        @repaint_required = true # this is required so C-e can pan screen
      else
        @pcol = 0
      end
      # the rest only determines cursor placement
      win_col = 0 # 2010-02-07 23:19 new cursor stuff
      col2 = win_col + @col + @col_offset + @curpos + @cols_panned + @pad_offset
      $log.debug "TV SFC #{@name} setting c to #{col2} #{win_col} #{@col} #{@col_offset} #{@curpos} "
      #@form.setrowcol @form.row, col
      setrowcol nil, col2
      @repaint_footer_required = true
    end
    def cursor_forward
      maxlen = @maxlen || @width-2
      repeatm { 
      if @curpos < @width and @curpos < maxlen-1 # else it will do out of box
        @curpos += 1
        addcol 1
      else
        @pcol += 1 if @pcol <= @buffer.length
      end
      }
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
      repeatm { 
      if @curpos > 0
        @curpos -= 1
        set_form_col 
        #addcol -1
      elsif @pcol > 0 
        @pcol -= 1   
      end
      }
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
      #raise " #{@name} neither form, nor target window given TV paint " unless my_win
      #raise " #{@name} NO GRAPHIC set as yet                 TV paint " unless @graphic
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
      @longest_line = @width #maxlen
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
                @longest_line = content.length if content.length > @longest_line
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
    ## this is just a test of prompting user for a string
    #+ as an alternative to the dialog.
    def getstr prompt, maxlen=10
      tabc = Proc.new {|str| Dir.glob(str +"*") }
      config={}; config[:tab_completion] = tabc
      config[:default] = "defaulT"
      $log.debug " inside getstr before call "
      ret, str = rbgetstr(@form.window, @row+@height-1, @col+1, prompt, maxlen, config)
      $log.debug " rbgetstr returned #{ret} , #{str} "
      return "" if ret != 0
      return str
    end
    # this is just a test of the simple "most" menu
    def disp_menu
      menu = PromptMenu.new self 
      menu.add( menu.create_mitem( 's', "Goto start ", "Going to start", Proc.new { goto_start} ))
      menu.add(menu.create_mitem( 'r', "scroll right", "I have scrolled ", :scroll_right ))
      menu.add(menu.create_mitem( 'l', "scroll left", "I have scrolled ", :scroll_left ))
      item = menu.create_mitem( 'm', "submenu", "submenu options" )
      menu1 = PromptMenu.new( self, "Submenu Options")
      menu1.add(menu1.create_mitem( 's', "CASE sensitive", "Ignoring Case in search" ))
      menu1.add(menu1.create_mitem( 't', "goto last position", "moved to previous position", Proc.new { goto_last_position} ))
      item.action = menu1
      menu.add(item)
      # how do i know what's available. the application or window should know where to place
      #menu.display @form.window, 23, 1, $datacolor #, menu
      menu.display @form.window, $error_message_row, $error_message_col, $datacolor #, menu
    end
    ##
    # dynamically load a module and execute init method.
    # Hopefully, we can get behavior like this such as vieditable or multibuffers
    def load_module requirename, includename
      require "rbcurse/#{requirename}"
      extend Object.const_get("#{includename}")
      send("#{requirename}_init") #if respond_to? "#{includename}_init"
    end

  end # class textview

end # modul
