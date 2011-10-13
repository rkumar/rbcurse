=begin
  * Name: ResultsetTextView 
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
require 'rbcurse/rtextview'

include RubyCurses
module RubyCurses
  extend self

  ##
  # A viewable read only box. Can scroll. 
  # Intention is to be able to change content dynamically - the entire list.
  # Use set_content to set content, or just update the list attrib
  # TODO - 
  #      - goto line - DONE
  class ResultsetTextView < TextView 
    attr_accessor :current_record
    dsl_accessor :row_selected_symbol

    def initialize form = nil, config={}, &block
      @row_offset = @col_offset = 1 
      @row = 0
      @col = 0
      @show_focus = true  # highlight row under focus
      @list = []
      @rows = nil
      @current_record = 0
      super
      @win = @graphic
      @datatypes = nil; # to be set when we query data, an array one for each column

      bind(:PRESS){ |eve| 
        s = eve.source
        r = s.current_record
        col = @columns[@current_index]
        alert "You clicked on #{r} , #{col} , #{eve.text} "
      }
      #@_events.push :CHANGE # thru vieditable
      #@_events << :PRESS # new, in case we want to use this for lists and allow ENTER
      #@_events << :ENTER_ROW # new, should be there in listscrollable ??
      #install_keys # do something about this nonsense FIXME
      #init_vars
      #map_keys
    end
    def next_record
      @current_record += 1 if @current_record < @rows.count-1; @repaint_required = true
    end
    def previous_record
      @current_record -= 1 if @current_record > 0 ; @repaint_required = true
    end
    def map_keys
      super
      bind_key([?\C-x, ?6], :scroll_backward)
      bind_key([?\C-x, ?v], :scroll_forward)
      bind_key([?\C-x, ?n], :next_record) 
      bind_key([?\C-x, ?p], :previous_record) 
      bind_key(?\M-, , :previous_record ) 
      bind_key(?\M-., :next_record) 
      #bind_key([?\C-x, ?>], :scroll_right)
      #bind_key([?\C-x, ?<], :scroll_left)
      #bind_key([?\C-x, ?\C-s], :saveas)
      #bind_key(?r) { getstr("Enter a word: ") }
      #bind_key(?m, :disp_menu)
    end
    # connect to database, run sql and set data, columns and datatypes
    # Similar can be done with another database
    def sqlite dbname, table, sql
      raise "file not found" unless File.exist? dbname
      require 'sqlite3'
      db = SQLite3::Database.new(dbname)
      columns, *rows = db.execute2(sql)
      #$log.debug "XXX COLUMNS #{sql}  "
      content = rows
      return nil if content.nil? or content[0].nil?
      self.datatypes = content[0].types 
      set_content rows, columns
    end
    ## 
    # send in a dataset (array of arrays) and array of column names
    # e.g.         set_content File.open("README.txt","r").readlines
    # set wrap at time of passing :WRAP_NONE :WRAP_WORD
    # XXX if we widen the textview later, as in a vimsplit that data
    # will still be wrapped at this width !!
    def set_content list, columns
      @rows = list
      @columns = columns
      @current_record = 0
      init_vars
    end
    def data=(list)
      @rows = list
    end
    def columns=(list)
      @columns = list
    end
    # set array of datatypes, one per column
    def datatypes=(list)
      @datatypes = list
    end
    def remove_all
      #@list = []
      #init_vars
      @repaint_required = true
    end
    #def row_count
      #@list.length
    #end
    ##
    # returns row of first match of given regex (or nil if not found)
    ## returns the position where cursor was to be positioned by default
    # It may no longer work like that. 
    #def rowcol #:nodoc:
      #return @row+@row_offset, @col+@col_offset
    #end

    def repaint # textview :nodoc:
      $log.debug "TEXTVIEW repaint r c #{@row}, #{@col} "  

      #return unless @repaint_required # 2010-02-12 19:08  TRYING - won't let footer print for col move
      paint if @repaint_required
    #  raise "TV 175 graphic nil " unless @graphic
      print_foot if @print_footer && !@suppress_borders && @repaint_footer_required
    end
    def getvalue
      @list
    end
    # not sure what to return, returning data value
    def current_value
      #@list[@current_record][@current_index]
      @rows[@current_record][@current_index]
    end
    def fire_action_event
      @selected_index = @current_index
      @repaint_required = true
      super
    end
    # newly added to check curpos when moving up or down
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
    #
    # prepares row data for paint to print
    # Creates a string for each row, which is great for textview operation, all of them 
    #  work just fine. But does not allow paint to know what part is title and what is 
    #  data
    #
    def get_content
      id = @current_record

      row = @rows[id]
      @lens = []
      a = []
      f = "%14s %-*s"
      #f = "%14s %-20s"
      @columns.each_with_index { |e, i| 
        value = row[i]
        len = value.to_s.length
        type = @datatypes[i]
        if type == "TEXT"
          value = value.gsub(/\n/," ") if value
        end
        @lens << len
        a << f % [e, len,  value]
      }
      @list = a # this keeps it compatible with textview operations. 
      return a
    end

    ## NOTE: earlier print_border was called only once in constructor, but when
    ##+ a window is resized, and destroyed, then this was never called again, so the 
    ##+ border would not be seen in splitpane unless the width coincided exactly with
    ##+ what is calculated in divider_location.
    def paint  #:nodoc:
    
      #@left_margin ||= @row_selected_symbol.length
      @left_margin = 0
      @fieldbgcolor ||= get_color($datacolor,@bgcolor, 'cyan')
      my_win = nil
      if @form
        my_win = @form.window
      else
        my_win = @target_window
      end
      @graphic = my_win unless @graphic
      @win_left = my_win.left
      @win_top = my_win.top

      print_borders if (@suppress_borders == false && @repaint_all) # do this once only, unless everything changes
      maxlen = @maxlen || @width-@internal_width
      #$log.debug " #{@name} textview repaint width is #{@width}, height is #{@height} , maxlen #{maxlen}/ #{@maxlen}, #{@graphic.name} roff #{@row_offset} coff #{@col_offset}" 
      tm = get_content
      rc = tm.size # row_count
      tr = @toprow
      acolor = get_color $datacolor
      h = scrollatrow() 
      r,c = rowcol
      @longest_line = @width-@internal_width #maxlen
                $log.debug "XXX: SELECTED ROW IS  #{@selected_index} "
      0.upto(h) do |hh|
        crow = tr+hh
        if crow < rc
              focussed = @current_index == crow  # row focussed ?
              selected = is_row_selected crow
              content = tm[crow]
              content = content.dup
              sanitize content if @sanitization_required
              truncate content

              if selected
                @graphic.printstring r+hh, c+@left_margin, "%-*s" % [@width-@internal_width,content], acolor, @focussed_attrib || 'reverse'
              elsif focussed
                @graphic.printstring r+hh, c+@left_margin, "%-*s" % [@width-@internal_width,content], acolor, @focussed_attrib || 'bold'
              else
                @graphic.printstring r+hh, c+@left_margin, "%-*s" % [@width-@internal_width,content], acolor, @attr
              end

              # paint field portion separately, take care of when panned
              # hl only field length, not whole thing.
              startpoint = [c+14+1-@pcol,c].max # don't let it go < 0
              clen = @lens[crow]
              # take into account when we've scrolled off right
              clen -= @pcol-14-1 if 14+1-@pcol < 0
              hlwidth = [clen,@width-@internal_width-14-1+@pcol, @width-@internal_width].min
              hlwidth = 0 if hlwidth < 0
              
              @graphic.mvchgat(y=r+hh, x=startpoint, hlwidth, Ncurses::A_NORMAL, @fieldbgcolor, nil)
            
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

    end
    def is_row_selected row
      @selected_index == row
    end
    # this is just a test of the simple "most" menu
    # How can application add to this, or override
    def disp_menu  #:nodoc:
      require 'rbcurse/extras/menutree'
      # we need to put this into data-structure so that i can be manipulated by calling apps
      # This should not be at the widget level, too many types of menus. It should be at the app
      # level only if the user wants his app to use this kind of menu.

      @menu = RubyCurses::MenuTree.new "Main", { s: :goto_start, r: :scroll_right, l: :scroll_left, m: :submenu }
      @menu.submenu :m, "submenu", {s: :noignorecase, t: :goto_last_position, f: :next3 }
      menu = PromptMenu.new self 
      menu.menu_tree @menu

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
      menu.display @form.window, $error_message_row, $error_message_col, $datacolor #, menu
    end


  end # class textview

end # modul
