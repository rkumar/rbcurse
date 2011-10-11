=begin
  * Name: rtree: 
  * Description : a Tree control  
  * Author: rkumar (arunachalesha)
  * Date: 2010-09-18 12:02 
  * License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
  * This file started on 2010-09-18 12:03 (copied from rlistbox)
TODO:
   [x] load on tree will expand
   [x] selected row on startup
   [x] open up a node and make current on startup
   [ ] find string
   [/] expand all descendants
   ++ +- and +?
=end
require 'rbcurse'
require 'rbcurse/tree/treemodel'
require 'rbcurse/tree/treecellrenderer'

TreeSelectionEvent = Struct.new(:node, :tree, :state, :previous_node, :row_first)

#include Ncurses # FFI 2011-09-8 
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
    dsl_accessor :border_attrib, :border_color # FIXME not used currently

    attr_reader :toprow
  #  attr_reader :prow
  #  attr_reader :winrow
    dsl_accessor :default_value  # node to show as selected - what if user doesn't have it?
    attr_accessor :current_index
    dsl_accessor :selected_color, :selected_bgcolor, :selected_attr
    dsl_accessor :max_visible_items   # how many to display 2009-01-11 16:15 
    dsl_accessor :cell_editing_allowed # obsolete
    dsl_accessor :suppress_borders
    dsl_property :show_selector
    dsl_property :row_selected_symbol # 2009-01-12 12:01 changed from selector to selected
    dsl_property :row_unselected_symbol # added 2009-01-12 12:00 
    dsl_property :left_margin
    dsl_accessor :sanitization_required # 2011-10-6 
    #dsl_accessor :valign  # popup related
    #
    # will pressing a single key move to first matching row. setting it to false lets us use vim keys
    attr_accessor :one_key_selection # will pressing a single key move to first matching row
    # index of row selected, relates to internal representation, not tree. @see selected_row
    attr_reader :selected_index   # index of row that is selected. this relates to representation
    attr_reader :treemodel        # returns treemodel for further actions 2011-10-2 

    def initialize form, config={}, &block
      @focusable = true
      @editable = false
      @row = 0
      @col = 0
      # array representation of tree
      @list = nil
      # any special attribs such as status to be printed in col1, or color (selection)
      @list_attribs = {}
      # hash containing nodes that are expanded or once expanded
      # if value is true, then currently expanded, else once expanded
      # TODO : will need purging under some situations
      @expanded_state = {}
      @suppress_borders = false
      @row_offset = @col_offset = 1
      @current_index = 0
      super
      #@selection_mode ||= :single # default is multiple, anything else given becomes single
      @win = @graphic    # 2010-01-04 12:36 BUFFERED  replace form.window with graphic
      @sanitization_required = true
      @longest_line = 0
      
     
      @win_left = 0
      @win_top = 0
      @_events.push(*[:ENTER_ROW, :LEAVE_ROW, :TREE_COLLAPSED_EVENT, :TREE_EXPANDED_EVENT, :TREE_SELECTION_EVENT, :TREE_WILL_COLLAPSE_EVENT, :TREE_WILL_EXPAND_EVENT])

      
      bind(:PROPERTY_CHANGE){|e| @cell_renderer = nil } # will be recreated if anything changes 2011-09-28 V1.3.1  
      init_vars

      #if !@list.selected_index.nil? 
        #set_focus_on @list.selected_index # the new version
      #end
      @keys_mapped = false
    end
    def init_vars
      @repaint_required = true
      @toprow = @pcol = 0
      if @show_selector
        @row_selected_symbol ||= '>'
        @row_unselected_symbol ||= ' '
        @left_margin ||= @row_selected_symbol.length
      end
      @left_margin ||= 0
      @one_key_selection = true if @one_key_selection.nil?
      @height ||= 10
      @width  ||= 30
      @row_offset = @col_offset = 0 if @suppress_borders
      @internal_width = 2 # taking into account borders accounting for 2 cols
      @internal_width = 0 if @suppress_borders # should it be 0 ???

    end
    # maps keys to methods
    # checks @key_map can be :emacs or :vim.
    def map_keys
      @keys_mapped = true
      $log.debug " cam in XXXX  map keys"
      bind_key(32){ toggle_row_selection() }
      bind_key(KEY_RETURN) { toggle_expanded_state() }
      bind_key(?o) { toggle_expanded_state() }
      bind_key(?f){ ask_selection_for_char() }
      bind_key(?\M-v){ @one_key_selection = !@one_key_selection }
      bind_key(KEY_DOWN){ next_row() }
      bind_key(KEY_UP){ previous_row() }
      bind_key(?O){ expand_children() }
      bind_key(?X){ collapse_children() }
      bind_key(?>, :scroll_right)
      bind_key(?<, :scroll_left)
      bind_key(?\M-l, :scroll_right)
      bind_key(?\M-h, :scroll_left)
      # TODO
      bind_key(?x){ collapse_parent() }
      bind_key(?p){ goto_parent() }
      if $key_map == :emacs
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
    def row_count
      return 0 if @list.nil?
      @list.length
    end
    #  at what row should scrolling begin
    def scrollatrow
      if @suppress_borders
        return @height - 1
      else
        return @height - 3
      end
    end
    #
    # Sets the given node as root and returns treemodel.
    # Returns root if no argument given.
    # Now we return root if already set
    # Made node nillable so we can return root. 
    #
    # @raise ArgumentError if setting a root after its set
    #   or passing nil if its not been set.
    def root node=nil, asks_allow_children=false, &block
      if @treemodel
        return @treemodel.root unless node
        raise ArgumentError, "Root already set"
      end

      raise ArgumentError, "root: node cannot be nil" unless node
      @treemodel = RubyCurses::DefaultTreeModel.new(node, asks_allow_children, &block)
    end

    # pass data to create this tree model
    # used to be list
    def data alist=nil

      # if nothing passed, print an empty root, rather than crashing
      alist = [] if alist.nil?
      @data = alist # data given by user
      case alist
      when Array
        @treemodel = RubyCurses::DefaultTreeModel.new("/")
        @treemodel.root.add alist
      when Hash
        @treemodel = RubyCurses::DefaultTreeModel.new("/")
        @treemodel.root.add alist
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
      if @_structure_changed 
        @list = nil
        @_structure_changed = false
      end
      unless @list
        $log.debug " XXX recreating _list"
        convert_to_list @treemodel
        $log.debug " XXXX list: #{@list.size} : #{@list} "
      end
      return @list
    end
    def convert_to_list tree
      @list = get_expanded_descendants(tree.root)
      #$log.debug "XXX convert #{tree.root.children.size} "
      #$log.debug " converted tree to list. #{@list.size} "
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
    # return object under cursor
    # Note: this should not be confused with selected row/s. User may not have selected this.
    # This is only useful since in some demos we like to change a status bar as a user scrolls down
    # @since 1.2.0  2010-09-06 14:33 making life easier for others.
    def current_row
      @list[@current_index]
    end
    alias :text :current_row  # thanks to shoes, not sure how this will impact since widget has text.

    # show default value as selected and fire handler for it
    # This is called in repaint, so can raise an error if called on creation
    # or before repaint. Just set @default_value, and let us handle the rest.
    # Suggestions are welcome.
    def select_default_values
      return if @default_value.nil?
      # NOTE list not yet created
      raise "list has not yet been created" unless @list
      index = node_to_row @default_value
      raise "could not find node #{@default_value}, #{@list}  " unless index
      return unless index
      @current_index = index
      toggle_row_selection
      @default_value = nil
    end
    def print_borders
      width = @width
      height = @height-1 # 2010-01-04 15:30 BUFFERED HEIGHT
      window = @graphic  # 2010-01-04 12:37 BUFFERED
      startcol = @col 
      startrow = @row 
      @color_pair = get_color($datacolor)
#      bordercolor = @border_color || $datacolor # changed 2011 dts  
      bordercolor = @border_color || @color_pair # 2011-09-28 V1.3.1 
      borderatt = @border_attrib || Ncurses::A_NORMAL
                           
      window.print_border startrow, startcol, height, width, bordercolor, borderatt
      print_title
    end
    def print_title
      return unless @title
      _title = @title
      if @title.length > @width - 2
        _title = @title[0..@width-2]
      end
      @color_pair ||= get_color($datacolor)
      @graphic.printstring( @row, @col+(@width-_title.length)/2, _title, @color_pair, @title_attrib) unless @title.nil?
    end
    ### START FOR scrollable ###
    def get_content
      #@list 2008-12-01 23:13 
      @list_variable && @list_variable.value || @list 
      # called by next_match in listscrollable
      @list
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
      return if @list.nil? || @list.empty?
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
        ret = :UNHANDLED 
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
            $log.debug " TREE before process key #{ch} "
            ret = process_key ch, self
            $log.debug " TREE after process key #{ch} #{ret} "
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
      return RubyCurses::TreeCellRenderer.new "", {"color"=>@color, "bgcolor"=>@bgcolor, "parent" => self, "display_length"=> @width-@internal_width-@left_margin}
    end
    ##
    # this method chops the data to length before giving it to the
    # renderer, this can cause problems if the renderer does some
    # processing. also, it pans the data horizontally giving the renderer
    # a section of it.
    # FIXME: tree may not be clearing till end see appdirtree after divider movement
    def repaint
      return unless @repaint_required
    
      my_win = @form ? @form.window : @target_window
      @graphic = my_win unless @graphic
   
      raise " #{@name} neither form, nor target window given TV paint " unless my_win
      raise " #{@name} NO GRAPHIC set as yet                 TV paint " unless @graphic
      @win_left = my_win.left
      @win_top = my_win.top

      $log.debug "rtree repaint  #{@name} graphic #{@graphic}"
      print_borders unless @suppress_borders # do this once only, unless everything changes
      maxlen = @maxlen || @width-@internal_width
      maxlen -= @left_margin # 2011-10-6 
      tm = _list()
      select_default_values
      rc = row_count
      tr = @toprow
      acolor = get_color $datacolor
      h = scrollatrow()
      r,c = rowcol
      @longest_line = @width #maxlen
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
            if content.is_a? TreeNode
              node = content
              object = content
              leaf = node.is_leaf?
              # content passed is rejected by treecellrenderer 2011-10-6 
              content = node.user_object.to_s # may need to trim or truncate
              expanded = row_expanded? crow  
            elsif content.is_a? String
              $log.warn "Removed this entire block since i don't think it was used XXX  "
              # this block does not set object XXX
            else
              raise "repaint what is the class #{content.class} "
              content = content.to_s
            end
            # this is redundant since data is taken by renderer directly
            #sanitize content if @sanitization_required
            #truncate value
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
            renderer.display_length(@width-@internal_width-@left_margin) # just in case resizing of listbox
            renderer.pcol = @pcol
            #renderer.repaint @graphic, r+hh, c+@left_margin, crow, content, _focussed, selected
            renderer.repaint @graphic, r+hh, c+@left_margin, crow, object, content, leaf,  focus_type, selected, expanded
            @longest_line = renderer.actual_length if renderer.actual_length > @longest_line 
        else
          # clear rows
          @graphic.printstring r+hh, c, " " * (@width-@internal_width), acolor,@attr
        end
      end
      @table_changed = false
      @repaint_required = false
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
      @cols_panned ||= 0 # RFED16 2010-02-17 23:40 
      win_col = 0 
      col2 = win_col + @col + @col_offset + col1 + @cols_panned + @left_margin
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
      if node.nil?
        Ncurses.beep
        $log.debug " No such node on row #{row} "
        return
      end
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
    # convert a given node to row
    def node_to_row node
      crow = nil
      @list.each_with_index { |e,i| 
        if e == node
          crow = i
          break
        end
      }
      crow
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
      #$log.debug " expand called on #{node.user_object} "
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
    # this is required to make a node visible, if you wish to start from a node that is not root
    # e.g. you are loading app in a dir somewhere but want to show path from root down.
    # NOTE this sucks since you have to click 2 times to expand it.
    def mark_parents_expanded node
      # i am setting parents as expanded, but NOT firing handlers - XXX separate this into expand_parents
      _path = node.tree_path
      _path.each do |e| 
        # if already expanded parent then break we should break
        set_expanded_state(e, true) 
      end
    end
    # goes up to root of this node, and expands down to this node
    # this is often required to make a specific node visible such 
    # as in a dir listing when current dir is deep in heirarchy.
    def expand_parents node
      _path = node.tree_path
      _path.each do |e| 
        # if already expanded parent then break we should break
        #set_expanded_state(e, true) 
        expand_node(e)
      end
    end
    # this expands all the children of a node, recursively
    # we can't use multiplier concept here since we are doing a preorder enumeration
    # we need to do a breadth first enumeration to use a multiplier
    #
    def expand_children node=:current_index
      $multiplier = 999 if !$multiplier || $multiplier == 0
      node = row_to_node if node == :current_index
      return if node.children.empty? # or node.is_leaf?
      #node.children.each do |e| 
        #expand_node e # this will keep expanding parents
        #expand_children e
      #end
      node.breadth_each($multiplier) do |e|
        expand_node e
      end
      $multiplier = 0
      _structure_changed true
    end
    def collapse_children node=:current_index
      $multiplier = 999 if !$multiplier || $multiplier == 0
      $log.debug " CCCC IINSIDE COLLLAPSE"
      node = row_to_node if node == :current_index
      return if node.children.empty? # or node.is_leaf?
      #node.children.each do |e| 
        #expand_node e # this will keep expanding parents
        #expand_children e
      #end
      node.breadth_each($multiplier) do |e|
        $log.debug "CCC collapsing #{e.user_object}  "
        collapse_node e
      end
      $multiplier = 0
      _structure_changed true
    end
    # collapse parent
    # can use multiplier.
    # # we need to move up also
    def collapse_parent node=:current_index
      node = row_to_node if node == :current_index
      parent = node.parent
      return if parent.nil?
      goto_parent node
      collapse_node parent
    end
    def goto_parent node=:current_index
      node = row_to_node if node == :current_index
      parent = node.parent
      return if parent.nil?
      crow = @current_index
      @list.each_with_index { |e,i| 
        if e == parent
          crow = i
          break
        end
      }
      @repaint_required = true
      #set_form_row  # will not work if off form
      set_focus_on crow
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

    #
    # To retrieve the node corresponding to a path specified as an array or string
    # Do not mention the root.
    # e.g. "ruby/1.9.2/io/console"
    # or %w[ ruby 1.9.3 io console ]
    # @since 1.4.0 2011-10-2 
    def get_node_for_path(user_path)
      case user_path
      when String
        user_path = user_path.split "/"
      when Array
      else
        raise ArgumentError, "Should be Array or String delimited with /"
      end
      $log.debug "TREE #{user_path} " if $log.debug? 
      root = @treemodel.root
      found = nil
      user_path.each { |e| 
        success = false
        root.children.each { |c| 
          if c.user_object == e
            found = c
            success = true
            root = c
            break
          end
        }
        return false unless success

      }
      return found
    end
    private
    # please do not rely on this yet, name could change
    def _structure_changed tf=true
      @_structure_changed = tf
      @repaint_required = true
      #@list = nil
    end



    # ADD HERE
  end # class tree


end # module
