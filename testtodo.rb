$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'lib/ver/ncurses'
#require 'lib/ver/keyboard'
require 'lib/ver/window'
require 'lib/rbcurse/rwidget'
require 'lib/rbcurse/rcombo'
require 'lib/rbcurse/rtable'
require 'lib/rbcurse/celleditor'
#require 'lib/rbcurse/table/tablecellrenderer'
require 'lib/rbcurse/comboboxcellrenderer'
require 'lib/rbcurse/keylabelprinter'
require 'lib/rbcurse/applicationheader'

class TodoList
  def initialize file
    @file = file
  end
  def load 
    @todomap = YAML::load(File.open(@file));
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
  def dump
    f = "#{@file}"
    File.open(f, "w") { |f| YAML.dump( @todomap, f )}
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
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils

  begin
    todo = TodoList.new "todo.yml"
    todo.load
    statuses = todo.get_statuses
    cats = todo.get_categories
    modules = todo.get_modules
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG

    @window = VER::Window.root_window

    catch(:close) do
      colors = Ncurses.COLORS
      $log.debug "START #{colors} colors  ---------"
      @form = Form.new @window
      title = "TODO APP"
      @header = ApplicationHeader.new @form, title, {"text2"=>"Some Text", "text_center"=>"Task Entry"}
      status_row = RubyCurses::Label.new @form, {'text' => "", "row" => Ncurses.LINES-4, "col" => 0, "display_length"=>60}
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
        bind(:ENTER){ status_row.text "Select a category and <TAB> out. KEY_UP, KEY_DOWN, M-Down" }
        bind(:LEAVE){ status_row.text "" }
      end
      data = todo.get_tasks_for_category 'TODO'
      @data = data
      $log.debug " data is #{data}"
      colnames = %w[ Module Prior Task Status]

      table_ht = 15
        texta = Table.new @form do
          name   "mytext" 
          row  r+2
          col  c
          width 78
          height table_ht
          #title "A Table"
          #title_attrib (Ncurses::A_REVERSE | Ncurses::A_BOLD)
          cell_editing_allowed true
          editing_policy :EDITING_AUTO
          set_data data, colnames
        end
        categ.bind(:CHANGED) do |fld| $log.debug " COMBO EXIT XXXXXXXX"; 
        data = todo.get_tasks_for_category fld.getvalue; 
        @data = data
        $log.debug " DATA is #{data.inspect} : #{data.length}"
        data = [[nil, 5, "NEW ", "TODO", Time.now]] if data.nil? or data.empty? or data.size == 0
        $log.debug " DATA is #{data.inspect} : #{data.length}"
        texta.table_model.data = data
        end

        tcm = texta.get_table_column_model
        #
        ## key bindings fo texta
        # column widths 
        $log.debug " tcm #{tcm.inspect}"
        $log.debug " tcms #{tcm.columns}"
          tcm.column(0).width 8
          tcm.column(1).width 5
          tcm.column(2).width 50
          tcm.column(3).width 8
        texta.configure() do
          #bind_key(330) { texta.remove_column(tcm.column(texta.focussed_col)) rescue ""  }
          bind_key(?+) {
            acolumn = texta.column texta.focussed_col()
            w = acolumn.width + 1
            acolumn.width w
            #texta.table_structure_changed
          }
          bind_key(?-) {
            acolumn = texta.column texta.focussed_col()
            w = acolumn.width - 1
            if w > 3
            acolumn.width w
            #texta.table_structure_changed
            end
          }
          bind_key(?>) {
            colcount = tcm.column_count-1
            #texta.move_column sel_col.value, sel_col.value+1 unless sel_col.value == colcount
            col = texta.focussed_col
            texta.move_column col, col+1 unless col == colcount
          }
          bind_key(?<) {
            col = texta.focussed_col
            texta.move_column col, col-1 unless col == 0
            #texta.move_column sel_col.value, sel_col.value-1 unless sel_col.value == 0
          }
        end
      #keylabel = RubyCurses::Label.new @form, {'text' => "", "row" => r+table_ht+3, "col" => c, "color" => "yellow", "bgcolor"=>"blue", "display_length"=>60, "height"=>2}
      #eventlabel = RubyCurses::Label.new @form, {'text' => "Events:", "row" => r+table_ht+6, "col" => c, "color" => "white", "bgcolor"=>"blue", "display_length"=>60, "height"=>2}

      # report some events
      #texta.table_model.bind(:TABLE_MODEL_EVENT){|e| #eventlabel.text = "Event: #{e}"}
      #texta.get_table_column_model.bind(:TABLE_COLUMN_MODEL_EVENT){|e| eventlabel.text = "Event: #{e}"}
      texta.bind(:TABLE_TRAVERSAL_EVENT){|e| @header.text_right "Row #{e.newrow+1} of #{texta.row_count}" }


      str_renderer = TableCellRenderer.new ""
      num_renderer = TableCellRenderer.new "", { "justify" => :right }
      bool_renderer = CheckBoxCellRenderer.new "", {"parent" => texta, "display_length"=>5}
      combo_renderer =  RubyCurses::ComboBoxCellRenderer.new nil, {"parent" => texta, "display_length"=> 8}
      combo_editor = RubyCurses::CellEditor.new(RubyCurses::ComboBox.new nil, {"focusable"=>false, "visible"=>false, "list"=>statuses, "display_length"=>8})
      combo_editor1 = RubyCurses::CellEditor.new(RubyCurses::ComboBox.new nil, {"focusable"=>false, "visible"=>false, "list"=>modules, "display_length"=>8})
      texta.set_default_cell_renderer_for_class "String", str_renderer
      texta.set_default_cell_renderer_for_class "Fixnum", num_renderer
      texta.set_default_cell_renderer_for_class "Float", num_renderer
      texta.set_default_cell_renderer_for_class "TrueClass", bool_renderer
      texta.set_default_cell_renderer_for_class "FalseClass", bool_renderer
      texta.get_table_column_model.column(3).cell_editor =  combo_editor
      texta.get_table_column_model.column(0).cell_editor =  combo_editor1
      ce = texta.get_default_cell_editor_for_class "String"
      # increase the maxlen of task
      ce.component.maxlen = 80
      # I want up and down to go up and down rows inside the combo box, i can use M-down for changing.
      combo_editor.component.unbind_key(KEY_UP)
      combo_editor.component.unbind_key(KEY_DOWN)
      combo_editor1.component.unbind_key(KEY_UP)
      combo_editor1.component.unbind_key(KEY_DOWN)
      texta.bind(:TABLE_EDITING_EVENT) do |evt|
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
=begin
      combo_editor.component.bind(:CHANGED){
        alert("CHANGED, #{texta.focussed_row}, #{@data[texta.focussed_row].size}")
        if @data.size == 4
          @data[texta.focussed_row] << Time.now
        else
          @data[texta.focussed_row][4] == Time.now
        end
        $log.debug "THSI ROW #{@data[texta.focussed_row]}"
        $log.debug "DATAAAA: #{@data}"
      }
=end
      #combo_editor.component.bind(:LEAVE){ alert "LEAVE"; $log.debug " LEAVE FIRED" }
        buttrow = r+table_ht+8 #Ncurses.LINES-4
        buttrow = Ncurses.LINES-5
      b_save = Button.new @form do
        text "&Save"
        row buttrow
        col c
        command {
          # this does not trigger a data change since we are not updating model. so update
          # on pressing up or down
          #0.upto(100) { |i| data << ["test", rand(100), "abc:#{i}", rand(100)/2.0]}
          #texta.table_data_changed
          todo.set_tasks_for_category categ.getvalue, data
          todo.dump
          alert("Rewritten yaml file")
        }
        bind(:ENTER) { status_row.text "Save changes to todo.yml " }
      end
      b_newrow = Button.new @form do
        text "&New"
        row buttrow
        col c+10
        bind(:ENTER) { status_row.text "New button adds a new row below current " }
      end
      b_newrow.command { 
        cc = texta.get_table_column_model.column_count
        frow = texta.focussed_row
        mod = texta.get_value_at(frow,0)
        tmp = [mod, 5, "", "TODO", Time.now]
        tm = texta.table_model
        tm.insert frow+1, tmp
        texta.set_focus_on frow+1
        status_row.text = "Added a row. Please press Save before changing Category."
        alert("Added a row below current one. Use C-k to clear task.")

      }

      # using ampersand to set mnemonic
      b_delrow = Button.new @form do
        text "&Delete"
        row buttrow
        col c+20
        bind(:ENTER) { status_row.text "Deletes focussed row" }
      end
      b_delrow.command { |form| 
        row = texta.focussed_row
        if confirm("Do your really want to delete row #{row+1}?")== :YES
          tm = texta.table_model
          tm.delete_at row
        else
          status_row.text = "Delete cancelled"
        end
      }
      b_change = Button.new @form do
        text "&Lock"
        row buttrow
        col c+30
        command {
          r = texta.focussed_row
          #c = sel_col.value
          #$log.debug " Update gets #{field.getvalue.class}"
          #texta.set_value_at(r, c, field.getvalue)
          toggle = texta.column(texta.focussed_col()).editable 
          if toggle.nil? or toggle==true
            toggle = false 
            text "Un&lock"
          else
            toggle = true
            text "&Lock  "
          end
          #eventlabel.text "Set column  #{texta.focussed_col()} editable to #{toggle}"
          texta.column(texta.focussed_col()).editable toggle
          alert("Set column  #{texta.focussed_col()} editable to #{toggle}")
        }
        bind(:ENTER) { status_row.text "Toggles editable state of current column " }
      end
      b_move = Button.new @form do
        text "&Move"
        row buttrow
        col c+40
        bind(:ENTER) { status_row.text "Move current row to Done" }
      end
      b_move.command { |form| 
        return if categ.getvalue == "DONE"
        row = texta.focussed_row
        d = todo.get_tasks_for_category "DONE"
        r = []
        tcm = texta.get_table_column_model
        tcm.each_with_index do |acol, colix|
          r << texta.get_value_at(row, colix)
        end
        # here i ignore the 5th row tht coud have been added
        r << Time.now
        d << r
        todo.set_tasks_for_category "DONE", d
        tm = texta.table_model
        ret = tm.delete_at row
        alert("Moved row #{row} to Done.")
      }
      @klp = RubyCurses::KeyLabelPrinter.new @form, get_key_labels
      @klp.set_key_labels get_key_labels_table, :table
      texta.bind(:ENTER){ @klp.mode :table ;
        status_row.text = "Please press Save (M-s) before changing Category."
      }
      texta.bind(:LEAVE){@klp.mode :normal; 
      }


      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != ?\C-q )
        colcount = tcm.column_count-1
        s = keycode_tos ch
        #status_row.text = "Pressed #{ch} , #{s}"
        @form.handle_key(ch)

        @form.repaint
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
