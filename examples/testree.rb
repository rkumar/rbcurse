require 'rbcurse'
require 'rbcurse/core/widgets/rtree'

if $0 == __FILE__
  $choice = ARGV[0].to_i || 1
class Tester
  def initialize
    acolor = $reversecolor
  end
  def run
    @window = VER::Window.root_window 
    @form = Form.new @window

    h = 20; w = 75; t = 3; l = 4
   #$choice = 1 
    case $choice
    when 1
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
    Tree.new @form, :data => model, :row =>2, :col=>2, :height => 20, :width => 30

    when 2

      # use an array to populate
      # we need to do root_visible = false so you get just a list
    model  = %W[ ruby cobol jruby smalltalk fortran piethon purrl lithp ]
    Tree.new @form, :data => model, :row =>2, :col=>2, :height => 20, :width => 30

    when 3

      # use an Has to populate
      #model = { :ruby => %W[ "jruby", "mri", "yarv", "rubinius", "macruby" ], :python => %W[ cpython jython laden-swallow ] }
      model = { :ruby => [ "jruby", {:mri => %W[ 1.8.6 1.8.7]}, {:yarv => %W[1.9.1 1.9.2]}, "rubinius", "macruby" ], :python => %W[ cpython jython laden-swallow ] }

    Tree.new @form, :data => model, :row =>2, :col=>2, :height => 20, :width => 30
    #when 4
    else
      Tree.new @form, :row =>2, :col=>2, :height => 20, :width => 30 do
        root "root" do
          branch "hello" do
            leaf "world"
          end
          branch "goodbyee" do
            leaf "java"
          end
        end
      end

    end

    #
    @help = "F1 to quit. Pass command-line argument 1,2,3,4  #{$0} "
    RubyCurses::Label.new @form, {'text' => @help, "row" => 1, "col" => 2, "color" => "yellow"}
    @form.repaint
    @window.wrefresh
    Ncurses::Panel.update_panels
    while((ch = @window.getchar()) != KEY_F1 )
      ret = @form.handle_key(ch)
      @window.wrefresh
      if ret == :UNHANDLED
        str = keycode_tos ch
        $log.debug " UNHANDLED #{str} by Vim #{ret} "
      end
    end

    @window.destroy

  end
end
include RubyCurses
include RubyCurses::Utils
# Initialize curses
begin
  # XXX update with new color and kb
  VER::start_ncurses  # this is initializing colors via ColorMap.setup
  $log = Logger.new("rbc13.log")
  $log.level = Logger::DEBUG
  n = Tester.new
  n.run
rescue => ex
ensure
  VER::stop_ncurses
  p ex if ex
  puts(ex.backtrace.join("\n")) if ex
  $log.debug( ex) if ex
  $log.debug(ex.backtrace.join("\n")) if ex
end
end
