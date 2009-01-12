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
#require 'lib/rbcurse/table/tablecellrenderer'
require 'lib/rbcurse/comboboxcellrenderer'

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
      r = 1; c = 30;
      data = [["You're beautiful",3,"James Blunt",3.21, true, "WIP"],
        ["Where are you",3,"London Beat",3.47, true, "WIP"],
        ["I swear",nil,"Boyz II Men",112.7, true, "Cancel"],
        ["I'll always love my mama",92,"Intruders",412, true, "Fin"],
        ["I believe in love",4,"Paula Cole",110.0, false, "Cancel"],
        ["Red Sky at night",4,"Dave Gilmour",102.72, false, "Postp"],
        ["Midnight and you",8,"Barry White",12.72, false, "Todo"],
        ["Let the music play",9,"Barry White",12.2, false, "WIP"],
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
          set_data data, colnames
        end
        sel_col = RVariable.new 0
        sel_col.value = 0
        tcm = texta.get_table_column_model
        selcolname = texta.get_column_name sel_col.value
        #
        ## key bindings fo texta
        # column widths 
        texta.configure() do
          tcm.column(0).width  24
          tcm.column(1).width  5
          tcm.column(2).width  18
          tcm.column(3).width  7
          tcm.column(4).width  5
          tcm.column(5).width  8
          bind_key(330) { texta.remove_column(tcm.column(sel_col.value))}
          bind_key(?+) {
            acolumn = texta.get_column selcolname
            w = acolumn.width + 1
            acolumn.width w
            texta.table_structure_changed
          }
          bind_key(?-) {
            acolumn = texta.get_column selcolname
            w = acolumn.width - 1
            if w > 3
            acolumn.width w
            texta.table_structure_changed
            end
          }
          bind_key(?>) {
            colcount = tcm.column_count-1
            texta.move_column sel_col.value, sel_col.value+1 unless sel_col.value == colcount
          }
          bind_key(?<) {
            texta.move_column sel_col.value, sel_col.value-1 unless sel_col.value == 0
          }
          bind_key(KEY_RIGHT) { sel_col.value = sel_col.value+1; current_column sel_col.value}
          bind_key(KEY_LEFT) { sel_col.value = sel_col.value-1;current_column sel_col.value}
        end
      keylabel = RubyCurses::Label.new @form, {'text' => "", "row" => r+16, "col" => c, "color" => "yellow", "bgcolor"=>"blue", "display_length"=>60, "height"=>2}
      @help = "C-q to quit. UP, DOWN, C-n (Pg Dn), C-p (Pg Up), 0 Top, C-] End, space (select). Columns:- Narrow, + expand, > < switch"
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
        buttrow = Ncurses.LINES-4
      b_newrow = Button.new @form do
        text "&New"
        row buttrow
        col 20
      end
      b_newrow.command { 
        cc = texta.get_table_column_model.column_count
        tmp=[]
        0.upto(cc-1) { tmp << "" }
        data << tmp
        texta.table_data_changed
        keylabel.text = "Added a row"

      }

      # using ampersand to set mnemonic
      b_delrow = Button.new @form do
        text "&Delete"
        row buttrow
        col 30
      end
      b_delrow.command { |form| 
        row = texta.focussed_row
        if confirm("Do your really want to delete row #{row}?")== :YES
          data.delete_at row
          texta.table_data_changed
        else
          #$message.value = "Quit aborted"
        end
      }
      b_change = Button.new @form do
        text "&Update"
        row buttrow
        col 40
        command {
          r = texta.focussed_row
          c = sel_col.value
          $log.debug " Update gets #{field.getvalue.class}"
          texta.set_value_at(r, c, field.getvalue)
          texta.table_data_changed
        }
      end
      b_insert = Button.new @form do
        text "&Insert"
        row buttrow
        col 50
        command {
          # this does not trigger a data change since we are not updating model. so update
          # on pressing up or down
          0.upto(100) { |i| data << ["test", rand(100), "abc:#{i}", rand(100)/2.0]}
          texta.table_data_changed
        }
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
