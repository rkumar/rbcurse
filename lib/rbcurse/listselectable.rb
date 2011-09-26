# this is a companion file to defaultlistselectionmodel
# if you use that, include this to get all the methods to use it
module RubyCurses
  module ListSelectable

    ## modified on 2009-02-13 23:41 to return model if no param passed
    # sets or returns a list selection model
    # Also listbox listens to it for selections, so it can tell those
    # who are interested 2010-09-21 16:02  
    def list_selection_model(*lsm)
      if lsm.empty?
        @list_selection_model 
      else
        @list_selection_model = lsm[0]
        # the listbox is listening to selection events on the
        # selection model and will inform any listeners of the same.
        @list_selection_model.bind :LIST_SELECTION_EVENT do |ev|
          fire_handler :LIST_SELECTION_EVENT, ev
        end
      end
      #@list_selection_model.selection_mode = @selection_mode || :MULTIPLE
    end
    def is_selected? row
      @list_selection_model.is_selected_index row
    end
    # this is the old name, should be deprecated
    alias :is_row_selected :is_selected?

    def add_row_selection_interval ix0, ix1
      $log.debug " def add_row_selection_interval #{ix0}, #{ix1}"
      # if row_selection_allowed
      @list_selection_model.add_selection_interval ix0, ix1
      @repaint_required = true
    end
    def remove_row_selection_interval ix0, ix1
      @list_selection_model.remove_selection_interval ix0, ix1
    end
    def toggle_row_selection row=@current_index
      if is_selected? row
        #$log.debug " deleting row #{row}"
        remove_row_selection_interval(row, row)
      else
        #$log.debug " adding row #{row}"
        add_row_selection_interval(row, row) 
      end
      @repaint_required = true 
    end

    def clear_selection
      @list_selection_model.clear_selection
      @repaint_required = true
    end
    # why is this commented off XXX could it override listscrollable
    #def selected_item
      #$log.warn "came in dummy selected_item of listselectable.rb"
    #  @list[@current_index]
    #end
    # returns selected indices
    # TODO : if array passed, set those as selected indices
    def selected_rows
      @list_selection_model.get_selected_rows
    end
    def selected_row_count
      selected_rows.size
    end
    # returns index of first selected row (lowest index)
    # TODO: if param passed set that as selected_index
    def selected_row
      @list_selection_model.get_min_selection_index
    end
    alias :selected_index :selected_row

    # returns value of first selected row (lowest index)
    def selected_value
      #@list[@current_index].to_s # old behavior since curr row was in reverse
      return nil if selected_row().nil?
      @list[selected_row()].to_s
    end
    # returns an array of selected values
    # or yields values to given block
    def selected_values &block
      ar = []
      selected_rows().each do |i|
        val = @list[i]
        if block_given?
          yield val
        else
          ar << val
        end
      end
      return ar unless block_given?
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
    # NOTE: I HAD removed this and put in listbox, but its required by rtable also
    # create a default list selection model and set it
    # NOTE: I am now checking if one is not already created, since
    # a second creation would wipe out any listeners on it.
    # @see ListSelectable 
    # @see DefaultListSelectionModel
    def create_default_list_selection_model
      if @list_selection_model.nil?
        list_selection_model DefaultListSelectionModel.new(self)
      end
    end
    alias :selected_index :selected_row
    attr_accessor :row_selection_allowed
    attr_accessor :column_selection_allowed
  end
  # class containing information relating to selections on a list
  #  2010-09-21 19:46 NOTE: Earlier source contained the model object, now it returns the parent
  #  You may do source.list_data_model() to get the model
  #  Typical operations on source would get selected_value(s), or selected_index
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
