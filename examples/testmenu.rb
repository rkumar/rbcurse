require 'logger'
require 'rbcurse'
#require 'lib/rbcurse/rform'
require 'rbcurse/rpopupmenu'
if $0 == __FILE__
  include RubyCurses

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new((File.join(ENV["LOGDIR"] || "./" ,"rbc13.log")))
    $log.level = Logger::DEBUG

    @window = VER::Window.root_window
    # Initialize few color pairs 
    # Create the window to be associated with the form 
    # Un post form and free the memory

    catch(:close) do
      colors = Ncurses.COLORS
      $log.debug "START #{colors} colors  #{$datacolor} ---------"
      @form = Form.new @window
      @form.window.printstring 0, 25, "Demo of Ruby Curses PopupMenu", $normalcolor, 'reverse'
      r = 1; fc = 12;
      row = 10; col = 10
      colorlabel = Label.new @form, {'text' => "A label:", "row" => row, "col" => col, "color"=>"cyan", "mnemonic" => 'A'}

      #@mb = RubyCurses::MenuBar.new
      #filemenu = RubyCurses::Menu.new "File"
      filemenu = RubyCurses::PopupMenu.new "File"
      filemenu.add(item = RubyCurses::PMenuItem.new("Open",'O'))

      filemenu.insert_separator 1
      filemenu.add(RubyCurses::PMenuItem.new "New",'N')
      filemenu.add(item = RubyCurses::PMenuItem.new("Save",'S'))
      filemenu.add(item = RubyCurses::PMenuItem.new("Test",'T'))
      filemenu.add(item = RubyCurses::PMenuItem.new("Wrap Text",'W'))
      filemenu.add(item = RubyCurses::PMenuItem.new("Exit",'X'))
      item.command() {
        #throw(:menubarclose);
        throw(:close)
      }
      item = RubyCurses::PCheckBoxMenuItem.new "Reverse"
      #filemenu.create_window
#     item.onvalue="On"
#     item.offvalue="Off"
     #item.checkbox.text "Labelcb"
     #item.text="Labelcb"
      # in next line, an explicit repaint is required since label is on another form.
      #item.command(colorlabel){|it, label| att = it.getvalue ? 'reverse' : nil; label.attr(att); label.repaint}
    

      filemenu.add(item)
      #@mb.add(filemenu)
      editmenu = RubyCurses::PMenu.new "Edit"
      item = RubyCurses::PMenuItem.new "Cut"
      editmenu.add(item)
      item.accelerator = "Ctrl-X"
      item=RubyCurses::PMenuItem.new "Copy"
      editmenu.add(item)
      item.accelerator = "Ctrl-C"
      item=RubyCurses::PMenuItem.new "Paste"
      editmenu.add(item)
      item.accelerator = "Ctrl-V"
      #@mb.add(editmenu)
      #@mb.add(
      menu=RubyCurses::PMenu.new("Others")
      filemenu.add(menu)
      #item=RubyCurses::PMenuItem.new "Save","S"
      item = RubyCurses::PMenuItem.new "Config"
      menu.add(item)
      item = RubyCurses::PMenuItem.new "Tables"
      menu.add(item)
      savemenu = RubyCurses::PMenu.new "EditM"
      item = RubyCurses::PMenuItem.new "CutM"
      savemenu.add(item)
      item = RubyCurses::PMenuItem.new "DeleteM"
      savemenu.add(item)
      item = RubyCurses::PMenuItem.new "PasteM"
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
