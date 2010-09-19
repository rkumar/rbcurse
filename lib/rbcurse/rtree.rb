=begin
  * Name: rtree: 
  * Description : a Tree control  
  * Author: rkumar (arunachalesha)
  * Date: 2010-09-18 12:02 
  * License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
  * This file started on 2010-09-18 12:03 (copied from rlistbox)
=end
require 'rbcurse'
require 'rbcurse/tree/treemodel'
require 'rbcurse/tree/treecellrenderer'
#require 'forwardable'

TreeArrayNode = Struct.new(:node, :level) # knock off TODO
TreeSelectionEvent = Struct.new(:node, :tree, :state, :previous_node, :row_first)

include Ncurses
module RubyCurses
  extend self
  # a representation of heirarchical data in outline form
  # Currently supports only single selection, and does not allow editing.
  # @events Events: SELECT, DESELECT, TREE_WILL_EXPAND_EVENT, TREE_COLLAPSED_EVENT
  #
  class Tree < Widget
    require 'rbcurse/listscrollable'
    # currently just use single selection
    include ListScrollable
    #extend Forwardable
    dsl_accessor :height
    dsl_accessor :title
    dsl_property :title_attrib   # bold, reverse, normal
    attr_reader :toprow
  #  attr_reader :prow
  #  attr_reader :winrow
    dsl_accessor :default_values  # array of default values
    attr_accessor :current_index
    dsl_accessor :selected_color, :selected_bgcolor, :selected_attr
    dsl_accessor :max_visible_items   # how many to display 2009-01-11 16:15 
    dsl_accessor :cell_editing_allowed
    dsl_property :show_selector
    dsl_property :row_selected_symbol # 2009-01-12 12:01 changed from selector to selected
    dsl_property :row_unselected_symbol # added 2009-01-12 12:00 
    dsl_property :left_margin
    # please set these in he constructor block. Settin them later will have no effect
    # since i would have bound them to actions
    # FIXME this is crap, remove it.
    dsl_accessor :valign  # 2009-01-17 18:32  XXX ???
    #
    # will pressing a single key move to first matching row. setting it to false lets us use vim keys
    attr_accessor :one_key_selection # will pressing a single key move to first matching row
    # index of row selected, relates to internal representation, not tree. @see selected_row
    attr_reader :selected_index   # index of row that is selected. this relates to representation

    def initialize form, config={}, &block
      @focusable = true
      @editable = false
      @row = 0
      @col = 0
      # array representation of tree
      @list = []
      # any special attribs such as status to be printed in col1, or color (selection)
      @list_attribs = {}
      @expanded_state = {}
      super
      @current_index ||= 0
      @row_offset = @col_offset = 1
      @content_rows = @list.length
      #@selection_mode ||= :single # default is multiple, anything else given becomes single
      @win = @graphic    # 2010-01-04 12:36 BUFFERED  replace form.window with graphic
      # moving down to repaint so that scrollpane can set should_buffered
      # added 2010-02-17 23:05  RFED16 so we don't need a form.
      @win_left = 0
      @win_top = 0

      select_default_values

      #install_keys ## FIXME kill this crap
      init_vars

      #if !@list.selected_index.nil? 
        #set_focus_on @list.selected_index # the new version
      #end
      @keys_mapped = false
    end
    def init_vars
      @to_print_borders ||= 1
      @repaint_required = true
      @toprow = @pcol = 0
      if @show_selector
        @row_selected_symbol ||= '>'
        @row_unselected_symbol ||= ' '
        @left_margin ||= @row_selected_symbol.length
      end
      @left_margin ||= 0
      @one_key_selection = false if @one_key_selection.nil?

    end
    # maps keys to methods
    # checks @key_map can be :emacs or :vim.
    def map_keys
      @keys_mapped = true
      $log.debug " cam in XXXX  map keys"
      bind_key(32){ toggle_row_selection() }
      bind_key(KEY_RETURN) { toggle_expanded_state() }
      bind_key(?f){ ask_selection_for_char() }
      bind_key(?\M-v){ @one_key_selection = true }
      bind_key(KEY_DOWN){ next_row() }
      bind_key(KEY_UP){ previous_row() }
      if @key_map == :emacs
        $log.debug " EMACSam in XXXX  map keys"
        bind_key(?\C-v){ scroll_forward }
        bind_key(?\M-v){ scroll_backward }
        bind_key(?\C-s){ ask_search() }
        bind_key(?\C-n){ next_row() }
        bind_key(?\C-p){ previous_row() }
        bind_key(?\M->){ goto_bottom() }
        bind_key(?\M-<){ goto_top() }
      else # :vim
        $log.debug " VIM cam in XXXX  map keys"
        bind_key(?j){ next_row() }
        bind_key(?k){ previous_row() }
        bind_key(?\C-d){ scroll_forward }
        bind_key(?\C-b){ scroll_backward }
        bind_key(?G){ goto_bottom() }
        bind_key([?g,?g]){ goto_top() }
        bind_key(?/){ ask_search() }
      end

    end

    ##
    # getter and setter for selection_mode
    # Must be called after creating model, so no duplicate. Since one may set in model directly.
    #def selection_mode(*val)
      #raise "ListSelectionModel not yet created!" if @list_selection_model.nil?
      #if val.empty?
        #@list_selection_model.selection_mode
      #else
        #@list_selection_model.selection_mode = val[0] 
      #end
    #end
    def row_count
      @list.length
    end
    # added 2009-01-07 13:05 so new scrollable can use
    def scrollatrow
      #@height - 2
      @height - 3 # 2010-01-04 15:30 BUFFERED HEIGHT
    end
    # used to be list
    def data alist=nil
      return @treemodel if alist.nil?
      @data = alist # data given by user
      case alist
      when Array

      when Hash
      when TreeNode
        # this is a root node
        @treemodel = RubyCurses::DefaultTreeModel.new(alist)
      when DefaultTreeModel
        @treemodel = alist
      else
        if alist.is_a? DefaultTreeModel
          @treemodel = alist
        else
          raise ArgumentError, "Tree does not know how to handle #{alist.class} "
        end
      end
      # we now have a tree
      raise "I still don't have a tree" unless @treemodel
      set_expanded_state(@treemodel.root, true)
      convert_to_list @treemodel
      
      # added on 2009-01-13 23:19 since updates are not automatic now
      #@list.bind(:LIST_DATA_EVENT) { |e| list_data_changed() }
      #create_default_list_selection_model TODO
    end
    # private, for use by repaint
    def _list
      unless @list
        $log.debug " XXX recreating _list"
        convert_to_list @treemodel
        $log.debug " XXXX list: #{@list.size} : #{@list} "
      end
      return @list
    end
    def convert_to_list tree
      @list = get_expanded_descendants(tree.root)
      $log.debug " convert #{tree.root.children.size} "
      #traverse tree.root, 0 do |n, level|
        #@list << TreeArrayNode.new(n,level)
      #end
      $log.debug " converted tree to list. #{@list.size} "
    end
    def traverse node, level=0, &block
      raise "disuse"
      #icon = node.is_leaf? ? "-" : "+"
      #puts "%*s %s" % [ level+1, icon,  node.user_object ]
      yield node, level if block_given?
      node.children.each do |e| 
        traverse e, level+1, &block
      end
    end
    #def list_variable alist=nil
      #return @list if alist.nil?
      #@list = RubyCurses::DefaultTreeModel.new(alist.value)
      ## added on 2009-01-13 23:19 since updates are not automatic now
      #@list.bind(:LIST_DATA_EVENT) { |e| list_data_changed() }
      #create_default_list_selection_model
    #end
    #def list_data_model ldm=nil
      #return @list if ldm.nil?
      #raise "Expecting list_data_model" unless ldm.is_a? RubyCurses::DefaultTreeModel
      #@list = ldm
      ## added on 2009-01-13 23:19 since updates are not automatic now
      #@list.bind(:LIST_DATA_EVENT) { |e| list_data_changed() }
      #create_default_list_selection_model
    #end
    # added 2010-09-15 00:11 to make life easier
    #def_delegators :@list, :insert, :remove_all, :delete_at, :include?
    # get element at
    # @param [Fixnum] index for element
    # @return [Object] element
    # @since 1.2.0  2010-09-06 14:33 making life easier for others.
    def [](off0)
      @list[off0]
    end
    # return object under cursor
    # Note: this should not be confused with selected row/s. User may not have selected this.
    # This is only useful since in some demos we like to change a status bar as a user scrolls down
    # @since 1.2.0  2010-09-06 14:33 making life easier for others.
    def current_row
      @list[@current_index]
    end
    alias :text :current_row  # thanks to shoes, not sure how this will impact since widget has text.

    def select_default_values
      return if @default_values.nil?
      @default_values.each do |val|
        row = @list.index val
        #do_select(row) unless row.nil?
        add_row_selection_interval row, row unless row.nil?
      end
    end
    def print_borders
      width = @width
      height = @height-1 # 2010-01-04 15:30 BUFFERED HEIGHT
      window = @graphic  # 2010-01-04 12:37 BUFFERED
      startcol = @col 
      startrow = @row 
      @color_pair = get_color($datacolor)
      #$log.debug "rlistb #{name}: window.print_border #{startrow}, #{startcol} , h:#{height}, w:#{width} , @color_pair, @attr "
      window.print_border startrow, startcol, height, width, @color_pair, @attr
      print_title
    end
    def print_title
      #printstring(@graphic, @row, @col+(@width-@title.length)/2, @title, @color_pair, @title_attrib) unless @title.nil?
      # 2010-01-04 15:53 BUFFERED
      # I notice that the old version would print a title that was longer than width,
      #+ but the new version won't print anything if it exceeds width.
      # TODO check title.length and truncate if exceeds width
      @graphic.printstring( @row, @col+(@width-@title.length)/2, @title, @color_pair, @title_attrib) unless @title.nil?
    end
    ### START FOR scrollable ###
    def get_content
      #@list 2008-12-01 23:13 
      @list_variable && @list_variable.value || @list 
    end
    def get_window
      @graphic # 2010-01-04 12:37 BUFFERED
    end
    ### END FOR scrollable ###
    # override widgets text
    def getvalue
      selected_row()
    end
    # Listbox
    def handle_key(ch)
      @current_index ||= 0
      @toprow ||= 0
      map_keys unless @keys_mapped
      h = scrollatrow()
      rc = row_count
      $log.debug " tree got ch #{ch}"
      case ch
      when 27, ?\C-c.getbyte(0)
        #editing_canceled @current_index if @cell_editing_allowed
        #cancel_block # block
        $multiplier = 0
        return 0
      #when ?\C-u.getbyte(0)
        # multiplier. Series is 4 16 64
        # TESTING @multiplier = (@multiplier == 0 ? 4 : @multiplier *= 4)
      #  return 0
      when ?\C-c.getbyte(0)
        @multiplier = 0
        return 0
      else
        # this has to be fixed, if compo does not handle key it has to continue into next part FIXME
        ret = :UNHANDLED # changed on 2009-01-27 13:14 not going into unhandled, tab not released
        #if @cell_editing_allowed
          #@repaint_required = true
          ## hack - on_enter_row should fire when this widget gets focus. first row that is DONE
          #begin
            #ret = @cell_editor.component.handle_key(ch)
          #rescue
            #on_enter_row @current_index
            #ret = @cell_editor.component.handle_key(ch)
          #end
        #end
        if ret == :UNHANDLED
          # beware one-key eats up numbers. we'll be wondering why
          if @one_key_selection
            case ch
            #when ?A.getbyte(0)..?Z.getbyte(0), ?a.getbyte(0)..?z.getbyte(0), ?0.getbyte(0)..?9.getbyte(0)
            when ?A.getbyte(0)..?Z.getbyte(0), ?a.getbyte(0)..?z.getbyte(0)
              # simple motion, key press defines motion
              ret = set_selection_for_char ch.chr
            else
              ret = process_key ch, self
              @multiplier = 0
              return :UNHANDLED if ret == :UNHANDLED
            end
          else
            # no motion on single key, we can freak out like in vim, pref f <char> for set_selection
            case ch
            when ?0.getbyte(0)..?9.getbyte(0)
              $multiplier *= 10 ; $multiplier += (ch-48)
              #$log.debug " setting mult to #{$multiplier} in list "
              return 0
            end
            ret = process_key ch, self
            #$multiplier = 0 # 2010-09-02 22:35 this prevents parent from using mult
            return :UNHANDLED if ret == :UNHANDLED
          end
        end
      end
      $multiplier = 0
    end
    # get a keystroke from user and go to first item starting with that key
    def ask_selection_for_char
      ch = @graphic.getch
      if ch < 0 || ch > 255
        return :UNHANDLED
      end
      ret = set_selection_for_char ch.chr
    end
    def ask_search_forward
        regex =  get_string("Enter regex to search")
        ix = @list.find_match regex
        if ix.nil?
          alert("No matching data for: #{regex}")
        else
          set_focus_on(ix)
        end
    end
    # gets string to search and calls data models find prev
    def ask_search_backward
      regex =  get_string("Enter regex to search (backward)")
      @last_regex = regex
      ix = @list.find_prev regex, @current_index
      if ix.nil?
        alert("No matching data for: #{regex}")
      else
        set_focus_on(ix)
      end
    end
    # please check for error before proceeding
    # @return [Boolean] false if no data
    def on_enter
      if @list.size < 1
        Ncurses.beep
        return false
      end
      on_enter_row @current_index
      set_form_row # added 2009-01-11 23:41 
      #$log.debug " ONE ENTER LIST #{@current_index}, #{@form.row}"
      @repaint_required = true
      super
      #fire_handler :ENTER, self
      true
    end
    def on_enter_row arow
      #$log.debug " Listbox #{self} ENTER_ROW with curr #{@current_index}. row: #{arow} H: #{@handler.keys}"
      #fire_handler :ENTER_ROW, arow
      fire_handler :ENTER_ROW, self
      #@list.on_enter_row self TODO
      #edit_row_at arow
      @repaint_required = true
    end
    ## 
    def on_leave_row arow
      #$log.debug " Listbox #{self} leave with (cr: #{@current_index}) #{arow}: list[row]:#{@list[arow]}"
      #$log.debug " Listbox #{self} leave with (cr: #{@current_index}) #{arow}: "
      #fire_handler :LEAVE_ROW, arow
      fire_handler :LEAVE_ROW, self
      #editing_completed arow
    end

    ##
    # getter and setter for cell_renderer
    def cell_renderer(*val)
      if val.empty?
        @cell_renderer ||= create_default_cell_renderer
      else
        @cell_renderer = val[0] 
      end
    end
    def create_default_cell_renderer
      return RubyCurses::TreeCellRenderer.new "", {"color"=>@color, "bgcolor"=>@bgcolor, "parent" => self, "display_length"=> @width-2-@left_margin}
    end
    ##
    # this method chops the data to length before giving it to the
    # renderer, this can cause problems if the renderer does some
    # processing. also, it pans the data horizontally giving the renderer
    # a section of it.
    def repaint
      safe_create_buffer # 2010-01-04 12:36 BUFFERED moved here 2010-01-05 18:07 
      return unless @repaint_required
      # not sure where to put this, once for all or repeat 2010-02-17 23:07 RFED16
      my_win = @form ? @form.window : @target_window
      @graphic = my_win unless @graphic
      #$log.warn "neither form not target window given!!! TV paint 368" unless my_win
      raise " #{@name} neither form, nor target window given TV paint " unless my_win
      raise " #{@name} NO GRAPHIC set as yet                 TV paint " unless @graphic
      @win_left = my_win.left
      @win_top = my_win.top

      $log.debug "VIM rlistbox repaint  #{@name} graphic #{@graphic}"
      print_borders if @to_print_borders == 1 # do this once only, unless everything changes
      maxlen = @maxlen ||= @width-2
      tm = _list()
      rc = row_count
      tr = @toprow
      acolor = get_color $datacolor
      h = scrollatrow()
      r,c = rowcol
      0.upto(h) do |hh|
        crow = tr+hh
        if crow < rc
            _focussed = @current_index == crow ? true : false  # row focussed ?
            focus_type = _focussed 
            # added 2010-09-02 14:39 so inactive fields don't show a bright focussed line
            #focussed = false if focussed && !@focussed
            focus_type = :SOFT_FOCUS if _focussed && !@focussed
            selected = row_selected? crow 
            content = tm[crow]   # 2009-01-17 18:37 chomp giving error in some cases says frozen
            if content.is_a? TreeArrayNode
              raise "deprecate !"
              node = content.node
              object = content
              leaf = node.is_leaf?
              content = node.user_object.to_s # may need to trim or truncate
              expanded = row_expanded? crow 
            elsif content.is_a? TreeNode
              node = content
              object = content
              leaf = node.is_leaf?
              content = node.user_object.to_s # may need to trim or truncate
              expanded = row_expanded? crow  
            elsif content.is_a? String
              content = content.dup
              content.chomp!
              content.gsub!(/\t/, '  ') # don't display tab
              content.gsub!(/[^[:print:]]/, '')  # don't display non print characters
              if !content.nil? 
                if content.length > maxlen # only show maxlen
                  content = content[@pcol..@pcol+maxlen-1] 
                else
                  content = content[@pcol..-1]
                end
              end
            else
              raise "repaint what is the class #{content.class} "
              content = content.to_s
            end
            ## set the selector symbol if requested
            selection_symbol = ''
            if @show_selector
              if selected
                selection_symbol = @row_selected_symbol
              else
                selection_symbol =  @row_unselected_symbol
              end
              @graphic.printstring r+hh, c, selection_symbol, acolor,@attr
            end
            renderer = cell_renderer()
            #renderer.repaint @graphic, r+hh, c+@left_margin, crow, content, _focussed, selected
            $log.debug " calling XXXX renderer for #{content} "
            renderer.repaint @graphic, r+hh, c+@left_margin, crow, object, content, leaf,  focus_type, selected, expanded
        else
          # clear rows
          @graphic.printstring r+hh, c, " " * (@width-2), acolor,@attr
        end
      end
      @table_changed = false
      @repaint_required = false
      @buffer_modified = true # required by form to call buffer_to_screen BUFFERED
      buffer_to_window # RFED16 2010-02-17 23:16 
    end
    def list_data_changed
      if row_count == 0 # added on 2009-02-02 17:13 so cursor not hanging on last row which could be empty
        init_vars
        @current_index = 0
        set_form_row
      end
      @repaint_required = true
    end
    def set_form_col col1=0
      # TODO BUFFERED use setrowcol @form.row, col
      # TODO BUFFERED use cols_panned
      @cols_panned ||= 0 # RFED16 2010-02-17 23:40 
      # editable listboxes will involve changing cursor and the form issue
      ## added win_col on 2010-01-04 23:28 for embedded forms BUFFERED TRYING OUT
      #win_col=@form.window.left
      win_col = 0 # 2010-02-17 23:19 RFED16
      #col = win_col + @orig_col + @col_offset + @curpos + @form.cols_panned
      col2 = win_col + @col + @col_offset + col1 + @cols_panned + @left_margin
      $log.debug " set_form_col in rlistbox #{@col}+ left_margin #{@left_margin} ( #{col2} ) "
      #super col+@left_margin
      #@form.setrowcol @form.row, col2   # added 2009-12-29 18:50 BUFFERED
      setrowcol nil, col2 # 2010-02-17 23:19 RFED16
    end
    def selected_row
      @list[@selected_index].node
    end

    # An event is thrown when a row is selected or deselected.
    # Please note that when a row is selected, another one is automatically deselected.
    # An event is not thrown for that since your may not want to collapse that.
    # Only clicking on a selected row, will send a DESELECT on it since you may want to collapse it.
    # However, the previous selection is also present in the event object, so you can act upon it.
    # This is not used for expanding or collapsing, only for application to show some data in another
    # window or pane based on selection. Maybe there should not be a deselect for current row ?
    def toggle_row_selection
      node = @list[@current_index]
      previous_node = nil
      previous_node = @list[@selected_index] if @selected_index
      if @selected_index == @current_index
        @selected_index = nil
      else
        @selected_index = @current_index
      end
      state = @selected_index.nil? ? :DESELECTED : :SELECTED
#TreeSelectionEvent = Struct.new(:node, :tree, :state, :previous_node, :row_first)
      @tree_selection_event = TreeSelectionEvent.new(node, self, state, previous_node, @current_index) #if @item_event.nil?
      fire_handler :TREE_SELECTION_EVENT, @tree_selection_event # should the event itself be ITEM_EVENT
      $log.debug " XXX tree selected #{@selected_index}/ #{@current_index} , #{state} "
      @repaint_required = true
    end
    def toggle_expanded_state row=@current_index
      state = row_expanded? row
      node  = row_to_node
      $log.debug " toggle XXX state #{state} #{node} "
      if state
        collapse_node node
      else
        expand_node node
      end
    end
    def row_to_node row=@current_index
      @list[row]
    end
    # private
    # related to index in representation, not tree
    def row_selected? row
      @selected_index == row
    end
    # @return [TreeNode, nil] returns selected node or nil
 
    def row_expanded? row
      node = @list[row]
      node_expanded? node
    end
    def row_collapsed? row
      !row_expanded? row
    end
    def set_expanded_state(node, state)
      @expanded_state[node] = state
      @repaint_required = true
      _structure_changed true
    end
    def expand_node(node)
      $log.debug " expand called on #{node.user_object} "
      state = true
      fire_handler :TREE_WILL_EXPAND_EVENT, node
      set_expanded_state(node, state)
      fire_handler :TREE_EXPANDED_EVENT, node
    end
    def collapse_node(node)
      $log.debug " collapse called on #{node.user_object} "
      state = false
      fire_handler :TREE_WILL_COLLAPSE_EVENT, node
      set_expanded_state(node, state)
      fire_handler :TREE_COLLAPSED_EVENT, node
    end
    def has_been_expanded node
      @expanded_state.has_key? node
    end
    def node_expanded? node
      @expanded_state[node] == true
    end
    def node_collapsed? node
      !node_expanded?(node)
    end
    def get_expanded_descendants(node)
      nodes = []
      nodes << node
      traverse_expanded node, nodes
      $log.debug " def get_expanded_descendants(node) #{nodes.size} "
      return nodes
    end
    def traverse_expanded node, nodes
      return if !node_expanded? node
      #nodes << node
      node.children.each do |e| 
        nodes << e
        if node_expanded? e
          traverse_expanded e, nodes
        else
          next
        end
      end
    end
    def OLDtraverse_expanded node, nodes
      if node_expanded? node
        nodes << node
      else
        return
      end
      node.children.each do |e| 
        traverse_expanded e, nodes
      end
    end
    private
    # please do not rely on this yet, name could change
    def _structure_changed tf=true
      @_structure_changed = tf
      @list = nil
    end


    # ADD HERE
  end # class tree


end # module
