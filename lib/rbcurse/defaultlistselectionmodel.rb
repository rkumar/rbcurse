module RubyCurses
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
      if @selection_mode != :MULTIPLE
        clear_selection
      end
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
end
