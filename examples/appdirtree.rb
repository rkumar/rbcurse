require 'rbcurse/app'
require 'fileutils'
require 'rbcurse/tree/treemodel'
require 'rbcurse/extras/directorylist'

# TODO - tree expand - also populate list
# TODO - startup     = populate list
App.new do 
  # this is for tree to get only directories
  def _directories wd
    $log.debug " directories got XXX: #{wd} "
    d = Dir.new(wd)
    ent = d.entries.reject{|e| !File.directory? File.join(wd,e)}
    $log.debug " directories got XXX: #{ent} "
    ent.delete(".");ent.delete("..")
    return ent
  end
  ht = 24
  borderattrib = :reverse
    dl = RubyCurses::DirectoryList.new nil, :width=>40, :height => ht, :border_attrib => borderattrib, :selection_mode => :multiple
    dl.title_attrib = "reverse"
    #@l.bind :LIST_SELECTION_EVENT  do |ev|
    dl.bind :PRESS  do |ev|
      value =  ev.source.text
      #TODO when selecting, sync tree with this
    end
  pwd = Dir.getwd
  #d = Dir.new(pwd)
  #entries = d.entries.reject{|e| !File.directory? e}
  #entries.delete(".");entries.delete("..")
  entries = _directories pwd
  patharray = pwd.split("/")
  # we have an array of path, to add recursively, one below the other`
  nodes = []
  patharray[0]="/" if patharray.first == ""
  nodes <<  TreeNode.new(patharray.shift)
  patharray.each do |e| 
    nodes <<  nodes.last.add(e)
  end
  last = nodes.last
  nodes.last.add entries
  model = DefaultTreeModel.new nodes.first
  header = app_header "rbcurse 1.2.0", :text_center => "Yet Another File Manager", :text_right =>"Directory Lister", :color => :black, :bgcolor => :white#, :attr =>  Ncurses::A_BLINK
  message "Press Enter to expand/collapse"


     


  stack :margin_top => 1, :margin => 0, :width => :EXPAND do
    vimsplit :height => Ncurses.LINES-2, :weight => 0.4, :orientation => :VERTICAL do |s|
    @t = tree :data => model, :height => ht, :border_attrib => borderattrib
    @t.one_key_selection = false
    @t.bind :TREE_WILL_EXPAND_EVENT do |node|
      path = File.join(*node.user_object_path)
      dirs = _directories path
      ch = node.children
      ch.each do |e| 
        o = e.user_object
        if dirs.include? o
          dirs.delete o
        else
          # delete this child since its no longer present TODO
        end
      end
      message " #{node} will expand: #{path}, #{dirs} "
      node.add dirs
    end
    
    @t.bind :TREE_SELECTION_EVENT do |ev|
      if ev.state == :SELECTED
        node = ev.node
        path = File.join(*node.user_object_path)
        #TODO show all details in filelist
        dl.current_path path
        $log.debug " XXX selected afterseeting lb: #{dl} "
        message " #{ev.state}:  #{ev.node.user_object}   " 
      end
    end # select
    @t.expand_node last # 
    @t.mark_parents_expanded last # make parents visible
    s.add @t, :FIRST
    #@l = list_box :height => ht, :border_attrib => borderattrib, :selection_mode => :multiple
    s.add dl, :SECOND
    end
  end # flow
end # app
