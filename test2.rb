$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
# this program tests out various widgets.
require 'rubygems'
require 'ncurses'
require 'logger'
require 'lib/ver/ncurses'
require 'lib/ver/window'
require 'lib/rbcurse/rwidget'
require 'lib/rbcurse/rform'
require 'lib/rbcurse/rcombo'
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
      r = 1; c = 22;
      mnemonics = %w[ n l r p]
      %w[ name line regex password].each_with_index do |w,i|
        field = Field.new @form do
          name   w 
          row  r 
          col  c 
          display_length  30
          set_buffer "abcd " 
          set_label Label.new @form, {'text' => w, 'mnemonic'=> mnemonics[i]}
        end
        r += 1
      end
      $results = Variable.new
      $results.value = "A variable"
      var = RubyCurses::Label.new @form, {'text_variable' => $results, "row" => r, "col" => 22}
        r += 1
        mylist = []
        0.upto(100) { |v| mylist << "#{v} scrollable data" }
        $listdata = Variable.new mylist
        listb = Listbox.new @form do
          name   "mylist" 
          row  r 
          col  1 
          width 40
          height 10
#         list mylist
          list_variable $listdata
          title "A long list"
          title_attrib 'reverse'
        end
        #listb.insert 55, "hello ruby", "so long python", "farewell java", "RIP .Net"
        $listdata.value.insert 55, "hello ruby", "so long python", "farewell java", "RIP .Net"
        texta = TextArea.new @form do
          name   "mytext" 
          row  1 
          col  52 
          width 40
          height 15
          title "Editable box"
          title_attrib (Ncurses::A_REVERSE | Ncurses::A_BOLD)
        end
        texta << "I expect to pass through this world but once." << "Any good therefore that I can do, or any kindness or abilities that I can show to any fellow creature, let me do it now. "
        texta << "Let me not defer it or neglect it, for I shall not pass this way again."
        #texta << "hello there" << "we are testing deletes in this application"
        #texta << "HELLO there" << "WE ARE testing deletes in this application"
        texta << " "
        texta << " F1 to exit. or click second button"

        @textview = TextView.new @form do
          name   "myView" 
          row  16 
          col  52 
          width 40
          height 7
          title "README.txt"
          title_attrib 'bold'
        end
        content = File.open("README.txt","r").readlines
        @textview.set_content content
        @textview.top_row 21

        # just for demo, lets scroll the text view as we scroll this.
        listb.bind(:ENTER_ROW, @textview) { |arow, tview| tview.top_row arow }
        
        # just for demo, lets scroll the text view to the line you enter
        @form.by_name["line"].bind(:LEAVE, @textview) { |fld, tv| raise(FieldValidationException, "#{fld.getvalue.to_i} Outside range 1,200") if fld.getvalue.to_i >200; tv.top_row(fld.getvalue.to_i) }
        @form.by_name["regex"].bind(:LEAVE, @textview) { |fld, tv| tv.top_row(tv.find_first_match(fld.getvalue)) }

      checkbutton = CheckBox.new @form do
        text_variable $results
        #value = true
        onvalue "Selected cb   "
        offvalue "UNselected cb"
        text "A checkbox BOLD ME"
        row 17
        col 22
        underline 11 
      end
      togglebutton = ToggleButton.new @form do
        value  true
        onvalue  "Toggle Down  "
        offvalue "Toggle Up    "
        row 18
        col 22
        underline 0
      end
      combo = ComboBox.new @form do
        name "combo"
        row 19
        col 22
        display_length 10
        editable false
        list %w[scotty tiger secret pass torvalds qwerty quail toiletry]
        set_label Label.new @form, {'text' => "Combo"}
        list_config 'color' => 'yellow', 'bgcolor'=>'red', 'max_visible_items' => 6
      end
      combo1 = ComboBox.new @form do
        name "combo1"
        row 20
        col 22
        display_length 10
        editable true
        list %w[scotty tiger secret pass torvalds qwerty quail toiletry]
        set_label Label.new @form, {'text' => "Edit Combo"}
        list_config 'color' => 'white', 'bgcolor'=>'blue', 'max_visible_items' => 5
      end

      @form.by_name["line"].display_length = 3
      @form.by_name["line"].maxlen = 3
      @form.by_name["line"].set_buffer  "24"
      @form.by_name["name"].set_buffer  "Not focusable"
      @form.by_name["name"].set_focusable(false)
      @form.by_name["line"].chars_allowed = /\d/
      #@form.by_name["regex"].type(:ALPHA)
      @form.by_name["regex"].valid_regex(/^[A-Z][a-z]*/)
      @form.by_name["regex"].set_buffer  "SYNOP"
      @form.by_name["regex"].display_length = 10
      @form.by_name["regex"].maxlen = 20
      @form.by_name["regex"].bgcolor 'cyan'
      @form.by_name["password"].set_buffer ""
      @form.by_name["password"].show '*'
      @form.by_name["password"].color 'red'
      @form.by_name["password"].bgcolor 'blue'
      @form.by_name["password"].values(%w[scotty tiger secret pass qwerty])

      # a form level event, whenever any widget is focussed
      @form.bind(:ENTER) { |f|   f.label.bgcolor = 'red' if f.respond_to? :label}
      @form.bind(:LEAVE) { |f|  f.label.bgcolor = $datacolor   if f.respond_to? :label}

      colorlabel = Label.new @form, {'text' => "Select a color:", "row" => 21, "col" => 22, "color"=>"cyan", "mnemonic" => 'S'}
      $radio = Variable.new
      $radio.update_command(colorlabel) {|tv, label|  label.color tv.value}
      $results.update_command(colorlabel,checkbutton) {|tv, label, cb| attrs =  cb.value ? 'bold' : nil; label.attrs(attrs)}
      radio1 = RadioButton.new @form do
        text_variable $radio
        text "red"
        value "red"
        color "red"
        row 22
        col 22
      end
      radio2 = RadioButton.new @form do
        text_variable $radio
        text  "green"
        value  "green"
        color "green"
        row 23
        col 22
        underline 0  
      end
      colorlabel.label_for radio1

      @mb = RubyCurses::MenuBar.new
      filemenu = RubyCurses::Menu.new "File"
      filemenu.add(item = RubyCurses::MenuItem.new("Open",'O'))
      item.command(@form) {|it, form|  form.printstr(@window, 23,45, "Open CALLED"); }

      filemenu.insert_separator 1
      filemenu.add(RubyCurses::MenuItem.new "New",'N')
      filemenu.add(RubyCurses::MenuItem.new "Save",'S')
      filemenu.add(item = RubyCurses::MenuItem.new("Exit",'X'))
      item.command() {throw(:close)}
      item = RubyCurses::CheckBoxMenuItem.new "CheckMe"
#     item.onvalue="On"
#     item.offvalue="Off"
     #item.checkbox.text "Labelcb"
     #item.text="Labelcb"
      # in next line, an explicit repaint is required since label is on another form.
      item.command(colorlabel){|it, label| att = it.getvalue ? 'reverse' : nil; label.attrs(att); label.repaint}
    
      ok_button = Button.new @form do
        text "OK"
        name "OK"
        row 25
        col 22
        underline 0
      end
      ok_button.command { |form| form.dump_data;form.window.printstring(25,45, "Dumped data to log",1) 
        $listdata.value.insert 0, "hello ruby", "so long python", "farewell java", "RIP .Net"
      }

      cancel_button = Button.new @form do
        #text_variable $results
        text "Cancel"
        row 25
        col 28
        underline 1
        surround_chars ['{','}']
      end
      cancel_button.command { |form| form.window.printstring(23,45, "Cancel CALLED",1); throw(:close); }
      filemenu.add(item)
      @mb.add(filemenu)
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
      @mb.add(editmenu)
      @mb.add(menu=RubyCurses::Menu.new("Others"))
      #item=RubyCurses::MenuItem.new "Save","S"
      item = RubyCurses::MenuItem.new "Options"
      menu.add(item)
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
      @mb.toggle_key = KEY_F2
      @form.set_menu_bar  @mb
      # END
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
