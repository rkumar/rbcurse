$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
# this program tests out various widgets.
require 'rubygems'
require 'ncurses'
require 'logger'
require 'lib/ver/ncurses'
require 'lib/ver/window'
require 'lib/rbcurse/rwidget'
#require 'lib/rbcurse/rform'
require 'lib/rbcurse/rpopupmenu'
if $0 == __FILE__
  include RubyCurses

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG

    @window = VER::Window.root_window
    # Initialize few color pairs 
    # Create the window to be associated with the form 
    # Un post form and free the memory

    catch(:close) do
      colors = Ncurses.COLORS
      $log.debug "START #{colors} colors  ---------"
      @form = Form.new @window
      @form.window.printstring 0, 25, "Demo of Ruby Curses PopupMenu", $normalcolor, 'reverse'
      r = 1; fc = 12;
      row = 10; col = 10
      colorlabel = Label.new @form, {'text' => "A label:", "row" => row, "col" => col, "color"=>"cyan", "mnemonic" => 'S'}

      #@mb = RubyCurses::MenuBar.new
      #filemenu = RubyCurses::Menu.new "File"
      filemenu = RubyCurses::PopupMenu.new "File"
      filemenu.add(item = RubyCurses::MenuItem.new("Open",'O'))

      filemenu.insert_separator 1
      filemenu.add(RubyCurses::MenuItem.new "New",'N')
      filemenu.add(item = RubyCurses::MenuItem.new("Save",'S'))
      filemenu.add(item = RubyCurses::MenuItem.new("Test",'T'))
      filemenu.add(item = RubyCurses::MenuItem.new("Wrap Text",'W'))
      filemenu.add(item = RubyCurses::MenuItem.new("Exit",'X'))
      item.command() {
        #throw(:menubarclose);
        throw(:close)
      }
      item = RubyCurses::CheckBoxMenuItem.new "Reverse"
      #filemenu.create_window
#     item.onvalue="On"
#     item.offvalue="Off"
     #item.checkbox.text "Labelcb"
     #item.text="Labelcb"
      # in next line, an explicit repaint is required since label is on another form.
      #item.command(colorlabel){|it, label| att = it.getvalue ? 'reverse' : nil; label.attr(att); label.repaint}
    

      filemenu.add(item)
      #@mb.add(filemenu)
      editmenu = RubyCurses::Menu.new "Edit"
      item = RubyCurses::MenuItem.new "Cut"
      editmenu.add(item)
      item.accelerator = "Ctrl-X"
      item=RubyCurses::MenuItem.new "Copy"
      editmenu.add(item)
      item.accelerator = "Ctrl-C"
      item=RubyCurses::MenuItem.new "Paste"
      editmenu.add(item)
      item.accelerator = "Ctrl-V"
      #@mb.add(editmenu)
      #@mb.add(
      menu=RubyCurses::Menu.new("Others")
      filemenu.add(menu)
      #item=RubyCurses::MenuItem.new "Save","S"
      item = RubyCurses::MenuItem.new "Config"
      menu.add(item)
      item = RubyCurses::MenuItem.new "Tables"
      menu.add(item)
      savemenu = RubyCurses::Menu.new "EditM"
      item = RubyCurses::MenuItem.new "CutM"
      savemenu.add(item)
      item = RubyCurses::MenuItem.new "DeleteM"
      savemenu.add(item)
      item = RubyCurses::MenuItem.new "PasteM"
      savemenu.add(item)
      menu.add(savemenu)
      # 2008-12-20 13:06 no longer hardcoding toggle key of menu_bar.
      #@mb.toggle_key = KEY_F2
      #@form.set_menu_bar  @mb
      #@cell = CellRenderer.new "Hello", {"col" => 1, "row"=>29, "justify"=>:right, "display_length" => 30}
      # END
      @form.repaint
      filemenu.show colorlabel, 0,1
      @window.wrefresh
      Ncurses::Panel.update_panels
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
