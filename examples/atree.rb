require 'rbcurse'
require 'rbcurse/app'

App.new do 
  header = app_header "rbcurse 1.2.0", :text_center => "Tree Demo", :text_right =>"enabled"
  message "Press Enter to expand/collapse"

  stack :margin_top => 2, :margin => 5, :width => 30 do
      tree :height => 10  do
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


      # using a Hash
      model = { :ruby => [ "jruby", {:mri => %W[ 1.8.6 1.8.7]}, {:yarv => %W[1.9.1 1.9.2]}, "rubinius", "macruby" ], :python => %W[ cpython jython laden-swallow ] }
      tree :data => model

  end # stack
  stack :margin_top => 2, :margin => 40, :width => 30 do
    
      # using an Array
      tree :data => %W[ ruby cobol jruby smalltalk fortran piethon purrl lithp ]

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

      tree :data => model
  end
end # app
