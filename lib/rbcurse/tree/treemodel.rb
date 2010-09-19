# File TreeModel
# (c) rkumar arunachalesha
# Created on: Fri Sep 17 20:03:10 IST 2010
require 'rbcurse'

module RubyCurses
  class DefaultTreeModel #< TreeModel
    include RubyCurses::EventHandler 
    attr_reader :root
    attr_reader :asks_allow_children
    attr_accessor :root_visible
    def initialize node, asks_allow_children=false, &block
      @asks_allow_children = asks_allow_children
      @root_visible        = true
      _set_root_node node
      instance_eval &block if block_given?
    end
    # insert a node the old sucky java pain in the butt way
    # private
    # sets node as root
    def _set_root_node node
      if !node.is_a? TreeNode
        n = TreeNode.new node
        node = n
      end
      @root = node
    end
    def insert_node_into nodechild, nodeparent, index
      $log.debug " TODO remove from existing parent to avoid bugs XXX"
      nodeparent.insert nodechild, index
      if @handler # only if someone is listening, won't fire when being prepared
        tme = TreeModelEvent.new(row, row,:ALL_COLUMNS,  self, :INSERT)
        fire_handler :TREE_MODEL_EVENT, tme
      end
    end
    # add a node to root passing a block optionally
    # @see TreeNode.add
    def add nodechild, allow_children=true, &block
      # calling TreeNode.add
      @root.add nodechild, allow_children, &block
      if @handler # only if someone is listening, won't fire when being prepared
        tme = TreeModelEvent.new(row, row,:ALL_COLUMNS,  self, :INSERT)
        fire_handler :TREE_MODEL_EVENT, tme
      end
      return @root
    end
    alias :<< :add
    def insert row, obj
      @data.insert row, obj
      if @handler # only if someone is listening, won't fire when being prepared
        tme = TreeModelEvent.new(row, row,:ALL_COLUMNS,  self, :INSERT)
        fire_handler :TREE_MODEL_EVENT, tme
      end
    def child_at parent, index
    end
    def index_of_child parent, child
    end
    def child_count node
      node.children.size
    end

    def row_count
      @data.length
    end
    # 
    def set_value_at row, col, val
      # if editing allowed
      raise "not yet used"
      @data[row][col] = val
      tme = TreeModelEvent.new(row, row, col, self, :UPDATE)
      fire_handler :TREE_MODEL_EVENT, tme
    end
    ##
    # please avoid directly hitting this. Suggested to use get_value_at of jtable
    # since columns could have been switched.
    def get_value_at row, col
      raise "not yet used"
      #$log.debug " def get_value_at #{row}, #{col} "

      raise "IndexError get_value_at #{row}, #{col}" if @data.nil? or row >= @data.size
      return @data[row][ col]
    end
    #def << obj
      #@data << obj
      #tme = TreeModelEvent.new(@data.length-1,@data.length-1, :ALL_COLUMNS, self, :INSERT)
      #fire_handler :TREE_MODEL_EVENT, tme
    #end
      # create tablemodelevent and fire_table_changed for all listeners 
    end
    def delete obj
      raise "not yet used"
      row = @data.index obj
      return if row.nil?
      ret = @data.delete obj
      tme = TreeModelEvent.new(row, row,:ALL_COLUMNS,  self, :DELETE)
      fire_handler :TREE_MODEL_EVENT, tme
      # create tablemodelevent and fire_table_changed for all listeners
      return ret
    end
    def delete_at row
      raise "not yet used"
      if !$multiplier or $multiplier == 0 
        @delete_buffer = @data.delete_at row
      else
        @delete_buffer = @data.slice!(row, $multiplier)
      end
      $multiplier = 0
      #ret = @data.delete_at row
      # create tablemodelevent and fire_table_changed for all listeners 
      # we don;t pass buffer to event as in listeditable. how to undo later?
      tme = TreeModelEvent.new(row, row+@delete_buffer.length,:ALL_COLUMNS,  self, :DELETE)
      fire_handler :TREE_MODEL_EVENT, tme
      return @delete_buffer
    end
    # a quick method to undo deletes onto given row. More like paste
    def undo where
      raise "not yet used"
      return unless @delete_buffer
      case @delete_buffer[0]
      when Array
        @delete_buffer.each do |r| 
          insert where, r 
        end
      else
        insert where, @delete_buffer
      end
    end
    ## 
    # added 2009-01-17 21:36 
    # Use with  caution, does not call events per row
    def delete_all
      raise "not yet used"
      len = @data.length-1
      @data=[]
      tme = TreeModelEvent.new(0, len,:ALL_COLUMNS,  self, :DELETE)
      fire_handler :TREE_MODEL_EVENT, tme
    end
    ##
    # for those quick cases when you wish to replace all the data
    # and not have an event per row being generated
    def data=(data)
      raise "not yet used"
      raise "Data nil or invalid" if data.nil? or data.size == 0
      delete_all
      @data = data
      tme = TreeModelEvent.new(0, @data.length-1,:ALL_COLUMNS,  self, :INSERT)
      fire_handler :TREE_MODEL_EVENT, tme
    end
    #def ask_search_forward
    #regex = get_string "Enter regex to search for:"
    #ix = get_list_data_model.find_match regex
    #if ix.nil?
    #alert("No matching data for: #{regex}")
    #else
    #set_focus_on(ix)
    #end
    #end
    ## continues previous search
    ###
    #def find_match regex, ix0=0, ix1=row_count()
    #$log.debug " find_match got #{regex} #{ix0} #{ix1}"
    #@last_regex = regex
    #@search_start_ix = ix0
    #@search_end_ix = ix1
    #@data.each_with_index do |row, ix|
    #next if ix < ix0
    #break if ix > ix1
    #if row.grep(/#{regex}/) != [] 
    ##if !row.match(regex).nil?
    #@search_found_ix = ix
    #return ix 
    #end
    #end
    #return nil
    #end
    #def find_prev regex=@last_regex, start = @search_found_ix 
    #raise "No previous search" if @last_regex.nil?
    #$log.debug " find_prev #{@search_found_ix} : #{@current_index}"
    #start -= 1 unless start == 0
    #@last_regex = regex
    #@search_start_ix = start
    #start.downto(0) do |ix| 
    #row = @data[ix]
    #if row.grep(/#{regex}/) != [] 
    #@search_found_ix = ix
    #return ix 
    #end
    #end
    #return nil
    ##return find_match @last_regex, start, @search_end_ix
    #end
    ### dtm findnext
    #def find_next
    #raise "No more search" if @last_regex.nil?
    #start = @search_found_ix && @search_found_ix+1 || 0
    #return find_match @last_regex, start, @search_end_ix
    #end
    # just a test program
    def traverse node=@root, level=0
      icon = node.is_leaf? ? "-" : "+"
      puts "%*s %s" % [ level+1, icon,  node.user_object ]
      node.children.each do |e| 
        traverse e, level+1
      end
    end
  end # class  DTM
  # When an event is fired by TableModel, contents are changed, then this object will be passed 
  # to trigger
  # type is :INSERT :UPDATE :DELETE :HEADER_ROW 
  # columns: number or :ALL_COLUMNS
  class TreeModelEvent
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
  class TreeNode
    #extend Forwardable

    attr_accessor :parent
    attr_reader :children
    attr_reader :user_object
    attr_reader :allow_children
    def initialize user_object=nil, allow_children=true, &block #form, config={}, &block
      @allow_children  = allow_children
      @user_object  = user_object
      @children = []
      #super
      instance_eval &block if block_given?
      init_vars
    end
    #def node user_object = nil, allows_children=true, &block
      #n = TreeNode.new user_object, allows_children, &block
      #add n
    #end
    # private
    #@returns just creates node
    def _add node, allows_children=true, &block
      #raise ArgumentError, "Argument should be a node" if !node.is_a? TreeNode
      $log.debug " TODO remove from existing parent to avoid bugs XXX"
      if !node.is_a? TreeNode
        n = TreeNode.new node, allows_children, &block
        node = n
      end
      node.parent = self
      @children << node
      node
    end
    # add a node to this node, optionally passing a block for further adding 
    # add a node as child to existing node
    # If node is not a TreeNode it will be converted to one.
    # @param [TreeNode, Array] node/s to add
    # @param [boolean] should children be allowed
    def add node, allows_children=true, &block
      case node
      when Array
        node.each do |e| 
          add e, allows_children, &block 
        end
      when Hash
        node.each_pair { |name, val|  
          n = _add name, allows_children, &block 
          n.add val, allows_children, &block
        }
      else
        _add node, allows_children, &block 
      end
    end
    alias :<< :add
    def insert node, index
      raise ArgumentError, "Argument should be a node. it is #{node.class} " if !node.is_a? TreeNode
      @children.insert index, node
      self
    end
    def child_after node
    end
    def child_before node
    end
    def child_at node
    end
    def next_node node
    end
    def remove
    end
    def remove_all_children
    end
    def remove_from_parent
    end
    def is_leaf?
      @children.size == 0
    end
    def leaf_count
    end
    def user_object_path
    end
    def level
      $log.debug " inside level XXX for #{user_object} "
      level = 0
      nodeparent = parent()
      while( nodeparent != nil )
        $log.debug " inside level loop XXX for #{nodeparent.user_object}, nodeparent "
        level += 1
        nodeparent = nodeparent.parent()
      end
      return level
    end
    def leaf_count
    end
    def to_s
      @user_object.to_s
    end
    def init_vars
       @repaint_required = true
    end
  end
end # module

if $0 == __FILE__

  include RubyCurses
  root    =  TreeNode.new "ROOT"
  subroot =  TreeNode.new "subroot"
  leaf1   =  TreeNode.new "leaf 1"
  leaf2   =  TreeNode.new "leaf 2"

  model = DefaultTreeModel.new root
  #model.insert_node_into(subroot, root,  0)
  #model.insert_node_into(leaf1, subroot, 0)
  #model.insert_node_into(leaf2, subroot, 1)
  root << subroot
  subroot << leaf1 << leaf2
  leaf1 << "leaf11"
  leaf1 << "leaf12"

  root.add "blocky", true do 
    add "block2"
    add "block3" do
      add "block31"
    end
  end
  
  model.traverse root
end
