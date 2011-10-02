require 'rbcurse/app'

App.new do 
  header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Tree Demo", :text_right =>"New Improved!", :color => :black, :bgcolor => :white, :attr => :bold 
  message "Press Enter to expand/collapse"
      @form.bind_key(FFI::NCurses::KEY_F3) { 
        require 'rbcurse/extras/viewer'
        RubyCurses::Viewer.view("rbc13.log", :close_key => KEY_RETURN, :title => "<Enter> to close")
      }

  stack :margin_top => 2, :margin => 5, :width => 30 do
    tm = nil
      atree = tree :height => 10, :title => "ruby way"  do
        root "root" do
          branch "hello" do
            leaf "ruby"
          end
          branch "goodbye" do
            leaf "java"
            leaf "verbosity"
          end
        end
      end
      found=atree.get_node_for_path "goodbye"
      atree.set_expanded_state(atree.root, true)
      atree.set_expanded_state(found,true)

      # using a Hash
      model = { :ruby => [ "jruby", {:mri => %W[ 1.8.6 1.8.7]}, {:yarv => %W[1.9.1 1.9.2]}, "rubinius", "macruby" ], :python => %W[ cpython jython laden-swallow ] }
      tree :data => model, :title => "Hash"

  end # stack
  stack :margin_top => 2, :margin => 40, :width => 30 do
    
      # using an Array
      tree :data => %W[ ruby cobol jruby smalltalk fortran piethon purrl lithp ], :title=> "Array"

      # long way ISO 9001 certifed, SEI CMM 5 compliant
      #
      root    =  TreeNode.new "ROOT"
      subroot =  TreeNode.new "subroot"
      leaf1   =  TreeNode.new "leaf 1"
      leaf2   =  TreeNode.new "leaf 2"
      model = DefaultTreeModel.new root
      #model.insert_node_into(subroot, root,  0)  # BLEAH JAVA !!

      # slightly better, since we return self in ruby
      root << subroot
      subroot << leaf1 << leaf2
      leaf1 << "leaf11"
      leaf1 << "leaf12"

      # more rubyish way
      root.add "blocky", true do 
        add "block2"
        add "block3" do
          add "block31"
        end
      end

      tree :data => model, :title => "legacy way"

  end
end # app
