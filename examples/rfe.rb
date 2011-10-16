#####################################################
# This is a sample program demonstrating a 2 pane file explorer using
# rbcurse's widgets.
# I have used a listbox here, perhaps a Table would be more configurable
# than a listbox.
#
# Copyright rkumar 2009, 2010 under Ruby License.
#
####################################################
#require 'rubygems'
#require 'ncurses'
#require 'logger'
require 'rbcurse'
require 'rbcurse/rcombo'
require 'rbcurse/rlistbox'
require './rfe_renderer'
require 'rbcurse/keylabelprinter'
require 'rbcurse/applicationheader'
require 'rbcurse/action'
require 'fileutils'
require 'yaml'  ## added for 1.9
#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"

# TODO
# operations on selected files: move, delete, zip, copy
#   - delete should move to Trash if exists - DONE
#   global - don't ask confirm
#   Select based on pattern.
# This class represents the finder pane. There are 2 
# on this sample app
# NOTE: rfe_renderer uses entries so you may need to sync it with list_data_model
# actually, renderer should refer back to list data model!
class FileExplorer
  include FileUtils
  attr_reader :wdir
  attr_reader :list # listbox
  attr_reader :dir
  attr_reader :prev_dirs
  attr_reader :other_list # the opposite list
  attr_reader :entries # avoid, can be outdated
  attr_accessor :filter_pattern

  def initialize form, rfe, row, col, height, width
    @form = form
    @rfe = rfe
    @row, @col, @ht, @wid = row, col, height, width
    @dir = Dir.new(Dir.getwd)
    @wdir = @dir.path
    @filter_pattern = '*'
    @prev_dirs=[]
    @inside_block = false
    $entry_count = 0 # just for show... may not be accurate  after deletes etc

  end
  def title str
    @list.title = str
  end
  def selected_color
    @list.selected_color
  end
  def selected_bgcolor
    @list.selected_bgcolor
  end

  # changes to given dir
  # ensure that path is provided since other list
  # may have cd'd elsewhere
  def change_dir adir
    list = @list
    begin
      #dir = File.expand_path dir
      #cd "#{@dir.path}/#{adir}"
      cd adir
      list.title = pwd()
      @dir = Dir.new(Dir.getwd)
      @wdir = @dir.path
      @prev_dirs << @wdir
      rescan
    rescue => err
      @rfe.status_row.text = err.to_s
    end
  end
  def goto_previous_dir
    #alert "Previous dirs contain #{@prev_dirs} "
    d = @prev_dirs.pop
    if !d.nil? and d == @wdir
      d = @prev_dirs.pop
    end
    change_dir d unless d.nil?
  end
  def filter list
    list.delete_if { |f|
      !File.directory? @wdir +"/"+ f and !File.fnmatch?(@filter_pattern, f)
    }
    #$log.debug " FILTER CALLED AFTER  #{list.size}, #{list.entries}"
  end
  def rescan
    flist = @dir.entries
    $entry_count = flist.size # just for show... may not be accurate  after deletes etc
    flist.shift
    #populate @entries
    populate flist
  end
  def populate flist
    #fl << format_string("..", nil)
    #fl = []
    #flist.each {|f| ff = "#{@wdir}/#{f}"; stat = File.stat(ff)
    #  fl << format_string(f, stat)
    #}
    filter(flist) if @filter_pattern != '*'
    @entries = flist
    list.list_data_model.remove_all
    #list.list_data_model.insert 0, *fl
    list.list_data_model.insert 0, *flist
    list.set_form_row
    #$entry_count = list.size # just for show... may not be accurate  after deletes etc
  end
  def sort key, reverse=false
    # remove parent before sorting, keep at top
    first = @entries.delete_at(0) if @entries[0]==".."
    key ||= @sort_key
    cdir=cur_dir()+"/"
    case key
    when  :size
      @entries.sort! {|x,y| xs = File.stat(cdir+x); ys = File.stat(cdir+y); 
        if reverse
          xs.size <=> ys.size 
        else
          ys.size <=> xs.size 
        end
      }
    when  :mtime
      @entries.sort! {|x,y| xs = File.stat(cdir+x); ys = File.stat(cdir+y); 
        if reverse
          xs.mtime <=> ys.mtime 
        else
          ys.mtime <=> xs.mtime 
        end
      }
    when  :atime
      @entries.sort! {|x,y| xs = File.stat(cdir+x); ys = File.stat(cdir+y); 
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
          File.extname(cdir+x) <=> File.extname(cdir+y) 
        else
          File.extname(cdir+y) <=> File.extname(cdir+x) 
        end
      }
    end
    @sort_key = key
    @entries.insert 0, first unless first.nil?  # keep parent on top
    populate @entries
  end
  GIGA_SIZE = 1073741824.0
  MEGA_SIZE = 1048576.0
  KILO_SIZE = 1024.0

  # Return the file size with a readable style.
  def readable_file_size(size, precision)
    case
      #when size == 1 : "1 B"
      when size < KILO_SIZE then "%d B" % size
      when size < MEGA_SIZE then "%.#{precision}f K" % (size / KILO_SIZE)
      when size < GIGA_SIZE then "%.#{precision}f M" % (size / MEGA_SIZE)
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
  alias :current_dir :cur_dir
  def draw_screen dir=nil
    # I get an error here if dir in yaml file is non-existent, like deleted or copied from another machine
    #  2010-08-22 19:25 
    if dir
      if File.exists?(dir) && File.directory?(dir)
        cd dir unless dir.nil?
      else
        dir = nil
      end
    end

    wdir = FileUtils.pwd
    @prev_dirs << wdir
    @dir = Dir.new(Dir.getwd)
    @wdir = @dir.path
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
    filter(fl)
    #flist = []
    #fl.each {|f| stat = File.stat(f)
    #  flist << format_string(f, stat)
    #}
    @entries = fl
    $entry_count = @entries.size
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
      #title_attrib 'reverse'
      cell_renderer RfeRenderer.new "", {"color"=>@color, "bgcolor"=>@bgcolor, "parent" => rfe, "display_length"=> wid-2}
      KEY_ROW_SELECTOR 0 # C-space since space used for preview
    end
    @list = lista
    lista.bind(:ENTER) {|l| @rfe.current_list(self); l.title_attrib 'reverse';  }
    lista.bind(:LEAVE) {|l| l.title_attrib 'normal';  }


    #row_cmd = lambda {|list| file = list.list_data_model[list.current_index].split(/\t/)[0].strip; @rfe.status_row.text = File.stat("#{cur_dir()}/#{file}").inspect }
    row_cmd = lambda {|lb, list| file = list.entries[lb.current_index]; @rfe.status_row.text = file; # File.stat("#{cur_dir()}/#{file}").inspect 
    }
    lista.bind(:ENTER_ROW, self) {|lb,list| row_cmd.call(lb,list) }

  end
  def list_data
    @list.list_data_model
  end
  def current_index
    @list.current_index
  end
  def filename ix=current_index()
    #@entries[@list.current_index]
    list_data()[ix]
  end
  def filepath ix=current_index()
    f = filename(ix)
    return unless f
    if f[0,1]=='/'
      f
    else
      cur_dir() + "/" + f
    end
  end
  # delete the item at position i
  def delete_at i=@list.current_index
    ret = @list.list_data_model.delete_at i
    ret = @entries.delete_at i
  end
  def delete obj
    ret = @list.list_data_model.delete obj
    ret = @entries.delete_at obj
  end
  def insert_at obj, ix = @list.current_index
    @list.list_data_model.insert ix, f
    @entries.insert ix, obj
  end
  def remove_selected_rows
    rows = @list.selected_rows
    rows=rows.sort! {|x,y| y <=> x }
    rows.each do |i|
      ret = @list.list_data_model.delete_at i
      ret = @entries.delete_at i
    end
  end

  # ADD
end
class RFe
  attr_reader :status_row
  def initialize
    @window = VER::Window.root_window
    @form = Form.new @window
    status_row = RubyCurses::Label.new @form, {'text' => "", :row => Ncurses.LINES-4, :col => 0, :display_length=>Ncurses.COLS-2}
    @status_row = status_row
    colb = Ncurses.COLS/2
    ht = Ncurses.LINES - 5
    wid = Ncurses.COLS/2 - 0
    @trash_path = File.expand_path("~/.Trash")
    @trash_exists = File.directory? @trash_path
    $log.debug " trash_path #{@trash_path}, #{@trash_exists}"
    @lista = FileExplorer.new @form, self, row=1, col=1, ht, wid
    @listb = FileExplorer.new @form, self, row=1, col=colb, ht, wid

    init_vars
  end
  def init_vars
    @bookmarks=[]
    @config_name = File.expand_path("~/.rfe.yml")
    if File.exist? @config_name
      @config = YAML::load( File.open(@config_name));
      if !@config.nil?
        @bookmarks = @config["bookmarks"]||[]
        @last_dirs = @config["last_dirs"]
      end
    end
    @config ||={}
    @stopping = false
  end
  def save_config
    @config["last_dirs"]=[@lista.current_dir(),@listb.current_dir()]
    File.open(@config_name, "w") { | f | YAML.dump( @config, f )} 
  end
  def move
    fp = @current_list.filepath #.gsub(' ',"\ ")
    fn = @current_list.filename
    $log.debug " FP #{fp}"
    other_list = [@lista, @listb].index(@current_list)==0 ? @listb : @lista
    other_dir = other_list.cur_dir
    $log.debug " OL #{other_list.cur_dir}"
    if @current_list.list.selected_row_count == 0
      str= "#{fn}"
    else
      str= "#{@current_list.list.selected_row_count} files "
    end
    mb = RubyCurses::MessageBox.new do
      title "Move"
      message "Move #{str} to"
      type :input
      width 80
      default_value other_dir
      button_type :ok_cancel
      default_button 0
    end
      #confirm "selected :#{mb.input_value}, #{mb.selected_index}"
      if mb.selected_index == 0
        if @current_list.list.selected_row_count == 0
          FileUtils.move(fp, mb.input_value)
          #ret = @current_list.list.list().delete_at @current_list.list.current_index  # ???
          #  @current_list.entries.delete_at @current_list.current_index
          @current_list.delete_at
        else
          each_selected_row do |f|
            FileUtils.move(f, mb.input_value)
          end
          @current_list.remove_selected_rows
          @current_list.list.clear_selection
        end
        other_list.rescan
      end 
  end
  def each_selected_row #title, message, default_value
    rows = @current_list.list.selected_rows
    rows = rows.dup
    rows.each do |i|
      fp = @current_list.filepath i
      #$log.debug " moving #{i}: #{fp}"
      #FileUtils.move(fp, mb.input_value)
      yield fp
    end
  end
  def copy
    fp = @current_list.filepath #.gsub(' ',"\ ")
    fn = @current_list.filename
    $log.debug " FP #{fp}"
    other_list = [@lista, @listb].index(@current_list)==0 ? @listb : @lista
    other_dir = other_list.cur_dir
    $log.debug " OL #{other_list.cur_dir}"
    if @current_list.list.selected_row_count == 0
      str= "#{fn}"
    else
      str= "#{@current_list.list.selected_row_count} files "
    end
    mb = RubyCurses::MessageBox.new do
      title "Copy"
      message "Copy #{str} to"
      type :input
      width 80
      default_value other_dir
      button_type :ok_cancel
      default_button 0
    end
    if mb.selected_index == 0
      if @current_list.list.selected_row_count == 0
        FileUtils.copy(fp, mb.input_value)
      else
        each_selected_row do |f|
          FileUtils.copy(f, mb.input_value)
        end
        @current_list.list.clear_selection
      end
      other_list.rescan
    end 
  end
  def delete
    fp = @current_list.filepath #.gsub(' ',"\ ")
    fn = @current_list.filename
    if @current_list.list.selected_row_count == 0
      str= "#{fn}"
    else
      str= "#{@current_list.list.selected_row_count} files "
    end
    if confirm("delete #{str}")==:YES
      if @current_list.list.selected_row_count == 0
        if @trash_exists
          FileUtils.mv fp, @trash_path
        else
          FileUtils.rm fp
        end
        ret=@current_list.delete_at 
      else
        each_selected_row do |f|
          if @trash_exists
            FileUtils.mv f, @trash_path
          else
            FileUtils.rm f
          end
        end
        @current_list.remove_selected_rows
        @current_list.list.clear_selection
      end
    end 
  end
  def copy1
    fp = @current_list.filepath
    fn = @current_list.filename
    $log.debug " FP #{fp}"
    other_list = [@lista, @listb].index(@current_list)==0 ? @listb : @lista
    other_dir = other_list.cur_dir
    $log.debug " OL #{other_list.cur_dir}"
    str= "copy #{fn} to #{other_list.cur_dir}"
    $log.debug " copy #{fp}"
    #confirm "#{str}"
      mb = RubyCurses::MessageBox.new do
        title "Copy"
        message "Copy #{fn} to"
       type :input
       width 60
        default_value other_dir
       button_type :ok_cancel
       default_button 0
      end
      #confirm "selected :#{mb.input_value}, #{mb.selected_index}"
      if mb.selected_index == 0
        # need to redraw directories
        FileUtils.copy(fp, mb.input_value)
        other_list.rescan
      end 
  end
  ## TODO : make this separate and callable with its own keylabels
  def view  content=nil # can throw IO errors
    require 'rbcurse/rtextview'
    wt = 0
    wl = 0
    wh = Ncurses.LINES-wt
    ww = Ncurses.COLS-wl
    if content.nil?
      begin
      fp = @current_list.filepath
      content = get_contents(fp)
      rescue => err
        $log.debug err.to_s
        $log.debug(err.backtrace.join("\n"))
        alert err.to_s
        return
      end
    else
      fp=""
    end
    @layout = { :height => wh, :width => ww, :top => wt, :left => wl } 
    @v_window = VER::Window.new(@layout)
    @v_form = RubyCurses::Form.new @v_window
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
    begin
    @textview.set_content content #, :WRAP_WORD
    @v_form.repaint
    @v_window.wrefresh
    Ncurses::Panel.update_panels
    while((ch = @v_window.getchar()) != ?\C-q.getbyte(0) )
      break if ch == FFI::NCurses::KEY_F3
      @v_form.handle_key ch
      @v_form.repaint
      ##@v_window.wrefresh
    end
    rescue => err
      alert err.to_s
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
    when '.zip'
      cmd = "unzip -l #{fp}"
      content = %x[#{cmd}]
    else
      content = File.open(fp,"r").readlines
    end
  end
  def opt_file c
    fp = @current_list.filepath
    fn = @current_list.filename
    other_list = [@lista, @listb].index(@current_list)==0 ? @listb : @lista
    case c
    when 'c'
      copy
    when 'm'
      move
    when 'd'
      delete
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
    when 'x'
      str= "exec #{fp}"
      exec_popup fp
    when 'p'
      page fp
    when 'q'
      qlmanage fp
    end
  end
  def opt_dir c
    fp = @current_list.filepath
    fn = @current_list.filename
    case c
    when 'O'
    #  str= "copy #{fn} to #{other_list.cur_dir}"
      if File.directory? @current_list.filepath
        @current_list.change_dir fp
      end
    when 'o'
      if File.directory? @current_list.filepath
        @other_list.change_dir fp
      end
      @open_in_other = true # ???basically keep opening in other
    when 'd'
      str= "delete #{fn} "
      if confirm("#{str}")==:YES
        $log.debug " delete #{fp}"
        FileUtils.rm fp
        ret=@current_list.list.list_data_model.delete_at @current_list.list.current_index  # ???
        $log.debug " DEL RET #{ret},#{@current_list.list.current_index}"
      end
    when 'u'
      str= "move #{fn} to #{other_list.cur_dir}"
      if confirm("#{str}")==:YES
      $log.debug " MOVE #{str}"
      end
    when 'b'
      dd = @current_list.wdir 
      @bookmarks << dd unless @bookmarks.include? dd
    when 'u'
      dd = @current_list.wdir 
      @bookmarks.delete dd
    when 'l'
      @current_list.populate @bookmarks
    when 's'
      @config["bookmarks"] = @bookmarks
      save_config
    when 'e'
      str= "edit #{fp}"
      #if confirm("#{str}")==:YES
      edit fp
    when 'm'
      f = get_string("Enter a directory to create", 20 )
      if f != ""
        FileUtils.mkdir f
        @current_list.list.list_data_model.insert @current_list.list.current_index, f  # ???
        @current_list.entries.insert @current_list.list.current_index, f  # ???
      end
  
    when 'x'
      str= "exec #{fp}"
      exec_popup fp
    end
  end
  def exec_popup fp
    last_exec_def1 = @last_exec_def1 || ""
    last_exec_def2 = @last_exec_def2 || false

    sel, inp, hash = get_string_with_options("Enter a command to execute on #{fp}", 30, last_exec_def1, {"checkboxes" => ["view result"], "checkbox_defaults"=>[last_exec_def2]})
    if sel == 0
      @last_exec_def1 = inp
      @last_exec_def2 = hash["view result"]
      cmd = "#{inp} #{fp}"
      filestr = %x[ #{cmd} 2>/dev/null ]
      if hash["view result"]==true
        view filestr
      end
    end
  end
  def edit fp=@current_list.filepath
    $log.debug " edit #{fp}"
    editor = ENV['EDITOR'] || 'vi'
    vimp = %x[which #{editor}].chomp
    shell_out "#{vimp} #{fp}"
  end
  def page fp=@current_list.filepath
    ft=%x[file #{fp}]
    if ft.index("text")
      pager = ENV['PAGER'] || 'less'
      vimp = %x[which #{pager}].chomp
      shell_out "#{vimp} #{fp}"
    elsif ft.index(/zip/i)
      shell_out "tar tvf #{fp} | less"
    elsif ft.index(/directory/i)
      shell_out "ls -lh  #{fp} | less"
    else
      alert "#{fp} is not text, not paging "
      #use_on_file "als", fp # only zip or archive
    end
  end
  def qlmanage fp=@current_list.filepath
      begin
        a=%x[which qlmanage]
        if a != ""
          cmd="qlmanage -p #{@current_list.filepath} 2>/dev/null"
          %x[#{cmd}]
        else
          alert "qlmanage not present on your system. Trying pager"
          page fp
        end
      rescue Interrupt
      rescue => err
        alert err.to_s
      end
  end
  # also if calling program gives output but does not stop
  # or take control, then nothing will show up
  def use_on_file prog, args, fp=@current_list.filepath
    vimp = %x[which #{prog}].chomp
    if vimp != ""
      alert "using #{prog} "
      shell_out "#{vimp} #{args } #{fp}"
    else
      alert "could not locate #{prog} "
    end
  end
  def stopping?
    @stopping
  end
  def draw_screens
    lasta = lastb = nil
    if !@config["last_dirs"].nil?
      lasta = @config["last_dirs"][0]
      lastb = @config["last_dirs"][1]
    end
    @lista.draw_screen lasta
    @listb.draw_screen lastb

#    @form.bind_key(?\M-x){
#      @current_list.mark_block
#    }
    # i am just testing out double key bindings
    @form.bind_key([?\C-w,?v]){
      @status_row.text = "got C-w, v"
      $log.debug " Got C-w v "
      view()
    }
    @form.bind_key([?\C-w,?e]){
      @status_row.text = "got C-w, e"
      $log.debug " Got C-w e "
      edit()
    }
    # bind dd to delete file
    # actually this should be in listbox, and we should listen for row delete and then call opt_file
    @form.bind_key([?d,?d]){
      opt_file 'd'
    }
    @form.bind_key([?q,?q]){
      @stopping = true
    }
    # this won't work since the listbox will consume the d first
    @form.bind_key(?@){
      @current_list.change_dir File.expand_path("~/")
    }
    @form.bind_key(?^){
      @current_list.change_dir @current_list.prev_dirs[0] unless @current_list.prev_dirs.empty?
    }
    @form.bind_key(?\C-f){
      @klp.mode :file
      @klp.repaint
      while((ch = @window.getchar()) != ?\C-c.getbyte(0) )
        if ch < 33 || ch > 126
          Ncurses.beep
        elsif "cmdsuvrexpq".index(ch.chr) == nil
          Ncurses.beep
        else
          opt_file ch.chr
          break
        end
      end
      @klp.mode :normal
    }
    @form.bind_key(?\C-d){
      @klp.mode :dir
      @klp.repaint
      keys = @klp.get_current_keys
      while((ch = @window.getchar()) != ?\C-c.getbyte(0) )
        if ch < 33 || ch > 126
          Ncurses.beep
        elsif !keys.include?(ch.chr) 
          Ncurses.beep
        else
          opt_dir ch.chr
          break
        end
      end
      @klp.mode :normal
    }
    # backspace
    @form.bind_key(127){
      @current_list.goto_previous_dir
    }
    # form gives this to list which consumes it for selection.
    # need to bind to list's LIST_SELECTION_EVENT
    @form.bind_key(32){
      fp = @current_list.filepath
      page fp
    }
    @form.bind_key(FFI::NCurses::KEY_F3){
      begin 
        view()
      rescue => err
        alert err.to_s
      end
    }
    @form.bind_key(FFI::NCurses::KEY_F1){
      #Io.view(["this is some help text","hello there"])
      color0 = get_color($promptcolor, 'black','cyan')
      color1 = get_color($reversecolor, 'green','black')
      color2 = get_color($reversecolor, 'blue','black')
      arr = []
      #arr << "  FILE BROWSER HELP  "
      arr << [color0,"        FILE BROWSER HELP      ", FFI::NCurses::A_BOLD]
      arr << "           "
      arr << [[color1," <tab>   ",nil],[color2, "- switch between windows", nil]]
      arr << [[color1," <enter> ",nil],[color2, "- open dir", nil]]
      arr << [[color1," F3      ",nil],[color2, "- view file/dir/zip contents (toggle) ", nil]]
      arr << [[color1," F4      ",nil],[color2, "- edit file content", nil]]
      arr << [[color1," <char>  ", nil],[color2, "first file starting with <char>",nil]]
      #arr << "         VIM MODE                              "
      arr << [color0,"         VIM MODE  ", FFI::NCurses::A_BOLD]
      arr << [[color1," M",nil],[color2, "-v     - Vim like bindings for navigation (toggle)", nil]]
      arr << "   jk gg G up down motion, C-n C-p, Alt-0, Alt-9           "
      arr << [[color1,"   p or Space ",nil],[color2, "- use pager on current file", nil]]
      arr << [[color1,"   q      ",nil],[color2, "- use qlmanage on file ",nil],[$promptcolor, " (OSX)", nil]]
      arr << [[color1,"   f<char> ",nil],[color2, "- first file starting with <char>", nil]]

      arr << "           "
      arr << " < > ^ V - move help window "
      arr << "           "
      # next line does not work due to chunks
      w = arr.max_by(&:length).length
      #arr = ["this is some help text","hello there"]

      require 'rbcurse/extras/viewer'
      RubyCurses::Viewer.view(arr, :layout => [10,10, 4+arr.size, w+2],:close_key => KEY_RETURN, :title => "<Enter> to close", :print_footer => false) do |t|
      # you may configure textview further here.
      #t.suppress_borders true
      #t.color = :black
      #t.bgcolor = :white
      # or
      #t.attr = :reverse
      t.attr = :normal
      #t.bind_key(KEY_F1){ alert "closing up!"; throw :close }
      # just for kicks move window around
      t.bind_key('<'){ f = t.form.window; c = f.left - 1; f.hide; f.mvwin(f.top, c); f.show;
        f.reset_layout([f.height, f.width, f.top, c]); 
      }
      t.bind_key('>'){ f = t.form.window; c = f.left + 1; f.hide; f.mvwin(f.top, c); 
        f.reset_layout([f.height, f.width, f.top, c]); f.show;
      }
      t.bind_key('^'){ f = t.form.window; c = f.top - 1 ; f.hide; f.mvwin(c, f.left); 
        f.reset_layout([f.height, f.width, c, f.left]) ; f.show;
      }
      t.bind_key('V'){ f = t.form.window; c = f.top + 1 ; f.hide; f.mvwin(c, f.left); 
        f.reset_layout([f.height, f.width, c, f.left]); f.show;
      }
    end
    }
    @form.bind_key(FFI::NCurses::KEY_F4){
      edit()
    }
    @form.bind_key(FFI::NCurses::KEY_F6){
      selected_index, sort_key, reverse, case_sensitive = sort_popup
      if selected_index == 0
        @current_list.sort(sort_key, reverse)
      end
    }
    @form.bind_key(FFI::NCurses::KEY_F5){
      filter()
    }
    @form.bind_key(FFI::NCurses::KEY_F7){
      grep_popup()
    }
    @form.bind_key(FFI::NCurses::KEY_F8){
      system_popup()
    }
    # will work if you are in vim mode
    @form.bind_key(?p){
      page
    }
    @form.bind_key(?q){
      qlmanage
    }
    # will no longer come here. list event has to be used
    #@form.bind_key(?\C-m){ # listbox has eaten it up
    @lista.list.bind(:PRESS){
      dir = @current_list.filepath
      if File.directory? @current_list.filepath
        @current_list.change_dir dir
      end
    }
    @listb.list.bind(:PRESS){
      dir = @current_list.filepath
      if File.directory? @current_list.filepath
        @current_list.change_dir dir
      end
    }
    gw = get_color($reversecolor, 'green', 'black')
    bw = get_color($datacolor, 'blue', 'black')
    @klp = RubyCurses::KeyLabelPrinter.new @form, get_key_labels
    @klp.footer_color_pair = bw
    @klp.footer_mnemonic_color_pair = gw 
    @klp.set_key_labels get_key_labels(:file), :file
    @klp.set_key_labels get_key_labels(:view), :view
    @klp.set_key_labels get_key_labels(:dir), :dir
    @form.repaint
    @window.wrefresh
    Ncurses::Panel.update_panels
    begin
      chunks=["File","Key"]
      color0 = get_color($promptcolor, 'black','cyan')
      color1 = get_color($datacolor, 'white','cyan')

      ## qq stops program, but only if M-v (vim mode)
    while(!stopping? && (ch = @window.getchar()) != ?\C-q.getbyte(0) )
      s = keycode_tos ch
      #status_row.text = "|  Pressed #{ch} , #{s}"
      @form.handle_key(ch)

      # the following is just a test of show_colored_chunks
      #count = @current_list.list.size
      count1 = @lista.list.size
      count2 = @listb.list.size
      x, y = FFI::NCurses::getyx @window.get_window
      chunks[0]=[color0, "%-30s" % status_row.text, FFI::NCurses::A_BOLD]
      chunks[1]=[color1, "%-18s" % " |   #{ch}, #{s} |", FFI::NCurses::A_NORMAL]
      chunks[2]=[color0, "   Total: #{count1}, #{count2}"]
      @window.wmove(Ncurses.LINES-3,0)
      @window.color_set(color0, nil)
      @window.print_empty_line
      @window.wmove(Ncurses.LINES-3,0)
      @window.show_colored_chunks chunks
      @window.wmove(x,y)

      #@form.repaint
      @window.wrefresh
    end
    ensure
      @window.destroy if !@window.nil?
      save_config
    end

  end
  # TODO 
  # 
  # 
  # 

# current_list
    ##
    # getter and setter for current_list
    def current_list(*val)
      if val.empty?
        @current_list
      else
        @current_list = val[0] 
        @other_list = [@lista, @listb].index(@current_list)==0 ? @listb : @lista
      end
    end
def get_key_labels categ=nil
  if categ.nil?
  key_labels = [
    ['C-q', 'Exit'], ['C-v', 'View'], 
    ['C-f', 'File'], ['C-d', 'Dir'],
    ['C-Sp','Select'], ['Spc', "Preview"],
    ['F3', 'View'], ['F4', 'Edit'],
    ['F5', 'Filter'], ['F6', 'Sort'],
    ['F7', 'Grep'], ['F8', 'System'],
    ['M-0', 'Top'], ['M-9', 'End'],
    ['C-p', 'PgUp'], ['C-n', 'PgDn'],
    ['M-v', 'Vim Mode'], ['BSpc', 'PrevDir']
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
  elsif categ == :dir
  key_labels = [
    ['o', 'open'], ['O', 'Open in right'],
    ['d', 'Delete'], ['R', 'Del Recurse'],
    ['t', 'tree'], ['p', 'Previous'],
    ['b', 'Bookmark'], ['u', 'Unbookmark'],
    ['l', 'List'],  ['s', 'Save'],
    ['m', 'mkdir'],  nil,
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
def filter
  f = get_string("Enter a filter pattern", 20, "*")
  f = "*" if f.nil? or f == ""
  @current_list.filter_pattern = f
  @current_list.rescan
end

# ask user for pattern to grep through files
#  and display file names in same list

def grep_popup
  last_regex = @last_regex || ""
  last_pattern = @last_pattern || "*"
  mform = RubyCurses::Form.new nil
  r = 4
    field = RubyCurses::Field.new mform do
      name "regex"
      row r
      col 30
      set_buffer last_regex
      set_label Label.new @form, {'text' => 'Regex', 'col'=>5, :color=>'black',:bgcolor=>'white','mnemonic'=> 'R'}
    end
    r += 1
    field = RubyCurses::Field.new mform do
      name "filepattern"
      row r
      col 30
      set_buffer last_pattern
      set_label Label.new @form, {'text' => 'File Pattern','col'=>5, :color=>'black',:bgcolor=>'white','mnemonic'=> 'F'}
    end
    r += 1
  ["Recurse", "case insensitive"].each do |cbtext|
    field = RubyCurses::CheckBox.new mform do
      text cbtext
      name cbtext
      color 'black'
      bgcolor 'white'
      row r
      col 5
    end
    r += 1
  end
  mb = RubyCurses::MessageBox.new mform do
    title "Grep Options"
    button_type :ok_cancel
    default_button 0
  end
  if mb.selected_index == 0
    return if mform.by_name["regex"].getvalue()==""
    @last_regex = mform.by_name["regex"].getvalue
    inp = mform.by_name["regex"].getvalue
    fp = mform.by_name["filepattern"].getvalue
    @last_pattern = fp
    flags=""
    flags << " -i "  if mform.by_name["case insensitive"].value==true
    flags << " -R " if mform.by_name["Recurse"].value==true
    # sometimes grep pukes "No such file or directory if you specify some
    #  filespec that is not present. I don't want it to come in filestr
    #  so i am not piping stderr to stdout
    cmd = "cd #{@current_list.cur_dir()};grep -l #{flags} #{inp} #{fp}"
    filestr = %x[ #{cmd} ]
    files = nil
    files = filestr.split(/\n/) unless filestr.nil?
    #view filestr
    if !files || files.empty?
      alert "Sorry! No files for regex #{inp}"
      return
    end
    @current_list.title "grep #{inp}"
    @current_list.populate files
    # Use backspace to go back
  end
  return mb.selected_index, mform.by_name["regex"].getvalue, mform.by_name["filepattern"].getvalue, mform.by_name["Recurse"].value, mform.by_name["case insensitive"].value
end

def system_popup
  deflt = @last_system || ""
  options=["run in shell","view output","file explorer"]
  #inp = get_string("Enter a system command", 30, deflt)
  sel, inp, hash = get_string_with_options("Enter a system command", 40, deflt, {"radiobuttons" => options, "radio_default"=>@last_system_radio || options[0]})
  if sel == 0
    if !inp.nil?
      @last_system = inp
      @last_system_radio = hash["radio"]
      case hash["radio"]
      when options[0]
        shell_out inp
      when options[1]
        filestr = %x[ #{inp} ]
        view filestr
      when options[2]
        filestr = %x[ #{inp} ]
        files = nil
        files = filestr.split(/\n/) unless filestr.nil?
        @current_list.title inp
        @current_list.populate files
        $log.debug " SYSTEM got #{files.size}, #{files.inspect}"
      end
    end
  end
end
def popup
  deflt = @last_regexp || ""
  #sel, inp, hash = get_string_with_options("Enter a filter pattern", 20, "*", {"checkboxes" => ["case sensitive","reverse"], "checkbox_defaults"=>[true, false]})
  sel, inp, hash = get_string_with_options("Enter a grep pattern", 20, deflt, {"checkboxes" => ["case insensitive","not-including"]})
  if sel == 0
    @last_regexp = inp
    flags=""
    flags << " -i " if hash["case insensitive"]==true
    flags << " -v " if hash["not-including"]==true
    cmd = "grep -l #{flags} #{inp} *"
    filestr = %x[ #{cmd} ]
    files = nil
    files = filestr.split(/\n/) unless filestr.nil?
    view filestr
  end
  $log.debug " POPUP: #{sel}: #{inp}, #{hash['case sensitive']}, #{hash['reverse']}"
end
def shell_out command
  @window.hide
  Ncurses.endwin
  system command
  Ncurses.refresh
  #Ncurses.curs_set 0  # why ?
  @window.show
end
end
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils

  begin
    # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    #$log = Logger.new("rbc13.log")
    $log = Logger.new(ENV['LOGDIR'] || "" + "rbc13.log")

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
