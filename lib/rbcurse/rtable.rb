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

  # ------ NOTE ------------------ #
  # Table contains a TableModel
  # Table contains a TableColumnModel (which contains TableColumn instances)
  # TableColumn contains 2 TableCellRenderer: column and header
  # ------------------------ #
  # TODO : tableheader, model index
  #
  # Due to not having method overloading, after usig new, use set_data or set_model
  #
  # This is a widget that displays tabular data. We will get into editing after this works out.
  # This uses the MVC architecture and is WIP as of 2009-01-04 18:37 
  # TODO cellrenderers should be able to get parents bgcolor and color (Jtables) if none defined for them.
  class Table < Widget
    include RubyCurses::EventHandler

    dsl_accessor :height
    dsl_accessor :title
    dsl_accessor :title_attrib
    dsl_accessor :selected_color, :selected_bgcolor, :selected_attr
    attr_accessor :current_index

    def initialize form, config={}, &block
      super
      init_locals
    end

    def init_locals
      @col_offset = @row_offset = 1
      @focusable= true
      @current_index ||= 0
      @toprow ||= 0
      @to_print_borders ||= 1
      @show_grid ||= 1
      # @selected_color ||= 'yellow'
      # @selected_bgcolor ||= 'black'
      @table_changed = true
      @repaint_required = true
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
      create_default_list_selection_model
      create_table_header
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

    def table_model tm
      raise "data error" if !tm.is_a? RubyCurses::TableModel
      @table_model = tm
    end
    def table_column_model tcm
      raise "data error" if !tcm.is_a? RubyCurses::TableColumnModel
      @table_column_model = tcm
      @table_header.column_model(tcm) unless @table_header.nil?
    end
    def get_table_column_model
      @table_column_model 
    end
    # XXX link in
    def list_selection_model lsm
      @list_selection_model = lsm
    end
    def create_default_list_selection_model
      list_selection_model DefaultListSelectionModel.new
    end
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
    def is_row_selected row
      @list_selection_model.is_selected_index row
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
    def add_row_selection_interval ix0, ix1
      # if row_selection_allowed
      @list_selection_model.add_selection_interval ix0, ix1
    end
    def remove_row_selection_interval ix0, ix1
      @list_selection_model.remove_selection_interval ix0, ix1
    end
    def toggle_row_selection row
      if is_row_selected row
        $log.debug " deleting row #{row}"
        remove_row_selection_interval(row, row)
      else
        $log.debug " adding row #{row}"
        add_row_selection_interval(row, row) 
      end

    end
    attr_accessor :row_selection_allowed
    attr_accessor :column_selection_allowed


    def clear_selection
      @list_selection_model.clear_selection
    end
    def selected_item
    #  @list[@current_index]
    end
    def selected_rows
      @list_selection_model.get_selected_rows
    end
    def selected_row_count
      selected_rows.size
    end
    def selected_row
      @list_selection_model.get_min_selection_index
    end
    alias :selected_index :selected_row

    def selected_column
      @table_column_model.selected_columns
    end
    def selected_columns
      @table_column_model.selected_columns
    end
    def selected_column_count
      @table_column_model.selected_column_count
    end

    #--- row and column  methods ---#
    def add_column tc
      @table_column_model << tc
    end
    def remove_column tc
      @table_column_model.delete  tc
    end
    def get_column ident
    end
    def get_column_name ix
      @table_column_model[ix]
    end
    def move_column ix, newix
    end

    #--- row and column  methods ---#
    def get_value_at row, col
      @table_model.get_value_at row, col
    end
    def set_value_at row, col, value
      @table_model.set_value_at row, col, value
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
    ## to do for TrueClass and FalseClass
    def prepare_renderers
      @crh = Hash.new
      @crh['String'] = TableCellRenderer.new "", {"parent" => self }
      @crh['Fixnum'] = TableCellRenderer.new "", { "justify" => :right, "parent" => self}
      @crh['Float'] = TableCellRenderer.new "", {"justify" => :right, "parent" => self}
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
      @crh ||= []
      @crh[cname]=rend
    end
    ## override for cell or row behaviour
    def get_cell_renderer row, col
      # get columns renderer else class default
      column = @table_column_model.column(col)
      rend = column.cell_renderer
      return rend # can be nil
    end
    # -----------------

    ##
    # key handling
    # make separate methods so callable programmatically
    def handle_key(ch)
      @current_index ||= 0
      @toprow ||= 0
      h = @height-3      
      rc = @table_model.row_count
      case ch
      when KEY_UP  # show previous value
        previous_row
    #    @toprow = @current_index
      when KEY_DOWN  # show previous value
        next_row
      when 32:
        #add_row_selection_interval @current_index, @current_index
        toggle_row_selection @current_index #, @current_index
        @repaint_required = true
      when ?\C-n:
        scroll_forward
      when ?\C-p:
        scroll_backward
      when 48, ?\C-[:
        # please note that C-[ gives 27, same as esc so will respond after ages
        goto_top
      when ?\C-]:
        goto_bottom
      else
    #    super
      end
    end
    ##
    def previous_row
        @current_index -= 1 if @current_index > 0
        bounds_check
    end
    def next_row
      rc = @table_model.row_count
      @current_index += 1 if @current_index < rc
      bounds_check
    end
    def goto_bottom
      rc = @table_model.row_count
      @current_index = rc -1
      bounds_check
    end
    def goto_top
        @current_index = 0
        bounds_check
    end
    def scroll_backward
      h = @height-3      
      @current_index -= h 
      bounds_check
    end
    def scroll_forward
      h = @height-3      
      rc = @table_model.row_count
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
      h = @height-3      
      rc = @table_model.row_count
      #$log.debug " PRE CURR:#{@current_index}, TR: #{@toprow} RC: #{rc} H:#{h}"
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
      #$log.debug " POST CURR:#{@current_index}, TR: #{@toprow} RC: #{rc} H:#{h}"
      set_form_row
      @repaint_required = true
    end
    # the cursor should be appropriately positioned
    def set_form_row
      r,c = rowcol
      @form.row = r + (@current_index-@toprow) + 1
    end
    # temporary, while testing and fleshing out
    def table_data_changed 
      $log.debug " TEMPORARILY PLACED. REMOVE AFTER FINALIZED. table_data_changed"
      #@data_changed = true
      @repaint_required = true
    end
    def repaint
      return unless @repaint_required
      print_border @form.window if @to_print_borders == 1 # do this once only, unless everything changes
      cc = @table_model.column_count
      rc = @table_model.row_count
      tcm = @table_column_model
      tm = @table_model
      tr = @toprow
      h = @height - 3
      r,c = rowcol
      # each cell should print itself, however there is a width issue. 
      # Then thee
      print_header # do this once, unless columns changed
      # TODO TCM should give modelindex of col which is used to fetch data from TM
      r += 1 # save for header
      0.upto(h) do |hh|
        crow = tr+hh
        if crow < rc
          offset = 0
          0.upto(cc-1) do |colix|
            acolumn = tcm.column(colix)
            focussed = @current_index == crow ? true : false 
            selected = is_row_selected crow
            content = tm.get_value_at(crow, colix)
            #renderer = get_default_cell_renderer_for_class content.class.to_s
            renderer = get_cell_renderer(crow, colix)
            if renderer.nil?
              renderer = get_default_cell_renderer_for_class(content.class.to_s) if renderer.nil?
              renderer.display_length acolumn.width unless acolumn.nil?
            end
            width = renderer.display_length + 1
            #renderer.repaint @form.window, r+hh, c+(colix*11), content, focussed, selected
            renderer.repaint @form.window, r+hh, c+(offset), content, focussed, selected
            offset += width
          end
        else
          # clear rows
        end
      end
      @table_changed = false
      @repaint_required = false
    end
    def print_border g
      return unless @table_changed
      g.print_border @row, @col, @height, @width, $datacolor
    end
    def print_header
      return unless @table_changed
      r,c = rowcol
      header_model = @table_header.table_column_model
      tcm = @table_column_model
      offset = 0
      header_model.each_with_index do |tc, colix|
        acolumn = tcm.column colix
        renderer = tc.cell_renderer
        renderer = @table_header.default_renderer if renderer.nil?
        renderer.display_length acolumn.width unless acolumn.nil?
        width = renderer.display_length + 1
        content = tc.header_value
        renderer.repaint @form.window, r, c+(offset), content, false, false
        offset += width
      end
    end


    attr_accessor :toprow # top visible
  end # class Table

  ## TC 
  #
  class TableColumn
    attr_reader :identifier
    attr_accessor :min_width, :max_width, :is_resizable
    attr_accessor :cell_renderer
    # user may override or set for this column, else headers default will be used
    attr_accessor :header_renderer  
    attr_reader :header_value
    def initialize identifier, header_value, width, config={}, &block
      @width = width
      @identifier = identifier
      @header_value = header_value
      instance_eval &block if block_given?
    end
    ## display this row on top
    def width(*val)
      if val.empty?
        @width
      else
        @width = val[0] 
      # fire property change
      end
    end
    ## table header will be picking header_value from here
    def set_header_value w
      @header_value = w
      # fire property change
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
  ## DTCM  DCM
  class DefaultTableColumnModel < TableColumnModel
    include Enumerable
    attr_accessor :column_selection_allowed
    
    ##
    #  takes a column names array
    def initialize cols=[]
      @columns = []
      cols.each {|c| @columns << TableColumn.new(c, c, 10) }
      @selected_columns = []
    end
    def column ix
      raise "Invalid arg #{ix}" if ix < 0 or ix > (@columns.length() -1)
      @columns[ix]
    end
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
    def total_column_width
      0
    end
    def set_selection_model lsm
      @column_selection_model = lsm
    end
    def add_column tc
      @columns << tc
    end
    def remove_column tc
      @columns.delete  tc
    end
    def move_column ix, newix
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

    class DefaultTableModel
      def initialize data, colnames_array
        @data = data
        @column_identifiers = colnames_array
      end
      def column_count
        @column_identifiers.count
      end
      def row_count
        @data.length
      end
      def set_value_at row, col, val
          # if editing allowed
          @data[row][col] = val
      end
      def get_value_at row, col
        return @data[row][ col]
      end
      def << obj
        @data << obj
      end
      def insert row, obj
        @data.insert row, obj
      end
      def delete obj
        @data.delete obj
      end
      def delete_at row
        @data.delete_at row
      end
    end # class 

    ##
    # LSM 
    #
    class DefaultListSelectionModel
      include EventHandler
      attr_accessor :selection_mode
      attr_reader :anchor_selection_index
      attr_reader :lead_selection_index
      def initialize
        @selected_indices=[]
        @anchor_selection_index = -1
        @lead_selection_index = -1
        @selection_mode = :MULTIPLE
      end

      def clear_selection
        @selected_indices=[]
      end
      def is_selected_index ix
        @selected_indices.include? ix
      end
      def get_max_selection_index
        @selected_indices[-1]
      end
      def get_min_selection_index
        @selected_indices[0]
      end
      def get_selected_rows
        @selected_indices
      end
      ## TODO should go in sorted, and no dupes
      def add_selection_interval ix0, ix1
        @anchor_selection_index = ix0
        @lead_selection_index = ix1
        ix0.upto(ix1) {|i| @selected_indices  << i unless @selected_indices.include? i }
      end
      def remove_selection_interval ix0, ix1
        @anchor_selection_index = ix0
        @lead_selection_index = ix1
        @selected_indices.delete_if {|x| x >= ix0 and x <= ix1}
      end
      def insert_index_interval ix0, len
        @anchor_selection_index = ix0
        @lead_selection_index = ix0+len
        add_selection_interval @anchor_selection_index, @lead_selection_index
      end
    end # class DefaultListSelectionModel
    ##
    # 
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

    end

end # module
