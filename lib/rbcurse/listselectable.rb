# this is a companion file to defaultlistselectionmodel
# if you use that, include this to get all the methods to use it
module RubyCurses
  module ListSelectable

    def list_selection_model lsm
      @list_selection_model = lsm
    end
    def create_default_list_selection_model
      list_selection_model DefaultListSelectionModel.new
    end
    def is_row_selected row
      @list_selection_model.is_selected_index row
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
    attr_accessor :row_selection_allowed
    attr_accessor :column_selection_allowed
  end
end
