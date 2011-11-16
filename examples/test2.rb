# This program tests out various widgets.
# This is the old style of creating an application in which the user
# has to start and stop ncurses. No shortcuts for widget constructors are available.
#
# The newer easier way is to use 'App' which manages the environment, and provides shortcuts
# for all widgets. See app*.rb, alpmenu.rb, dbdemo.rb etc for samples.
#
# In case, you are running this in a directory that does not allow writing, set LOGDIR to 
# your home directory, or temp directory so a log file can be generated.
#
require 'logger'
require 'rbcurse'
require 'rbcurse/core/widgets/rtextarea'
require 'rbcurse/core/widgets/rtextview'
require 'rbcurse/core/widgets/rmenu'
require 'rbcurse/core/widgets/rcombo'
require 'rbcurse/extras/widgets/rcomboedit'
require 'rbcurse/core/include/listcellrenderer'
require 'rbcurse/extras/include/checkboxcellrenderer'
require 'rbcurse/extras/include/comboboxcellrenderer'
require 'rbcurse/extras/include/celleditor'
require 'rbcurse/extras/widgets/rlistbox'
require 'rbcurse/core/widgets/rbasiclistbox'
#require 'rbcurse/deprecated/widgets/rmessagebox'
require 'rbcurse/core/widgets/rtree'
require 'rbcurse/core/include/appmethods.rb'
require 'rbcurse/core/widgets/scrollbar'
def help_text
      <<-eos
               TEST2  HELP 1.5.0

      This is some help text for test2.

      Alt-C/F10 -   Exit application 
      Alt-!    -   Drop to shell
      C-x c    -   Drop to shell
      C-x l    -   list of files
      C-x p    -   process list
      C-x d    -   disk usage list
      C-x s  -   Git status
      C-x d  -   Git diff
      C-x w  -   Git whatchanged
      Alt-x    -   Command mode (<tab> to see commands and select)

      Some commands for using bottom of screen as vim and emacs do.
        To add

      -----------------------------------------------------------------------
      eos
end
if $0 == __FILE__

  include RubyCurses
  include RubyCurses::Utils

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    path = File.join(ENV["LOGDIR"] || "./" ,"rbc13.log")
    file   = File.open(path, File::WRONLY|File::TRUNC|File::CREAT) 
    $log = Logger.new(path)
    $log.level = Logger::DEBUG

    @lookfeel = :classic # :dialog # or :classic

    @window = VER::Window.root_window
    # Initialize few color pairs 
    # Create the window to be associated with the form 
    # Un post form and free the memory

    catch(:close) do
      colors = Ncurses.COLORS
      $log.debug "START #{colors} colors test2.rb --------- #{@window} "
      @form = Form.new @window
      title = (" "*30) + "Demo of some Ruby Curses Widgets - rbcurse " + Rbcurse::VERSION
      Label.new @form, {'text' => title, :row => 0, :col => 0, :color => 'green', :bgcolor => 'black'}
      r = 1; fc = 12;
      mnemonics = %w[ n l r p]
      %w[ name line regex password].each_with_index do |w,i|
        field = Field.new @form do
          name w 
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
      message_label = RubyCurses::Label.new @form, {'text_variable' => $message, 
        "name"=>"message_label","row" => Ncurses.LINES-1, "col" => 1, "display_length" => 60,  
        "height" => 2, 'color' => 'cyan'}

      $results = Variable.new
      $results.value = "A variable"
      var = RubyCurses::Label.new @form, {'text_variable' => $results, "row" => r, "col" => fc}
        r += 1
        mylist = File.open("data/tasks.txt",'r').readlines
        #0.upto(100) { |v| mylist << "#{v} scrollable data" }
        listb = BasicListbox.new @form do
          name   "mylist" 
          row  r 
          col  1 
          width 40
          height 11
          list mylist
          #selection_mode :SINGLE
          show_selector true
          #row_selected_symbol "*"
          #row_unselected_symbol " "
          selected_bgcolor :white
          selected_color :blue
          title "Todo List"
        end
        Scrollbar.new @form, :parent => listb # 2011-10-1  added
        #listb.list_data_model.insert -1, "rake build", "rake release", "bump version", "fix bugs"
        col2 = 42
        texta = TextArea.new @form do
          name   "mytext" 
          row  1 
          col  col2
          width 50
          height 14
          title "Editable box"
          #title_attrib (Ncurses::A_REVERSE | Ncurses::A_BOLD)
          print_footer true
          bind(:CHANGE){|e| $message.value = e.to_s+" CP:"+e.source.curpos.to_s }
        end
        lines = File.open("data/unix1.txt",'r').readlines
        lines.each { |e| texta << e }
        #texta << "I expect to pass through this world but once." << "Any good therefore that I can do, or any kindness or abilities that I can show to any fellow creature, let me do it now."
        #texta << "Let me not defer it or neglect it, for I shall not pass this way again."
        #texta << " "
        #texta << " F10 to exit. or click cancel button"
        #texta << " Or alt-c"

        col3 = 92
        treemodel = nil
        atree = Tree.new @form, :title => "Tree", :row =>1, :col=>col3, :height => 14, :width => 15 do
        treemodel = root "ruby language" do
          branch "mri" do
            leaf "1.9.1"
            leaf "1.9.2"
            leaf "1.9.3"
          end
          branch "jruby" do
            leaf "1.5"
            leaf "a really long leaf"

          end
          branch "ree" do
            leaf "1.8"
            leaf "1.9"
            leaf "2.0"
          end
        end
      end
      root = treemodel.root
      atree.set_expanded_state root, true
        #listcb.cell_editor.component.form = @form

      w1 = Ncurses.COLS-col2-1
        @textview = TextView.new @form do
          name   "myView" 
          row  15 
          col  col2 
          width w1
          height 11
          title "README.mark"
          #title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
        end
        content = File.open("../README.markdown","r").readlines
        @textview.set_content content #, :WRAP_WORD
        #@textview.top_row 21

        # just for demo, lets scroll the text view as we scroll this.
        listb.bind(:ENTER_ROW, @textview) { |alist, tview| tview.top_row alist.current_index
         pb =  @form.by_name["pbar"]
         pb.visible true
         len = alist.current_index
         pb.fraction(len/100.0)
         i = ((len/100.0)*100).to_i
         i = 100 if i > 100
         pb.text = "completed:#{i}"
        }
        listb.bind(:LEAVE) { 
          pb =  @form.by_name["pbar"]
          pb.visible false
          r = pb.row
          c = pb.col
          @window.wmove(r,c); @window.wclrtoeol
          #@window.wrefresh
        }
        
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
        list_config :color => :yellow, :bgcolor=>:blue
      end

      list = ListDataModel.new( %w[white yellow cyan magenta red blue black])
      list.bind(:LIST_DATA_EVENT) { |lde| $message.value = lde.to_s; $log.debug " STA: #{$message.value} #{lde}";   }
      list.bind(:ENTER_ROW) { |obj| $message.value = "ENTER_ROW :#{obj.current_index} : #{obj.selected_item}    "; $log.debug " ENTER_ROW: #{$message.value} , #{obj}"; @form.widgets.each { |e| next unless e.is_a? Widget; e.color = obj.selected_item }; @mb.color = obj.selected_item }

      row += 1
      combo1 = ComboBoxEdit.new @form do
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
        variable $results
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
      @cb_rev = Variable.new false # related to checkbox reverse
      cbb = @cb_rev
      checkbutton1 = CheckBox.new @form do
        variable cbb # $cb_rev
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

      f = @form.by_name["line"]
      f.display_length(3).set_buffer(24).valid_range(1..200).
        maxlen(3).
        type(:integer)

      @form.by_name["name"].set_buffer( "Not focusable").
        set_focusable(false)
      
      @form.by_name["regex"].valid_regex(/^[A-Z][a-z]*/).
        set_buffer( "SYNOP").
        display_length(10).
        maxlen = 20

      @form.by_name["password"].set_buffer("").
        show('*').
        color('red').
        values(%w[scotty tiger secret pass qwerty]).
        null_allowed true

      # a form level event, whenever any widget is focussed, make the label red
      @form.bind(:ENTER) { |f|   f.label && f.label.bgcolor = 'red' if f.respond_to? :label}
      @form.bind(:LEAVE) { |f|  f.label && f.label.bgcolor = 'black'   if f.respond_to? :label}

      row += 1
      colorlabel = Label.new @form, {'text' => "Select a color:", "row" => row, "col" => col, 
        "color"=>"cyan", "mnemonic" => 'S'}
      $radio = Variable.new
      $radio.update_command(colorlabel) {|tv, label|  label.color tv.value; }
      $radio.update_command() {|tv|  message_label.color tv.value; align.bgcolor tv.value; 
        combo1.bgcolor tv.value}
      $radio.update_command() {|tv|  @form.widgets.each { |e| next unless e.is_a? Widget; 
        e.bgcolor tv.value }; @mb.bgcolor = tv.value }

      # whenever updated set colorlabel and messagelabel to bold
      $results.update_command(colorlabel,checkbutton) {|tv, label, cb| 
        attrs =  cb.value ? 'bold' : 'normal'; label.attr(attrs); message_label.attr(attrs)}

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
      #@cb_rev.update_command(colorlabel,checkbutton1) {|tv, label, cb| attrs =  cb.value ? 'reverse' : nil; label.attr(attrs); message_label.attr(attrs)}
      # changing nil to normal since PROP CHAN handler will not fire if nil being set.
      @cb_rev.update_command(colorlabel,checkbutton1) {|tv, label, cb| 
        attrs =  cb.value ? 'reverse' : 'normal'; label.attr(attrs); message_label.attr(attrs)}

      row += 1
      dlen = 10
      radio1 = RadioButton.new @form do
        variable $radio
        text "red"
        value "red"
        color "red"
        display_length dlen  # helps when right aligning
        row row
        col col
      end
      radio11 = RadioButton.new @form do
        variable $radio
        text "c&yan"
        value "cyan"
        color "cyan"
        display_length dlen  # helps when right aligning
        row row
        col col+24
      end

      row += 1
      radio2 = RadioButton.new @form do
        variable $radio
        text  "&green"
        value  "green"
        color "green"
        display_length dlen  # helps when right aligning
        row row
        col col
      end
      radio22 = RadioButton.new @form do
        variable $radio
        text "magenta"
        value "magenta"
        color "magenta"
        display_length dlen  # helps when right aligning
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

      # instead of using frozen, I will use a PropertyVeto
      # to disallow changes to color itself
      veto = lambda { |e, name|
        if e.property_name == 'color'
          if e.newvalue != name
            raise PropertyVetoException.new("Cannot change this at all!", e)
          end
        elsif e.property_name == 'bgcolor'
            raise PropertyVetoException.new("Cannot change this!", e)
        end
      }
      [radio1, radio2, radio11, radio22].each { |r| 
        r.bind(:PROPERTY_CHANGE) do |e| veto.call(e, r.text) end
      }

      # 
      # define the menu
      #
      @mb = RubyCurses::MenuBar.new
      filemenu = RubyCurses::Menu.new "File"
      filemenu.add(item = RubyCurses::MenuItem.new("Open",'O'))
      item.command(@form) {|it, form|  $message.value = "Open called on menu bar"; 
        require './qdfilechooser'
        fchooser = QDFileChooser.new
        option = fchooser.show_open_dialog
        $message.value = "File Selection #{option}, #{fchooser.get_selected_file}"
        if option == :OK
          filesel = fchooser.get_selected_file
          if !filesel.nil?
            texta.remove_all
            content = File.open(filesel,"r").readlines
            content.each do |line|
              texta << line
            end
          else
            alert "File name #{filesel} nil. Pls check code. "
          end
        end
      }

      filemenu.insert_separator 1
      filemenu.add(RubyCurses::MenuItem.new "New",'N')
      filemenu.add(item = RubyCurses::MenuItem.new("Save",'S'))
      item.command() do |it|  
        filename = get_string("Please enter file to save in", 20, "t.t")
        $message.value = "file: #{filename}"
        filename ||= "tmpzzzz.tmp"
        str = texta.to_s
        File.open(filename, 'w') {|f| f.write(str) }
        $message.value = " written #{str.length} bytes to file: #{filename}"
      end
      filemenu.add(item = RubyCurses::MenuItem.new("Test",'T'))
      item.command(@form, texta) do |it, form, testa|  
        $message.value = "Testing textarea"
        str = File.open("data/lotr.txt",'r').readlines.join 
        #str = "Hello there good friends and fellow rubyists. Here is a textarea that I am testing out with"
        #str << " some long data, to see how it acts, how the wrapping takes place. Sit back and enjoy the "
        #str << " bugs as they crop up."
        testa.goto_start
        #testa.cursor_bol
        testa.handle_key ?\C-a.getbyte(0)  
        str.each_char {|c| testa.putch(c)}
        testa.repaint
        3.times { testa.handle_key KEY_DOWN }
        testa.handle_key ?\C-a.getbyte(0)  
        
        str.each_char {|c| testa.putch(c)}
        $message.value = "Wrapping textarea"
        testa.repaint
        throw(:menubarclose)
      end
      filemenu.add(item = RubyCurses::MenuItem.new("Wrap",'W'))
      item.command(@form, texta) do |it, form, testa|  
        #testa.goto_start
        testa.handle_key ?\C-a.getbyte(0)  
        testa.wrap_para
        testa.repaint
        throw(:menubarclose)
      end
      filemenu.add(item = RubyCurses::MenuItem.new("Exit",'X'))
      item.command() {
        #throw(:menubarclose);
        throw(:close)
      }
      item = RubyCurses::CheckBoxMenuItem.new "Reverse"
#     item.onvalue="On"
#     item.offvalue="Off"
     #item.checkbox.text "Labelcb"
     #item.text="Labelcb"
      # in next line, an explicit repaint is required since label is on another form.
      item.command(colorlabel){|it, label| att = it.getvalue ? 'reverse' : 'normal'; label.attr(att); label.repaint}
      @status_line = status_line :row => Ncurses.LINES-2
      @status_line.command {
        "F1 Help | F2 Menu | F3 View | F4 Shell | F5 Sh | %20s" % [$message.value]
      }
      row += 1 #2
      ok_button = Button.new @form do
        text "OK"
        name "OK"
        row row
        col col
        #attr 'reverse'
        #highlight_background "white"
        #highlight_foreground "blue"
        mnemonic 'O'
      end
      ok_button.command() { |eve| 
        alert("Hope you enjoyed this demo ", {'title' => "Hello", :bgcolor => :blue, :color => :white})
        sw = case @lookfeel
             when :dialog
               progress_dialog :color_pair => $reversecolor, :row_offset => 4, :col_offset => 5
             else
               status_window # at footer last 2 rows
             end

        sw.print  "I am adding some stuff to list", "And testing out StatusWindow"
        sleep 1.0
        listb.list.insert 0, "hello ruby", "so long python", "farewell java", "RIP .Net"
        sw.printstring 1,1, "And some more now ..."
        sleep 0.5
        listb.list.insert 0, "get milk", "make beds", "clean shark pond","sell summer house"
        sleep 0.5
        sw.print "This was a test of Window", "we are almost done now ..."
        clock = %w[ | / - \ ]
        listb.list.each_with_index { |e, index| sw.print e, clock[index%4]; sleep 0.1   }
        sw.linger #@window
      }

      # using ampersand to set mnemonic
      cancel_button = Button.new @form do
        #variable $results
        text "&Cancel"
        row row
        col col + 10
        #attr 'reverse'
        #highlight_background "white"
        #highlight_foreground "blue"
        #surround_chars ['{ ',' }']  ## change the surround chars
      end
      cancel_button.command { |aeve| 
        if @lookfeel == :dialog
          ret = confirm("Do your really want to quit?") 
        else
          ret = confirm_window("Do your really want to quit?") 
        end
        if ret == :YES
          throw(:close); 
        else
          $message.value = "Quit aborted"
        end
      }
      #col += 22
      col += 15
      require 'rbcurse/core/widgets/rprogress'
      pbar = Progress.new @form, {:width => 20, :row => Ncurses.LINES-1, :col => Ncurses.COLS-20 , 
        :bgcolor => 'white', :color => 'red', :name => "pbar"}
      #len = 1
      #pbar.fraction(len/100.0)
      pbar.visible false


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
      item = RubyCurses::MenuItem.new "Options ..."
      item.command() do |it|  
        require './testtabp'
        tp = TestTabbedPane.new
        tp.run
        $message.value=$config_hash.inspect
        $log.debug " returning with #{$config_hash}: #{$config_hash.inspect}"
      end
      menu.add(item)
      item = RubyCurses::MenuItem.new "Options2 ..."
      item.command() do |it|  
        require './newtabbedwindow'
        tp = SetupTabbedPane.new
        tp.run
        $message.value=$config_hash.inspect
        $log.debug " returning with #{$config_hash}: #{$config_hash.inspect}"
      end
      menu.add(item)
      item = RubyCurses::MenuItem.new "Shell Command..."
      item.command { shell_output }
      menu.add(item)
      savemenu = RubyCurses::Menu.new "Shell"
      item = RubyCurses::MenuItem.new "Processes"
      item.command { run_command "ps -l" }
      savemenu.add(item)
      item = RubyCurses::MenuItem.new "Files"
      item.command { run_command "ls -l" }
      savemenu.add(item)
      item = RubyCurses::MenuItem.new "Disk"
      item.command { run_command "df -h" }
      savemenu.add(item)
      menu.add(savemenu)

      savemenu2 = RubyCurses::Menu.new "Git"
      item = RubyCurses::MenuItem.new "Status"
      item.command { run_command "git status" }
      savemenu2.add(item)
      item = RubyCurses::MenuItem.new "Diff"
      item.command { run_command "git diff" }
      savemenu2.add(item)
      item = RubyCurses::MenuItem.new "Name"
      item.command { run_command "git diff --name-status" }
      savemenu2.add(item)
      savemenu.add(savemenu2)
      
      @mb.toggle_key = FFI::NCurses::KEY_F2
      @form.set_menu_bar  @mb
     
      # END
      @form.bind_key(FFI::NCurses::KEY_F3) { 
        require 'rbcurse/core/util/viewer'
        RubyCurses::Viewer.view(path || "rbc13.log", :close_key => KEY_RETURN, :title => "<Enter> to close")
      }
      @form.bind_key(FFI::NCurses::KEY_F4) {  shell_output }
      @form.bind_key(FFI::NCurses::KEY_F5) {  suspend }
      @form.bind_key([?\C-x,?c]) {  suspend }
      @form.bind_key(?\M-!) {  suspend }
      @form.bind_key([?\C-x,?l]) {  run_command "ls -al" }
      @form.bind_key([?\C-x,?p]) {  run_command "ps -l" }
      @form.bind_key([?\C-x,?d]) {  run_command "df -h" }
      @form.bind_key([?\C-x,?d]) {  run_command "git diff --name-status" }
      @form.bind_key([?\C-x, ?s]) {  run_command "git status" }
      @form.bind_key([?\C-x,?w]) {  run_command "git whatchanged" }
      @form.bind_key(FFI::NCurses::KEY_F1) {  display_app_help help_text() }
      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels

      # the main loop

      while((ch = @window.getchar()) != FFI::NCurses::KEY_F10 )
        break if ch == ?\C-q.getbyte(0)
        begin
          @form.handle_key(ch)

        rescue FieldValidationException => fve 
          alert fve.to_s
          
          f = @form.get_current_field
          # lets restore the value
          if f.respond_to? :restore_original_value
            f.restore_original_value
            @form.repaint
          end
          $error_message.value = ""
        rescue => err
          $log.error( err) if err
          $log.error(err.backtrace.join("\n")) if err
          alert "Got an exception in test2: #{err} "
          $error_message.value = ""
        end

        # this should be avoided, we should not muffle the exception and set a variable
        # However, we have been doing that
        if $error_message.get_value != ""
          if @lookfeel == :dialog
            alert($error_message, {:bgcolor => :red, 'color' => 'yellow'}) if $error_message.get_value != ""
          else
            print_error_message $error_message, {:bgcolor => :red, :color => :yellow}
          end
          $error_message.value = ""
        end

        @window.wrefresh
      end # while loop
    end # catch
  rescue => ex
  ensure
    $log.debug " -==== EXCEPTION =====-"
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
    @window.destroy if !@window.nil?
    VER::stop_ncurses
    puts ex if ex
    puts(ex.backtrace.join("\n")) if ex
  end
end
