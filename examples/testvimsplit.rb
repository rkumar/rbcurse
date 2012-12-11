# This is a new kind of splitpane, inspired by the vim editor.
# I was deeply frustrated with the Java kind of splitpane,
# which requires splitpanes within splitpanes to get several split.
# This is an attempt at getting many splits, keeping them at one level
# and keeping the interface as simple as possible, with minimal input
# from user.
# It usually takes a listbox or textview or textarea.
# It can also take an array, or string or hash.
# It supports moving the split, and increasing or decreasing the current box to some extent.
# Typically if the split is vertical, add stacks the components, one below the other.
# If horizontal, if will flow the components, to the right of previous. This can be overriden by passing 
# type as :STACK or :FLOW.
#
# This does not support changing the orientation at run time, that's nice for demos, but a pain
# to get right, and results in a lot of extra code, meaning more bugs.
# TODO: create a class that contains component array and a pointer so it can give next/prev
# i am tired of maintaining this everywhere.
require 'rbcurse'
require 'rbcurse/extras/widgets/rlistbox'
require 'rbcurse/core/widgets/rtextview'
require 'rbcurse/extras/widgets/rvimsplit'

if $0 == __FILE__
class Tester
  def initialize
    acolor = $reversecolor
  end
  def run
    @window = VER::Window.root_window 
    @form = Form.new @window

    h = 20; w = 75; t = 3; l = 4

    vf = :H
    @vim = VimSplit.new @form, {:row => 2, :col => 5, :width => :EXPAND, :height => 25, :orientation => vf, :weight => 0.6}
    lb = Listbox.new nil, :list => ["ruby","perl","lisp","java", "scala"] , :name => "mylist"
    lb1 = Listbox.new nil, :list => ["roger","borg","laver","edberg", "sampras","ashe"] , :name => "mylist1"
    
    lb2 = Listbox.new nil, :list => `gem list --local`.split("\n") , :name => "mylist2"

    alist = %w[ ruby perl python java jruby macruby rubinius rails rack sinatra gawk zsh bash groovy] 
    str = "Hello people of this world.\nThis is a textbox.\nUse arrow keys, j/k/h/l/gg/G/C-a/C-e/C-d/C-b\n"
    str << alist.join("\n")
    stfl = vf == :V ? :FLOW : :STACK
    @vim.add lb, :FIRST, :AUTO
    @vim.add lb1, :FIRST, :AUTO #nil #0.7:AUTO
    @vim.add ["mercury","venus","earth","mars","jupiter", "saturn"], :FIRST, :AUTO
    @vim.add alist, :FIRST, 0.4, stfl
    #@vim.add alist, :FIRST, nil, stfl
    @vim.add alist.shuffle, :FIRST, 0.6, stfl
    @vim.add lb2, :SECOND, :AUTO
    @vim.add str, :SECOND, :AUTO
      ok_button = Button.new @form do
        text "+"
        name "+"
        row 27
        col 10
      end
      #ok_button.command { |form| @vim.weight(@vim.weight + 0.1)  }
      ok_button.command {  @vim.increase_weight }
      

      k_button = Button.new @form do
        text "-"
        name "-"
        row 27
        col 17
      end
      #k_button.command { |form| @vim.weight( @vim.weight - 0.1) }
      k_button.command { |form| @vim.decrease_weight }
      
    #
    @help = "F10 to quit. "
    RubyCurses::Label.new @form, {'text' => @help, "row" => 1, "col" => 2, "color" => "yellow"}
    @form.repaint
    @window.wrefresh
    Ncurses::Panel.update_panels
    ctr = 0
    row = 2
    while((ch = @window.getchar()) != Ncurses::KEY_F10 )
      ret = @form.handle_key(ch)
      @window.wrefresh
      #ret = @vim.handle_key ch
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
