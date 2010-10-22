require 'rbcurse/app'
require 'fileutils'
require 'rbcurse/tree/treemodel'
require 'rbcurse/extras/directorylist'
require 'rbcurse/extras/directorytree'

# TODO - tree expand - also populate list
# TODO - startup     = populate list
App.new do 
  this = self
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
    dl = RubyCurses::DirectoryList.new nil, :width=>40, :height => ht, :border_attrib => borderattrib, :selection_mode => :multiple, :suppress_borders => true
    dl.title_attrib = "reverse"
    #@l.bind :LIST_SELECTION_EVENT  do |ev|
    dl.bind :PRESS  do |ev|
      value =  ev.source.text
      #TODO when selecting, sync tree with this
    end
  pwd = Dir.getwd
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
    vimsplit :height => Ncurses.LINES-2, :weight => 0.4, :orientation => :VERTICAL, :suppress_borders => true do |s|
      # TODO make this into a separate class in extras DirectoryTree
    #@t = tree :data => model, :height => ht, :border_attrib => borderattrib, :suppress_borders => true
    @t = RubyCurses::DirectoryTree.new nil, :data => model, :height => ht, :border_attrib => borderattrib, :suppress_borders => true, :default_value => last
    # store for later use
    @t.config[:dl] = dl
    @t.config[:app] = this
    def @t.selected_path_changed path
      dl = @config[:dl]
      dl.current_path path
    end
    def @t.path_expanded path
      dl = @config[:dl]
      dl.current_path path
      o = @config[:app]
      o.message " #{path} will be expanded "
    end
    @t.expand_node last # 
    #@t.mark_parents_expanded last # make parents visible
    @t.expand_parents last # make parents visible and expand
    s.add @t, :FIRST
    #@l = list_box :height => ht, :border_attrib => borderattrib, :selection_mode => :multiple
    s.add dl, :SECOND
    end # vimsplit
  end # flow
end # app
