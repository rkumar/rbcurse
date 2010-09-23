require 'rbcurse/listselectable'
##
# Added ListSelectionEvents on 2009-02-13 23:33 
# Data model for list selections. Uses index or indices, or value/values. Please avoid using "row"
# as this is not clear to user, and will be deprecated.
# 2010-09-21 19:43 source now contains List object, not this class

module RubyCurses
  class DefaultListSelectionModel
    include EventHandler
    attr_accessor :selection_mode
    attr_reader :anchor_selection_index
    attr_reader :lead_selection_index
    attr_reader :parent
    def initialize parent
      raise ArgumentError "Parent cannot be nil. Please pass List while creating" if parent.nil?
      @parent  = parent

      @selected_indices=[]
      @anchor_selection_index = -1
      @lead_selection_index = -1
      @selection_mode = 'multiple'
      @_events = [:LIST_SELECTION_EVENT]

      #$log.debug " created DefaultListSelectionModel XXX"
    end
     #def event_list
       #return @@events if defined? @@events
       #nil
     #end

    def clear_selection
      ix0 = @selected_indices.first
      ix1 = @selected_indices.last
      @selected_indices=[]
      return if ix0.nil?
      lse = ListSelectionEvent.new(ix0, ix1, @parent, :DELETE)
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
    def get_selected_indices
      @selected_indices
    end
    alias :get_selected_rows :get_selected_indices
    ## TODO should go in sorted, and no dupes
    def add_selection_interval ix0, ix1
      $log.debug " def add_selection_interval #{ix0}, #{ix1}, mode: #{@selection_mode} "
      if @selection_mode != :multiple
        clear_selection
      end
      @anchor_selection_index = ix0
      @lead_selection_index = ix1
      ix0.upto(ix1) {|i| @selected_indices  << i unless @selected_indices.include? i }
      lse = ListSelectionEvent.new(ix0, ix1, @parent, :INSERT)
      fire_handler :LIST_SELECTION_EVENT, lse
      $log.debug " DLSM firing LIST_SELECTION EVENT #{lse}"
    end
    def remove_selection_interval ix0, ix1
      @anchor_selection_index = ix0
      @lead_selection_index = ix1
      @selected_indices.delete_if {|x| x >= ix0 and x <= ix1}
      lse = ListSelectionEvent.new(ix0, ix1, @parent, :DELETE)
      fire_handler :LIST_SELECTION_EVENT, lse
    end
    def insert_index_interval ix0, len
      @anchor_selection_index = ix0
      @lead_selection_index = ix0+len
      add_selection_interval @anchor_selection_index, @lead_selection_index
    end
  end # class DefaultListSelectionModel
end
