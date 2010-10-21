require 'rbcurse/rtree'
#require 'forwardable'
# we can extend from Tree but lets just try forwarding
module RubyCurses
  # this class shows a tree of directories. Pressing ENTER expands or collapses
  # the node. Pressing ENTER selects a node.
  # Should we give options for displaying filenames also ? TODO
  class DirectoryTree < Tree
    attr_reader :selected_path
    #@t = tree :data => model, :height => ht, :border_attrib => borderattrib, :suppress_borders => true
    def _directories wd
      d = Dir.new(wd)
      ent = d.entries.reject{|e| !File.directory? File.join(wd,e)}
      ent.delete(".");ent.delete("..")
      return ent
    end

    def init_vars
      super

      one_key_selection = false
      bind :TREE_WILL_EXPAND_EVENT do |node|
        will_expand_action node
      end

      bind :TREE_SELECTION_EVENT do |ev|
        selection_event ev
      end 
    end  # init_v

    # populate this node with child directories
    # this gives user application a chance to override or extend this action
    def will_expand_action node
      path = File.join(*node.user_object_path)
      dirs = _directories path
      ch = node.children
      # add only children that may not be there
      ch.each do |e| 
        o = e.user_object
        if dirs.include? o
          dirs.delete o
        else
          # delete this child since its no longer present TODO
        end
      end
      node.add dirs
      path_expanded path
    end
    # notify applications of path expanded so they may do any
    # related action
    # # NOTE: this is not the cleanest way, since you will need objects from your app
    # scope here. User will have to add objects into the config hash after object creation
    # and access them here. (See appdirtree.rb in examples)
    def path_expanded path
    end
    def selection_event ev
      if ev.state == :SELECTED
        node = ev.node
        path = File.join(*node.user_object_path)
        @selected_path = path
        selected_path_changed path
      end
    end
    # inform applications that path has changed
    # gives the user application a place to effect changes elsewhere in app
    def selected_path_changed path
    end
  end  # class
end
