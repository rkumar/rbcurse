require 'rbcurse/app'
require 'fileutils'
require 'rbcurse/tree/treemodel'

def _directories wd
  $log.debug " directories got XXX: #{wd} "
  d = Dir.new(wd)
  ent = d.entries.reject{|e| !File.directory? File.join(wd,e)}
  $log.debug " directories got XXX: #{ent} "
  ent.delete(".");ent.delete("..")
  return ent
end
App.new do 
  header = app_header "rbcurse 1.2.0", :text_center => "Yet Another File Manager", :text_right =>"Directory Lister", :color => :black, :bgcolor => :white#, :attr =>  Ncurses::A_BLINK
  message "Press Enter to expand/collapse"

  pwd = Dir.getwd
  #d = Dir.new(pwd)
  #entries = d.entries.reject{|e| !File.directory? e}
  #entries.delete(".");entries.delete("..")
  entries = _directories pwd
  patharray = pwd.split("/")
  # we have an array of path, to add recursively, one below the other`
  nodes = []
  nodes <<  TreeNode.new(patharray.shift)
  patharray.each do |e| 
    nodes <<  nodes.last.add(e)
  end
  last = nodes.last
  nodes.last.add entries
  model = DefaultTreeModel.new nodes.first
     


  ht = 24
  borderattrib = :reverse
  stack :margin_top => 1, :margin => 0, :width => 30 do
    @t = tree :data => model, :height => ht, :border_attrib => borderattrib
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
        files = Dir.new(path).entries
        files.delete(".")
        @l.list files 
        #TODO show all details in filelist
        @current_path = path
        $log.debug " XXX selected afterseeting lb: #{@l} "
      end
    end # select
    @t.expand_node last # 
    @t.mark_parents_expanded last # make parents visible
  end
  stack :margin_top => 1, :margin => 30, :width => 50 do
    @l = list_box :height => ht, :border_attrib => borderattrib
    @l.bind :LIST_SELECTION_EVENT  do |ev|
      $log.debug " XXX GOT A LIST EVENT #{ev} "
      message ev.source.selected_value
      #TODO when selects drill down
      #TODO when selecting, sync tree with this
    end
  end
end # app
