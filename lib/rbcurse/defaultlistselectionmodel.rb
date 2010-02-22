require 'rbcurse/listselectable'
##
# Added ListSelectionEvents on 2009-02-13 23:33 
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
      @selection_mode = 'multiple'
      $log.debug " created DefaultListSelectionModel XXX"
    end

    def clear_selection
      ix0 = @selected_indices.first
      ix1 = @selected_indices.last
      @selected_indices=[]
      lse = ListSelectionEvent.new(ix0, ix1, self, :DELETE)
      fire_handler :LIST_SELECTION_EVENT, lse
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
      $log.debug " def add_selection_interval #{ix0}, #{ix1}, mode: #{@selection_mode} "
      if @selection_mode != 'multiple'
        clear_selection
      end
      @anchor_selection_index = ix0
      @lead_selection_index = ix1
      ix0.upto(ix1) {|i| @selected_indices  << i unless @selected_indices.include? i }
      lse = ListSelectionEvent.new(ix0, ix1, self, :INSERT)
      fire_handler :LIST_SELECTION_EVENT, lse
      $log.debug " DLSM firing LIST_SELECTION EVENT #{lse}"
    end
    def remove_selection_interval ix0, ix1
      @anchor_selection_index = ix0
      @lead_selection_index = ix1
      @selected_indices.delete_if {|x| x >= ix0 and x <= ix1}
      lse = ListSelectionEvent.new(ix0, ix1, self, :DELETE)
      fire_handler :LIST_SELECTION_EVENT, lse
    end
    def insert_index_interval ix0, len
      @anchor_selection_index = ix0
      @lead_selection_index = ix0+len
      add_selection_interval @anchor_selection_index, @lead_selection_index
    end
  end # class DefaultListSelectionModel
end
