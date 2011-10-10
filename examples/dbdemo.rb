require 'rbcurse/app'
require 'sqlite3'

# @return array of table names from selected db file
def get_table_names
  raise "No database file selected." unless $current_db

  $tables = get_data "select name from sqlite_master"
  $tables.collect!{|x| x[0] }  ## 1.9 hack, but will it run on 1.8 ??
  $tables
end
def get_column_names tbname
  get_metadata tbname
end
def connect dbname
  $current_db = dbname
  $db = SQLite3::Database.new(dbname)

  return $db
end
def get_data sql
  $log.debug "SQL: #{sql} "
  $columns, *rows = $db.execute2(sql)
  $log.debug "XXX COLUMNS #{sql}  "
  content = rows
  return nil if content.nil? or content[0].nil?
  $datatypes = content[0].types #if @datatypes.nil?
  return content
end
def get_metadata table
  get_data "select * from #{table} limit 1"
  #$columns.collect!{|x| x[0] }  ## 1.9 hack, but will it run on 1.8 ??
  return $columns
end
#
# creates a popup for selection given the data, and executes given block with
#  following return value.
# @return [String] if mode is :single
# @return [Array] if mode is :multiple
#
def create_popup array, selection_mode=:single,  &blk
  require 'rbcurse/rlistbox'
  #raise "no block given " unless block_given?
  listconfig = {'bgcolor' => 'blue', 'color' => 'white'}
  url_list= RubyCurses::ListDataModel.new(array)
  ht = 16
  if array.length < 16
    ht = array.length+1
  end
  pl = RubyCurses::PopupList.new do
    row  4 
    col  10
    width 30
    height ht
    #list url_list
    list_data_model url_list
    list_selection_mode selection_mode
    #relative_to f
    list_config listconfig
    bind :PRESS do |lb|
      #field.set_buffer url_list[index]
      #blk.call(url_list[index]) #if &blk
      #selected = []; indices.each{|i| selected << url_list[i] }
      #blk.call(selected.join(", "))
      if selection_mode == :single
        blk.call(url_list[lb]) #if &blk
      else
        blk.call(lb.selected_values)
      end
      
    end
  end
end

def view_data fields="*", name
  stmt = "select #{fields} from #{name}"
  @form.by_name['tarea'] << stmt
  view_sql stmt
end
def view_sql stmt
  begin
  content = get_data stmt
  if content.nil?
  else
    require 'rbcurse/extras/tabular'
    t = Tabular.new do |t|
      t.headings = $columns
      t.data=content   
    end
    view t.render
  end
  rescue => err
    $log.error err.to_s
    $log.error(err.backtrace.join("\n"))
    alert err.to_s
  end
end

App.new do 
  header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Database Demo", :text_right =>"enabled"
  form = @form
  mylabel = "a field"
  $catch_alt_digits = true # use M-1..9 in textarea
  $current_table = nil
  $current_db = nil # "testd.db"
  connect $current_db if $current_db

  def help_text
    <<-eos
               APPEMAIL HELP 

      This is some help text for appemail.
      We are testing out this feature.

      Alt-d    -   Select a database
      <Enter>      on a table, view data (q to close window)
      <Space>      on a table, display columns in lower list

                COLUMN LIST KEYS
      <Space>      on a column for multiple select
      <Ctrl-Space> on a column for range select/deselect from previous selection
      <Enter>      on column table to view data for selected columns
             u     unselect all
             a     select all
             *     invert selection
      F4           View data for selected table (or columns if selected)

      q or C-q     Close the data window that comes on Enter or F4

      Alt-x    -   Command mode (<tab> to see commands and select)
      :        -   Command mode
      F10      -   Quit application



      -----------------------------------------------------------------------
      Hope you enjoyed this help.
    eos
  end
  # TODO accelerators and 
  # getting a handle for later use
  mb = menubar do
    keep_visible true
    #@toggle_key=KEY_F2
    menu "File" do
      item "Open", "O" do
        accelerator "Ctrl-O"
        command do 
          alert "HA!! you wanted to open a file?"
        end
      end
      menu "Database" do
        item_list do
          Dir.glob("**/*.{sqlite,db}")
        end
        command do |menuitem, text|
          connect text
          form.by_name["tlist"].list(get_table_names)
        end
      end
      menu "Tables" do
        item_list do
          if $current_db
            get_table_names
          end
        end
        command do |menuitem, text|
          $current_table = text
          #alert(get_column_names(text).join(", "))
          create_popup(get_column_names(text), :multiple) { |value| view_data( value.join(","), text) }
        end
      end
      item "New", "N" 
      separator
      item "Exit", "x"  do 
        command do
          throw(:close)
        end
      end
      item "Cancel Menu" do
        accelerator "Ctrl-g"
      end

    end # menu
    menu "Window" do
      item "Tile", "T"
      menu "Find" do
        item "More", "M"
        $x = item "Less", "L" do
          #accelerator "Ctrl-X"
          command do
            alert "You clickses on Less"
          end
        end
        menu "Size" do
          item "Zoom", "Z"
          item "Maximize", "X"
          item "Minimize", "N"
        end
      end
    end
  end # menubar
  mb.toggle_key = FFI::NCurses::KEY_F2
  mb.color = :white
  mb.bgcolor = :blue
  @form.set_menu_bar mb
  stack :margin => 0 do
    tlist = basiclist :name => "tlist", :list => ["No tables"], :title => "Tables", :height => 10
    tlist.bind(:PRESS) do |eve|
      # get data of table
      view_data eve.text
    end
    tlist.bind(:ENTER_ROW) do |eve|
      $current_table = eve.text if $db
    end
    clist = basiclist :name => "clist", :list => ["No columns"], :title => "Columns", :height => 14, 
      :selection_mode => :multiple
    tlist.bind(:LIST_SELECTION_EVENT) do |eve|
      $current_table = eve.source[eve.firstrow]
      clist.data = get_column_names $current_table
    end
    clist.bind(:PRESS) do |eve|
      # get data of table
      if $current_table
        cols = "*"
        c = clist.get_selected_values
        unless c.empty?
          cols = c.join(",")
        end
        view_data cols, $current_table
      else
        alert "Select a table first." 
      end
    end
    @statusline = status_line
    @statusline.command { 
      # trying this out. If you want a persistent message that remains till the next on
      #  then send it in as $status_message
      text = $status_message.value || ""
      if !$current_db
        "%-20s [%-s] %s" % [ Time.now, "Select a Database", text]
      elsif !$current_table
        "%-20s [DB: %-s | %-s ] %s" % [ Time.now, $current_db || "None", $current_table || "Select a table", text] 
      else
        "%-20s [DB: %-s | %-s ] %s" % [ Time.now, $current_db || "None", $current_table || "----", text] 
      end
    }
    @adock = nil
    keyarray = [
      ["F1" , "Help"], ["F10" , "Exit"], 
      ["F2", "Menu"], ["F4", "View"],
      ["M-d", "Datebase"], ["M-t", "Table"],
      ["M-x", "Command"], nil
    ]
    tlist_keyarray = keyarray + [ ["Sp", "Select"], nil, ["Enter","View"] ]

    clist_keyarray = keyarray + [ ["Sp", "Select"], ["C-sp", "Range Sel"], ["Enter","View"] ]
    tarea_keyarray = keyarray + [ ["M-z", "Commands"], nil ]
    tarea_sub_keyarray = [ ["r", "Run"], ["c", "clear"], ["w","Save"], ["a", "Append next"], 
      ["y", "Yank"], ["Y", "yank pop"] ]

    gw = get_color($reversecolor, 'green', 'black')
    @adock = dock keyarray, { :row => Ncurses.LINES-2, :footer_color_pair => $datacolor, 
      :footer_mnemonic_color_pair => gw }
    @adock.set_key_labels tlist_keyarray, :tables
    @adock.set_key_labels clist_keyarray, :columns
    @adock.set_key_labels tarea_sub_keyarray, :tarea_sub
    @adock.set_key_labels tarea_keyarray, :tarea
    tlist.bind(:ENTER) { @adock.mode :tables }
    clist.bind(:ENTER) { @adock.mode :columns }



    @form.bind_key([?q,?q]) { throw :close }
    @form.bind_key(?\M-t) do
      if $current_db.nil?
        alert "Please select database first"
      else
        create_popup( get_table_names,:single) {|value| $current_table = value}
      end
    end
    @form.bind_key(?\M-d) do
      names = Dir.glob("**/*.{sqlite,db}")
      if names
        create_popup( names,:single) {|value| connect(value);
          @form.by_name["tlist"].list(get_table_names)
        }
      else
        alert "Can't find a .db or .sqlite file"
      end
    end
    @form.bind_key(Ncurses::KEY_F4) do
      if $current_table
        cols = "*"
        c = clist.get_selected_values
        unless c.empty?
          cols = c.join(",")
        end
        view_data cols, $current_table
      else
        alert "Select a table first." 
      end
    end
  end # stack
  stack :margin => 50, :width => :EXPAND  do
    tarea = textarea :name => 'tarea', :height => 20, :title => 'Sql Statement'
    tarea.bind_key(Ncurses::KEY_F4) do
      text = tarea.get_text
      if text == ""
        alert "Please enter a query and then hit F4. Or press F4 over column list"
      else
        view_sql tarea.get_text
      end
    end
    tarea.bind(:ENTER) { @adock.mode :tarea }
    tarea.bind_key(?\M-z){
      $log.debug "XXXX MZ inside M-z"
      @adock.mode :tarea_sub
      @adock.repaint
      keys = @adock.get_current_keys
      while((ch = @window.getchar()) != ?\C-c.getbyte(0) )
        if ch < 33 || ch > 126
          Ncurses.beep
        elsif !keys.include?(ch.chr) 
          Ncurses.beep
        else
          #opt_file ch.chr
          break
        end
      end
      @adock.mode :normal
    }
  end
end # app
#end
