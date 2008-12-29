$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
# this program tests out various widgets.
require 'rubygems'
require 'ncurses'
require 'logger'
require 'lib/ver/ncurses'
require 'lib/ver/window'
require 'lib/rbcurse/rwidget'
require 'lib/rbcurse/rform'
require 'lib/rbcurse/rmenu'
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
      r = 1; fc = 12;
      mnemonics = %w[ n l r p]
      %w[ name line regex password].each_with_index do |w,i|
        field = Field.new @form do
          name   w 
          row  r 
          col  fc 
          display_length  30
          #set_buffer "abcd " 
          set_label Label.new @form, {'text' => w, 'color'=>'cyan','mnemonic'=> mnemonics[i]}
        end
        r += 1
      end

      $message = Variable.new
      $message.value = "Message Comes Here"
      message_label = RubyCurses::Label.new @form, {'text_variable' => $message, "name"=>"message_label","row" => 27, "col" => 1, "display_length" => 80, 'color' => 'cyan'}

      $results = Variable.new
      $results.value = "A variable"
      var = RubyCurses::Label.new @form, {'text_variable' => $results, "row" => r, "col" => fc}
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
          height 14
          title "Editable box"
          title_attrib (Ncurses::A_REVERSE | Ncurses::A_BOLD)
          print_footer true
          bind(:CHANGE){|e| $message.value = e.to_s+" CP:"+e.source.curpos.to_s }
        end
        texta << "I expect to pass through this world but once." << "Any good therefore that I can do, or any kindness or abilities that I can show to any fellow creature, let me do it now."
        texta << "Let me not defer it or neglect it, for I shall not pass this way again."
        texta << " "
        texta << " F1 to exit. or click cancel button"
        texta << " Or alt-c"

        @textview = TextView.new @form do
          name   "myView" 
          row  16 
          col  52 
          width 40
          height 7
          title "README.txt"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
        end
        content = File.open("README.txt","r").readlines
        @textview.set_content content
        @textview.top_row 21

        # just for demo, lets scroll the text view as we scroll this.
        listb.bind(:ENTER_ROW, @textview) { |alist, tview| tview.top_row alist.current_index }
        
        # just for demo, lets scroll the text view to the line you enter
        @form.by_name["line"].bind(:LEAVE, @textview) { |fld, tv| raise(FieldValidationException, "#{fld.getvalue.to_i} Outside range 1,200") if fld.getvalue.to_i >200; tv.top_row(fld.getvalue.to_i) }
        @form.by_name["regex"].bind(:LEAVE, @textview) { |fld, tv| tv.top_row(tv.find_first_match(fld.getvalue)) }
        @form.by_name["regex"].bind(:CHANGED) { |fld| 
          $message.value =  "REGEX CHANGED!!! #{fld.getvalue}   " }
          row = 17
          col = 2
      align = ComboBox.new @form do
        name "combo"
        row row
        col fc
        display_length 10
        editable false
        list %w[left right center]
        set_label Label.new @form, {'text' => "Align", 'color'=>'cyan','col'=>1, "mnemonic"=>"I"}
        list_config 'color' => 'yellow', 'bgcolor'=>'red', 'height' => 4
      end

      list = ListDataModel.new( %w[spotty tiger panther jaguar leopard ocelot lion])
      list.bind(:LIST_DATA_EVENT) { |lde| $message.value = lde.to_s; $log.debug " STA: #{$message.value} #{lde}"  }
      list.bind(:ENTER_ROW) { |obj| $message.value = "ENTER_ROW :#{obj.current_index} : #{obj.selected_item}    "; $log.debug " ENTER_ROW: #{$message.value} , #{obj}"  }

      row += 1
      combo1 = ComboBox.new @form do
        name "combo1"
        row row
        col fc
        display_length 10
        editable true
        list_data_model list
        set_label Label.new @form, {'text' => "Edit Combo",'color'=>'cyan','col'=>1}
        list_config 'color' => 'white', 'bgcolor'=>'blue', 'max_visible_items' => 6, 'height' => 7
      end
      row += 1
      checkbutton = CheckBox.new @form do
        text_variable $results
        #value = true
        onvalue "Selected bold   "
        offvalue "UNselected bold"
        text "Bold attribute "
        display_length 18  # helps when right aligning
        row row
        col col
        mnemonic 'B'
      end
      row += 1
      @cb_rev = Variable.new # related to checkbox reverse
      cbb = @cb_rev
      checkbutton1 = CheckBox.new @form do
        text_variable cbb # $cb_rev
        #value = true
        onvalue "Selected reverse   "
        offvalue "UNselected reverse"
        text "Reverse attribute "
        display_length 18
        row row
        col col
        mnemonic 'R'
      end
      row += 1
      togglebutton = ToggleButton.new @form do
        value  true
        onvalue  " Toggle Down "
        offvalue "  Untoggle   "
        row row
        col col
        mnemonic 'T'
        #underline 0
      end
      # a special case required since another form (combo popup also modifies)
      $message.update_command() { message_label.repaint }

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
      #@form.by_name["regex"].bgcolor 'cyan'
      @form.by_name["password"].set_buffer ""
      @form.by_name["password"].show '*'
      @form.by_name["password"].color 'red'
      #@form.by_name["password"].bgcolor 'blue'
      @form.by_name["password"].values(%w[scotty tiger secret pass qwerty])
      @form.by_name["password"].null_allowed true

      # a form level event, whenever any widget is focussed
      @form.bind(:ENTER) { |f|   f.label.bgcolor = 'red' if f.respond_to? :label}
      @form.bind(:LEAVE) { |f|  f.label.bgcolor = 'black'   if f.respond_to? :label}

      row += 1
      colorlabel = Label.new @form, {'text' => "Select a color:", "row" => row, "col" => col, "color"=>"cyan", "mnemonic" => 'S'}
      $radio = Variable.new(1)
      $radio.update_command(colorlabel) {|tv, label|  label.color tv.value; }
      $radio.update_command() {|tv|  message_label.color tv.value; align.bgcolor tv.value; combo1.bgcolor tv.value}

      # whenever updated set colorlabel and messagelabel to bold
      $results.update_command(colorlabel,checkbutton) {|tv, label, cb| attrs =  cb.value ? 'bold' : nil; label.attr(attrs); message_label.attr(attrs)}

      align.bind(:ENTER_ROW) {|fld| message_label.justify fld.getvalue}
      align.bind(:ENTER_ROW) {|fld| 
        if fld.getvalue == 'right'
          checkbutton1.align_right true
          checkbutton.align_right true
        else
          checkbutton1.align_right false
          checkbutton.align_right false
        end
      }

      # whenever updated set colorlabel and messagelabel to reverse
      @cb_rev.update_command(colorlabel,checkbutton1) {|tv, label, cb| attrs =  cb.value ? 'reverse' : nil; label.attr(attrs); message_label.attr(attrs)}
      row += 1
      radio1 = RadioButton.new @form do
        text_variable $radio
        text "red"
        value "red"
        color "red"
        display_length 18  # helps when right aligning
        row row
        col col
      end
      radio11 = RadioButton.new @form do
        text_variable $radio
        text "c&yan"
        value "cyan"
        color "cyan"
        display_length 18  # helps when right aligning
        row row
        col col+24
      end
      row += 1
      radio2 = RadioButton.new @form do
        text_variable $radio
        text  "&green"
        value  "green"
        color "green"
        display_length 18  # helps when right aligning
        row row
        col col
      end
      radio22 = RadioButton.new @form do
        text_variable $radio
        text "magenta"
        value "magenta"
        color "magenta"
        display_length 18  # helps when right aligning
        row row
        col col+24
      end
      colorlabel.label_for radio1
      align.bind(:ENTER_ROW) {|fld| 
        if fld.getvalue == 'right'
          radio1.align_right true
          radio2.align_right true
          radio11.align_right true
          radio22.align_right true
        else
          radio1.align_right false
          radio2.align_right false
          radio11.align_right false
          radio22.align_right false
        end
      }

      @mb = RubyCurses::MenuBar.new
      filemenu = RubyCurses::Menu.new "File"
      filemenu.add(item = RubyCurses::MenuItem.new("Open",'O'))
      item.command(@form) {|it, form|  $message.value = "Open called on menu bar"; }

      filemenu.insert_separator 1
      filemenu.add(RubyCurses::MenuItem.new "New",'N')
      filemenu.add(RubyCurses::MenuItem.new "Save",'S')
      filemenu.add(item = RubyCurses::MenuItem.new("Test",'T'))
      item.command(@form, texta) do |it, form, testa|  
        $message.value = "Testing textarea"
        #testa.focus()
        str = "Hello there good friends and fellow rubyists. Here is a textarea that I am testing out with"
        str << " some long data, to see how it acts, how the wrapping takes place. Sit back and enjoy the "
        str << " bugs as they crop up."
        testa.goto_start
        testa.cursor_bol
        str.each_char {|c| testa.putch(c)}
        testa.repaint
        testa.handle_key KEY_DOWN # down
        testa.handle_key KEY_DOWN # down
        testa.handle_key KEY_DOWN # down
        testa.handle_key ?\C-a  # bol
        #testa.cursor_bol
        str.each_char {|c| testa.putch(c)}
        $message.value = "Wrapping textarea"
        testa.repaint
      end
      filemenu.add(item = RubyCurses::MenuItem.new("Wrap",'W'))
      item.command(@form, texta) do |it, form, testa|  
        testa.goto_start
        testa.handle_key ?\C-a  # bol
        testa.wrap_para 0
        testa.repaint
      end
      filemenu.add(item = RubyCurses::MenuItem.new("Exit",'X'))
      item.command() {throw(:close)}
      item = RubyCurses::CheckBoxMenuItem.new "CheckMe"
#     item.onvalue="On"
#     item.offvalue="Off"
     #item.checkbox.text "Labelcb"
     #item.text="Labelcb"
      # in next line, an explicit repaint is required since label is on another form.
      item.command(colorlabel){|it, label| att = it.getvalue ? 'reverse' : nil; label.attr(att); label.repaint}
    
      row += 2
      ok_button = Button.new @form do
        text "OK"
        name "OK"
        row row
        col col
        mnemonic 'O'
      end
      ok_button.command { |form| form.dump_data; $message.value = "Dumped data to log file"
        $listdata.value.insert 0, "hello ruby", "so long python", "farewell java", "RIP .Net"
      }

      # using ampersand to set mnemonic
      cancel_button = Button.new @form do
        #text_variable $results
        text "&Cancel"
        row row
        col col + 10
        #surround_chars ['{ ',' }']  ## change the surround chars
      end
      cancel_button.command { |form| throw(:close); }


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
