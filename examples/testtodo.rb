#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
#require 'ver/keyboard'
require 'rbcurse'
require 'rbcurse/rcombo'
require 'rbcurse/rtable'
require 'rbcurse/celleditor'
#require 'rbcurse/table/tablecellrenderer'
require 'rbcurse/comboboxcellrenderer'
require 'rbcurse/keylabelprinter'
require 'rbcurse/applicationheader'
require 'rbcurse/action'

# TODO move the csv to a database so you can update. this sucketh.
#
class TodoList
  def initialize file
    @file = file
  end
  def load 
    #@todomap = YAML::load(File.open(@file));
    @data =[]
    @statuses=[]
    @categories=[]
    @modules=[]
    require 'csv'
    #CSV::Reader.parse(File.open(@file, 'r')) do |row|
    CSV.foreach(@file) do |row|    # 1.9 2009-10-05 11:12 
      @data << row
      $log.debug " #{row.inspect} "
      @categories << row[0] unless @categories.include? row[0]
      @statuses << row[4] unless @statuses.include? row[4]
      @modules << row[1] unless @modules.include? row[1]
    end
    $log.debug " MOD #{@modules}"
  end
  def get_statuses
    #    @todomap['__STATUSES']
    @statuses
  end
  def get_modules
    #@todomap['__MODULES'].sort
    @modules.sort
  end
  def get_categories
    #@todomap.keys.delete_if {|k| k.match(/^__/) }
    @categories
  end
  def get_tasks_for_category categ
    @data.select do |row|
      row[0] == categ
    end
  end
  def insert_task_for_category task, categ
    task[0] = categ
    @data << task
  end
  def delete_task task
    @data.delete task
  end
  def oldget_tasks_for_category categ
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
  def set_tasks_for_category categ, data
  $log.debug " def set_tasks_for_category #{categ}, #{data.size} old #{@data.size}"
    @data.delete_if { |row| row[0] == categ }
  $log.debug " 2 def set_tasks_for_category #{categ}, #{data.size} old #{@data.size}"
  data.each { |row| row[0] = categ }
    @data.insert -1, *data
  $log.debug " 3 def set_tasks_for_category #{categ}, #{data.size} old #{@data.size}"
  end
  def old_set_tasks_for_category categ, data
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
=begin
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
    #File.open("todo.yml", "w") { |f| YAML.dump( d, f )}
    buf =''
=end
    d = @data
    require 'csv'
    #CSV.open('todocsv.csv', 'w') do |writer|     
    CSV.open("todocsv.csv", "w") do |writer|
      #writer << [nil, nil]                  
      d.each do |row|
        #parced_cells = CSV.generate_rows(row, row.size, buf)
        writer << row
      end
    end  
  end
  def dump
    f = "#{@file}"
    #File.open(f, "w") { |f| YAML.dump( @todomap, f )}
    convert_to_text
  end
end
def get_key_labels
  key_labels = [
    ['C-q', 'Exit'], nil,
    ['M-s', 'Save'], ['M-m', 'Move']
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

    @todo = TodoList.new "todocsv.csv"
    @todo.load
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

    searchmenu = RubyCurses::Menu.new "&Search"

    item = RubyCurses::MenuItem.new "Find forward"
    item.accelerator = "Alt-f"
    item.command() { table.ask_search_forward }
    searchmenu.add(item)

    item = RubyCurses::MenuItem.new "Find backward"
    item.accelerator = "Alt-F"
    item.command() { table.ask_search_backward }
    searchmenu.add(item)

    item = RubyCurses::MenuItem.new "Find Next"
    item.accelerator = "Alt-g"
    item.enabled = false if table.table_model.last_regex.nil?
    item.command() { table.find_next }
    searchmenu.add(item)

    item = RubyCurses::MenuItem.new "Find Prev"
    item.accelerator = "Alt-G"
    item.enabled = false if table.table_model.last_regex.nil?
    item.command() { table.find_prev }
    searchmenu.add(item)

    tablemenu.add(searchmenu)

    tablemenu.show @atable, 0,1
  end
  def run
    todo = @todo
    statuses = todo.get_statuses
    cats = todo.get_categories
    modules = todo.get_modules
    title = "TODO APP"
    @header = ApplicationHeader.new @form, title, {:text2=>"Some Text", :text_center=>"Task Entry"}
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
      set_buffer 'TODO'
      set_label Label.new @form, {'text' => "Category", 'color'=>'cyan','col'=>1, "mnemonic"=>"C"}
      list_config 'height' => 4
      help_text "Select a category and <TAB> out. KEY_UP, KEY_DOWN, M-Down" 
      bind(:LEAVE){ status_row.text "" }
    end
    data = todo.get_tasks_for_category 'TODO'
    @data = data
    $log.debug " data is #{data}"
    colnames = %w[ Categ Module Prior Task Status]

    table_ht = 15
    atable = Table.new @form do
      name   "tasktable" 
      row  r+2
      col  c
      width 84
      height table_ht
      #title "A Table"
      #title_attrib (Ncurses::A_REVERSE | Ncurses::A_BOLD)
      cell_editing_allowed true
      editing_policy :EDITING_AUTO
      set_data data, colnames
    end
    @atable = atable
    categ.bind(:CHANGED) do |fld| $log.debug " COMBO EXIT XXXXXXXX"; 
    data = todo.get_tasks_for_category fld.getvalue; 
    @data = data
    $log.debug " DATA is #{data.inspect} : #{data.length}"
    data = [['FIXME',nil, 5, "NEW ", "TODO", Time.now]] if data.nil? or data.empty? or data.size == 0
    #$log.debug " DATA is #{data.inspect} : #{data.length}"
    atable.table_model.data = data
    end

    tcm = atable.get_table_column_model
    #
    ## key bindings fo atable
    # column widths 
    #$log.debug " tcm #{tcm.inspect}"
    #$log.debug " tcms #{tcm.columns}"
    tcm.column(0).width 5
    tcm.column(0).editable false
    tcm.column(1).width 8
    tcm.column(2).width 5
    tcm.column(3).width 50
    tcm.column(3).edit_length 80
    tcm.column(4).width 8
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


    str_renderer = TableCellRenderer.new ""
    num_renderer = TableCellRenderer.new "", { "justify" => :right }
    bool_renderer = CheckBoxCellRenderer.new "", {"parent" => atable, "display_length"=>5}
    combo_renderer =  RubyCurses::ComboBoxCellRenderer.new nil, {"parent" => atable, "display_length"=> 8}
    combo_editor = RubyCurses::CellEditor.new(RubyCurses::ComboBox.new nil, {"focusable"=>false, "visible"=>false, "list"=>statuses, "display_length"=>8})
    combo_editor1 = RubyCurses::CellEditor.new(RubyCurses::ComboBox.new nil, {"focusable"=>false, "visible"=>false, "list"=>modules, "display_length"=>8})
    atable.set_default_cell_renderer_for_class "String", str_renderer
    atable.set_default_cell_renderer_for_class "Fixnum", num_renderer
    atable.set_default_cell_renderer_for_class "Float", num_renderer
    atable.set_default_cell_renderer_for_class "TrueClass", bool_renderer
    atable.set_default_cell_renderer_for_class "FalseClass", bool_renderer
    atable.get_table_column_model.column(4).cell_editor =  combo_editor
    atable.get_table_column_model.column(1).cell_editor =  combo_editor1
    ce = atable.get_default_cell_editor_for_class "String"
    # increase the maxlen of task
    # ce.component.maxlen = 80 # this is obsolete, use edit_length
    # I want up and down to go up and down rows inside the combo box, i can use M-down for changing.
    combo_editor.component.unbind_key(KEY_UP)
    combo_editor.component.unbind_key(KEY_DOWN)
    combo_editor1.component.unbind_key(KEY_UP)
    combo_editor1.component.unbind_key(KEY_DOWN)
    atable.bind(:TABLE_EDITING_EVENT) do |evt|
      #return if evt.oldvalue != evt.newvalue
      $log.debug " TABLE_EDITING : #{evt} "
      if evt.type == :EDITING_STOPPED
        if evt.col == 3
          if @data[evt.row].size == 4
            @data[evt.row] << Time.now
          else
            @data[evt.row][4] == Time.now
          end
        end
      end
    end
    #combo_editor.component.bind(:LEAVE){ alert "LEAVE"; $log.debug " LEAVE FIRED" }
    buttrow = r+table_ht+8 #Ncurses.LINES-4
    buttrow = Ncurses.LINES-5
    create_table_actions atable, todo, data, categ.getvalue
    save_cmd = @save_cmd
    b_save = Button.new @form do
      text "&Save"
      row buttrow
      col c
      command {
        save_cmd.call
      }
      help_text "Save changes to todo.yml " 
    end
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
    b_newrow = Button.new @form do
      action new_act
      row buttrow
      col c+10
      help_text "New button adds a new row below current "
      #bind(:ENTER) { status_row.text "New button adds a new row below current " }
    end

    # using ampersand to set mnemonic
    b_delrow = Button.new @form do
      text "&Delete"
      row buttrow
      col c+25
      #bind(:ENTER) { status_row.text "Deletes focussed row" }
      help_text "Deletes focussed row" 
    end
    b_delrow.command { 
      @del_cmd.call
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
    b_move = Button.new @form do
      text "&Move"
      row buttrow
      col c+45
      help_text "Move current row to Done" 
    end
    b_move.command { |form| 
      #mods = cats.delete categ.getvalue

      mods = cats - [categ.getvalue]
      @mb = RubyCurses::MessageBox.new do
        title "Change Module"
        message "Move to? "
        type :custom
        button_type :custom
        buttons mods
      end
      #return if categ.getvalue == "DONE"
      amod = mods[@mb.selected_index]
      row = atable.focussed_row
      d = todo.get_tasks_for_category amod
      $log.debug " retrieved #{d.size} rows for #{amod}"
      r = []
      tcm = atable.table_column_model
      tcm.each_with_index do |acol, colix|
        r << atable.get_value_at(row, colix)
      end
      # here i ignore the 5th row tht coud have been added
      r << Time.now
      d << r
      $log.debug " sending #{d.size} rows for #{amod}"
      todo.set_tasks_for_category amod, d
      $log.debug " MOVE #{data.size} rows for #{categ.getvalue}"
      tm = atable.table_model
      ret = tm.delete_at row
      $log.debug " MOVE after del #{data.size} rows for #{categ.getvalue}"
      todo.set_tasks_for_category categ.getvalue, data
      alert("Moved row #{row} to #{amod}.")
    }
    b_view = Button.new @form do
      text "View"
      row r
      col 65
      help_text "View sort and filter tasks in another window"
      command { require 'viewtodo'; todo = TodoApp.new; todo.run }
    end
      buttons = [b_save, b_newrow, b_delrow, b_move , b_view ]
      Button.button_layout buttons, buttrow
    @klp = RubyCurses::KeyLabelPrinter.new @form, get_key_labels
    @klp.set_key_labels get_key_labels_table, :table
    atable.bind(:ENTER){ @klp.mode :table ;
      status_row.text = "Please press Save (M-s) before changing Category."
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
      mod = nil
      cat = 'TODO'
      cc = atable.get_table_column_model.column_count
      if atable.row_count < 1
        frow = 0
      else
        frow = atable.focussed_row
        #frow += 1 # why ?
        cat = atable.get_value_at(frow,0) unless frow.nil?
        mod = atable.get_value_at(frow,1) unless frow.nil?
      end
      tmp = [cat,mod, 5, "", "TODO", Time.now]
      tm = atable.table_model
      tm.insert frow, tmp
      atable.set_focus_on frow
      @status_row.text = "Added a row. Please press Save before changing Category."
      alert("Added a row before current one. Use C-k to clear task.")
    }
    @new_act.accelerator "Alt-N"
    @save_cmd = lambda {
        todo.set_tasks_for_category categ, data
        todo.dump
        alert("Rewritten csv file")
    }
    @del_cmd = lambda { 
      row = atable.focussed_row
      if !row.nil?
      if confirm("Do your really want to delete row #{row+1}?")== :YES
        tm = atable.table_model
        tm.delete_at row
      else
        @status_row.text = "Delete cancelled"
      end
      end
    }

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
    $log.debug "START #{colors} colors  ---------"

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
