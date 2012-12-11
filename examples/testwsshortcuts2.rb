# this is a test program, tests out widget shortcuts. type C-q to exit
#
require 'rbcurse'
require 'rbcurse/core/util/widgetshortcuts'

include RubyCurses
include RubyCurses::Utils

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
    catch(:close) do
    while ((ch = @window.getchar()) != 999)
      break if ch == ?\C-q.getbyte(0)
      @form.handle_key ch
      @window.wrefresh
    end
    end # catch
  end
  def _create_form
    widget_shortcuts_init
    stack :margin_top => 1, :width => :expand do
      label :text => " Details ", :color => :cyan, :attr => :reverse, :width => :expand, :justify => :center
      flow :margin_top => 1, :margin_left => 4, :item_width => 50   do
        stack :margin_top => 0, :margin_left => 3, :width => 50 , :color => :cyan, :bgcolor => :black do
          box do
            field :text => "steve", :attr => :reverse, :label => "%15s" % ["Name: "]
            field :label => "%15s" % ["Address: "], :width => 15, :attr => :reverse
            blank
            check :text => "Using version control", :value => true, :onvalue => "yes", :offvalue => "no" do |eve|
              unless eve.item.value 
                alert "NO VC! We need to talk"
              end
            end
            check :text => "Upgraded to Lion", :value => false, :onvalue => "yes", :offvalue => "no" do |eve|
              unless eve.item.value
                alert "You goin back to Snow Leopard?"
              end
            end
          end # box
        end
        stack :margin_top => 0, :margin_left => 3, :width => 50 , :color => :cyan, :bgcolor => :black do
          box :title => "OS Maintenance", :margin_left => 2 do
            radio :text => "Linux", :value => "LIN", :group => :os
            radio :text => "OSX", :value => "OSX", :group => :os
            radio :text => "Window", :value => "Win", :group => :os
            blank
          flow  :item_width => 15 do
            button :text => "Install" do 
              # you can avoid this by giving the radio buttons your own Variable (see test2.rb)
              choice = @variables[:os].value
              case choice
              when ""
                alert "Select an OS"
              when "OSX", "LIN"
                alert "Good choice"
              else
                alert "Pfft !"
              end
            end
            button :text => "Uninstall"
            button :text => "Delete"
          end
          end # box
        end
      end # flow
      #button :text => "Execute"
      text = ["      #[reverse]Unix Philosophy #[end]  ", 
        "#[fg=green, underline]Eric Raymond#[end] in his book, #[fg=green, underline]The Art of Unix Programming#[end] summarized the Unix philosophy.",
      "  ",
        "Rule of #[fg=yellow]Modularity#[end]: Write simple parts connected by clean interfaces.",
        "Rule of #[fg=blue]Clarity#[end]: #[bold]Clarity#[end] is better than cleverness.",
        "Rule of #[fg=red]Separation#[end]: Separate #[bold]policy#[end] from mechanism; separate interfaces from engines.",
          "Rule of #[fg=green]Simplicity#[end]: Design for #[bold]simplicity;#[end] add complexity only where you must.",
        "Rule of #[fg=magenta]Parsimony#[end]: Write a big program only when it is clear by demonstration that nothing else will do.",
        "Rule of #[fg=cyan]Representation#[end]: Fold knowledge into #[bold]data#[end] so program logic can be stupid and robust"]
        text << "For more check: #[underline]http://en.wikipedia.org/wiki/Unix_philosophy#Eric_Raymond#[end]"
        formatted = []
        #text.each { |line| formatted << @window.convert_to_chunk(line) }

      #textview :text => formatted
        #textview do |t| t.formatted_text(text, :tmux) end
        t = textview :title => 'tmux format'
        t.formatted_text(text, :tmux)
        t1 = textview :title => 'ansi formatted document'
        text = File.open("data/color.2","r").readlines
        t1.formatted_text(text, :ansi)

      flow do
        #box do
          button :text => "  Ok  " do  alert "Pressed okay"  end
          button :text => "Cancel" do  confirm "Do you wish to Quit?" ; throw :close;  end
          button :text => "Apply "
        #end
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
