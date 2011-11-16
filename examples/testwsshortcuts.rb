# this is a test program, tests out tabbed panes. type F1 to exit
#
require 'rbcurse'
require 'rbcurse/core/util/widgetshortcuts'

include RubyCurses

class SetupMessagebox
  include RubyCurses::WidgetShortcuts
  def initialize config={}, &block
    @window = VER::Window.root_window
    @form = Form.new @window
  end
  def run
    _create_form
    @form.repaint
    @window.wrefresh
    while ((ch = @window.getchar()) != 999)
      break if ch == ?\C-q.getbyte(0)
      @form.handle_key ch
      @window.wrefresh
    end
  end
  def _create_form
    widget_shortcuts_init
    stack :margin_top => 2, :margin_left => 3, :width => 50 , :color => :cyan, :bgcolor => :black do
      label :text => " Details ", :color => :blue, :attr => :reverse, :width => :expand, :justify => :center
      blank
      field :text => "john", :attr => :reverse, :label => "%15s" % ["Name: "]
      field :label => "%15s" % ["Address: "], :width => 15, :attr => :reverse
      check :text => "Using version control", :value => true, :onvalue => "yes", :offvalue => "no"
      check :text => "Upgraded to Lion", :value => false, :onvalue => "yes", :offvalue => "no"
      blank
      radio :text => "Linux", :value => "LIN", :group => :os
      radio :text => "OSX", :value => "OSX", :group => :os
      radio :text => "Window", :value => "Win", :group => :os
      flow :margin_top => 2, :margin_left => 4, :item_width => 15  do
        button :text => "Ok"
        button :text => "Cancel"
        button :text => "Apply"
      end
    end
  end

end
if $0 == __FILE__
  # Initialize curses
  begin
    # XXX update with new color and kb
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new((File.join(ENV["LOGDIR"] || "./" ,"rbc13.log")))
    $log.level = Logger::DEBUG
    tp = SetupMessagebox.new()
    buttonindex = tp.run
    $log.debug "XXX:  MESSAGEBOX retirned #{buttonindex} "
  rescue => ex
  ensure
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
