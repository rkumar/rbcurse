# File created: 2010-10-29 14:09 
# Author      : rkumar
#
# this is a new, simpler version of listselectable
# the original gets into models and has complicated operation as well
# as difficult to remember method names. This attempts to be a simple plugin.
# Currently being used by rbasiclistbox and now tabularwidget.
# NOTE: pls define @_header_adjustment to 0 if you don't use it or know what it means.
# TODO: of course we need to fire events so user can do something.
module RubyCurses
  module NewListSelectable

    # @group selection related

    # change selection of current row on pressing space bar
    # If mode is multiple, then other selections are cleared and this is added
    # @example
    #     bind_key(32) { toggle_row_selection }
    # current_index is not account for header_adjustment
    # if current row is selected in mulitple we should deselect ?? FIXME
    def toggle_row_selection crow=@current_index-@_header_adjustment
      @last_clicked = crow
      @repaint_required = true
      case @selection_mode 
      when :multiple
        @widget_scrolled = true # FIXME we need a better name
        if @selected_indices.include? crow
          @selected_indices.delete crow
          lse = ListSelectionEvent.new(crow, crow, self, :DELETE)
          fire_handler :LIST_SELECTION_EVENT, lse
        else
          @selected_indices << crow
          lse = ListSelectionEvent.new(crow, crow, self, :INSERT)
          fire_handler :LIST_SELECTION_EVENT, lse
        end
      else
        if @selected_index == crow 
          @old_selected_index = @selected_index # 2011-10-15 so we can unhighlight
          @selected_index = nil
          lse = ListSelectionEvent.new(crow, crow, self, :DELETE)
          fire_handler :LIST_SELECTION_EVENT, lse
        else
          @old_selected_index = @selected_index # 2011-10-15 so we can unhighlight
          @selected_index = crow 
          lse = ListSelectionEvent.new(crow, crow, self, :INSERT)
          fire_handler :LIST_SELECTION_EVENT, lse
        end
      end
    end
    #
    # Only for multiple mode.
    # add an item to selection, if selection mode is multiple
    # if item already selected, it is deselected, else selected
    # typically bound to Ctrl-Space
    # @example
    #     bind_key(0) { add_to_selection }
    def add_to_selection crow=@current_index-@_header_adjustment
      @last_clicked ||= crow
      min = [@last_clicked, crow].min
      max = [@last_clicked, crow].max
      case @selection_mode 
      when :multiple
        @widget_scrolled = true # FIXME we need a better name
        if @selected_indices.include? crow
          # delete from last_clicked until this one in any direction
          min.upto(max){ |i| @selected_indices.delete i }
          lse = ListSelectionEvent.new(min, max, self, :DELETE)
          fire_handler :LIST_SELECTION_EVENT, lse
        else
          # add to selection from last_clicked until this one in any direction
          min.upto(max){ |i| @selected_indices << i unless @selected_indices.include?(i) }
          lse = ListSelectionEvent.new(min, max, self, :INSERT)
          fire_handler :LIST_SELECTION_EVENT, lse
        end
      else
      end
      @repaint_required = true
      self
    end
    # clears selected indices, typically called when multiple select
    # Key binding is application specific
    def clear_selection
      return if @selected_indices.nil? || @selected_indices.empty?
      @selected_indices = []
      @selected_index = nil
      @old_selected_index = nil
      # Not sure what event type I should give, DELETE or a new one, user should
      #  understand that selection has been cleared, and ignore first two params
      lse = ListSelectionEvent.new(0, @list.size, self, :CLEAR)
      fire_handler :LIST_SELECTION_EVENT, lse
      @repaint_required = true
      @widget_scrolled = true # FIXME we need a better name
    end
    def is_row_selected crow=@current_index-@_header_adjustment
      case @selection_mode 
      when :multiple
        @selected_indices.include? crow
      else
        crow == @selected_index
      end
    end
    alias :is_selected? is_row_selected
    # FIXME add adjustment and test
    def goto_next_selection
      return if selected_rows().length == 0 
      row = selected_rows().sort.find { |i| i > @current_index }
      row ||= @current_index
      @current_index = row
      @repaint_required = true # fire list_select XXX
    end
    # FIXME add adjustment and test
    def goto_prev_selection
      return if selected_rows().length == 0 
      row = selected_rows().sort{|a,b| b <=> a}.find { |i| i < @current_index }
      row ||= @current_index
      @current_index = row
      @repaint_required = true # fire list_select XXX
    end
    # add the following range to selected items, unless already present
    # should only be used if multiple selection interval
    def add_selection_interval ix0, ix1
      return if @selection_mode != :multiple
      @widget_scrolled = true # FIXME we need a better name
      @anchor_selection_index = ix0
      @lead_selection_index = ix1
      ix0.upto(ix1) {|i| @selected_indices  << i unless @selected_indices.include? i }
      lse = ListSelectionEvent.new(ix0, ix1, self, :INSERT)
      fire_handler :LIST_SELECTION_EVENT, lse
      #$log.debug " DLSM firing LIST_SELECTION EVENT #{lse}"
    end
    alias :add_row_selection_interval :add_selection_interval
    def remove_selection_interval ix0, ix1
      @anchor_selection_index = ix0
      @lead_selection_index = ix1
      @selected_indices.delete_if {|x| x >= ix0 and x <= ix1}
      lse = ListSelectionEvent.new(ix0, ix1, self, :DELETE)
      fire_handler :LIST_SELECTION_EVENT, lse
    end
    alias :remove_row_selection_interval :remove_selection_interval
    # convenience method to select next len rows
    def insert_index_interval ix0, len
      @anchor_selection_index = ix0
      @lead_selection_index = ix0+len
      add_selection_interval @anchor_selection_index, @lead_selection_index
    end
    # select all rows, you may specify starting row.
    # if header row, then 1 else should be 0. Actually we should have a way to determine
    # this, and the default should be zero.
    def select_all start_row=0 #+@_header_adjustment
      @repaint_required = true
      # don't select header row - need to make sure this works for all cases. we may 
      # need a variable instead of hardoded value
      add_row_selection_interval start_row, row_count()
    end
    def invert_selection start_row=0 #+@_header_adjustment
      start_row.upto(row_count()){|i| invert_row_selection i }
    end
     
    def invert_row_selection row=@current_index-@_header_adjustment
      @repaint_required = true
      if is_selected? row
        remove_row_selection_interval(row, row)
      else
        add_row_selection_interval(row, row) 
      end
    end
    # selects all rows with the values given, leaving existing selections
    # intact. Typically used after accepting search criteria, and getting a list of values
    # to select (such as file names). Will not work with tables (array or array)
    def select_values values
      return unless values
      values.each do |val|
        row = @list.index val
        add_row_selection_interval row, row unless row.nil?
      end
    end
    # unselects all rows with the values given, leaving all other rows intact
    # You can map "-" to ask_select and call this from there.
    #   bind_key(?+, :ask_select) # --> calls select_values
    #   bind_key(?-, :ask_unselect)
    def unselect_values values
      return unless values
      values.each do |val|
        row = @list.index val
        remove_row_selection_interval row, row unless row.nil?
      end
    end
    # please override this, this is just very basic and default
    # Please implement get_matching_indices(String).
    def ask_select prompt="Enter selection pattern: "
      ret = ask(prompt, String) {|q| yield q if block_given? }
      return if ret.nil? || ret ==  ""
      indices = get_matching_indices ret
      return if indices.nil? || indices.empty?
      indices.each { |e|
        # will not work if single select !! FIXME
        add_row_selection_interval e,e
      }
      @repaint_required = true
    end
    def get_matching_indices pattern
      alert "please implement this method get_matching_indices(pattern)->[] in your class  "
      return []
    end # mod
    # Applications may call this or just copy and modify
    def list_bindings
      # what about users wanting 32 and ENTER to also go to next row automatically
      # should make that optional, TODO
      bind_key(32) { toggle_row_selection }
      bind_key(0) { add_to_selection }
      bind_key(?+, :ask_select) # --> calls select_values
      bind_key(?-, :ask_unselect) # please implement FIXME TODO
      bind_key(?a, :select_all)
      bind_key(?*, :invert_selection)
      bind_key(?u, :clear_selection)
      @_header_adjustment ||= 0 #  incase caller does not use
      @_events << :LIST_SELECTION_EVENT unless @_events.include? :LIST_SELECTION_EVENT
    end
    def list_init_vars
      @selected_indices = []
      @selected_index = nil
      @old_selected_index = nil
      #@row_selected_symbol = ''
      if @show_selector
        @row_selected_symbol ||= '*'
        @row_unselected_symbol ||= ' '
        @left_margin ||= @row_selected_symbol.length
      end
    end
    # paint the selector. Called from repaint, prior to printing data row
    # remember to set left_margin at top of repaint method as:
    #    @left_margin ||= @row_selected_symbol.length
    def paint_selector crow, r, c, acolor, attrib
      selected = is_row_selected crow
      selection_symbol = ''
      if @show_selector
        if selected
          selection_symbol = @row_selected_symbol
        else
          selection_symbol =  @row_unselected_symbol
        end
        @graphic.printstring r, c, selection_symbol, acolor,attrib
      end
    end
    def selected_rows
      @selected_indices
    end
  end # mod
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
end # mod
