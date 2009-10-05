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
require 'rbcurse/action'

##
# a renderer which paints alternate lines with
# another color, for people with poor taste.
class MyRenderer < TableCellRenderer
  def initialize text="", config={}, &block
    super
    @orig_bgcolor = @bgcolor
    @orig_color = @color
  end
  def repaint graphic, r=@row,c=@col, value=@text, focussed=false, selected=false
    @bgcolor = @orig_bgcolor
    @color = @orig_color
    if !focussed and !selected
      @bgcolor = r % 2 == 0 ? "green" : @orig_bgcolor
      @color = r % 2 == 0 ? "black" : @orig_color
    end
    super
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

    @window = VER::Window.root_window

    catch(:close) do
      colors = Ncurses.COLORS
      $log.debug "START #{colors} colors  ---------"
      @form = Form.new @window
      @window.printstring 0,30,"Demo of Ruby Curses Table: Edit, Resize, Insert, Move, Delete Row/Col", $datacolor
      r = 1; c = 30;
      data = [["You're beautiful",3,"James Blunt",3.21, true, "WIP"],
        ["Where are you",3,"London Beat",3.47, true, "WIP"],
        ["I'll always love my mama",92,"Intruders",412, true, "Fin"],
        ["I believe in love",4,"Paula Cole",110.0, false, "Cancel"],
        ["Red Sky at night",4,"Dave Gilmour",102.72, false, "Postp"],
        ["Midnight and you",8,"Barry White",12.72, false, "Todo"],
        ["Let the music play",9,"Barry White",12.2, false, "WIP"],
        ["I swear",nil,"Boyz II Men",112.7, true, "Cancel"],
        ["Believe",9,"Elton John",12.2, false, "Todo"],
        ["Private Dancer",9,"Tina Turner",12.2, false, "Todo"],
        ["Liberian Girl",9,"Michael Jackson",12.2, false, "Todo"],
        ["Like a prayer",163,"Charlotte Perrelli",5.4, false, "WIP"]]

      colnames = %w[ Song Cat Artist Ratio Flag Status]
      statuses = ["Todo", "WIP", "Fin", "Cancel", "Postp"]

        texta = Table.new @form do
          name   "mytext" 
          row  r 
          col  c
          width 78
          height 15
          #title "A Table"
          #title_attrib (Ncurses::A_REVERSE | Ncurses::A_BOLD)
          cell_editing_allowed true
          editing_policy :EDITING_AUTO
          set_data data, colnames
        end
        sel_col = Variable.new 0
        sel_col.value = 0
        tcm = texta.get_table_column_model
        selcolname = texta.get_column_name sel_col.value
        #
        ## key bindings fo texta
        # column widths 
          tcm.column(0).width 24
          tcm.column(1).width 5
          tcm.column(2).width 18
          #tcm.column(2).editable false
          tcm.column(3).width 7
          tcm.column(4).width 5
          tcm.column(5).width 8
        texta.configure() do
          bind_key(330) { texta.remove_column(tcm.column(texta.focussed_col)) rescue ""  }
          bind_key(?+) {
            acolumn = texta.get_column selcolname
            w = acolumn.width + 1
            acolumn.width w
            #texta.table_structure_changed
          }
          bind_key(?-) {
            acolumn = texta.get_column selcolname
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
          #bind_key(KEY_RIGHT) { sel_col.value = sel_col.value+1; current_column sel_col.value}
          #bind_key(KEY_LEFT) { sel_col.value = sel_col.value-1;current_column sel_col.value}
        end
      keylabel = RubyCurses::Label.new @form, {'text' => "", "row" => r+16, "col" => c, "color" => "yellow", "bgcolor"=>"blue", "display_length"=>60, "height"=>2}
      eventlabel = RubyCurses::Label.new @form, {'text' => "Events:", "row" => r+19, "col" => c, "color" => "white", "bgcolor"=>"blue", "display_length"=>60, "height"=>2}

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
      texta.set_default_cell_renderer_for_class "String", str_renderer
      texta.set_default_cell_renderer_for_class "Fixnum", num_renderer
      texta.set_default_cell_renderer_for_class "Float", num_renderer
      texta.set_default_cell_renderer_for_class "TrueClass", bool_renderer
      texta.set_default_cell_renderer_for_class "FalseClass", bool_renderer
      texta.get_table_column_model.column(5).cell_editor =  combo_editor
=begin
        field = Field.new @form do
          name   "value" 
          row  r+18
          col  c
          display_length  30
          bgcolor "cyan"
          set_label Label.new @form, {'text' => "Value", 'mnemonic'=> 'V'}
        #  bind :ENTER do $editing = true end
        #  bind :LEAVE do $editing = false end
        end
=end
        buttrow = r+21 #Ncurses.LINES-4
      b_newrow = Button.new @form do
        text "&New"
        row buttrow
        col c
        bind(:ENTER) { eventlabel.text "New button adds a new row at the bottom " }
      end
      tm = texta.table_model
      b_newrow.command { 
        cc = texta.get_table_column_model.column_count
        # need to get datatypes etc, this is just a junk test
        tmp=[]
        #0.upto(cc-1) { tmp << "" }
        0.upto(cc-1) { tmp << nil }
        tm << tmp
        #texta.table_data_changed
        keylabel.text = "Added a row"
        alert("Added a row at bottom of table")

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
      while((ch = @window.getchar()) != ?\C-q.getbyte(0) )
        colcount = tcm.column_count-1
        s = keycode_tos ch
        keylabel.text = "Pressed #{ch} , #{s}"
        @form.handle_key(ch)

        sel_col.value = tcm.column_count-1 if sel_col.value > tcm.column_count-1
        sel_col.value = 0 if sel_col.value < 0
        selcolname = texta.get_column_name sel_col.value
        keylabel.text = "Pressed #{ch} , #{s}. Column selected #{texta.focussed_col}: Width:#{tcm.column(sel_col.value).width} #{selcolname}. Focussed Row: #{texta.focussed_row}, Rows: #{texta.table_model.row_count}, Cols: #{colcount}"
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
