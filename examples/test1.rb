# this is a test program, tests out messageboxes. type F1 to exit
#  2008-12-17 22:13 tried out the listdatamodel
#  Certain terminals are not displaying background colors correctly.
#  TERM=screen does but does not show UNDERLINES.
#  TERM=xterm-color does but does not trap F1, f2 etc
#  TERM=xterm does not but other things are fine.
#
#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
#require 'lib/rbcurse/mapper'
#require 'lib/rbcurse/keylabelprinter'
require 'rbcurse'
require 'rbcurse/rmessagebox'

if $0 == __FILE__
  # Initialize curses
  begin
    # XXX update with new color and kb
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG

#    @window = VER::Window.root_window


    catch(:close) do
      choice = ARGV[0] && ARGV[0].to_i || 3
      $log.debug "START  MESSAGE BOX TEST #{ARGV[0]}. choice==#{choice} ---------"
      # need to pass a form, not window.
      case choice
      when 1
      @mb = RubyCurses::MessageBox.new do
        title "Enter your name"
        message "Enter your name"
       type :list
       button_type :ok_cancel
       list %w[john tim lee wong rahul edward why chad andy]
       list_selection_mode 'multiple'
       default_values %w[ lee why ]
  
        default_button 0
      end
      when 2
      @mb = RubyCurses::MessageBox.new do
        title "Color selector"
        message "Select a color"
        type :custom
        button_type :custom
        buttons %w[&red &green &blue &yellow]
        underlines [0,0,0,0]
        default_button 0
      end
      when 3
        config = {}
        config["input_config"] = {}
        config["input_config"]["chars_allowed"]=/[^xzq]/
        config["input_config"]["valid_regex"]=/[A-Z][a-z]*/
      @mb = RubyCurses::MessageBox.new nil, config do
        title "Enter your name"
        #message "Enter your first name. You are not permitted to enter x z or q and must enter a capital first"
        message "Enter your first name. "
        type :input
        button_type :ok_cancel
        default_value "Rahul"
      end
      when 4
      @form = RubyCurses::Form.new nil
      field_list = []
        titlelabel = RubyCurses::Label.new @form, {'text' => 'User', 'row'=>3, 'col'=>4, 'color'=>'black', 'bgcolor'=>'white', 'mnemonic'=>'U'}
      field_list << titlelabel
        field = RubyCurses::Field.new @form do
          name   "url" 
          row  3 
          col  10
          display_length  30
#         set_buffer "http://"
          set_label titlelabel
        end
      checkbutton = RubyCurses::CheckBox.new @form do
       # variable $results
        #value = true
        onvalue "Selected cb   "
        offvalue "UNselected cb"
          color 'black'
          bgcolor 'white'
        text "No &frames"
        row 4
        col 4
      end
      field_list << field
      field_list << checkbutton
      checkbutton = RubyCurses::CheckBox.new @form do
       # variable $results
        value  true
        color 'black'
        bgcolor 'white'
        text "Use &HTTP/1.0"
        row 5
        col 4
      end
      field_list << checkbutton
      checkbutton = RubyCurses::CheckBox.new @form do
       # variable $results
        color 'black'
        bgcolor 'white'
        text "Use &passive FTP"
        row 6
        col 4
      end
      field_list << checkbutton
      titlelabel = RubyCurses::Label.new @form, {'text' => 'Language', 'row'=>8, 'col'=>4, 'color'=>'black', 'bgcolor'=>'white'}
      field_list << titlelabel
      $radio = RubyCurses::Variable.new
      #$radio.update_command(colorlabel) {|tv, label|  label.color tv.value}
      radio1 = RubyCurses::RadioButton.new @form do
        variable $radio
        text "rub&y"
        value "ruby"
        color "red"
        bgcolor 'white'
        row 9
        col 4
      end
      radio2 = RubyCurses::RadioButton.new @form do
        variable $radio
        text  "python"
        value  "py&thon"
        color "blue"
        bgcolor 'white'
        row 10
        col 4
      end
      field_list << radio1
      field_list << radio2
      field.bind(:ENTER) do |f|   
        listconfig = {'bgcolor' => 'blue', 'color' => 'white'}
        url_list= RubyCurses::ListDataModel.new(%w[john tim lee wong rahul edward _why chad andy])
        pl = RubyCurses::PopupList.new do
#         title "Enter URL "
          row  4 
          col  10
          width 30
          #list url_list
          list_data_model url_list
          list_selection_mode 'single'
          relative_to f
          list_config listconfig
          #default_values %w[ lee _why ]
          bind :PRESS do |index|
            field.set_buffer url_list[index]
          end
        end
      end
      @mb = RubyCurses::MessageBox.new @form do
        #title "Color selector"
        title "HTTP Configuration"
  #     message "Enter your name"
  #     type :custom
  #     buttons %w[red green blue yellow]
  #     underlines [0,0,0,0]
  #     type :input
  #     default_value "rahul"
       #type :field_list
       #field_list field_list
        button_type :ok
       default_button 0
      end
      when 5
        @form = RubyCurses::Form.new nil
        label = RubyCurses::Label.new @form, {'text' => 'File', 'row'=>3, 'col'=>4, 'color'=>'black', 'bgcolor'=>'white', 'mnemonic'=>'F'}
        field = RubyCurses::Field.new @form do
          name   "file" 
          row  3 
          col  10
          display_length  40
          set_label label
        end
        flist = Dir.glob("*.*")
        listb = RubyCurses::Listbox.new @form do
          name   "mylist" 
          row  5 
          col  10 
          width 40
          height 10
          list flist
          title "File list"
          title_attrib 'bold'
        end
        #listb.list.bind(:ENTER_ROW) { field.set_buffer listb.selected_item }
        field.bind(:CHANGE) do |f|   
          flist = Dir.glob(f.getvalue+"*")
          l = listb.list
          l.remove_all
          l.insert 0, *flist
        end
        @mb = RubyCurses::MessageBox.new @form do
          title "Sample File Selector"
          type :override
          height 20
          width 60
          top 5
          left 20
          default_button 0
          button_type :ok_cancel

        end
        $log.debug "MBOX :selected #{listb.selected_item}"
      end 
      
     $log.debug "MBOX :selected button index #{@mb.selected_index} "
     $log.debug "MBOX :input val #{@mb.input_value} "
#     $log.debug "row : #{@form.row} "
#     $log.debug "col : #{@form.col} "
#     $log.debug "Config : #{@form.config.inspect} "
#     @form.configure "row", 23
#     @form.configure "col", 83
#     $log.debug "row : #{@form.row} "
#     x = @form.row
#    @form.depth   21
#    @form.depth = 22
#    @form.depth   24
#    @form.depth = 25
#     $log.debug "col : #{@form.col} "
#     $log.debug "config : #{@form.config.inspect} "
#     $log.debug "row : #{@form.configure('row')} "
      #$log.debug "mrgods : #{@form.public_methods.sort.inspect}"
      #while((ch = @window.getchar()) != ?q )
      #  @window.wrefresh
      #end
    end
  rescue => ex
  ensure
    @window.destroy unless @window.nil?
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
