=begin
  * Name: ResultsetTextView 
  * Description   View text in this widget.
  * Author: rkumar (arunachalesha)
  * file created 2009-01-08 15:23  
  * major change: 2010-02-10 19:43 simplifying the buffer stuff.
  * major change: 2011-10-14 reducing repaint, calling only if scrolled
      also, printing row focus and selection outside of repaint so only 2 rows affected.
  --------
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'rbcurse/rtextview'

include RubyCurses
module RubyCurses
  extend self

  ##
  # An extension of textview that allows viewing a resultset, one record
  # at a time, paging records.

  class ResultsetTextView < TextView 

    # The offset of the current record in the resultset, starting 0
    attr_accessor :current_record

    # not used, and may not be used since i would have to reserve on more column for this
    #dsl_accessor :row_selected_symbol
    # Should the row focussed on show a highlight or not, default is false
    #  By default, the cursor will be placed on focussed row.
    dsl_accessor :should_show_focus
    #
    # Attribute of selected row 'reverse' 'bold'
    #  By default, it is reverse.
    dsl_accessor :selected_attrib    
    # Attribute of focussed row 'reverse' 'bold'
    #  By default, it is not set.
    dsl_accessor :focussed_attrib    # attribute of focussed row 'bold' 'underline'
    dsl_accessor :editing_allowed    # can user edit values and store in database

    def initialize form = nil, config={}, &block
      @row_offset = @col_offset = 1 
      @row = 0
      @col = 0
      @should_show_focus = false # don;t show focus and unfocus by default
      @list = [] # this is not only the currently visible record
      @rows = nil  # this is the entire resultset
      @old_record = @current_record = 0 # index of currently displayed record from resultset
      @editing_allowed = true
      super
      @win = @graphic
      @datatypes = nil; # to be set when we query data, an array one for each column

      @widget_scrolled = true
      @record_changed = false

      bind(:PRESS){ |eve| 
        s = eve.source
        r = s.current_record
        col = @columns[@current_index]
        #alert "You clicked on #{r} , #{col} , #{eve.text} "
        #edit_record 
      }
      #@selected_attrib = 'standout'
      #@focussed_attrib = 'underline'
    end
    def edit_record
        unless @editing_allowed
          say "You clicked on #{r} , #{col} , #{eve.text}. If editing_allowed was true you could have modified the db "
          return
        end
        col = @columns[@current_index]
        text = @rows[@current_record][@current_index]
        value = ask("Edit #{col}: "){ |q| q.default = text }
        if value && value != "" && value != text
          @rows[@current_record][@current_index] = value
          @widget_scrolled = true # force repaint of data
          begin
            sql_update @tablename, id=@rows[@current_record][0], col, value
            say_with_wait "Update to database successful"
          rescue => err
            alert "UPDATE ERROR:#{err.to_s} "
          end
        else
          say_with_pause "Editing aborted", :color_pair => $errorcolor
        end
    end
    ##
    # update a row from bugs based on id, giving one fieldname and value
    # @param [Fixnum] id unique key
    # @param [String] fieldname 
    # @param [String] value to update
    # @example sql_update "bugs", 9, :name, "Roger"
    # I need to know keyfields for 2 reasons , disallow update and use in update XXX
    def sql_update table, id, field, value
      # 2010-09-12 11:42 added to_s to now, due to change in sqlite3 1.3.x
      alert "No database connection" unless @db
      return unless @db
      ret = @db.execute( "update #{table} set #{field} = ? where id = ?", [value, id])
      $log.debug "SQLITE ret value : #{ret}, #{table} #{field} #{id} #{value}  "
    end

    def repaint_all tf
      super
      @widget_scrolled = true
    end
    def next_record
      @old_record = @current_record
      @record_changed = true
      @current_record += 1 if @current_record < @rows.count-1; @repaint_required = true
    end
    def previous_record
      @old_record = @current_record
      @record_changed = true
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
      bind_key('C', :edit_record) 
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
      @db = db # for update
      @dbname = dbname
      @tablename = table
      $log.debug "XXX sql #{sql}, #{rows.count}  "
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
      $log.warn "ResultsetTextView remove_all not yet tested XXX"
      @list = []
      @rows = []
      init_vars
      @repaint_required = true
    end

    def repaint # textview :nodoc:
      #$log.debug "TEXTVIEW repaint r c #{@row}, #{@col} "  
      $log.debug "TEXTVIEW repaint r c #{@row}, #{@col}, key: #{$current_key}, reqd #{@repaint_required} "  

      # TRYING OUT dangerous 2011-10-13 
      @repaint_required = false
      @repaint_required = true if @widget_scrolled || @pcol != @old_pcol || @record_changed


      paint if @repaint_required

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
      if @current_index == @selected_index
        @old_selected_index = @current_index
        #highlight_unselected_row
        unhighlight_row @current_index
        color_field @current_index 
        @selected_index = nil
        return
      end
      unhighlight_row @selected_index
      color_field @selected_index 
      @selected_index = @current_index
      highlight_selected_row
      @old_selected_index = @selected_index

      #print_selected_row
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
      return nil unless @rows
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
    
      $log.debug "XXX TEXTVIEW PAINT HAPPENING #{@current_index} "
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
      return unless tm  # no data
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

              @graphic.printstring r+hh, c+@left_margin, "%-*s" % [@width-@internal_width,content], acolor, @attr

              if selected
                #print_selected_row r+hh, c+@left_margin, content, acolor
                highlight_selected_row r+hh, c
                #@graphic.printstring r+hh, c+@left_margin, "%-*s" % [@width-@internal_width,content], acolor, @focussed_attrib || 'reverse'
              elsif focussed
                # i am keeping this here just since sometimes repaint gets called
                highlight_focussed_row :FOCUSSED, r+hh, c
              end
                #print_focussed_row :FOCUSSED, nil, nil, content, acolor
                #@graphic.printstring r+hh, c+@left_margin, "%-*s" % [@width-@internal_width,content], acolor, @focussed_attrib || 'bold'

              color_field crow
=begin
              # paint field portion separately, take care of when panned
              # hl only field length, not whole thing.
              startpoint = [c+14+1-@pcol,c].max # don't let it go < 0
              clen = @lens[crow]
              # take into account when we've scrolled off right
              clen -= @pcol-14-1 if 14+1-@pcol < 0
              hlwidth = [clen,@width-@internal_width-14-1+@pcol, @width-@internal_width].min
              hlwidth = 0 if hlwidth < 0
              
              @graphic.mvchgat(y=r+hh, x=startpoint, hlwidth, Ncurses::A_NORMAL, @fieldbgcolor, nil)
              #@graphic.mvchgat(y=r+hh, x=startpoint, hlwidth, Ncurses::A_BOLD, acolor, nil)
=end
            
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
      # 2011-10-13 
      @widget_scrolled = false
      @record_changed = false
      @old_pcol = @pcol

    end
    def color_field index
      return unless index
      _r,c = rowcol
      r = _convert_index_to_printable_row index
      return unless r
      # paint field portion separately, take care of when panned
      # hl only field length, not whole thing.
      startpoint = [c+14+1-@pcol,c].max # don't let it go < 0
      clen = @lens[index]
      # take into account when we've scrolled off right
      clen -= @pcol-14-1 if 14+1-@pcol < 0
      hlwidth = [clen,@width-@internal_width-14-1+@pcol, @width-@internal_width].min
      hlwidth = 0 if hlwidth < 0

      @graphic.mvchgat(y=r, x=startpoint, hlwidth, Ncurses::A_NORMAL, @fieldbgcolor, nil)
    end
    # the idea here is to be able to call externally or from loop
    # However, for that content has to be truncated here, not in loop
    def DELprint_focussed_row type,  r=nil, c=nil, content=nil, acolor=nil
      return unless @should_show_focus
      case type
      when :FOCUSSED
        r = _convert_index_to_printable_row() unless r
        attrib = @focussed_attrib || 'bold'
        ix = @current_index

      when :UNFOCUSSED
        return if @oldrow.nil? || @oldrow == @current_index
        r = _convert_index_to_printable_row(@oldrow) unless r
        return unless r # row is not longer visible
        ix = @oldrow
        attrib = @attr
      end
      unless c
        _r, c = rowcol
      end
      if content.nil?
        content = @list[ix]
        content = content.dup
        sanitize content if @sanitization_required
        truncate content
      end
      acolor ||= get_color $datacolor
      #@graphic.printstring r+hh, c+@left_margin, "%-*s" % [@width-@internal_width,content], acolor, @focussed_attrib || 'bold'
      @graphic.printstring r, c+@left_margin, "%-*s" % [@width-@internal_width, content], acolor, attrib
    end

    # this only highlights the selcted row, does not print data again
    # so its safer and should be used instead of print_selected_row
    def highlight_selected_row r=nil, c=nil, acolor=nil
      return unless @selected_index # no selection
      r = _convert_index_to_printable_row(@selected_index) unless r
      return unless r # not on screen
      unless c
        _r, c = rowcol
      end
      acolor ||= get_color $datacolor
      att = FFI::NCurses::A_REVERSE
      att = get_attrib(@selected_attrib) if @selected_attrib
      @graphic.mvchgat(y=r, x=c, @width-@internal_width, att , acolor , nil)
    end
    def highlight_focussed_row type, r=nil, c=nil, acolor=nil
      return unless @should_show_focus
      case type
      when :FOCUSSED
        r = _convert_index_to_printable_row() unless r
        attrib = @focussed_attrib || 'bold'
        ix = @current_index

      when :UNFOCUSSED
        return if @oldrow.nil? || @oldrow == @current_index
        r = _convert_index_to_printable_row(@oldrow) unless r
        return unless r # row is not longer visible
        ix = @oldrow
        attrib = @attr
      end
      unless c
        _r, c = rowcol
      end
      acolor ||= get_color $datacolor
      att = get_attrib(attrib) #if @focussed_attrib
      @graphic.mvchgat(y=r, x=c, @width-@internal_width, att , acolor , nil)
      #@graphic.printstring r, c+@left_margin, "%-*s" % [@width-@internal_width,content], acolor, @focussed_attrib || 'reverse'
    end
    def unhighlight_row index,  r=nil, c=nil, acolor=nil
      return unless index # no selection
      r = _convert_index_to_printable_row(index) unless r
      return unless r # not on screen
      unless c
        _r, c = rowcol
      end
      acolor ||= get_color $datacolor
      att = FFI::NCurses::A_NORMAL
      att = get_attrib(@normal_attrib) if @normal_attrib
      @graphic.mvchgat(y=r, x=c, @width-@internal_width, att , acolor , nil)
    end
    def is_row_selected row
      @selected_index == row
    end
    def on_enter_row arow
      if @should_show_focus
        highlight_focussed_row :FOCUSSED
        unless @oldrow == @selected_index
          highlight_focussed_row :UNFOCUSSED
          color_field @oldrow
        end
      end
      super
    end
    # no such method in superclass !!! XXX FIXME no such event too
    def on_leave_row arow
      #print_focussed_row :UNFOCUSSED
      #print_normal_row
      #super
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
