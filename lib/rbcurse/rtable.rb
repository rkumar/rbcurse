=begin
  * Name: table widget
  * Description: 
  * Author: rkumar 


  TODO: NOTE: 
     A few higher level methods check for no data but lower level ones do not.
   XXX FIXME if M-tab to exit table then editing_stopped should be called.
             currenty valus is lost if exiting table using Mtab or M-S-tab 2009-10-06 15:10 
   FIXME if a field is not printed since it is going out, tab still goes there, and celleditor
   still prints there. - DONE
   
   FIXME Increasing a column shoud decrease others till min size but not push off.
   Should we have a method for changing column width online that recomputes others?
   See testtable.rb - TODO a bit later
   FIXME - tabbing in a row, should auto scroll to columns not displayed ?
   currently it moves to next row. (examples/sqlc.rb) - DONE
  
  * 2010-01-18 19:54 - BUFFERING related changes.
  * 2011-09-30       - removed all buffer related stuff
  --------
  * Date:   2008-12-27 21:33 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'logger'
require 'rbcurse'
require 'rbcurse/table/tablecellrenderer'
require 'rbcurse/table/tabledatecellrenderer'
require 'rbcurse/checkboxcellrenderer'
require 'rbcurse/listselectable'
require 'rbcurse/listkeys'

#include Ncurses # FFI 2011-09-8 
include RubyCurses
module RubyCurses
  extend self

  # ------ NOTE ------------------ #
  # Table contains a TableModel
  # Table contains a TableColumnModel (which contains TableColumn instances)
  # TableColumn contains 2 TableCellRenderer: column and header
  # ------------------------ #
  # 
  #
  # Due to not having method overloading, after usig new, use set_data or set_model
  #
  # This is a widget that displays tabular data. We will get into editing after this works out.
  # This uses the MVC architecture and is WIP as of 2009-01-04 18:37 
  # TODO cellrenderers should be able to get parents bgcolor and color (Jtables) if none defined for them.
  class Table < Widget
    #include RubyCurses::EventHandler # widget does 2009-01-15 15:38 
    include RubyCurses::ListSelectable
    include RubyCurses::ListKeys

    dsl_accessor :title
    dsl_accessor :title_attrib
    dsl_accessor :selected_color, :selected_bgcolor, :selected_attr
    attr_accessor :current_index   # the row index universally
    #attr_accessor :current_column  # index of column (usually in current row )
    # a changed event of an editor component can utitlize this if it wishes to know
    # the row or col that was exited.
    attr_reader :editing_col, :editing_row  # r and col being edited, set to nil on leave
    attr_accessor :is_editing # boolean is only true if cell_editing_allowed
    dsl_accessor :editing_policy   # :EDITING_AUTO
    dsl_accessor :size_to_fit   # boolean, will size columns upon set data just to fit
    dsl_accessor :estimate_widths   # boolean, will size columns upon set data
    
    # A table should only be editable if this is true regardless of other variables
    # In addition, A column to be editable must either have editable as nil or true
    dsl_accessor :cell_editing_allowed # 2009-01-16 22:55 

    def initialize form = nil, config={}, &block
      _data = config.delete :data
      _columns = config.delete :columns
      @_column_widths = config.delete :column_widths
      # if user leaves width blank but gives us col widths, that means calculate total width
      if @_column_widths && config[:width].nil?
        total = @_column_widths.inject(0) { |total, w| total+=w }
        @width = total+2
      end
      @suppress_borders = false
      @col_offset = @row_offset = 1

      super
      # added LIST event since bombing when selecting a row in table 2011-09-8 FFI
      @_events.push(*[:TABLE_TRAVERSAL_EVENT,:TABLE_EDITING_EVENT, :LIST_SELECTION_EVENT])
      init_vars
      install_list_keys
      install_keys_bindings
      if _data && _columns
        set_data _data, _columns
      end
    end

    def init_vars
      @focusable= true
      @current_index = 0
      @current_column = 0
      @oldrow = @oldcol = 0
      @current_column_offset ||= 0 # added 2009-01-12 19:06 current_column's offset
      @toprow = 0
      @show_grid ||= 1
      @_first_column_print = 0 # intro for horiz scrolling 2009-02-14 16:20 
      @_last_column_print = 0 # 2009-02-16 23:57 so we don't tab further etc. 
      # table needs to know what columns are being printed.
      @curpos = 0
      @inter_column_spacing = 1
      # @selected_color ||= 'yellow'
      # @selected_bgcolor ||= 'black'
      @col_offset = @row_offset = 0 if @suppress_borders
      @table_changed = true
      @repaint_required = true
    end
    def install_keys_bindings

      # alt-tab next column
      # alt-shift-tab prev column
      #bind_key(?\M-\C-i) { next_column }
      #bind_key(481) { previous_column }
      bind_key(KEY_TAB) { next_column }
      bind_key(KEY_BTAB) { previous_column }
      bind_key(KEY_RIGHT) { next_column }
      bind_key(KEY_LEFT) { previous_column }
      bind_key(@KEY_ASK_FIND_FORWARD) { ask_search_forward }
      bind_key(@KEY_ASK_FIND_BACKWARD) { ask_search_backward }
      bind_key(@KEY_FIND_NEXT) { find_next }
      bind_key(@KEY_FIND_PREV) { find_prev }
      # added 2010-05-12 21:41 for vim keys, will work if cell editing allowed is false
      # user should be able to switch to editable and off so he can use keys TODO
      # TODO vim_editable mode: C dd etc . to repeat change, how about range commands like vim
      # TODO use numeric to widen, so we can distribute spacing
      bind_key(?j){ next_row() }
      bind_key(?k){ previous_row() }
      bind_key(?G){ goto_bottom() }
      bind_key([?g,?g]){ goto_top() }
      bind_key(?l) { next_column }
      bind_key(?h) { previous_column }
    end

    def focussed_row
      #raise "No data in table" if row_count < 1
      return nil if row_count < 1
      return @current_index if @current_index < row_count
      @current_index = row_count-1
    end
    def focussed_col
      return nil if row_count < 1
      #raise "No data in table" if row_count < 1
      @current_column
    end
    # added 2009-01-07 13:05 so new scrollable can use
    def row_count
      return 0 if @table_model.nil?
      @table_model.row_count
    end
    # added 2009-01-07 13:05 so new scrollable can use
    def scrollatrow
      if @suppress_borders # NOT TESTED XXX
        @height - 2 # we forgot to remove 1 from height in border.
      else
        @height - 4 # we forgot to remove 1 from height in border.
      end
    end

    # 
    # Sets the data in models
    # Should replace if these are created. TODO FIXME
    def set_data data, colnames_array
      # next 2 added in case set_data called again
      @table_changed = true
      @repaint_required = true
      data ||= [[]]
      colnames_array ||= [""]
      if data.is_a? Array
        model = RubyCurses::DefaultTableModel.new data, colnames_array
        table_model model
      elsif data.is_a? RubyCurses::TableModel
        table_model data
      else
        raise "set_data: don't know how to handle data: #{data.class.to_s}"
      end
      if colnames_array.is_a? Array
        model = DefaultTableColumnModel.new colnames_array
        table_column_model model
      elsif colnames_array.is_a? RubyCurses::TableColumnModel
        table_column_model  colnames_array
      else
        raise "set_data: don't know how to handle column data: #{colnames_array.class.to_s}"
      end
      create_default_list_selection_model
      create_table_header
      # added 2010-09-09 19:57 if user provides col widths in hash, or size_to_fit
        $log.debug " XXX @size_to_fit: #{@size_to_fit} "
      if @_column_widths
        $log.debug "XXXX inside set column widths "
        set_column_widths @_column_widths
      elsif @estimate_widths
        $log.debug "XXXX inside estimate column widths "
        cw = estimate_column_widths data
        set_column_widths cw
      elsif @size_to_fit
        $log.debug " XXX inside  @size_to_fit: #{@size_to_fit} "
        size_columns_to_fit
      end
    end
    def set_model tm, tcm=nil, lsm=nil
      table_model tm
      if tcm.nil?
        create_default_table_column_model
      else
        table_column_model tcm
      end
      if lsm.nil?
        create_default_list_selection_model
      else
        list_selection_model lsm
      end
      create_table_header
    end

    # getter and setter for table_model
    def table_model(*val)
      if val.empty?
        @table_model
      else
        raise "data error" if !val[0].is_a? RubyCurses::TableModel
        @table_model = val[0] 
        ## table registers as a listener, or rather binds to event
        @table_model.bind(:TABLE_MODEL_EVENT){|lde| table_data_changed(lde) }
      end
    end
    # updated this so no param will return the tcm 2009-02-14 12:31 
    def table_column_model(*val)
      if val.empty?
        return @table_column_model
      end
      tcm = val[0]
      raise "data error: table_column_model wrong class" if !tcm.is_a? RubyCurses::TableColumnModel
      @table_column_model = tcm
      @table_column_model.bind(:TABLE_COLUMN_MODEL_EVENT) {|e| 
        table_structure_changed e
      }
      @table_column_model.bind(:PROPERTY_CHANGE){|e| column_property_changed(e)}

      #@table_header.column_model(tcm) unless @table_header.nil?
      @table_header.table_column_model=(tcm) unless @table_header.nil?
    end
    # @deprecated, avoid usage
    def get_table_column_model
      $log.warn " DEPRECATED. Pls use table_column_model()"
      @table_column_model 
    end
    # 
    def create_default_table_column_model
      table_column_model DefaultTableColumnModel.new
    end
    def create_table_header
      @table_header = TableHeader.new @table_column_model
    end

    #--- selection methods ---#
    def is_column_selected col
      raise "TODO "
    end
    def is_cell_selected row, col
      raise "TODO "
    end
    def add_column_selection_interval ix0, ix1
      raise "TODO "
      # if column_selection_allowed
    end
    def remove_column_selection_interval ix0, ix1
      raise "TODO "
    end

    def selected_column
      @table_column_model.selected_columns[0]
    end
    def selected_columns
      @table_column_model.selected_columns
    end
    def selected_column_count
      @table_column_model.selected_column_count
    end

    #--- row and column  methods ---#

    ##
    # getter and setter for current_column index
    def current_column(*val)
      if val.empty?
        @current_column || 0
      else
        @oldcol = @current_column
        v = val[0]
        v = 0 if v < 0
        v = @table_column_model.column_count-1 if v > @table_column_model.column_count-1
        @current_column = v 
        if @current_column != @oldcol
          on_leave_column @oldcol
          on_enter_column @current_column
        end
        set_form_col
        @oldcol = @current_column # added on 2009-01-16 19:40 for next_col
      end
    end


    def add_column tc
      @table_column_model << tc
      #table_structure_changed # this should be called by tcm TODO with object
    end
    def remove_column tc
      @table_column_model.remove_column  tc
      #table_structure_changed # this should be called by tcm TODO with object
    end
    def get_column identifier
      ix = @table_column_model.column_index identifier
      return @table_column_model.column ix
    end
    ## 
    # returns col by col ix added on 2009-01-16 23:45 
    def column ix
      @table_column_model.column(ix)
    end
    def get_column_name ix
      @table_column_model.column(ix).identifier
    end
    def move_column ix, newix
      @table_column_model.move_column ix, newix
      #table_structure_changed # this should be called by tcm TODO with object
    end

    #--- row and column methods of Table ---#
    # must not give wrong results when columns switched!
    def get_value_at row, col
      return nil if row.nil? || col.nil? # 2011-09-29 
      model_index = @table_column_model.column(col).model_index
      @table_model.get_value_at row, model_index
    end
    # must not give wrong results when columns switched!
    def set_value_at row, col, value
      model_index = @table_column_model.column(col).model_index
      @table_model.set_value_at row, model_index, value
    end

    #--- event listener support  methods (p521) TODO ---#

    def table_data_changed tabmodev
      #$log.debug " def table_data_changed got #{tabmodev}"
      @repaint_required = true
      # next was required otherwise on_enter would bomb if data changed from outside
      if row_count == 0
        init_vars
        set_form_col # added 2009-01-24 14:32 since cursor was still showing on existing col
        return #  added 2009-01-23 15:15 
      end
      # the next block to be only called if user is inside editing. Often data will be refreshed by
      # a search field and this gets called.
      if @is_editing
        @is_editing = false # 2009-01-19 18:18 testing this out XXX
        # we need to refresh the editor if you deleted a row while sitting on it
        # otherwise it shows the old value
        editing_started 
      end
    end
    def table_structure_changed tablecolmodelevent
      $log.debug " def table_structure_changed #{tablecolmodelevent}"
      @table_changed = true
      @repaint_required = true
      init_vars
    end
    def column_property_changed evt
      $log.debug "JT def column_property_changed #{evt} "
      @table_changed = true
      @repaint_required = true
    end
=begin
   # this could be complicating things. I don't need it in here.
    def column_added tabcolmodev
      @repaint_required = true
    end
    def column_removed tabcolmodev
      @repaint_required = true
    end
    def column_moved tabcolmodev
      @repaint_required = true
    end
=end
    ## to do for TrueClass and FalseClass
    def prepare_renderers
      @crh = Hash.new
      @crh['String'] = TableCellRenderer.new "", {"parent" => self }
      @crh['Fixnum'] = TableCellRenderer.new "", { "justify" => :right, "parent" => self}
      @crh['Float'] = TableCellRenderer.new "", {"justify" => :right, "parent" => self}
      @crh['TrueClass'] = CheckBoxCellRenderer.new "", {"parent" => self, "display_length"=>7}
      @crh['FalseClass'] = CheckBoxCellRenderer.new "", {"parent" => self, "display_length"=>7}
      @crh['Time'] = TableDateCellRenderer.new "", {"parent" => self, "display_length"=>16}
      #@crh['String'] = TableCellRenderer.new "", {"bgcolor" => "cyan", "color"=>"white", "parent" => self}
      #@crh['Fixnum'] = TableCellRenderer.new "", {"display_length" => 6, "justify" => :right, "color"=>"blue","bgcolor"=>"cyan" }
      #@crh['Float'] = TableCellRenderer.new "", {"display_length" => 6, "justify" => :right, "color"=>"blue", "bgcolor"=>"cyan" }
    end
    # this is vry temporary and will change as we begin to use models - i need to pick 
    # columns renderer
    def get_default_cell_renderer_for_class cname
      @crh || prepare_renderers
      @crh[cname] || @crh['String']
    end
    def set_default_cell_renderer_for_class cname, rend
      @crh ||= {}
      @crh[cname]=rend
    end
    ## override for cell or row behaviour
    def get_cell_renderer row, col
      # get columns renderer else class default
      column = @table_column_model.column(col)
      rend = column.cell_renderer
      return rend # can be nil
    end
    #
    # ------- editing methods---------- #
    def get_cell_editor row, col
    $log.debug " def get_cell_editor #{row}, #{col}"
      column = @table_column_model.column(col)
      return nil if column.editable == false or (column.editable.nil? and @cell_editing_allowed!=true)
      editor = column.cell_editor
      return editor # can be nil
    end
    def edit_cell_at row, col
      acolumn = column(col)
      if acolumn.editable == false or (acolumn.editable.nil? and @cell_editing_allowed!=true)
        $log.debug " editing not allowed in #{col}"
        @is_editing = false
        return nil
      end
      return nil if row >= row_count
      value = get_value_at row, col
      editor = get_cell_editor row, col
      @old_cell_value = value # for event
      if editor.nil?
        
        cls = value.nil? ? get_value_at(0,col).class.to_s : value.class.to_s
        if value.nil?
          case cls
          when 'String'
            value = value.to_s
          when 'Fixnum'
            value = value.to_i
          when 'Float'
            value = value.to_f
          else
            value = value.to_s
          end
        end
        editor = get_default_cell_editor_for_class cls
        #$log.debug "EDIT_CELL_AT:1 #{cls}  #{editor.component.display_length} = #{@table_column_model.column(col).width}i maxlen #{editor.component.maxlen}"
        editor.component.display_length = @table_column_model.column(col).width
        # maxlen won't be nil ! This used to work earlier
        #editor.component.maxlen = editor.component.display_length if editor.component.respond_to? :maxlen and editor.component.maxlen.nil? # 2009-01-18 00:59  XXX don't overwrite if user has set
        if editor.component.respond_to? :maxlen 
          editor.component.maxlen = @table_column_model.column(col).edit_length || editor.component.display_length 
        end
        #$log.debug "EDIT_CELL_AT: #{cls}  #{editor.component.display_length} = #{@table_column_model.column(col).width}i maxlen #{editor.component.maxlen}"
      end
      #$log.debug " got an EDITOR #{editor} ::  #{editor.component} "
      # by now we should have something to edit with. We just need to prepare the widgey.
      prepare_editor editor, row, col, value
    
    end
    def prepare_editor editor, row, col, value
      r,c = rowcol
      row = r + (row - @toprow) +1  #  @form.row , 1 added for header row!
      col = c+get_column_offset()
      editor.prepare_editor self, row, col, value
      # added on 2009-02-16 23:49 
      # if data is longer than can be displayed then update editors disp len too
      if (col+editor.component.display_length)>= @col+@width
        editor.component.display_length = @width-1-col
        $log.debug "DDDXXX #{editor.component.display_length} = @width-1-col"
      else
      $log.debug "EEE if (#{col+editor.component.display_length})> #{@col+@width}"
      end
      @cell_editor = editor
      @repaint_required = true
      # copied from rlistbox, so that editors write on parent's graphic, otherwise
      # their screen updates get overwritten by parent. 2010-01-19 20:17 
      set_form_col 
    end
    ## Its too late to call components on_leave here
    # since cursor would have moved elsewhere.
    # Prior to moving out of a field, the on_leave should be called and exceptions caught FIXME
    def cancel_editor
      # not really required, the refresh was required. Ok, now i call components on_leave inside
      #@cell_editor.cancel_editor
      @editing_row, @editing_col = nil, nil
      @is_editing = false
      @repaint_required = true
    end
    def get_default_cell_editor_for_class cname
      @ceh ||= {}
      cname = 'Boolean' if cname == 'TrueClass' or cname == 'FalseClass'
      if @ceh.include? cname
        return @ceh[cname]
      else
        case cname
        when 'String'
          # I do not know cell width here, you will have toset display_length NOTE
          ce = RubyCurses::CellEditor.new RubyCurses::Field.new nil, {"focusable"=>false, "visible"=>false, "display_length"=> 8, :name => "tb_field_str"}
          @ceh['String'] = ce
          return ce
        when 'Fixnum'
          ce = RubyCurses::CellEditor.new RubyCurses::Field.new nil, {"focusable"=>false, "visible"=>false, "display_length"=> 5, :name => "tb_field_num"}
          @ceh[cname] = ce
          return ce
        when 'Float'
          ce = RubyCurses::CellEditor.new RubyCurses::Field.new nil, {"focusable"=>false, "visible"=>false, "display_length"=> 5, :name => "tb_field_flt"}
          @ceh[cname] = ce
          return ce
        when "Boolean" #'TrueClass', 'FalseClass'
          ce = RubyCurses::CellEditor.new(RubyCurses::CheckBox.new nil, {"display_length"=> 0})
          @ceh[cname] = ce
          return ce
        else
          $log.debug " get_default_cell_editor_for_class UNKNOWN #{cname}"
          ce = RubyCurses::CellEditor.new RubyCurses::Field.new nil, {"focusable"=>false, "visible"=>false, "display_length"=> 6, :name => "tb_field_unk"}
          @ceh[cname] = ce
          return ce
        end
      end
    end
    # returns true if editing is occurring
    #def is_editing?
    #  @editing
    #end
   
    # ----------------- #

    ##
    # key handling
    # make separate methods so callable programmatically
    def handle_key(ch)
      return :UNHANDLED if @table_model.nil?
      @current_index ||= 0
      @toprow ||= 0
      h = scrollatrow()
      rc = @table_model.row_count
      if @is_editing and (ch != 27 and ch != ?\C-c and ch != 13)
        $log.debug " sending ch #{ch} to cell editor"
        ret = @cell_editor.component.handle_key(ch)
        @repaint_required = true
        $log.debug "RET #{ret} got from to cell editor"
        #set_form_col if ret != :UNHANDLED # added 2010-01-30 20:17 CURSOR POS TABBEDPANE
        return if ret != :UNHANDLED
      end
      case ch
      when KEY_UP  # show previous value
        editing_stopped if @is_editing # 2009-01-16 16:06 
        previous_row
      when KEY_DOWN  # show previous value
        editing_stopped if @is_editing # 2009-01-16 16:06 
        next_row
      when 27, ?\C-c
        editing_canceled
      when KEY_ENTER, 10, 13
        # actually it should fall through to the else
        return :UNHANDLED unless @cell_editing_allowed
        toggle_cell_editing

      when @KEY_ROW_SELECTOR # ?\C-x #32
        #add_row_selection_interval @current_index, @current_index
        toggle_row_selection @current_index #, @current_index
        @repaint_required = true
      when ?\C-n.getbyte(0)
        editing_stopped if @is_editing # 2009-01-16 16:06 
        scroll_forward
      when ?\C-p.getbyte(0)
        editing_stopped if @is_editing # 2009-01-16 16:06 
        scroll_backward
      when @KEY_GOTO_TOP # removed 48 (0) from here so we can trap numbers
        # please note that C-[ gives 27, same as esc so will respond after ages
        editing_stopped if @is_editing # 2009-01-16 16:06 
        goto_top
      when @KEY_GOTO_BOTTOM
        editing_stopped if @is_editing # 2009-01-16 16:06 
        goto_bottom
      when @KEY_SCROLL_RIGHT
        editing_stopped if @is_editing # dts 2009-02-17 00:35 
        scroll_right
      when @KEY_SCROLL_LEFT
        editing_stopped if @is_editing # dts 2009-02-17 00:35 
        scroll_left
      when ?0.getbyte(0)..?9.getbyte(0)
        $multiplier *= 10 ; $multiplier += (ch-48)
        #$log.debug " setting mult to #{$multiplier} in list "
        return 0
      else
        # there could be a case of editing here too!
        ret = process_key ch, self
        $multiplier = 0 
        return :UNHANDLED if ret == :UNHANDLED
      end
      return 0 # added 2010-03-14 13:27 
    end
    def editing_canceled
      return unless @cell_editing_allowed
      @is_editing = false if @is_editing
      cancel_editor
    end
    def toggle_cell_editing
      return unless @cell_editing_allowed
      @is_editing = !@is_editing
      if @is_editing 
        editing_started
      else
        editing_stopped
      end
    end
    def editing_started
      return if !@cell_editing_allowed or row_count < 1
      @is_editing = true # 2009-01-16 16:14 
      $log.debug " turning on editing cell at #{focussed_row}, #{focussed_col}"
      # on deleting last row, we need to go back 2009-01-19 18:31 
      if focussed_row >= row_count
        bounds_check
      end
      @editing_row, @editing_col = focussed_row(), focussed_col()
      edit_cell_at focussed_row(), focussed_col()
    end
    # EDST
    # the defualt values are useful when user is ON the field and pressed ENTER
    # when leaving a cell, this should have oldrow and oldcol, not default values
    # this throws an exception if validation on field fails NOTE
    def editing_stopped row=focussed_row(), col=focussed_col()
      return unless @cell_editing_allowed or @is_editing == false or column(col).editable == false
      return if row_count < 1
      $log.debug "editing_stopped set_value_at(#{row}, #{col}: #{@cell_editor.getvalue}"
      # next line should be in on_leave_cell but that's not being called FIXME from everywhere
      @cell_editor.on_leave row,col # added here since this is called whenever a cell is exited

      value = @cell_editor.getvalue
      if value != @old_cell_value
        set_value_at(row, col, @cell_editor.getvalue) #.dup 2009-01-10 21:42 boolean can't duplicate
        if @table_editing_event.nil? 
          @table_editing_event ||= TableEditingEvent.new row, col, self, @old_cell_value, value, :EDITING_STOPPED
        else
          @table_editing_event.set row, col, self, @old_cell_value, value, :EDITING_STOPPED
        end
        fire_handler :TABLE_EDITING_EVENT, @table_editing_event
      end
      cancel_editor
    end
    ##
    #def previous_row
    def previous_row num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
      @oldrow = @current_index
    #  @current_index -= 1 if @current_index > 0
      num.times { 
        @current_index -= 1 if @current_index > 0
      }
      $multiplier = 0
      bounds_check
    end
    # goto next row
    # added multipler 2010-05-12 20:51 
    def next_row num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
      rc = row_count
      @oldrow = @current_index
      # don't go on if rc 2009-01-16 19:55  XXX
      if @current_index < rc
        @current_index += 1*num if @current_index < rc
        bounds_check
      end
      $multiplier = 0
    end
    # move focus to next column
    #  2009-10-07 12:47 behavior change. earlier this would move to next row
    #  if focus was on last visible field. Now it scrolls so that first invisible
    #  field becomes the first column. 
    #  # 2010-05-13 12:42 added multiplier
    #def next_column
    def next_column num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
      $multiplier = 0 # so not used again in next row
      #v =  @current_column+1 
      v =  @current_column + num
      # normal situation, there is a next column go to
      if v < @table_column_model.column_count 
        if v <= @_last_column_print
          $log.debug " if v < #{@table_column_model.column_count} nd lastcolprint "
          current_column v
        else
          # there is a col but its not visible
          # XXX inefficient but i scroll completely to next column (putting it at start)
          # otherwise sometimes it was still not visible if last column
          (v-@_first_column_print).times(){scroll_right}
          current_column v
          set_form_col 
        end

      else
        if @current_index < row_count()-1 
          $log.debug " GOING TO NEXT ROW FROM NEXT COL : #{@current_index} : #{row_count}"
          @current_column = 0
          #@current_column = @_first_column_print # added 2009-02-17 00:01 
          @_first_column_print = 0 # added 2009-10-07 11:25 
          next_row 1
          set_form_col
          @repaint_required = true
          @table_changed = true    # so columns are modified by print_header
        else
          return :UNHANDLED
        end
      end
    end
    # move focus to previous column
    # if you are on first column, check if scrolling required, else move up to
    # last *visible* column of prev row
    #def previous_column
    def previous_column num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
      v =  @current_column - num # 2010-05-13 12:44 1 to num
      # returning unhandled so focus can go to prev field auto
      if v < @_first_column_print and @current_index <= 0
        return :UNHANDLED
      end
      if v < @_first_column_print
        if v > 0
          scroll_left
          current_column v
        elsif @current_index >  0
          @current_column = @table_column_model.column_count-1
          @current_column = @_last_column_print # added 2009-02-17 00:01 
          $log.debug " XXXXXX prev col #{@current_column}, las #{@_last_column_print}, fi: #{@_first_column_print}"
          set_form_col
          previous_row 1
        end
      else
        current_column v
      end
    end
    def goto_bottom
      @oldrow = @current_index
      rc = row_count
      @current_index = rc -1
      bounds_check
    end
    def goto_top
      @oldrow = @current_index
      @current_index = 0
      bounds_check
    end
    def scroll_backward
      @oldrow = @current_index
      h = scrollatrow()
      @current_index -= h 
      bounds_check
    end
    def scroll_forward
      @oldrow = @current_index
      h = scrollatrow()
      rc = row_count
      # more rows than box
      if h < rc
        @toprow += h+1 #if @current_index+h < rc
        @current_index = @toprow
      else
        # fewer rows than box
        @current_index = rc -1
      end
      #@current_index += h+1 #if @current_index+h < rc
      bounds_check
    end

    def bounds_check
      h = scrollatrow()
      rc = row_count

      @current_index = 0 if @current_index < 0  # not lt 0
      @current_index = rc-1 if @current_index >= rc # not gt rowcount
      @toprow = rc-h-1 if rc > h and @toprow > rc - h - 1 # toprow shows full page if possible
      # curr has gone below table,  move toprow forward
      if @current_index - @toprow > h
        @toprow = @current_index - h
      elsif @current_index < @toprow
        # curr has gone above table,  move toprow up
        @toprow = @current_index
      end

      if @oldrow != @current_index
        #$log.debug "going to call on leave and on enter"
        on_leave_row @oldrow #if respond_to? :on_leave_row     # to be defined by widget that has included this
        on_enter_row @current_index   #if respond_to? :on_enter_row  # to be defined by widget that has included this
      end
      set_form_row
      @oldrow = @current_index 
      @repaint_required = true
    end
    def on_leave_row arow
      #$log.debug " def on_leave_row #{arow}"
      #on_leave_cell arow, @current_column
      on_leave_cell arow, @oldcol # 2009-01-16 19:41 XXX trying outt
    end
    def on_leave_column acol
      #$log.debug " def on_leave_column #{acol}"
      #on_leave_cell @current_index, acol
      on_leave_cell @oldrow, acol
    end
    def on_enter_row arow
      #$log.debug " def on_enter_row #{arow}"
      on_enter_cell arow, @current_column
    end
    def on_enter_column acol
      #$log.debug " def on_enter_column #{acol}"
      on_enter_cell @current_index, acol
    end
    ## OLCE
    def on_leave_cell arow, acol
      $log.debug " def on_leave_cell #{arow}, #{acol}"
      #if @editing_policy == :EDITING_AUTO  # actually this should happen in all cases
      if @is_editing # 2009-01-17 00:49 
        editing_stopped arow, acol
      end
    end
    ## OECE
    def on_enter_cell arow, acol
      $log.debug " def on_enter_cell #{arow}, #{acol}"
      if @table_traversal_event.nil? 
        @table_traversal_event ||= TableTraversalEvent.new @oldrow, @oldcol, arow, acol, self
      else
        @table_traversal_event.set(@oldrow, @oldcol, arow, acol, self)
      end
      fire_handler :TABLE_TRAVERSAL_EVENT, @table_traversal_event
      if @editing_policy == :EDITING_AUTO
        editing_started
      end
    end
    # on enter of widget
    # the cursor should be appropriately positioned
    def on_enter
      super
      set_form_row
      set_form_col # 2009-01-17 01:35 
      on_enter_cell focussed_row(), focussed_col() unless focussed_row().nil? or focussed_col().nil?
    end
    def on_leave
      super
      $log.debug " on leave of table 2009-01-16 21:58 "
      editing_stopped if @is_editing #  2009-01-16 21:58 
    end
    def set_form_row
      r,c = rowcol
      @rows_panned ||= 0 # RFED16 2010-02-19 10:00 
      win_row = 0
      #win_row=@form.window.top # 2010-01-18 20:28 added
      # +1 is due to header
      #@form.row = r + (@current_index-@toprow) + 1
      frow = r + (@current_index-@toprow) + 1 + win_row + @rows_panned
      setrowcol(frow, nil) # 2010-01-18 20:04 
    end
    # set cursor on correct column, widget
    def set_form_col col=@curpos
      @curpos = col
      @cols_panned ||= 0 # RFED16 2010-02-19 10:00 
      @current_column_offset = get_column_offset 
      #@form.col = @col + @col_offset + @curpos + @current_column_offset
      #win_col=@form.window.left
      win_col = 0 # RFED16 2010-02-19 10:00 
      fcol = @col + @col_offset + @curpos + @current_column_offset + @cols_panned + win_col
      setrowcol(nil, fcol) # 2010-01-18 20:04 
    end
    # protected
    def get_column_offset columnid=@current_column
      return 0 if @table_column_model.nil?
      return @table_column_model.column(columnid).column_offset || 0
    end


    def repaint
      return unless @repaint_required
      my_win = @form ? @form.window : @target_window
      @graphic = my_win unless @graphic
      #$log.warn "neither form not target window given!!! TV paint 368" unless my_win
      raise " #{@name} neither form, nor target window given TV paint " unless my_win
      raise " #{@name} NO GRAPHIC set as yet                 TV paint " unless @graphic
      @win_left = my_win.left # unused remove TODO
      @win_top = my_win.top

      print_border @graphic if !@suppress_borders  # do this once only, unless everything changes
      return if @table_model.nil? # added 2009-02-17 12:45 
      @_first_column_print ||= 0
      cc = @table_model.column_count
      rc = @table_model.row_count
      inter_column_padding = " " * @inter_column_spacing 
      @_last_column_print = cc-1
      tcm = @table_column_model
      tm = @table_model
      tr = @toprow
      _column_scrolling = false
      acolor = get_color $datacolor
      h = scrollatrow()
      r,c = rowcol
      # each cell should print itself, however there is a width issue. 
      # Then thee
      print_header # do this once, unless columns changed
      # TCM should give modelindex of col which is used to fetch data from TM
      r += 1 # save for header
      0.upto(h) do |hh|
        crow = tr+hh  # crow is the row
        if crow < rc
          offset = 0 # offset of column
    #      0.upto(cc-1) do |colix|
          focussed = @current_index == crow ? true : false 
          selected = is_row_selected crow
          # we loop through column_model and fetch data based on model index
          # FIXED better to call table.get_value_at since we may now 
          # introduce a view - 2009-01-18 18:21 
          tcm.each_with_index do |acolumn, colix|
            next if colix < @_first_column_print
            #acolumn = tcm.column(colix)
            #model_index = acolumn.model_index
            content = get_value_at(crow, colix)  # tables
            renderer = get_cell_renderer(crow, colix)
            if renderer.nil?
              renderer = get_default_cell_renderer_for_class(content.class.to_s) if renderer.nil?
              renderer.display_length acolumn.width unless acolumn.nil?
            end
            width = renderer.display_length + @inter_column_spacing
            acolumn.column_offset = offset
            # trying to ensure that no overprinting
            if c+offset+width > @col+@width
              _column_scrolling = true
              @_last_column_print = colix
              # experimental to print subset of last
              space_left = (@width-3)-(offset) # 3 due to boundaries
              space_left = 0 if space_left < 0
              # length bombed for trueclass 2009-10-05 19:34 
              contentlen = content.length rescue content.to_s.length
              #if content.length > space_left
              if contentlen > space_left
                clen = space_left
                renderer.display_length clen
              else
                clen = -1
                renderer.display_length space_left # content.length
              end
              # added 2009-10-05 20:29 since non strings were bombing
              # in other cases should be just pass the content as-is. XXX
              contenttrim = content[0..clen] rescue content # .to_s[0..clen]
              # print the inter cell padding just in case things mess up while scrolling
              @graphic.mvprintw r+hh, c+offset-@inter_column_spacing, inter_column_padding
              #renderer.repaint @graphic, r+hh, c+offset, crow, content[0..clen], focussed, selected
              #renderer.repaint @graphic, r+hh, c+offset, crow, contenttrim, focussed, selected
              # 2009-10-05 20:35 XXX passing self so we check it doesn't print outside
              renderer.repaint self, r+hh, c+offset, crow, contenttrim, focussed, selected
              break
            end
            # added crow on 2009-02-11 22:46 
            #renderer.repaint @graphic, r+hh, c+(offset), crow, content, focussed, selected
              # 2009-10-05 20:35 XXX
            renderer.repaint self, r+hh, c+(offset), crow, content, focussed, selected
            offset += width
          end
        else
          #@graphic.printstring r+hh, c, " " * (@width-2), acolor,@attr
          printstring r+hh, c, " " * (@width-2), acolor,@attr
          # clear rows
        end
      end
      if @is_editing
        @cell_editor.component.repaint unless @cell_editor.nil? or @cell_editor.component.form.nil?
      end
      _print_more_columns_marker _column_scrolling
      _print_more_data_marker(rc-1 > tr + h)
      $log.debug " _print_more_data_marker(#{rc} >= #{tr} + #{h})"
      @table_changed = false
      @repaint_required = false
      #@buffer_modified = true # 2011-09-30 CLEANUP
    end
    # NEW to correct overflow
    #  2009-10-05 21:34 
    #  when resizing columns a renderer can go outside the table bounds
    #  so printing should be done by parent not window
    def printstring(r,c,string, color, att)
      # 3 is table borders
      # if renderer trying to print outside don't let it
      if c > @col+@width-3
        return
      end
      # if date exceeds boundary truncate
      if c+string.length > (@col+@width)-3
        len = string.length-((c+string.length)-(@col+@width-3))
        @graphic.printstring(r,c,string[0..len], color,att)
      else
        @graphic.printstring(r,c,string, color,att)
      end
    end
    def print_border g
      return unless @table_changed
      g.print_border @row, @col, @height-1, @width, $datacolor
      return if @table_model.nil?
      rc = @table_model.row_count
      h = scrollatrow()
      _print_more_data_marker (rc>h)
    end
    # private
    def _print_more_data_marker tf
      marker = tf ?  Ncurses::ACS_CKBOARD : Ncurses::ACS_VLINE
      @graphic.mvwaddch @row+@height-2, @col+@width-1, marker
      marker = @toprow > 0 ?  Ncurses::ACS_CKBOARD : Ncurses::ACS_VLINE
      @graphic.mvwaddch @row+1, @col+@width-1, marker
    end
    def _print_more_columns_marker tf
      marker = tf ?  Ncurses::ACS_CKBOARD : Ncurses::ACS_HLINE
      @graphic.mvwaddch @row+@height-1, @col+@width-2, marker
      # show if columns to left or not
      marker = @_first_column_print > 0 ?  Ncurses::ACS_CKBOARD : Ncurses::ACS_HLINE
      @graphic.mvwaddch @row+@height-1, @col+@_first_column_print+1, marker
    end
    # print table header
    # 2011-09-17 added repaint all check so that external components can triger this
    # e.g. multi-container when it changes tables.
    def print_header
      return unless @table_changed || @repaint_all
          $log.debug " TABLE: inside printheader 2009-10-07 11:51  DDD "

      r,c = rowcol
      header_model = @table_header.table_column_model
      tcm = @table_column_model ## could have been overridden, should we use this at all
      offset = 0
      header_model.each_with_index do |tc, colix|
        next if colix < @_first_column_print # added for scrolling rt and left 2009-02-14 17:49 
        acolumn = tcm.column colix
        renderer = tc.cell_renderer
        renderer = @table_header.default_renderer if renderer.nil?
        renderer.display_length acolumn.width unless acolumn.nil?
        width = renderer.display_length + 1
        content = tc.header_value
        if c+offset+width > @col+@width
          #$log.debug " TABLE: experimental code to NOT print if chance of exceeding table width"
          # 2009-02-14 14:24 now printing, but truncating data for last column
              space_left = (@width-3)-(offset)
              space_left = 0 if space_left < 0
              if content.length > space_left
                clen = space_left
                renderer.display_length clen
              else
                clen = -1
                renderer.display_length space_left
              end
              #$log.debug " TABLE BREAKING SINCE sl: #{space_left},#{crow},#{colix}: #{clen} "
        # passing self so can prevent renderer from printing outside 2009-10-05 22:56 
              #renderer.repaint @graphic, r, c+(offset), 0, content[0..clen], false, false
              renderer.repaint self, r, c+(offset), 0, content[0..clen], false, false
          break
        end
        # passing self so can prevent renderer from printing outside 2009-10-05 22:56 
        #renderer.repaint @graphic, r, c+(offset),0, content, false, false
        renderer.repaint self, r, c+(offset),0, content, false, false
        offset += width
      end
    end
    # 2009-01-17 13:25 
    def set_focus_on arow
      @oldrow = @current_index
      @current_index = arow
      bounds_check if @oldrow != @current_index  
    end
    attr_accessor :toprow # top visible
    def ask_search_backward
      regex =  get_string("Enter regex to search (backward)")
      ix = @table_model.find_prev regex, @current_index
      if ix.nil?
        alert("No matching data for: #{regex}")
      else
        set_focus_on(ix)
      end
    end
    def find_prev 
      ix = @table_model.find_prev
      regex = @table_model.last_regex 
      if ix.nil?
        alert("No previous matching data for: #{regex}")
      else
        set_focus_on(ix)
      end
    end
    def ask_search_forward
      regex =  get_string("Enter regex to search (forward)")
      #ix = @table_model.find_next regex, @current_index
      ix = @table_model.find_match regex, @current_index
      if ix.nil?
        alert("No matching data for: #{regex}")
      else
        set_focus_on(ix)
      end
    end
    # table find_next
    def find_next 
      ix = @table_model.find_next
      regex = @table_model.last_regex 
      if ix.nil?
        alert("No more matching data for: #{regex}")
      else
        set_focus_on(ix)
      end
    end
    def scroll_right
      cc = @table_model.column_count
      if @_first_column_print < cc-1
        @_first_column_print += 1
        @_last_column_print += 1 if @_last_column_print < cc-1
        @current_column =  @_first_column_print
          set_form_col # FIXME not looking too good till key press
        @repaint_required = true
        @table_changed = true    # so columns are modified
      end
    end
    def scroll_left
      if @_first_column_print > 0
        @_first_column_print -= 1
        @current_column =  @_first_column_print
          set_form_col
        @repaint_required = true
        @table_changed = true
      end
    end
    ## 
    # Makes an estimate of columns sizes, returning a hash, and storing it as @column_widths
    # based on checking first 20 rows of data.
    # This does not try to fit all columns into table, but gives best width, so you
    # can scroll right to see other columns.
    # @params - columns is columns returned by database
    # using the command: @columns, *rows = @db.execute2(command)
    # @param - datatypes is an array returned by following command to DB
    # @datatypes = @content[0].types 
    def estimate_column_widths columns, datatypes=nil
      tablewidth = @width-3
      colwidths = {}
      unless datatypes
        datatypes = []
        row = columns[0]
        $log.debug " XXX row: #{row} "

        row.each do |c| 
          $log.debug " XXX c: #{c} "
          case c
          when Fixnum, Integer
            datatypes << "int"
          when Date, Time
            datatypes << "date"
          else
            datatypes << "varchar"
          end
        end
      end
      min_column_width = (tablewidth/columns.length) -1
      $log.debug("min: #{min_column_width}, #{tablewidth}")
      0.upto(20) do |rowix|
        break if rowix >= row_count
      #@content.each_with_index do |row, cix|
      #  break if cix >= 20
        @table_column_model.each_with_index do |acolumn, ix|
          col = get_value_at(rowix, ix)
          colwidths[ix] ||= 0
          colwidths[ix] = [colwidths[ix], col.to_s.length].max
        end
      end
      total = 0
      # crashing in 1.9.2 due to hash key no insert in iteration 2010-08-22 20:09 
      #colwidths.each_pair do |k,v|
      tkeys = colwidths.keys
      tkeys.each do |k|
        name = columns[k.to_i]
        v = colwidths[k]
        colwidths[name] = v
        total += v
      end
      colwidths["__TOTAL__"] = total
      column_widths = colwidths
      @max_data_widths = column_widths.dup

      $log.debug "XXXX datatypes #{datatypes} "
      columns.each_with_index do | col, i|
       break if datatypes[i].nil?
      if datatypes[i].match(/(real|int)/) != nil
        wid = column_widths[i]
        #   cw = [column_widths[i], [8,min_column_width].min].max
        $log.debug("XXX #{wid}. #{columns[i].length}")
        cw = [wid, columns[i].length].max
        $log.debug("int #{col} #{column_widths[i]}, #{cw}")
      elsif datatypes[i].match(/(date)/) != nil
        cw = [column_widths[i], [12,min_column_width].min].max
        #cw = [12,min_column_width].min
        $log.debug("date #{col}  #{column_widths[i]}, #{cw}")
      else
        cw = [column_widths[i], min_column_width].max
        if column_widths[i] <= col.length and col.length <= min_column_width
          cw = col.length
        end
        $log.debug("else #{col} #{column_widths[i]}, #{col.length} #{cw}")
      end
      column_widths[i] = cw
      total += cw
      end
      column_widths["__TOTAL__"] = total
      $log.debug("Estimated col widths: #{column_widths.inspect}")
      @column_widths = column_widths
      return column_widths
    end
    ##
    # convenience method
    # sets column widths given an array of ints
    # You may get such an array from estimate_column_widths
    def set_column_widths cw
      raise "Cannot call set_column_widths till table set" unless @table_column_model
      tcm = @table_column_model
      tcm.each_with_index do |col, ix|
        col.width cw[ix]
      end
      table_structure_changed(nil)
    end
    def size_columns_to_fit
      delta = @width - table_column_model().get_total_column_width()
      tcw = table_column_model().get_total_column_width()

      $log.debug "size_columns_to_fit D #{delta}, W #{@width}, TCW #{tcw}"
      accomodate_delta(delta) if delta != 0
      #set_width_from_preferred_widths
    end
    private
    def accomodate_delta delta
      tcm = @table_column_model
      cc = tcm.column_count 
      return if cc == 0
      average = (delta/cc).ceil
      total = 0
      tcm.each do |col|
        oldcw = col.width + average
        next if oldcw < col.min_width or oldcw > col.max_width
        if delta >0 
          break if total > delta
        else
          break if total < delta
        end
        col.width oldcw
        total += average
      end
      $log.debug "accomodate_delta: #{average}. #{total}"
      table_structure_changed(nil)
    end

    # ADD METHODS HERE
  end # class Table

  ## TC 
  # All column changes take place in ColumnModel not in data. TC keeps pointer to col in data via
  # TODO - can't change width beyond min and max if set
  # resizable - user  can't resize but programatically can
  # model_index
# XXX Seems we are not using min_width and max_width.
# min should be used for when resizing,, max should not be used. we are using width which is
# updated as changed
  class TableColumn
    include RubyCurses::EventHandler # 2009-01-15 22:49 
    attr_reader :identifier
    attr_accessor :min_width, :max_width, :is_resizable
    attr_accessor :cell_renderer
    attr_accessor :model_index  # index inside TableModel
    # user may override or set for this column, else headers default will be used
    attr_accessor :header_renderer  
    dsl_property :header_value
    dsl_property :width  # XXX don;t let user set width later, should be readonly
    dsl_property :preferred_width # user should use this when requesting a change
    # some columns may not be editable. e.g in a Finder, file size or time not editable
    # whereas name is.

    # is this column editable. Set to false to disable a column from editing IF the table
    # allows editing. Setting to true not required.
    dsl_accessor :editable   # if not set takes tables value 2009-01-16 22:49 
    ## added column_offset on 2009-01-12 19:01 
    attr_accessor :column_offset # where we've place this guy. in case we need to position cursor
    attr_accessor :cell_editor
    dsl_accessor :edit_length # corresponds to maxlen, if not set, col width will be useda 2009-02-16 21:55 


    # width is used as initial and preferred width. It has actual value at any time
    # width must never be directly set, use preferred width later
    def initialize model_index, identifier, header_value, width, config={}, &block
      @width = width
      @preferred_width = width
      @min_width = 4
      @max_width = 1000
      @model_index = model_index
      @identifier = identifier
      @header_value = header_value
      @config={}
      instance_eval &block if block_given?
      @_events = [:PROPERTY_CHANGE]
    end
    def fire_property_change(text, oldval, newval)
      #$log.debug "TC: def fire_property_change(#{text}, #{oldval}, #{newval})"
      # need to send changeevent FIXME XXX maybe dsl_prop should do this.
      fire_handler :PROPERTY_CHANGE, self
    end
  end # class tc

  ## TCM 
  #
  class TableColumnModel
    def column ix
      nil
    end
    def columns 
      nil
    end
    def column_count
      0
    end
    def column_selection_allowed
      false
    end
    def selected_column_count
      0
    end
    def selected_columns
      nil
    end
    def total_column_width
      -1
    end
    def get_selection_model
      nil
    end
    def set_selection_model lsm
    end
    def add_column tc
    end
    def remove_column tc
    end
    def move_column ix, newix
    end
    def column_index identifier
      nil
    end
    # add tcm listener
  end
  ## DTCM  DCM
  class DefaultTableColumnModel < TableColumnModel
    include Enumerable
    include RubyCurses::EventHandler # widget does 2009-01-15 15:38 
    attr_accessor :column_selection_allowed
    
    ##
    #  takes a column names array
    def initialize cols=[]
      @columns = []
      @total_column_width= -1
      ##cols.each_with_index {|c, index| @columns << TableColumn.new(index, c, c, 10) }
      cols.each_with_index {|c, index| add_column(TableColumn.new(index, c, c, 10)) }
      @selected_columns = []
      @_events = [:TABLE_COLUMN_MODEL_EVENT, :PROPERTY_CHANGE]
    end
    def column ix
      raise "Invalid arg #{ix}" if ix < 0 or ix > (@columns.length() -1)
      @columns[ix]
    end
    def columns; @columns; end
    ##
    # yields a table column
    def each
      @columns.each { |c| 
        yield c 
      }
    end
    def column_count
      @columns.length
    end
    def selected_column_count
      @selected_columns.length
    end
    def selected_columns
      @selected_columns
    end
    def clear_selection
      @selected_columns = []
    end
    ## 
    # added 2009-10-07 23:04 
    def get_total_column_width
      @total_column_width = -1 # XXX
      if @total_column_width == -1
        total = 0
        each { |c| total += c.width ; $log.debug "get_total_column_width: #{c.width}"}
        @total_column_width = total
      end
      return @total_column_width 
    end
    def set_selection_model lsm
      @column_selection_model = lsm
    end
    def add_column tc
      @columns << tc
      tc.bind(:PROPERTY_CHANGE){|e| column_property_changed(e)}
      tmce = TableColumnModelEvent.new(nil, @columns.length-1, self, :INSERT)
      fire_handler :TABLE_COLUMN_MODEL_EVENT, tmce
    end
    def column_property_changed evt
      $log.debug "DTCM def column_property_changed #{evt} "
      # need to send changeevent FIXME XXX
      fire_handler :PROPERTY_CHANGE, self
    end
    def remove_column tc
      ix = @columns.index tc
      @columns.delete  tc
      tmce = TableColumnModelEvent.new(ix, nil, self, :DELETE)
      fire_handler :TABLE_COLUMN_MODEL_EVENT, tmce
    end
    def move_column ix, newix
  #    acol = remove_column column(ix)
      acol = @columns.delete_at ix 
      @columns.insert newix, acol
      tmce = TableColumnModelEvent.new(ix, newix, self, :MOVE)
      fire_handler :TABLE_COLUMN_MODEL_EVENT, tmce
    end
    ##
    # return index of column identified with identifier
    def column_index identifier
      @columns.each_with_index {|c, i| return i if c.identifier == identifier }
      return nil
    end
    ## TODO  - if we get into column selection somewhen
    def get_selection_model
      @lsm
    end
    def set_selection_model lsm
      @lsm = lsm
    end
    # add tcm listener
  end

  ## TM 
    class TableModel
      def column_count
      end
      def row_count
      end
      def set_value_at row, col, val
      end
      def get_value_at row, col
      end
      def get_total_column_width
      end
=begin
      def << obj
      end
      def insert row, obj
      end
      def delete obj
      end
      def delete_at row
      end
  
=end
    end # class 

    ##
    # DTM
    class DefaultTableModel < TableModel
      attr_reader :last_regex
      include RubyCurses::EventHandler # 2009-01-15 15:38 
      def initialize data, colnames_array
        @data = data
        @column_identifiers = colnames_array
        @_events = [:TABLE_MODEL_EVENT, :PROPERTY_CHANGE]
      end
      def column_count
         # 2010-01-12 19:35  changed count to size since size is supported in 1.8.6 also
        #@column_identifiers.count
        @column_identifiers.size
      end
      def row_count
        @data.length
      end
      # 
      # please avoid directly hitting this. Suggested to use get_value_at of jtable
      # since columns could have been switched.
      def set_value_at row, col, val
       # $log.debug " def set_value_at #{row}, #{col}, #{val} "
          # if editing allowed
          @data[row][col] = val
          tme = TableModelEvent.new(row, row, col, self, :UPDATE)
          fire_handler :TABLE_MODEL_EVENT, tme
      end
      ##
      # please avoid directly hitting this. Suggested to use get_value_at of jtable
      # since columns could have been switched.
      def get_value_at row, col
      #$log.debug " def get_value_at #{row}, #{col} "
        
        raise "IndexError get_value_at #{row}, #{col}" if @data.nil? or row >= @data.size
        return @data[row][ col]
      end
      def << obj
        @data << obj
        tme = TableModelEvent.new(@data.length-1,@data.length-1, :ALL_COLUMNS, self, :INSERT)
        fire_handler :TABLE_MODEL_EVENT, tme
        # create tablemodelevent and fire_table_changed for all listeners 
      end
      def insert row, obj
        @data.insert row, obj
        tme = TableModelEvent.new(row, row,:ALL_COLUMNS,  self, :INSERT)
        fire_handler :TABLE_MODEL_EVENT, tme
        # create tablemodelevent and fire_table_changed for all listeners 
      end
      def delete obj
        row = @data.index obj
        return if row.nil?
        ret = @data.delete obj
        tme = TableModelEvent.new(row, row,:ALL_COLUMNS,  self, :DELETE)
        fire_handler :TABLE_MODEL_EVENT, tme
        # create tablemodelevent and fire_table_changed for all listeners
        return ret
      end
      def delete_at row
        if !$multiplier or $multiplier == 0 
          @delete_buffer = @data.delete_at row
        else
          @delete_buffer = @data.slice!(row, $multiplier)
        end
        $multiplier = 0
        #ret = @data.delete_at row
        # create tablemodelevent and fire_table_changed for all listeners 
        # we don;t pass buffer to event as in listeditable. how to undo later?
        tme = TableModelEvent.new(row, row+@delete_buffer.length,:ALL_COLUMNS,  self, :DELETE)
        fire_handler :TABLE_MODEL_EVENT, tme
        return @delete_buffer
      end
      # a quick method to undo deletes onto given row. More like paste
      def undo where
        return unless @delete_buffer
        case @delete_buffer[0]
        when Array
        @delete_buffer.each do |r| 
          insert where, r 
        end
        else
          insert where, @delete_buffer
        end
      end
      ## 
      # added 2009-01-17 21:36 
      # Use with  caution, does not call events per row
      def delete_all
        len = @data.length-1
        @data=[]
        tme = TableModelEvent.new(0, len,:ALL_COLUMNS,  self, :DELETE)
        fire_handler :TABLE_MODEL_EVENT, tme
      end
      ##
      # for those quick cases when you wish to replace all the data
      # and not have an event per row being generated
      def data=(data)
        raise "Data nil or invalid" if data.nil? or data.size == 0
        delete_all
        @data = data
        tme = TableModelEvent.new(0, @data.length-1,:ALL_COLUMNS,  self, :INSERT)
        fire_handler :TABLE_MODEL_EVENT, tme
      end
      def ask_search_forward
        regex = get_string "Enter regex to search for:"
        ix = get_list_data_model.find_match regex
        if ix.nil?
          alert("No matching data for: #{regex}")
        else
          set_focus_on(ix)
        end
      end
      # continues previous search
    ##
    def find_match regex, ix0=0, ix1=row_count()
      $log.debug " find_match got #{regex} #{ix0} #{ix1}"
      @last_regex = regex
      @search_start_ix = ix0
      @search_end_ix = ix1
      @data.each_with_index do |row, ix|
        next if ix < ix0
        break if ix > ix1
        if row.grep(/#{regex}/) != [] 
        #if !row.match(regex).nil?
          @search_found_ix = ix
          return ix 
        end
      end
      return nil
    end
      def find_prev regex=@last_regex, start = @search_found_ix 
        raise "No previous search" if @last_regex.nil?
        $log.debug " find_prev #{@search_found_ix} : #{@current_index}"
        start -= 1 unless start == 0
        @last_regex = regex
        @search_start_ix = start
        start.downto(0) do |ix| 
          row = @data[ix]
          if row.grep(/#{regex}/) != [] 
            @search_found_ix = ix
            return ix 
          end
        end
        return nil
        #return find_match @last_regex, start, @search_end_ix
      end
      ## dtm findnext
    def find_next
      raise "No more search" if @last_regex.nil?
      start = @search_found_ix && @search_found_ix+1 || 0
      return find_match @last_regex, start, @search_end_ix
    end
    end # class  DTC

    ##
    ##
    # Class that manages Table's Header
    # are we not taking events such as column added, removed ?
    class TableHeader
      attr_accessor :default_renderer
      attr_accessor :table_column_model
      def initialize table_column_model
        @table_column_model = table_column_model
        create_default_renderer
      end
      def create_default_renderer
        #@default_renderer = TableCellRenderer.new "", {"display_length" => 10, "justify" => :center}
        @default_renderer = TableCellRenderer.new "", {"display_length" => 10, "justify" => :center, "color"=>"white", "bgcolor"=>"blue"}
      end

      # added 2009-10-07 14:03 
      # returns the column being resized
      # @returns TableColumn
      # @protected
      def get_resizing_column
      end

    end # class TableHeader
  ##
  # When an event is fired by TableModel, contents are changed, then this object will be passed 
  # to trigger
  # type is :INSERT :UPDATE :DELETE :HEADER_ROW 
  # columns: number or :ALL_COLUMNS
  class TableModelEvent
    attr_accessor :firstrow, :lastrow, :column, :source, :type
    def initialize firstrow, lastrow, column, source, type
      @firstrow = firstrow
      @lastrow = lastrow
      @column = column
      @source = source
      @type = type
    end
    def to_s
      "#{@type.to_s}, firstrow: #{@firstrow}, lastrow: #{@lastrow}, column: #{@column}, source: #{@source}"
    end
    def inspect
      to_s
    end
  end
  ##
  # event sent when a column is added, removed or moved
  # type :INSERT :DELETE :MOVE
  # in the case of add query first col, for removed query second
  class TableColumnModelEvent
    attr_accessor :from_col, :to_col, :source, :type
    def initialize from_col, to_col, source, type
      @from_col = from_col
      @to_col = to_col
      @source = source
      @type = type
    end
    def to_s
      "#{@type.to_s}, from_col: #{@from_col}, to_col: #{@to_col}, source: #{@source}"
    end
    def inspect
      to_s
    end
  end
  ## caller can create one and reuse NOTE TODO
  class TableTraversalEvent
    attr_accessor :oldrow, :oldcol, :newrow, :newcol, :source
    def initialize oldrow, oldcol, newrow, newcol, source
      @oldrow, @oldcol, @newrow, @newcol, @source = oldrow, oldcol, newrow, newcol, source
    end
    def set oldrow, oldcol, newrow, newcol, source
      @oldrow, @oldcol, @newrow, @newcol, @source = oldrow, oldcol, newrow, newcol, source
    end
    def to_s
      "TRAVERSAL oldrow: #{@oldrow}, oldcol: #{@oldcol}, newrow: #{@newrow}, newcol: #{@newcol}, source: #{@source}"
    end
    def inspect
      to_s
    end
  end
  ## caller can create one and reuse NOTE TODO
  class TableEditingEvent
    attr_accessor :row, :col, :source, :oldvalue, :newvalue, :type
    def initialize row, col, source, oldvalue, newvalue, type
      set row, col, source, oldvalue, newvalue, type
    end
    def set row, col, source, oldvalue, newvalue, type
      @row, @col, @source, @oldvalue, @newvalue, @type = row, col, source, oldvalue, newvalue, type
    end
    def to_s
      "TABLEDITING #{@type} row: #{@row}, col: #{@col}, oldval: #{@oldvalue}, newvalue: #{@newvalue}, source: #{@source}"
    end
    def inspect
      to_s
    end
  end

end # module
