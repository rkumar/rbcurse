=begin
  * Name: TextView 
  * Description   View text in this widget.
  * Author: rkumar (arunachalesha)
  * file created 2009-01-08 15:23  
  * major change: 2010-02-10 19:43 simplifying the buffer stuff.
TODO 
   * border, and footer could be objects (classes) at some future stage.
  --------
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'logger'
require 'rbcurse'
require 'rbcurse/listscrollable'

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
    #attr_reader :winrow   # the row in the viewport/window
    # painting the footer does slow down cursor painting slightly if one is moving cursor fast
    dsl_accessor :print_footer
    dsl_accessor :suppress_borders # added 2010-02-10 20:05 values true or false
    attr_reader :current_index
    dsl_accessor :border_attrib, :border_color # 
    dsl_accessor :sanitization_required

    def initialize form = nil, config={}, &block
      @focusable = true
      @editable = false
      @sanitization_required = true
      @suppress_borders = false
      @row_offset = @col_offset = 1 
      @row = 0
      @col = 0
      @show_focus = false  # don't highlight row under focus
      @list = []
      super
      # ideally this should have been 2 to take care of borders, but that would break
      # too much stuff !
      @win = @graphic

      @_events.push :CHANGE # thru vieditable
      @_events << :PRESS # new, in case we want to use this for lists and allow ENTER
      @_events << :ENTER_ROW # new, should be there in listscrollable ??
      install_keys # do something about this nonsense FIXME
      init_vars
      map_keys
    end
    def init_vars #:nodoc:
      @curpos = @pcol = @toprow = @current_index = 0
      @repaint_all=true 
      @repaint_required=true 
      @widget_scrolled = true
      ## 2010-02-10 20:20 RFED16 taking care if no border requested
      @row_offset = @col_offset = 0 if @suppress_borders == true
      # added 2010-02-11 15:11 RFED16 so we don't need a form.
      $error_message_row ||= 23
      $error_message_col ||= 1
      # currently i scroll right only if  current line is longer than display width, i should use 
      # longest line on screen.
      @longest_line = 0 # the longest line printed on this page, used to determine if scrolling shd work
      @internal_width = 2
      @internal_width = 0 if @suppress_borders

    end
    def map_keys
      bind_key([?g,?g]){ goto_start } # mapping double keys like vim
      bind_key([?',?']){ goto_last_position } # vim , goto last row position (not column)
      bind_key(?/, :ask_search)
      bind_key(?n, :find_more)
      bind_key([?\C-x, ?>], :scroll_right)
      bind_key([?\C-x, ?<], :scroll_left)
      bind_key(?\M-l, :scroll_right)
      bind_key(?\M-h, :scroll_left)
      bind_key([?\C-x, ?\C-s], :saveas)
      #bind_key(?r) { getstr("Enter a word: ") }
      bind_key(?m, :disp_menu)
    end
    ## 
    # send in a list
    # e.g.         set_content File.open("README.txt","r").readlines
    # set wrap at time of passing :WRAP_NONE :WRAP_WORD
    # XXX if we widen the textview later, as in a vimsplit that data
    # will still be wrapped at this width !!
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
      init_vars
    end
    # for consistency with other objects that respect text
    alias :text :set_content
    def formatted_text text, fmt
      require 'rbcurse/common/chunk'
      @formatted_text = text
      @color_parser = fmt
      remove_all
    end

    def remove_all
      @list = []
      init_vars
      @repaint_required = true
    end
    ## display this row on top
    def top_row(*val) #:nodoc:
      if val.empty?
        @toprow
      else
        @toprow = val[0] || 0
      end
      @repaint_required = true
    end
    ## ---- for listscrollable ---- ##
    def scrollatrow #:nodoc:
      if @suppress_borders
        @height - 1  # should be 2 FIXME but erasing lower line. see appemail
      else
        @height - 3 
      end
    end
    def row_count
      @list.length
    end
    ##
    # returns row of first match of given regex (or nil if not found)
    def find_first_match regex #:nodoc:
      @list.each_with_index do |row, ix|
        return ix if !row.match(regex).nil?
      end
      return nil
    end
    ## returns the position where cursor was to be positioned by default
    # It may no longer work like that. 
    def rowcol #:nodoc:
      return @row+@row_offset, @col+@col_offset
    end
    def wrap_text(txt, col = @maxlen) #:nodoc:
      col ||= @width-@internal_width
      #$log.debug "inside wrap text for :#{txt}"
      txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,
               "\\1\\3\n") 
    end
    ## print a border
    ## Note that print_border clears the area too, so should be used sparingly.
    def print_borders #:nodoc:
      raise "textview needs width" unless @width
      raise "textview needs height" unless @height

      $log.debug " #{@name} print_borders,  #{@graphic.name} "
      
      @color_pair = get_color($datacolor) # added 2011-09-28 as in rlistbox
#      bordercolor = @border_color || $datacolor # changed 2011 dts  
      bordercolor = @border_color || @color_pair # 2011-09-28 V1.3.1 
      borderatt = @border_attrib || Ncurses::A_NORMAL
      @graphic.print_border @row, @col, @height-1, @width, bordercolor, borderatt
      print_title
    end
    def print_title #:nodoc:
      return unless @title
      raise "textview needs width" unless @width
      @color_pair ||= get_color($datacolor) # should we not use this ??? XXX 

      # check title.length and truncate if exceeds width
      _title = @title
      if @title.length > @width - 2
        _title = @title[0..@width-2]
      end
      @graphic.printstring( @row, @col+(@width-_title.length)/2, _title, @color_pair, @title_attrib) unless @title.nil?
    end
    def print_foot #:nodoc:
      @footer_attrib ||= Ncurses::A_REVERSE
      footer = "R: #{@current_index+1}, C: #{@curpos+@pcol}, #{@list.length} lines  "
      $log.debug " print_foot calling printstring with #{@row} + #{@height} -1, #{@col}+2"
      @graphic.printstring( @row + @height -1 , @col+2, footer, @color_pair || $datacolor, @footer_attrib) 
      @repaint_footer_required = false # 2010-01-23 22:55 
    end
    ### FOR scrollable ###
    def get_content
      @list
    end
    def get_window #:nodoc:
      @graphic
    end

    def repaint # textview :nodoc:
      #$log.debug "TEXTVIEW repaint r c #{@row}, #{@col}, key: #{$current_key}, reqd #{@repaint_required} "  

      #return unless @repaint_required # 2010-02-12 19:08  TRYING - won't let footer print for col move
      # TRYING OUT dangerous 2011-10-13 
      @repaint_required = false
      @repaint_required = true if @widget_scrolled || @pcol != @old_pcol || @record_changed || @property_changed

      paint if @repaint_required

      @repaint_footer_required = true if @oldrow != @current_index # 2011-10-15 
      print_foot if @print_footer && !@suppress_borders && @repaint_footer_required
    end
    def getvalue
      @list
    end
    def current_value
      @list[@current_index]
    end

    # determine length of row since we have chunks now.
    # Since chunk implements length, so not required except for the old
    # cases of demos that use an array.
    def row_length
      case @buffer
      when String
        @buffer.length
      when Chunks::ChunkLine
        return @buffer.length
      when Array
        # this is for those old cases like rfe.rb which sent in an array
        # (before we moved to chunks) 
        # line is an array of arrays
        if @buffer[0].is_a? Array
          result = 0
          @buffer.each {|e| result += e[1].length  }
          return result
        end
        # line is one single chunk
        return @buffer[1].length
      end
    end
    # textview
    # NOTE: i think this should return if list is nil or empty. No need to put
    #
    # stuff into buffer and continue. will trouble other classes that extend.
    def handle_key ch #:nodoc:
      $log.debug " textview got ch #{ch} "
      @old_pcol = @pcol
      @buffer = @list[@current_index]
      if @buffer.nil? and row_count == 0
        @list << "\r"
        @buffer = @list[@current_index]
      end
      return if @buffer.nil?
      #$log.debug " before: curpos #{@curpos} blen: #{row_length}"
      if @curpos > row_length #@buffer.length
        addcol((row_length-@curpos)+1)
        @curpos = row_length
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
        # next removed as very irritating, can be configured if required 2011-11-2 
        #get_window.ungetch(KEY_BTAB) if ret == :NO_PREVIOUS_ROW
        check_curpos
        
      when KEY_DOWN, ?j.getbyte(0)
        ret = down
        # This should be configurable, or only if all rows are visible
        #get_window.ungetch(KEY_TAB) if ret == :NO_NEXT_ROW
        check_curpos
      when KEY_LEFT, ?h.getbyte(0)
        cursor_backward
      when KEY_RIGHT, ?l.getbyte(0)
        cursor_forward
      when KEY_BACKSPACE, KEY_BSPACE, KEY_DELETE
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
        blen = row_length # @buffer.rstrip.length FIXME
        set_form_col blen
        # search related 
      when @KEY_ASK_FIND
        ask_search
      when @KEY_FIND_MORE
        find_more
      when 10, 13, KEY_ENTER
        #fire_handler :PRESS, self
        fire_action_event
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
      when ?\C-c.getbyte(0)
        $multiplier = 0
        return 0
      else
        # check for bindings, these cannot override above keys since placed at end
        begin
          ret = process_key ch, self
        rescue => err
          $log.error " TEXTVIEW ERROR #{err} "
          $log.debug(err.backtrace.join("\n"))
          alert err.to_s
        end
        return :UNHANDLED if ret == :UNHANDLED
      end
      $multiplier = 0 # you must reset if you've handled a key. if unhandled, don't reset since parent could use
      set_form_row
      return 0 # added 2010-01-12 22:17 else down arrow was going into next field
    end
    # newly added to check curpos when moving up or down
    def check_curpos #:nodoc:
      @buffer = @list[@current_index]
      # if the cursor is ahead of data in this row then move it back
      if @pcol+@curpos > row_length
        addcol((@pcol+row_length-@curpos)+1)
        @curpos = row_length 
        maxlen = (@maxlen || @width-@internal_width)

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
    def set_form_col col1=@curpos #:nodoc:
      @cols_panned ||= 0
      @pad_offset ||= 0 # added 2010-02-11 21:54 since padded widgets get an offset.
      @curpos = col1
      maxlen = @maxlen || @width-@internal_width
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
    def cursor_forward #:nodoc:
      maxlen = @maxlen || @width-@internal_width
      repeatm { 
      if @curpos < @width and @curpos < maxlen-1 # else it will do out of box
        @curpos += 1
        addcol 1
      else
        @pcol += 1 if @pcol <= row_length
      end
      }
      set_form_col 
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41 
    end
    def addcol num #:nodoc:
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41 
      if @form
        @form.addcol num
      else
        @parent_component.form && @parent_component.form.addcol(num)
      end
    end
    def addrowcol row,col #:nodoc:
      #@repaint_required = true
      @repaint_footer_required = true # 2010-01-23 22:41 
      if @form
      @form.addrowcol row, col
      else
        @parent_component.form.addrowcol num
      end
    end
    def cursor_backward  #:nodoc:
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
    # @deprecated
    def next_line  #:nodoc:
      @list[@current_index+1]
    end
    # @deprecated
    def do_relative_row num  #:nodoc:
      raise "unused will be removed"
      yield @list[@current_index+num] 
    end

    # supply with a color parser, if you supplied formatted text
    def color_parser f
      $log.debug "XXX: parser setting color_parser to #{f} "
      #@window.color_parser f
      @color_parser = f
    end



    ## NOTE: earlier print_border was called only once in constructor, but when
    ##+ a window is resized, and destroyed, then this was never called again, so the 
    ##+ border would not be seen in splitpane unless the width coincided exactly with
    ##+ what is calculated in divider_location.
    def paint  #:nodoc:
    
      $log.debug "XXX TEXTVIEW repaint HAPPENING #{@current_index} "
      my_win = nil
      if @form
        my_win = @form.window
      else
        my_win = @target_window
      end
      @graphic = my_win unless @graphic
      if @formatted_text
        $log.debug "XXX:  INSIDE FORMATTED TEXT "

        # I don't want to do this in 20 places and then have to change
        # it and retest. Let me push it to util.
        l = RubyCurses::Utils.parse_formatted_text(@color_parser,
                                               @formatted_text)

        #cp = Chunks::ColorParser.new @color_parser
        #l = []
        #@formatted_text.each { |e| l << cp.convert_to_chunk(e) }

        text(l)
        @formatted_text = nil

      end

      print_borders if (@suppress_borders == false && @repaint_all) # do this once only, unless everything changes
      rc = row_count
      maxlen = @maxlen || @width-@internal_width
      #$log.debug " #{@name} textview repaint width is #{@width}, height is #{@height} , maxlen #{maxlen}/ #{@maxlen}, #{@graphic.name} roff #{@row_offset} coff #{@col_offset}" 
      tm = get_content
      tr = @toprow
      acolor = get_color $datacolor
      h = scrollatrow() 
      r,c = rowcol
      @longest_line = @width-@internal_width #maxlen
      0.upto(h) do |hh|
        crow = tr+hh
        if crow < rc
            #focussed = @current_index == crow ? true : false 
            #selected = is_row_selected crow
            content = tm[crow]
            # next call modified string. you may wanna dup the string.
            # rlistbox does
            # scrolling fails if you do not dup, since content gets truncated
            if content.is_a? String
              content = content.dup
              sanitize(content) if @sanitization_required
              truncate content
              @graphic.printstring  r+hh, c, "%-*s" % [@width-@internal_width,content], 
                acolor, @attr
            elsif content.is_a? Chunks::ChunkLine
              @graphic.printstring  r+hh, c, " "* (@width-@internal_width), 
                acolor, @attr
              @graphic.wmove r+hh, c
              # either we have to loop through and put in default color and attr
              # or pass it to show_col
              a = get_attrib @attrib
              # FIXME this does not clear till the eol
              @graphic.show_colored_chunks content, acolor, a
            elsif content.is_a? Chunks::Chunk
              raise "TODO chunk in textview"
            elsif content.is_a? Array
                # several chunks in one row - NOTE Very experimental may change
              if content[0].is_a? Array
                # clearing the line since colored_chunks does not yet XXX FIXME if possible
                @graphic.printstring  r+hh, c, " "* (@width-@internal_width), 
                  acolor, @attr
                @graphic.wmove r+hh, c
                # either we have to loop through and put in default color and attr
                # or pass it to show_col
                a = get_attrib @attrib
                # FIXME this does not clear till the eol
                @graphic.show_colored_chunks content, acolor, a
              else
                # a single row chunk - NOTE Very experimental may change
                text = content[1].dup
                sanitize(text) if @sanitization_required
                truncate text
                @graphic.printstring  r+hh, c, "%-*s" % [@width-@internal_width,text], 
                  content[0] || acolor, content[2] || @attr
              end
            end

            # highlighting search results.
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
          @graphic.printstring r+hh, c, " " * (@width-@internal_width), acolor,@attr
        end
      end


      @repaint_required = false
      @repaint_footer_required = true
      @repaint_all = false 
      # 2011-10-15 
      @widget_scrolled = false
      @record_changed = false
      @property_changed = false
      @old_pcol = @pcol

    end
    # takes a block, this way anyone extending this class can just pass a block to do his job
    # This modifies the string
    def sanitize content  #:nodoc:

      if content.is_a? String
        content.chomp!
        # trying out since gsub giving #<ArgumentError: invalid byte sequence in UTF-8> 2011-09-11 
        
        content.replace(content.encode("ASCII-8BIT", :invalid => :replace, :undef => :replace, :replace => "?")) if content.respond_to?(:encode)
        content.gsub!(/[\t\n\r]/, '  ') # don't display tab or newlines
        content.gsub!(/[^[:print:]]/, '')  # don't display non print characters
      else
        content
      end
    end
    # returns only the visible portion of string taking into account display length
    # and horizontal scrolling. MODIFIES STRING
    def truncate content  #:nodoc:
      _maxlen = @maxlen || @width-@internal_width
      _maxlen = @width-@internal_width if _maxlen > @width-@internal_width # take care of decrease in width
      if !content.nil? 
        if content.length > _maxlen # only show maxlen
          @longest_line = content.length if content.length > @longest_line
          #content = content[@pcol..@pcol+maxlen-1] 
          content.replace(content[@pcol..@pcol+_maxlen-1] || "")
        else
          if @pcol > 0
              content.replace(content[@pcol..-1]  || "")
          end
        end
      end
      content
    end
    ## this is just a test of prompting user for a string
    #+ as an alternative to the dialog.
    def getstr prompt, maxlen=10  #:nodoc:
      tabc = Proc.new {|str| Dir.glob(str +"*") }
      config={}; config[:tab_completion] = tabc
      config[:default] = "default"
      $log.debug " inside getstr before call "
      ret, str = rbgetstr(@form.window, @row+@height-1, @col+1, prompt, maxlen, config)
      $log.debug " rbgetstr returned #{ret} , #{str} "
      return "" if ret != 0
      return str
    end
    # this is just a test of the simple "most" menu
    # How can application add to this, or override
    # TODO: use another window at bottom, statuswindow
    def disp_menu  #:nodoc:
      require 'rbcurse/extras/menutree'
      # we need to put this into data-structure so that i can be manipulated by calling apps
      # This should not be at the widget level, too many types of menus. It should be at the app
      # level only if the user wants his app to use this kind of menu.

      if false
        #@menu = RubyCurses::MenuTree.new "Main", { s: :goto_start, r: :scroll_right, l: :scroll_left, m: :submenu }
        #@menu.submenu :m, "submenu", {s: :noignorecase, t: :goto_last_position, f: :next3 }
        #menu = PromptMenu.new self 
        #menu.menu_tree @menu
        #menu.display @form.window, $error_message_row, $error_message_col, $datacolor #, menu
      end
      # trying to find a more rubyesque way of doing
      menu = PromptMenu.new self do
        item :s, :goto_start
        item :b, :goto_bottom
        item :r, :scroll_backward
        item :l, :scroll_forward
        submenu :m, "submenu..." do
          item :p, :goto_last_position
          item :r, :scroll_right
          item :l, :scroll_left
        end
      end
      #menu.display @form.window, $error_message_row, $error_message_col, $datacolor #, menu
      menu.display_new :title => "Menu"


=begin
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
=end
    end
    ##
    # dynamically load a module and execute init method.
    # Hopefully, we can get behavior like this such as vieditable or multibuffers
    def load_module requirename, includename
      require "rbcurse/#{requirename}"
      extend Object.const_get("#{includename}")
      send("#{requirename}_init") #if respond_to? "#{includename}_init"
    end
    # on pressing ENTER we send user some info, the calling program
    # would bind :PRESS
    #--
    # FIXME we can create this once and reuse
    #++
    def fire_action_event
      return if @list.nil? || @list.size == 0
      require 'rbcurse/ractionevent'
      aev = TextActionEvent.new self, :PRESS, current_value(), @current_index, @curpos
      fire_handler :PRESS, aev
    end
    # called by listscrollable, used by scrollbar ENTER_ROW
    def on_enter_row arow
      fire_handler :ENTER_ROW, self
      @repaint_required = true
    end
    # added 2010-09-30 18:48 so standard with other components, esp on enter 
    # NOTE: the on_enter repaint required causes this to be repainted 2 times
    # if its the first object, once with the entire form, then with on_enter.
    def on_enter
      if @list.nil? || @list.size == 0
        Ncurses.beep
        return :UNHANDLED
      end
      on_enter_row @current_index
      set_form_row 
      @repaint_required = true
      super
      true
    end
    def pipe_file
      # TODO ask process name from user
      output = pipe_output 'munpack', @list
      if output && !output.empty?
        set_content output
      end
    end
    # returns array of lines after running command on string passed
    # TODO: need to close pipe other's we'll have a process lying
    # around forever.
    def pipe_output (pipeto, str)
      case str
      when String
        #str = str.split "\n"
        # okay
      when Array
        str = str.join "\n"
      end
      #pipeto = '/usr/sbin/sendmail -t'
      #pipeto = %q{mail -s "my title" rahul}
      if pipeto != nil  # i was taking pipeto from a hash, so checking
        proc = IO.popen(pipeto, "w+")
        proc.puts str
        proc.close_write
        proc.readlines
      end
    end
    def saveas name=nil, config={}
      unless name
        name = @graphic.ask "File to save as: "
        return if name.nil? || name == ""
      end
      exists = File.exists? name
      if exists # need to prompt
        return unless @graphic.agree("Overwrite existing file? ", true)
      end
      l = getvalue
      File.open(name, "w"){ |f|
        l.each { |line| f.puts line }
        #l.each { |line| f.write line.gsub(/\r/,"\n") }
      }
      @graphic.say "#{name} written."
    end


  end # class textview

end # modul
