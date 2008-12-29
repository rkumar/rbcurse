=begin
  * Name: table widget
  * Description: 
  * Author: rkumar (arunachalesha)
  
  --------
  * Date:   2008-12-27 21:33 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'rubygems'
require 'ncurses'
require 'logger'
require 'lib/ver/ncurses'
require 'lib/ver/window'
require 'lib/rbcurse/rwidget'

include Ncurses
include RubyCurses
module RubyCurses
  extend self

  class Table < Widget
    include RubyCurses::EventHandler
    dsl_accessor :list_config

    attr_accessor :current_index

    def initialize form, config={}, &block
      super
      @current_index ||= 0
    end

    def set_data data, colnames_array
      if data.is_a? Array
        @table_model = RubyCurses::DefaultTableModel.new data, colnames_array
      elsif data.is_a? RubyCurses::TableModel
        table_model data
      end
      if colnames_array.is_a? Array
        @table_column_model = DefaultTableColumnModel.new colnames_array
      elsif colnames_array.is_a? RubyCurses::TableColumnModel
        table_column_model  colnames_array
      end
    end
    def table_model tm
      raise "data error" if !tm.is_a? RubyCurses::TableModel
      @table_model = tm
    end
    def table_column_model tcm
      raise "data error" if !tcm.is_a? RubyCurses::TableColumnModel
      @table_column_model = tcm
    end
    def list_selection_model lsm
      @list_selection_model = lsm
    end

    #--- selection methods ---#

    def clear_selection

    end


    #--- row and column  methods ---#
    def add_column tc
    end
    def remove_column tc
    end
    def get_column ident
    end
    def get_column_name ix
    end
    def move_column ix, newix
    end

    #--- row and column  methods ---#
    def get_value_at row, col
    end
    def set_value_at row, col, value
    end

    #--- event listener support  methods (p521) ---#

    def table_changed tabmodev
    end
    def column_added tabcolmodev
    end
    def column_removed tabcolmodev
    end
    def column_moved tabcolmodev
    end
    # -----------------
    def selected_item
    #  @list[@current_index]
    end
    def selected_index
    #  @current_index
    end

    ##
    # combo edit box key handling
    def handle_key(ch)
      @current_index ||= 0
      case ch
      when KEY_UP  # show previous value
        @current_index -= 1 if @current_index > 0
        set_buffer @list[@current_index].dup
        set_modified(true) 
        fire_handler :ENTER_ROW, self
        @list.on_enter_row self
      when KEY_DOWN  # show previous value
        @current_index += 1 if @current_index < @list.length()-1
        set_buffer @list[@current_index].dup
        set_modified(true) 
        fire_handler :ENTER_ROW, self
        @list.on_enter_row self
      when KEY_DOWN+ RubyCurses::META_KEY # alt down
        popup  # pop up the popup
      else
        super
      end
    end
    ##

    # Field putc advances cursor when it gives a char so we override this
    def putc c
      if c >= 0 and c <= 127
        ret = putch c.chr
        if ret == 0
          addcol 1 if @editable
          set_modified 
        end
      end
      return -1 # always ??? XXX 
    end
    ##
    # field does not give char to non-editable fields so we override
    def putch char
      @current_index ||= 0
      if @editable 
        super
        return 0
      else
        match = next_match(char)
        set_buffer match unless match.nil?
        fire_handler :ENTER_ROW, self
      end
      @modified = true
      fire_handler :CHANGE, self    # 2008-12-09 14:51  ???
      0
    end
    ##
    # the sets the next match in the edit field
    ##
    # on leaving the listbox, update the combo/datamodel.
    # we are using methods of the datamodel. Updating our list will have
    # no effect on the list, and wont trigger events.
    # Do not override.
    def on_leave
    end

    def repaint
      super
      c = @col + @display_length
     # @form.window.mvwvline( @row, c, ACS_VLINE, 1)
      @form.window.mvwaddch @row, c+1, Ncurses::ACS_GEQUAL
     # @form.window.mvwvline( @row, c+2, ACS_VLINE, 1)
     # @form.window.mvwaddch @row, c+2, Ncurses::ACS_S1
     # @form.window.mvwaddch @row, c+3, Ncurses::ACS_S9
     # @form.window.mvwaddch @row, c+4, Ncurses::ACS_LRCORNER
     # @form.window.mvwhline( @row, c+5, ACS_HLINE, 2)
    end

  end # class ComboBox

  class TableColumn
    attr_reader :width
    attr_reader :identifier
    attr_accessor :min_width, :max_width, :is_resizable
    attr_accessor :align # ?? datatype ?
    def initialize identifier, header_value, width, config={}, &block
      @current_width = width
      @identifier = identifier
      @header_value = header_value
      instance_eval &block if block_given?
    end
    def width w
      @width = w
      # fire property change
    end
    def header_value w
      @header_value = w
      # fire property change
    end
  end # class tc
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
      0
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
  class DefaultTableColumnModel < TableColumnModel
    attr_accessor :column_selection_allowed
    @columns = []
    @selected_columns = []
    def column ix
      @columns[ix]
    end
    def columns  # ??
      @columns
      #@columns.each { |c| 
      #  yield c if block_given?
      #}
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
    def total_column_width
      0
    end
    def get_selection_model
      @lsm
    end
    def set_selection_model lsm
      @lsm = lsm
    end
    def add_column tc
      @columns = tc
    end
    def remove_column tc
      @columns.remove tc
    end
    def move_column ix, newix
    end
    def column_index identifier
      @columns.detect { |i| i.identifier == identifier }
    end
    # add tcm listener

    class TableModel
      def column_count
      end
      def row_count
      end
      def value_at row, col, val
      end
    end # class 
    class DefaultTableModel
      def initialize data, colnames_array
        @data = data
        @column_identifiers = colnames_array
      def column_count
        @column_identifiers.count
      end
      def row_count
        @data.length
      end
      def value_at row, col, val=nil
        if val == nil
          return @data[row, col]
        else
          # if editing allowed
          @data[row][col] = val
        end
      end
    end # class 

end # module
