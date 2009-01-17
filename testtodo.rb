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
    @todomap['TODO'].keys
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
        $log.debug " ROW = #{row.inspect} "
      end
    }
    return d
  end
  def dump
    File.open(@file, "w") { |f| YAML.dump( @todomap, f )}
  end
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
      @window.printstring 0,(Ncurses.COLS-title.length)/2,title, $datacolor
      r = 1; c = 15;
      categ = ComboBox.new @form do
        name "categ"
        row r
        col c
        display_length 10
        editable false
        list cats
        set_buffer 'TODO'
        set_label Label.new @form, {'text' => "Category", 'color'=>'cyan','col'=>1, "mnemonic"=>"C"}
        list_config 'height' => 4
      end
      data = todo.get_tasks_for_category 'TODO'
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
        categ.bind(:LEAVE) do |fld| $log.debug " COMBO EXIT XXXXXXXX"; 
        data = todo.get_tasks_for_category fld.getvalue; 
        $log.debug " DATA is #{data.inspect} : #{data.length}"
        data = [[nil, 5, "NEW TASK", "TODO"]] if data.nil? or data.empty? or data.size == 0
        $log.debug " DATA is #{data.inspect} : #{data.length}"
        texta.table_model.data = data
        end
        sel_col = Variable.new 0
        sel_col.value = 0
        tcm = texta.get_table_column_model
        selcolname = texta.get_column_name sel_col.value
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
      keylabel = RubyCurses::Label.new @form, {'text' => "", "row" => r+table_ht+3, "col" => c, "color" => "yellow", "bgcolor"=>"blue", "display_length"=>60, "height"=>2}
      eventlabel = RubyCurses::Label.new @form, {'text' => "Events:", "row" => r+table_ht+6, "col" => c, "color" => "white", "bgcolor"=>"blue", "display_length"=>60, "height"=>2}

      # report some events
      texta.table_model.bind(:TABLE_MODEL_EVENT){|e| eventlabel.text = "Event: #{e}"}
      texta.get_table_column_model.bind(:TABLE_COLUMN_MODEL_EVENT){|e| eventlabel.text = "Event: #{e}"}
      texta.bind(:TABLE_TRAVERSAL_EVENT){|e| eventlabel.text = "Event: #{e}"}

      @help = "C-q to quit. M-Tab (next col) C-n (Pg Dn), C-p (Pg Up), M-0 Top, M-9 End, C-x (select). Columns:- Narrow, + expand, > < switch"
      RubyCurses::Label.new @form, {'text' => @help, "row" => Ncurses.LINES-3, "col" => 2, "color" => "yellow", "height"=>2}

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
=begin
=end
        buttrow = r+table_ht+8 #Ncurses.LINES-4
      b_newrow = Button.new @form do
        text "&New"
        row buttrow
        col c
        bind(:ENTER) { eventlabel.text "New button adds a new row below current " }
      end
      b_newrow.command { 
        cc = texta.get_table_column_model.column_count
        frow = texta.focussed_row
        mod = texta.get_value_at(frow,0)
        tmp = [mod, 5, "NEW TASK", "TODO"]
        tm = texta.table_model
        tm.insert frow+1, tmp
        texta.set_focus_on frow+1
        keylabel.text = "Added a row"
        alert("Added a row below current one ")

      }

      # using ampersand to set mnemonic
      b_delrow = Button.new @form do
        text "&Delete"
        row buttrow
        col c+10
        bind(:ENTER) { eventlabel.text "Deletes focussed row" }
      end
      b_delrow.command { |form| 
        row = texta.focussed_row
        if confirm("Do your really want to delete row #{row}?")== :YES
          tm = texta.table_model
          tm.delete_at row
          #texta.table_data_changed
        else
          #$message.value = "Quit aborted"
        end
      }
      b_change = Button.new @form do
        text "&Lock"
        row buttrow
        col c+20
        command {
          r = texta.focussed_row
          c = sel_col.value
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
          eventlabel.text "Set column  #{texta.focussed_col()} editable to #{toggle}"
          texta.column(texta.focussed_col()).editable toggle
          alert("Set column  #{texta.focussed_col()} editable to #{toggle}")
        }
        bind(:ENTER) { eventlabel.text "Toggles editable state of current column " }
      end
      b_insert = Button.new @form do
        text "&Insert"
        row buttrow
        col c+32
        command {
          # this does not trigger a data change since we are not updating model. so update
          # on pressing up or down
          #0.upto(100) { |i| data << ["test", rand(100), "abc:#{i}", rand(100)/2.0]}
          #texta.table_data_changed
        }
        bind(:ENTER) { eventlabel.text "Does nothing " }
      end


      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != ?\C-q )
        colcount = tcm.column_count-1
        s = keycode_tos ch
        keylabel.text = "Pressed #{ch} , #{s}"
        @form.handle_key(ch)

        sel_col.value = tcm.column_count-1 if sel_col.value > tcm.column_count-1
        sel_col.value = 0 if sel_col.value < 0
        selcolname = texta.get_column_name texta.focussed_col
        keylabel.text = "Pressed #{ch} , #{s}. Column selected #{texta.focussed_col}: Width:#{tcm.column(texta.focussed_col).width} #{selcolname}. Focussed Row: #{texta.focussed_row}, Rows: #{texta.table_model.row_count}, Cols: #{colcount}"
        s = texta.get_value_at(texta.focussed_row, texta.focussed_col)
        #s = s.to_s
      ##  $log.debug " updating Field #{s}, #{s.class}"
      ##  field.set_buffer s unless field.state == :HIGHLIGHTED # $editing

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
