$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'lib/ver/ncurses'
require 'lib/ver/window'
require 'lib/rbcurse/rwidget'
require 'lib/rbcurse/rcombo'
require 'lib/rbcurse/rlistbox'
require 'rfe_renderer'
#require 'lib/rbcurse/table/tablecellrenderer'
require 'lib/rbcurse/keylabelprinter'
require 'lib/rbcurse/applicationheader'
require 'lib/rbcurse/action'
require 'fileutils'

class FileExplorer
  include FileUtils
  attr_reader :wdir
  attr_reader :list
  attr_reader :dir
  attr_reader :entries

  def initialize form, rfe, row, col, height, width
    @form = form
    @rfe = rfe
    @row, @col, @ht, @wid = row, col, height, width
    @dir = Dir.new(Dir.getwd)
    @wdir = @dir.path
  end

  def change_dir adir

    list = @list
    begin
      #dir = File.expand_path dir
      cd "#{@dir.path}/#{adir}"
      list.title = pwd()
      @dir = Dir.new(Dir.getwd)
      @wdir = @dir.path
      rescan
    rescue => err
      @rfe.status_row.text = err.to_s
    end
  end
  def rescan
    flist = @dir.entries
    flist.shift
    @entries = flist
    populate @entries
  end
  def populate flist
    #fl << format_string("..", nil)
    #fl = []
    #flist.each {|f| ff = "#{@wdir}/#{f}"; stat = File.stat(ff)
    #  fl << format_string(f, stat)
    #}
    list.list_data_model.remove_all
    #list.list_data_model.insert 0, *fl
    list.list_data_model.insert 0, *flist
  end
  def sort key, reverse=false
    key ||= @sort_key
    case key
    when  :size
      @entries.sort! {|x,y| xs = File.stat(x); ys = File.stat(y); 
        if reverse
          xs.size <=> ys.size 
        else
          ys.size <=> xs.size 
        end
      }
    when  :mtime
      @entries.sort! {|x,y| xs = File.stat(x); ys = File.stat(y); 
        if reverse
          xs.mtime <=> ys.mtime 
        else
          ys.mtime <=> xs.mtime 
        end
      }
    when  :atime
      @entries.sort! {|x,y| xs = File.stat(x); ys = File.stat(y); 
        if reverse
          xs.atime <=> ys.atime 
        else
          ys.atime <=> xs.atime 
        end
      }
    when  :name
      @entries.sort! {|x,y| x <=> y 
        if reverse
          x <=> y
        else
          y <=> x
        end
      }
    when  :ext
      @entries.sort! {|x,y| 
        if reverse
          File.extname(x) <=> File.extname(y) 
        else
          File.extname(y) <=> File.extname(x) 
        end
      }
    end
    @sort_key = key
    populate @entries
  end
  GIGA_SIZE = 1073741824.0
  MEGA_SIZE = 1048576.0
  KILO_SIZE = 1024.0

  # Return the file size with a readable style.
  def readable_file_size(size, precision)
    case
      #when size == 1 : "1 B"
      when size < KILO_SIZE : "%d B" % size
      when size < MEGA_SIZE : "%.#{precision}f K" % (size / KILO_SIZE)
      when size < GIGA_SIZE : "%.#{precision}f M" % (size / MEGA_SIZE)
      else "%.#{precision}f G" % (size / GIGA_SIZE)
    end
  end
  def date_format t
    t.strftime "%Y/%m/%d"
  end
  def oldformat_string fn, stat
    max_len = 30
    f = fn.dup
    if File.directory? f
      #"%-*s\t(dir)" % [max_len,f]
      #f = "/"+f # disallows search on keypress
      f = f + "/ "
    end
    if f.size > max_len
      f = f[0..max_len-1]
    end
    "%-*s\t%10s\t%s" % [max_len,f,  readable_file_size(stat.size,1), date_format(stat.mtime)]
  end
  def cur_dir
    @dir.path
  end
  def draw_screen dir=nil
    wdir = FileUtils.pwd
    r = @row
    c = @col
    #cola = 1
    #colb = Ncurses.COLS/2
    ht = @ht
    wid = @wid
    #fl = Dir.glob(default_pattern)
    #flist << format_string("..", nil)
    fl = @dir.entries
    fl.shift
    #flist = []
    #fl.each {|f| stat = File.stat(f)
    #  flist << format_string(f, stat)
    #}
    @entries = fl
    title = pwd()
    @wdir = title
    rfe = self

    lista = Listbox.new @form do
      name   "lista" 
      row  r 
      col  c
      width wid
      height ht
      #list flist
      list fl
      title wdir
      title_attrib 'reverse'
      cell_renderer RfeRenderer.new "", {"color"=>@color, "bgcolor"=>@bgcolor, "parent" => rfe, "display_length"=> wid-2}
    end
    @list = lista
    lista.bind(:ENTER) {|l| @rfe.current_list(self); l.title_attrib 'reverse';  }
    lista.bind(:LEAVE) {|l| l.title_attrib 'normal'; $log.debug " LEAVING #{l}" }


    #row_cmd = lambda {|list| file = list.list_data_model[list.current_index].split(/\t/)[0].strip; @rfe.status_row.text = File.stat("#{cur_dir()}/#{file}").inspect }
    row_cmd = lambda {|lb, list| file = list.entries[lb.current_index]; @rfe.status_row.text = list.cur_dir+"::"+file; # File.stat("#{cur_dir()}/#{file}").inspect 
    }
    lista.bind(:ENTER_ROW, self) {|lb,list|$log.debug " ENTERRIW #{cur_dir()}"; row_cmd.call(lb,list) }

  end
  def filename
    #@list.list_data_model[@list.current_index].split(/\t/)[0].strip
    @entries[@list.current_index]
  end
  def filepath
    #@wdir +"/"+ @list.list_data_model[@list.current_index].split(/\t/)[0].strip
    cur_dir() + "/" + @entries[@list.current_index]
  end

end
class RFe
  attr_reader :status_row
  def initialize
    @window = VER::Window.root_window
    @form = Form.new @window
    status_row = RubyCurses::Label.new @form, {'text' => "", :row => Ncurses.LINES-4, :col => 0, :display_length=>Ncurses.COLS-2}
    @status_row = status_row
    colb = Ncurses.COLS/2
    ht = Ncurses.LINES - 7
    wid = Ncurses.COLS/2 - 0
    @lista = FileExplorer.new @form, self, row=2, col=1, ht, wid
    @listb = FileExplorer.new @form, self, row=2, col=colb, ht, wid

    init_vars
  end
  def init_vars

  end
  def move
    fp = @current_list.filepath
    fn = @current_list.filename
    $log.debug " FP #{fp}"
    other_list = [@lista, @listb].index(@current_list)==0 ? @listb : @lista
    other_dir = other_list.cur_dir
    $log.debug " OL #{other_list.cur_dir}"
    str= "move #{fn} to #{other_list.cur_dir}"
    $log.debug " MOVE #{fp}"
    #confirm "#{str}"
      mb = RubyCurses::MessageBox.new do
        title "Move"
        message "Move #{fn} to"
       type :input
       width 60
        default_value other_dir
       button_type :ok_cancel
       default_button 0
      end
      #confirm "selected :#{mb.input_value}, #{mb.selected_index}"
      if mb.selected_index == 0
        # need to redraw directories
        FileUtils.move(fp, mb.input_value)
        #@current_list.list.list_data_model.delete fp # ???
        #@lista.list.list_data_changed
        #@listb.list.list_data_changed
        @lista.rescan
        @listb.rescan
      end 
  end
  def view 
    require 'lib/rbcurse/rtextview'
    fp = @current_list.filepath
    wt = 0
    wl = 0
    wh = Ncurses.LINES-wt
    ww = Ncurses.COLS-wl
    @layout = { :height => wh, :width => ww, :top => wt, :left => wl } 
    @v_window = VER::Window.new(@layout)
    @v_form = RubyCurses::Form.new @v_window
    fp = @current_list.filepath
    @textview = TextView.new @v_form do
      name   "myView" 
      row  0
      col  0
      width ww
      height wh-2
      title fp
      title_attrib 'bold'
      print_footer true
      footer_attrib 'bold'
    end
    #content = File.open(fp,"r").readlines
    content = get_contents(fp)
    @textview.set_content content #, :WRAP_WORD
    @v_form.repaint
    @v_window.wrefresh
    Ncurses::Panel.update_panels
    begin
    while((ch = @v_window.getchar()) != ?\C-q )
      break if ch == KEY_F3
      @v_form.handle_key ch
      @v_form.repaint
      ##@v_window.wrefresh
    end
    ensure
      @v_window.destroy if !@v_window.nil?
    end
  end
  def get_contents fp
    return nil unless File.readable? fp 
    return Dir.new(fp).entries if File.directory? fp
    case File.extname(fp)
    when '.tgz','.gz'
      cmd = "tar -ztvf #{fp}"
      content = %x[#{cmd}]
    else
      content = File.open(fp,"r").readlines
    end
  end
  def opt_file c
    fp = @current_list.filepath
    fn = @current_list.filename
    $log.debug " FP #{fp}"
    other_list = [@lista, @listb].index(@current_list)==0 ? @listb : @lista
    $log.debug " OL #{other_list.cur_dir}"
    case c
    when 'c'
      str= "copy #{fn} to #{other_list.cur_dir}"
      if confirm("#{str}")==:YES
      $log.debug " COPY #{str}"
      end
    when 'm'
      str= "move #{fn} to #{other_list.cur_dir}"
      move
      #if confirm("#{str}")==:YES
      #$log.debug " MOVE #{str}"
      #end
    when 'd'
      str= "delete #{fn} "
      if confirm("#{str}")==:YES
      $log.debug " delete #{fp}"
      end
    when 'u'
      str= "move #{fn} to #{other_list.cur_dir}"
      if confirm("#{str}")==:YES
      $log.debug " MOVE #{str}"
      end
    when 'v'
      str= "view #{fp}"
      #if confirm("#{str}")==:YES
      $log.debug " VIEW #{fp}"
      view
      #end
    when 'r'
      str= "ruby #{fn}"
      if confirm("#{str}")=='y'
      $log.debug " #{str} "
      end
    when 'e'
      str= "edit #{fp}"
      #if confirm("#{str}")==:YES
      edit fp
    end
  end
  def edit fp=@current_list.filepath
    $log.debug " edit #{fp}"
    shell_out "/opt/local/bin/vim #{fp}"
  end
  def draw_screens
    @lista.draw_screen
    @listb.draw_screen
    @form.bind_key(?\C-f){
      @klp.mode :file
      @klp.repaint
      while((ch = @window.getchar()) != ?\C-c )
        if "cmdsuvre".index(ch.chr) == nil
          Ncurses.beep
        else
          opt_file ch.chr
          break
        end
      end
      @klp.mode :normal
    }
    @form.bind_key(?c){
      dir=get_string("Give directory to change to:")
      @current_list.change_dir dir
    }
    @form.bind_key(?\M-m){
      move()
    }
    @form.bind_key(KEY_F3){
      view()
    }
    @form.bind_key(KEY_F4){
      edit()
    }
    @form.bind_key(KEY_F7){
      selected_index, sort_key, reverse, case_sensitive = sort_popup
      if selected_index == 0
        @current_list.sort(sort_key, reverse)
      end
    }
    @form.bind_key(?\C-m){
      dir = @current_list.filename
      if File.directory? @current_list.filepath
        @current_list.change_dir dir
      end
    }
    @klp = RubyCurses::KeyLabelPrinter.new @form, get_key_labels
    @klp.set_key_labels get_key_labels(:file), :file
    @klp.set_key_labels get_key_labels(:view), :view
    @form.repaint
    @window.wrefresh
    Ncurses::Panel.update_panels
    begin
    while((ch = @window.getchar()) != ?\C-q )
      s = keycode_tos ch
      status_row.text = "Pressed #{ch} , #{s}"
      @form.handle_key(ch)

      @form.repaint
      @window.wrefresh
    end
    ensure
    @window.destroy if !@window.nil?
    end

  end
  # TODO make these 2 into classes with their environment and cwd etc
  # sort : make easy message boxes with given checkboxes or radio buttons
  # sort : .. remains on top always !
  # create list box cell renderer and do fornatting in that, using @entries

# current_list
    ##
    # getter and setter for current_list
    def current_list(*val)
      if val.empty?
        @current_list
      else
        @current_list = val[0] 
      end
    end
def get_key_labels categ=nil
  if categ.nil?
  key_labels = [
    ['C-q', 'Exit'], ['C-v', 'View'], 
    ['C-f', 'File'], ['C-d', 'Dir'],
    ['C-x','Select'], nil,
    ['F3', 'View'], ['F4', 'Edit'],
    ['M-0', 'Top'], ['M-9', 'End'],
    ['C-p', 'PgUp'], ['C-n', 'PgDn']
  ]
  elsif categ == :file
  key_labels = [
    ['c', 'Copy'], ['m', 'Move'],
    ['d', 'Delete'], ['v', 'View'],
    ['s', 'Select'], ['u', 'Unselect'],
    ['p', 'Page'], ['x', 'Exec Cmd'],
    ['r', 'ruby'], ['e', "Edit"],
    ['C-c', 'Cancel']
  ]
  elsif categ == :view
  key_labels = [
    ['c', 'Date'], ['m', 'Size'],
    ['d', 'Delete'], ['v', 'View'],
    ['C-c', 'Cancel']
  ]
  end
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
def sort_popup
  mform = RubyCurses::Form.new nil
  field_list = []
  r = 4
  $radio = RubyCurses::Variable.new
  rtextvalue = [:name, :ext, :size, :mtime, :atime]
  ["Name", "Extension", "Size", "Modify Time", "Access Time" ].each_with_index do |rtext,ix|
    field = RubyCurses::RadioButton.new mform do
      variable $radio
      text rtext
      value rtextvalue[ix]
      color 'black'
      bgcolor 'white'
      row r
      col 5
    end
    field_list << field
    r += 1
  end
  r = 4
  ["Reverse", "case sensitive"].each do |cbtext|
    field = RubyCurses::CheckBox.new mform do
      text cbtext
      name cbtext
      color 'black'
      bgcolor 'white'
      row r
      col 30
    end
    field_list << field
    r += 1
  end
  mb = RubyCurses::MessageBox.new mform do
    title "Sort Options"
    button_type :ok_cancel
    default_button 0
  end
  if mb.selected_index == 0
    $log.debug " SORT POPUP #{$radio.value}"
    #$log.debug " SORT POPUP #{mb.inspect}"
    $log.debug " SORT POPUP #{mform.by_name["Reverse"].value}"
    $log.debug " SORT POPUP #{mform.by_name["case sensitive"].value}"
  end
  return mb.selected_index, $radio.value, mform.by_name["Reverse"].value, mform.by_name["case sensitive"].value
end
def shell_out command
  Ncurses.endwin
  system command
  Ncurses.refresh
  Ncurses.curs_set 0
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

    catch(:close) do
      t = RFe.new
      t.draw_screens
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
