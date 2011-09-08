# this program tests out various widgets.
#require 'ncurses' # FFI
require 'logger'
require 'rbcurse'
require 'rbcurse/rwidget'
#require 'rbcurse/listcellrenderer'
#require 'rbcurse/celleditor'
require 'rbcurse/rlistbox'
require 'rbcurse/vieditable'
require 'rbcurse/undomanager'
#require 'rbcurse/rmessagebox'
class RubyCurses::Listbox
  # vieditable includes listeditable which
  # does bring in some functions which can crash program like x and X TODO
  # also, f overrides list f mapping. TODO
  include ViEditable
end
if $0 == __FILE__
  include RubyCurses

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new((File.join(ENV["LOGDIR"] || "./" ,"view.log")))
    $log.level = Logger::DEBUG

    @window = VER::Window.root_window
    $catch_alt_digits = true; # emacs like alt-1..9 numeric arguments
    # Initialize few color pairs 
    # Create the window to be associated with the form 
    # Un post form and free the memory

    catch(:close) do
      colors = Ncurses.COLORS
      $log.debug "START #{colors} colors testlistbox.rb --------- #{@window} "
      @form = Form.new @window
      @form.window.printstring 0, 30, "Demo of Listbox - rbcurse", $normalcolor, 'reverse'
      r = 1; fc = 1;

      $results = Variable.new
      $results.value = "A list with vim-like key bindings. Try j k gg G o O C dd u (undo) C-r (redo) f<char> w yy p P. Also try emacs's kill-ring save/yank/cycle using M-w C-y M-y. Also, C-u and M1..9 numeric arguments."
      var = RubyCurses::Label.new @form, {'text_variable' => $results, "row" => r+12, "col" => fc, "display_length" => 80, "height" => 5}
      r += 1
      mylist = []
      0.upto(100) { |v| mylist << "#{v} scrollable data" }
      $listdata = Variable.new mylist
      listb = Listbox.new @form do
        name   "mylist" 
        row  r 
        col  1 
        width 40
        height 11
        #         list mylist
        list_variable $listdata
        #selection_mode :SINGLE
        show_selector true
        row_selected_symbol "[X] "
        row_unselected_symbol "[ ] "
        title "A long list"
        title_attrib 'reverse'
        cell_editing_allowed false
      end
      listb.one_key_selection = false # this allows us to map keys to methods
      listb.vieditable_init_listbox
      undom = SimpleUndo.new listb

      #listb.list.insert 55, "hello ruby", "so long python", "farewell java", "RIP .Net"

    # just for demo, lets scroll the text view as we scroll this.
    #        listb.bind(:ENTER_ROW, @textview) { |alist, tview| tview.top_row alist.current_index }

    #list = ListDataModel.new( %w[spotty tiger panther jaguar leopard ocelot lion])
    #list.bind(:LIST_DATA_EVENT) { |lde| $message.value = lde.to_s; $log.debug " STA: #{$message.value} #{lde}"  }
    #list.bind(:ENTER_ROW) { |obj| $message.value = "ENTER_ROW :#{obj.current_index} : #{obj.selected_item}    "; $log.debug " ENTER_ROW: #{$message.value} , #{obj}"  }

    # using ampersand to set mnemonic
    col = 1
    row = 20
    cancel_button = Button.new @form do
      #variable $results
      text "&Cancel"
      row row
      col col + 10
      #surround_chars ['{ ',' }']  ## change the surround chars
    end
    cancel_button.command { |form| 
      if confirm("Do your really want to quit?")== :YES
        throw(:close); 
      else
        $message.value = "Quit aborted"
      end
    }


    @form.repaint
    @window.wrefresh
    Ncurses::Panel.update_panels
    while((ch = @window.getchar()) != KEY_F1 )
      @form.handle_key(ch)
      #@form.repaint
      @window.wrefresh
    end
  end
rescue => ex
ensure
  @window.destroy if !@window.nil?
  VER::stop_ncurses
  p ex if ex
  p(ex.backtrace.join("\n")) if ex
  $log.debug( ex) if ex
  $log.debug(ex.backtrace.join("\n")) if ex
end
end
