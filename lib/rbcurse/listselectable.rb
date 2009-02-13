# this is a companion file to defaultlistselectionmodel
# if you use that, include this to get all the methods to use it
module RubyCurses
  module ListSelectable

    ## modified on 2009-02-13 23:41 to return model if no param passed
    def list_selection_model(*lsm)
      if lsm.empty?
        @list_selection_model 
      else
        @list_selection_model = lsm[0]
      end
      #@list_selection_model.selection_mode = @selection_mode || :MULTIPLE
    end
    def create_default_list_selection_model
      list_selection_model DefaultListSelectionModel.new
    end
    def is_row_selected row
      @list_selection_model.is_selected_index row
    end

    def add_row_selection_interval ix0, ix1
      $log.debug " def add_row_selection_interval #{ix0}, ix1"
      # if row_selection_allowed
      @list_selection_model.add_selection_interval ix0, ix1
    end
    def remove_row_selection_interval ix0, ix1
      @list_selection_model.remove_selection_interval ix0, ix1
    end
    def toggle_row_selection row=@current_index
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
    def do_next_selection
      return if selected_rows().length == 0 
      row = selected_rows().sort.find { |i| i > @current_index }
      row ||= @current_index
      @current_index = row
      @repaint_required = true # fire list_select XXX
    end
    def do_prev_selection
      return if selected_rows().length == 0 
      row = selected_rows().sort{|a,b| b <=> a}.find { |i| i < @current_index }
      row ||= @current_index
      @current_index = row
      @repaint_required = true # fire list_select XXX
    end
    alias :selected_index :selected_row
    attr_accessor :row_selection_allowed
    attr_accessor :column_selection_allowed
  end
  class ListSelectionEvent
    attr_accessor :firstrow, :lastrow, :source, :type
    def initialize firstrow, lastrow, source, type
      @firstrow = firstrow
      @lastrow = lastrow
      @source = source
      @type = type
    end
    def to_s
      "#{@type.to_s}, firstrow: #{@firstrow}, lastrow: #{@lastrow}, source: #{@source}"
    end
    def inspect
      to_s
    end
  end
end
