$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'lib/ver/ncurses'
require 'lib/ver/window'
require 'lib/rbcurse/rwidget'
require 'lib/rbcurse/rcombo'
require 'lib/rbcurse/rlistbox'
#require 'lib/rbcurse/table/tablecellrenderer'
require 'lib/rbcurse/keylabelprinter'
require 'lib/rbcurse/applicationheader'
require 'lib/rbcurse/action'
require 'fileutils'

class FileExplorer

  def initialize form, rfe, row, col, height, width
    @form = form
    @rfe = rfe
    @row, @col, @ht, @wid = row, col, height, width
  end
  def change_dir dir, list=current_list()
    begin
      dir = File.expand_path dir
      cd dir
      pwd = pwd()
      list.title = pwd
      default_pattern ||= "*.*"
      flist = Dir.glob(default_pattern)
      fl = []
      flist.each {|f| stat = File.stat(f)
        fl << format_string(f, stat)
      }
      list.list_data_model.remove_all
      list.list_data_model.insert 0, *fl
    rescue => err
      @status_row.text = err.to_s
    end
  end
  GIGA_SIZE = 1073741824.0
  MEGA_SIZE = 1048576.0
  KILO_SIZE = 1024.0

  # Return the file size with a readable style.
  def readable_file_size(size, precision)
    case
      when size == 1 : "1 B"
      when size < KILO_SIZE : "%d B" % size
      when size < MEGA_SIZE : "%.#{precision}f K" % (size / KILO_SIZE)
      when size < GIGA_SIZE : "%.#{precision}f M" % (size / MEGA_SIZE)
      else "%.#{precision}f G" % (size / GIGA_SIZE)
    end
  end
  def format_string f, stat
    "%-*s %s" % [@wid-10,f, readable_file_size(stat.size,1)]
  end
  def draw_screen dir=nil
    pwd = FileUtils.pwd
    r = @row
    c = @col
    #cola = 1
    #colb = Ncurses.COLS/2
    ht = @ht
    wid = @wid
    default_pattern ||= "*.*"
    fl = Dir.glob(default_pattern)
      flist = []
      fl.each {|f| stat = File.stat(f)
        flist << format_string(f, stat)
      }
    title = pwd

        lista = Listbox.new @form do
          name   "lista" 
          row  r 
          col  c
          width wid
          height ht
          list flist
          title pwd
          title_attrib 'reverse'
        end
        lista.bind(:ENTER) {|l| @rfe.current_list(l); l.title_attrib 'reverse' }
        lista.bind(:LEAVE) {|l| l.title_attrib 'normal'; $log.debug " LEAVING #{l}" }


        row_cmd = lambda {|list| file = list.list_data_model[list.current_index].split()[0]; @rfe.status_row.text = File.stat(file).inspect }
        lista.bind(:ENTER_ROW) {|list| row_cmd.call(list) }

  end
end
class RFe
  include FileUtils
  attr_reader :status_row
  def initialize
    @window = VER::Window.root_window
    @form = Form.new @window
    status_row = RubyCurses::Label.new @form, {'text' => "", :row => Ncurses.LINES-2, :col => 0, :display_length=>Ncurses.COLS-2}
    @status_row = status_row
    colb = Ncurses.COLS/2
    ht = Ncurses.LINES - 5
    wid = Ncurses.COLS/2 - 0
    @lista = FileExplorer.new @form, self, row=2, col=1, ht, wid
    @listb = FileExplorer.new @form, self, row=2, col=colb, ht, wid

    init_vars
  end
  def init_vars

  end
  def draw_screens
    @lista.draw_screen
    @listb.draw_screen
    @form.bind_key(?c){
      dir=get_string("Give directory to change to:")
      change_dir dir
    }
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
