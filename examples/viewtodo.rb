$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rcombo'
require 'rbcurse/rtable'
require 'rbcurse/keylabelprinter'
require 'rbcurse/applicationheader'
require 'rbcurse/action'
require 'yaml'   # 1.9 2009-10-05 13:11 
###############################
## THIS WONT WORK SINCE I've changed to format of yaml file to array from hash
##############################

class TodoList
  def initialize file
    @file = file
  end
  def load 
    @todomap = YAML::load(File.open(@file));
    @records = convert_to_text
  end
  def get_statuses
    @todomap['__STATUSES']
  end
  def get_modules
    @todomap['__MODULES'].sort
  end
  def get_categories
    @todomap.keys.delete_if {|k| k.match(/^__/) }
  end
  def get_tasks_for_category categ
    c = @todomap[categ]
    d = []
    c.each_pair {|k,v|
      v.each do |r| 
        row=[]
        row << k
        r.each { |r1| row << r1 }
        d << row
        #$log.debug " ROW = #{row.inspect} "
      end
    }
    return d
  end
  def get_records_for_category categ
    if categ.nil? or categ == ""
      return @records
    else
      return @records.select { |row| row[0] == categ }
    end
  end
  def sort categ, column, descending=false
    d = get_records_for_category categ
    d = d.sort { |y,x| 
      if descending
        if x[column].nil?
          $log.debug "sort -1"
          -1
        elsif y[column].nil?
          $log.debug "sort 1"
          1
        else
          $log.debug "sort <> #{x[column]} <=> #{y[column]} "
          x[column] <=> y[column] 
        end
      else
        if x[column].nil?
         1 
        elsif y[column].nil?
          -1
        else
          y[column] <=> x[column] 
        end
      end
    }
    return d
  end
  def set_tasks_for_category categ, data
    d = {}
    data.each do |row|
      #key = row.delete_at 0
      key = row.first
      d[key] ||= []
      d[key] << row[1..-1]
    end
    @todomap[categ]=d
    $log.debug " NEW DATA #{categ}: #{data}"
  end
  def convert_to_text
    d = []
    cats = get_categories
    cats.each do |c|
      tasks = get_tasks_for_category c
      tasks.each do |t|
        n = t.dup
        n.insert 0, c
        d << n
      end
    end
    return d
  end
=begin
    File.open("todo.csv", "w") { |f| YAML.dump( d, f )}
    buf =''
    require 'csv'
    CSV.open('todocsv.csv', 'w') do |writer|     
      #writer << [nil, nil]                  
      d.each do |row|
        #parced_cells = CSV.generate_rows(row, row.size, buf)
        writer << row
      end
    end  
=end
  def dump
    f = "#{@file}"
    #File.open(f, "w") { |f| YAML.dump( @todomap, f )}
    convert_to_text
  end
end
def get_key_labels
  key_labels = [
    ['C-q', 'Exit'], nil,
    ['M-c', 'Category'], nil,
    ['M-f', 'Filter Fld'], ['M-p', 'Pattern'],
    ['M-s', 'Sort'], ['M-i', 'Filter']
  ]
  return key_labels
end
def get_key_labels_table
  key_labels = [
    ['M-n','NewRow'], ['M-d','DelRow'],
    ['C-x','Select'], nil,
    ['M-0', 'Top'], ['M-9', 'End'],
    ['C-p', 'PgUp'], ['C-n', 'PgDn'],
    ['M-Tab','Nxt Fld'], ['Tab','Nxt Col'],
    ['+','Widen'], ['-','Narrow']
  ]
  return key_labels
end
class TodoApp
  def initialize
    @window = VER::Window.root_window
    @form = Form.new @window
    @sort_dir = true

    @todo = TodoList.new "todo.yml"
    @todo.load
  end
  def run
    todo = @todo
    statuses = todo.get_statuses
    cats = todo.get_categories
    cats.insert 0,""
    modules = todo.get_modules
    title = "TODO APP"
    @header = ApplicationHeader.new @form, title, {:text2=>"Some Text", :text_center=>"Task View"}
    status_row = RubyCurses::Label.new @form, {'text' => "", :row => Ncurses.LINES-4, :col => 0, :display_length=>60}
    @status_row = status_row
    # setting ENTER across all objects on a form
    @form.bind(:ENTER) {|f| status_row.text = f.help_text unless f.help_text.nil? }
    #@window.printstring 0,(Ncurses.COLS-title.length)/2,title, $datacolor
    r = 1; c = 1;
    categ = ComboBox.new @form do
      name "categ"
      row r
      col 15
      display_length 10
      editable false
      list cats
      set_label Label.new @form, {'text' => "Category", 'color'=>'cyan','col'=>1, "mnemonic"=>"C"}
      list_config 'height' => 4
      help_text "Select a category and <TAB> out. KEY_UP, KEY_DOWN, M-Down" 
    end
    colnames = %w[ Categ Module Prior Task Status Date]

    colnames_cbl = colnames.dup
    colnames_cbl.insert 0, ""
    col_combo = ComboBox.new @form do
      name "col_combo"
      row r
      col 45
      display_length 10
      editable false
      list colnames_cbl
      set_label Label.new @form, {'text' => "Filter on:", 'color'=>'cyan',"mnemonic"=>"F"}
      list_config 'height' => 6
      help_text "Select a field to filter on"
    end
    col_value = Field.new @form do
      name "col_value"
      row r+1
      col 45
      bgcolor 'cyan'
      color 'white'
      display_length 10
      set_label Label.new @form, {'text' => "Pattern:", 'color'=>'cyan',:bgcolor => 'black',"mnemonic"=>"P"}
      help_text "Pattern/Regex to filter on"
    end
    data = todo.get_records_for_category 'TODO'
    @data = data
    b_filter = Button.new @form do
      text "Fi&lter"
      row r
      col 65
      help_text "Filter on selected filter column and value"
      #bind(:ENTER) { status_row.text "New button adds a new row below current " }
    end


    table_ht = 15
    atable = Table.new @form do
      name   "tasktable" 
      row  r+2
      col  c
      width 104
      height table_ht
      #title "A Table"
      #title_attrib (Ncurses::A_REVERSE | Ncurses::A_BOLD)
      cell_editing_allowed false
      set_data data, colnames
    end
    @atable = atable
    categ.bind(:CHANGED) do |fld| $log.debug " COMBO EXIT XXXXXXXX"; 
      data = todo.get_records_for_category fld.getvalue; 
      @data = data
      atable.table_model.data = data
    end
    b_filter.command { 
      alert("Data is blank") if data.nil? or data.size == 0
      raise("Data is blank") if data.nil? or data.size == 0
      raise("selected is blank") if col_combo.selected_item.nil?
      raise("col_val is blank") if col_value.getvalue.nil?

      $log.debug "#{col_combo.selected_index},   .#{col_value.getvalue}" 
      d = data.select {|row| row[col_combo.selected_index-1].to_s.match(col_value.getvalue) }
      atable.table_model.data = d unless d.nil? or d.size == 0
    }

    tcm = atable.get_table_column_model
    #
    ## key bindings fo atable
    # column widths 
    tcm.column(0).width 8
    tcm.column(1).width 8
    tcm.column(2).width 5
    tcm.column(3).width 50
    tcm.column(4).width 8
    tcm.column(5).width 16
    app = self
    atable.configure() do
      #bind_key(330) { atable.remove_column(tcm.column(atable.focussed_col)) rescue ""  }
      bind_key(?+) {
        acolumn = atable.column atable.focussed_col()
        w = acolumn.width + 1
        acolumn.width w
        #atable.table_structure_changed
      }
      bind_key(?-) {
        acolumn = atable.column atable.focussed_col()
        w = acolumn.width - 1
        if w > 3
          acolumn.width w
          #atable.table_structure_changed
        end
      }
      bind_key(?>) {
        colcount = tcm.column_count-1
        #atable.move_column sel_col.value, sel_col.value+1 unless sel_col.value == colcount
        col = atable.focussed_col
        atable.move_column col, col+1 unless col == colcount
      }
      bind_key(?<) {
        col = atable.focussed_col
        atable.move_column col, col-1 unless col == 0
        #atable.move_column sel_col.value, sel_col.value-1 unless sel_col.value == 0
      }
      bind_key(?\M-h, app) {|tab,td| $log.debug " BIND... #{tab.class}, #{td.class}"; app.make_popup atable}
    end
    #keylabel = RubyCurses::Label.new @form, {'text' => "", "row" => r+table_ht+3, "col" => c, "color" => "yellow", "bgcolor"=>"blue", "display_length"=>60, "height"=>2}
    #eventlabel = RubyCurses::Label.new @form, {'text' => "Events:", "row" => r+table_ht+6, "col" => c, "color" => "white", "bgcolor"=>"blue", "display_length"=>60, "height"=>2}

    # report some events
    #atable.table_model.bind(:TABLE_MODEL_EVENT){|e| #eventlabel.text = "Event: #{e}"}
    #atable.get_table_column_model.bind(:TABLE_COLUMN_MODEL_EVENT){|e| eventlabel.text = "Event: #{e}"}
    atable.bind(:TABLE_TRAVERSAL_EVENT){|e| @header.text_right "Row #{e.newrow+1} of #{atable.row_count}" }


    #str_renderer = TableCellRenderer.new ""
    #num_renderer = TableCellRenderer.new "", { "justify" => :right }
    #bool_renderer = CheckBoxCellRenderer.new "", {"parent" => atable, "display_length"=>5}
    #combo_renderer =  RubyCurses::ComboBoxCellRenderer.new nil, {"parent" => atable, "display_length"=> 8}
    #combo_editor = RubyCurses::CellEditor.new(RubyCurses::ComboBox.new nil, {"focusable"=>false, "visible"=>false, "list"=>statuses, "display_length"=>8})
    #combo_editor1 = RubyCurses::CellEditor.new(RubyCurses::ComboBox.new nil, {"focusable"=>false, "visible"=>false, "list"=>modules, "display_length"=>8})
    #atable.set_default_cell_renderer_for_class "String", str_renderer
    #atable.set_default_cell_renderer_for_class "Fixnum", num_renderer
    #atable.set_default_cell_renderer_for_class "Float", num_renderer
    #atable.set_default_cell_renderer_for_class "TrueClass", bool_renderer
    #atable.set_default_cell_renderer_for_class "FalseClass", bool_renderer
    #atable.get_table_column_model.column(3).cell_editor =  combo_editor
    #atable.get_table_column_model.column(0).cell_editor =  combo_editor1
    #ce = atable.get_default_cell_editor_for_class "String"
    # increase the maxlen of task
    #ce.component.maxlen = 80
    # I want up and down to go up and down rows inside the combo box, i can use M-down for changing.
    #combo_editor.component.unbind_key(KEY_UP)
    #combo_editor.component.unbind_key(KEY_DOWN)
    #combo_editor1.component.unbind_key(KEY_UP)
    #combo_editor1.component.unbind_key(KEY_DOWN)
    buttrow = r+table_ht+8 #Ncurses.LINES-4
    buttrow = Ncurses.LINES-5
    create_table_actions atable, todo, data, categ.getvalue
=begin
    b_newrow = Button.new @form do
      text "&New"
      row buttrow
      col c+10
      bind(:ENTER) { status_row.text "New button adds a new row below current " }
    end
    b_newrow.command { @new_act.call }
=end
    ## We use Action to create a button: to test out ampersand with MI and Button
    new_act = @new_act
    # using ampersand to set mnemonic
    b_sort = Button.new @form do
      text "&Sort"
      row buttrow
      col c+25
      #bind(:ENTER) { status_row.text "Deletes focussed row" }
      help_text "Sort focussed row" 
    end
    b_sort.command { 
      if @sorted_key == atable.focussed_col
        @sort_dir = !@sort_dir
      else
        @sort_dir = true
      end
      @sorted_key = atable.focussed_col

      $log.debug " SORT =  #{categ.getvalue}, #{atable.focussed_col}, sort:#{@sort_dir}"
      d = @todo.sort categ.getvalue, atable.focussed_col, @sort_dir
      atable.table_model.data = d
    }
=begin
    b_change = Button.new @form do
      text "&Lock"
      row buttrow
      col c+35
      command {
        r = atable.focussed_row
        #c = sel_col.value
        #$log.debug " Update gets #{field.getvalue.class}"
        #atable.set_value_at(r, c, field.getvalue)
        toggle = atable.column(atable.focussed_col()).editable 
        if toggle.nil? or toggle==true
          toggle = false 
          text "Un&lock"
        else
          toggle = true
          text "&Lock  "
        end
        #eventlabel.text "Set column  #{atable.focussed_col()} editable to #{toggle}"
        atable.column(atable.focussed_col()).editable toggle
        alert("Set column  #{atable.focussed_col()} editable to #{toggle}")
      }
      help_text "Toggles editable state of current column "
    end
=end
      #buttons = [b_save, b_newrow, b_delrow, b_move ]
      #Button.button_layout buttons, buttrow
    @klp = RubyCurses::KeyLabelPrinter.new @form, get_key_labels
    @klp.set_key_labels get_key_labels_table, :table
    atable.bind(:ENTER){ @klp.mode :table ;
    }
    atable.bind(:LEAVE){@klp.mode :normal; 
    }


    @form.repaint
    @window.wrefresh
    Ncurses::Panel.update_panels
    begin
    while((ch = @window.getchar()) != ?\C-q.getbyte(0) )
      colcount = tcm.column_count-1
      s = keycode_tos ch
      #status_row.text = "Pressed #{ch} , #{s}"
      @form.handle_key(ch)

      @form.repaint
      @window.wrefresh
    end
    ensure
    @window.destroy if !@window.nil?
    end
  end
  def create_table_actions atable, todo, data, categ
    #@new_act = Action.new("New Row", "mnemonic"=>"N") { 
    @new_act = Action.new("&New Row") { 
      cc = atable.get_table_column_model.column_count
      if atable.row_count < 1
        mod = nil
        frow = 0
      else
        frow = atable.focussed_row
        frow += 1
        mod = atable.get_value_at(frow,0)
      end
      tmp = [mod, 5, "", "TODO", Time.now]
      tm = atable.table_model
      tm.insert frow, tmp
      atable.set_focus_on frow
      @status_row.text = "Added a row. Please press Save before changing Category."
      alert("Added a row below current one. Use C-k to clear task.")
    }
    @new_act.accelerator "Alt-N"
    @save_cmd = lambda {
        todo.set_tasks_for_category categ, data
        todo.dump
        alert("Rewritten yaml file")
    }
    @del_cmd = lambda { 
      row = atable.focussed_row
      if confirm("Do your really want to delete row #{row+1}?")== :YES
        tm = atable.table_model
        tm.delete_at row
      else
        @status_row.text = "Delete cancelled"
      end
    }

  end
  def make_popup table
    require 'rbcurse/rpopupmenu'
    tablemenu = RubyCurses::PopupMenu.new "Table"
    #tablemenu.add(item = RubyCurses::MenuItem.new("Open",'O'))
    tablemenu.add(item = RubyCurses::MenuItem.new("&Open"))

    tablemenu.insert_separator 1
    #tablemenu.add(RubyCurses::MenuItem.new "New",'N')
    tablemenu.add(@new_act)
    tablemenu.add(item = RubyCurses::MenuItem.new("&Save"))
    item.command() { @save_cmd.call }

    item=RubyCurses::MenuItem.new "Select"
    item.accelerator = "Ctrl-X"
    item.command() { table.toggle_row_selection() }
    #item.enabled = false
    tablemenu.add(item)

    item=RubyCurses::MenuItem.new "Clr Selection"
    item.accelerator = "Alt-e"
    item.command() { table.clear_selection() }
    item.enabled = table.selected_row_count > 0 ? true : false
    tablemenu.add(item)

    item=RubyCurses::MenuItem.new "Delete"
    item.accelerator = "Alt-D"
    item.command() { @del_cmd.call }
    tablemenu.add(item)

    gotomenu = RubyCurses::Menu.new "&Goto"

    item = RubyCurses::MenuItem.new "Top"
    item.accelerator = "Alt-0"
    item.command() { table.goto_top }
    gotomenu.add(item)

    item = RubyCurses::MenuItem.new "Bottom"
    item.accelerator = "Alt-9"
    item.command() { table.goto_bottom }
    gotomenu.add(item)

    item = RubyCurses::MenuItem.new "Next Page"
    item.accelerator = "Ctrl-n"
    item.command() { table.scroll_forward }
    gotomenu.add(item)

    item = RubyCurses::MenuItem.new "Prev Page"
    item.accelerator = "Ctrl-p"
    item.command() { table.scroll_backward }
    gotomenu.add(item)

    tablemenu.add(gotomenu)


    tablemenu.show @atable, 0,1
  end
end
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils

  begin
    # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG

    colors = Ncurses.COLORS

    catch(:close) do
      t = TodoApp.new
      t.run
  end
  rescue => ex
  ensure
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
