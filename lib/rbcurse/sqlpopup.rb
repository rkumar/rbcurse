$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"

require 'rubygems'
require 'ncurses'
require 'logger'
require 'sqlite3'
require 'lib/ver/ncurses'
require 'lib/ver/keyboard'
require 'lib/ver/keymap'
require 'lib/ver/window'
require 'lib/rbcurse/orderedhash'
require 'lib/rbcurse/mapper'
require 'lib/rbcurse/keylabelprinter'
require 'lib/rbcurse/commonio'
require 'lib/rbcurse/dbcommon'

##
# given an sql statement, shows the result in a tabular format.
# allows multiple selection of rows.
# shows full screen, so not exactly a popup
# Author: rkumar 2008-11-13 09:14 
#
# TODO: 
#       
#       - integrate keys_handled with key_lable and keymappings
#       - think about allowing for a got_focus and lost_focus of row


include Ncurses
class SqlPopup

  include CommonIO
  include DBCommon
  attr_accessor :header_left   # will print on left what you give
  attr_accessor :labelcolor   # colorpair of label
  attr_accessor :datacolor   # color pair of data
  attr_accessor :promptcolor   # color pair or prompt
  attr_accessor :barcolor   # color pair of bottom bar
  attr_reader :keyhandler, :window
  attr_accessor :mode
  attr_accessor :rows, :cols
  attr_accessor :layout            # window layout, this is a hash
  attr_accessor :show_key_labels   # boolean for whether you want key labels shown at bottom, def true

  def initialize(rows=Ncurses.LINES-1, cols=Ncurses.COLS-1)
    @rows = rows
    @cols = cols
    @startrow = 2 # 1
    $header_row = 0
    #@lastrow = Ncurses.LINES-1 # @rows-1
    @lastrow = rows # @rows-1

    $promptcolor = 4 # as in alpine
    $labelcolor = 6
    $datacolor = 5
    $barcolor = 2
    $selectioncolor = 4
    @barrow = @lastrow
    @data_frow = 1  # first row of data
    #@padrows = Ncurses.LINES-1    # XXX ? rows ?
    @padrows = rows  # 2008-11-13 23:37 
    @scrollatrow = @lastrow - 4 # 2 header, 1 footer, 1 prompt 
    @message = nil
    @selected = []   # required for selection function
    @stopping = false
    @mode = :control
    @key_labels = get_key_labels
    #@layout = { :height => 0, :width => 0, :top => 0, :left => 0 } # XXX 2008-11-13 23:15 
    @layout = { :height => rows+1, :width => cols, :top => 0, :left => 0 }
    @show_key_labels = true
    @klp = KeyLabelPrinter.new self, @key_labels, @barrow-1
    if block_given?
      yield self
    end
  end
        

  def print_tabular_data #:yields pad, ix,  row, labelcol, datacol, column_name, column_value
    @prow = 0
    r = @data_frow
    lc = 1
    @pad.clear

    ## LOOP PRINT
    #printstr(@pad,r, lc, "#" , $labelcolor);
    lc += @numpadding+1
    ## COLUMNS
    @colstring = " # "
    @columns.each do |name|
      @colstring << sprintf(" %-*s", @column_widths[name]+1, name)
    #  printstr(@win,0, lc, "%s" % name, $labelcolor);
      lc += @column_widths[name]+1
    end
    @colstring = format_titles
    r = @data_frow
    ## DATA
    @content.each_with_index do |row, rowid|
      lc = 1
      printstr(@pad, r, lc," %*d" % [@numpadding,(rowid+1)] , $datacolor);
      lc += @numpadding+1
      row.each_index do |ix|
        col = row[ix]
        if block_given?
          yield @pad, r, lc, col
        else
          col = sprintf("%*s", @column_widths[ix], col) if @datatypes[ix].match(/int|real/)!=nil
          printstr(@pad, r, lc, " "+col , $datacolor);
          lc += @column_widths[ix]+1
        end
      end
      r += 1
    end
    @win.refresh
  end

  def show_focus_on_row row0, tf=true
    color = tf ? $selectioncolor : $datacolor
    r = row0+1 
    return if r > @content_rows
    @pad.mvchgat(y=r, x=1, max=-1, Ncurses::A_NORMAL, color, nil)
#    @pad.highlight_line(color, r, 1, 50)
#   @pad.wtouchln(r,1, 1)
  end
  def run_tabular
    begin
    #@win = WINDOW.new(0,0,0,0)
      @win = VER::Window.new(@layout)
      @window = @win
      # the next line will not obscure footer and header win of prev screen
    #@panel = @win.new_panel
    @panel = @win.panel
    @padrows = [(@content.length) +6, @lastrow+1].max
    @content_rows = @content.length
    #@column_widths = estimate_column_widths
    estimate_column_widths
    @padcols = @column_widths["__TOTAL__"]  +@columns.length
    $log.debug("cols: #{@padcols} #{@columns.length}")
    @pad = Ncurses.newpad(@padrows,@padcols)
    @padpanel = @pad.new_panel
    Ncurses::Panel.update_panels

    @win.bkgd(Ncurses.COLOR_PAIR(5));
    @pad.keypad(TRUE);
    print_tabular_data

#    Ncurses.refresh();

    @prow = 0; @pcol = 0;
    @toprow = 0
    ## CLEAR clear row
    print_header_left( sprintf("%*s", @cols, " "))
    print_header_left(@header_left) if !@header_left.nil?
    print_header_right(sprintf("Row 1 of %d ", @content.length))
    @win.mvprintw($header_row+1, 0, "%s", @colstring);
    @win.wrefresh
    show_focus_on_row(0)
    @winrow = 0 # the row on the window we are on
    #@pad.prefresh(1,0, @startrow, 0, @rows-2,Ncurses.COLS-1); # XXX 2008-11-13 22:55 
    @pad.prefresh(1,0, @startrow, 0, @rows-2, @cols-1);

    map_keys
    @klp.print_key_labels @key_labels if @show_key_labels 
    VER::Keyboard.focus = self
    ensure
      Ncurses::Panel.del_panel(@panel) if !@panel.nil?   
      Ncurses::Panel.del_panel(@padpanel) if !@padpanel.nil?   
      @win.delwin if !@win.nil?
    end
    return (@selected_data || [])
  end
  def press(key)
#     @message="pressed: #{@mode} - %10p" % key
      @oldprow = @prow
      @oldtoprow = @toprow
      #c = ch.chr rescue 0
      $log.debug("press key: %s" % key)
      begin
      @keyhandler.press(key)
      break if stopping?
      #@win.wclear
      @toprow = @prow if @prow < @toprow   # ensre search could be 
      @toprow = @prow if @prow > @toprow + @scrollatrow   
      @winrow = @prow - @toprow

      if @content.length - @toprow < @scrollatrow and  @toprow != @oldtoprow
        window_erase @win
      end
      print_header_left( sprintf("%*s", @cols, " "))
      print_header_left(@header_left) if !@header_left.nil?
      print_header_right(sprintf("Row %d of %d ", @prow+1, @content.length))
      @win.mvprintw($header_row+1, 0, "%s", @colstring[@pcol..-1]); # scrolls along with pcol
#     printstr(@win, @barrow-1, Ncurses.COLS-@message.length,@message, @barcolor) if !@message.nil?
      @win.refresh
      show_focus_on_row(@oldprow, false)
      show_focus_on_row(@prow)
    # $log.debug("tr:wr:pr #{@toprow} #{@winrow} #{@prow}")
      #@pad.prefresh(@toprow+1,@pcol, @startrow,0, @rows-2,Ncurses.COLS-1)  # XXX
      @pad.prefresh(@toprow+1,@pcol, @startrow,0, @rows-2, @cols-1)
      #@win.wclrtobot # gives less flicker since wclear sems to refresh immed
      Ncurses::Panel.update_panels
      if !@message.nil?
        print_message @message 
        @message = nil
      end

    rescue ::Exception => ex
      $log.debug ex
      show(ex.message)
    end
    #end # while

  end # run

  def do_select arow=@prow
    if @selected.include? arow
      @selected.delete arow
      sel = " "; r = arow+1; 
      printstr(@pad, r, col=1, "#{sel}", $datacolor);
    else
      $log.debug("Adding #{arow}")
      @selected << arow
      sel = "X"; r = arow+1; 
      printstr(@pad, r, col=1, "#{sel}", $selectioncolor);
      #@message = %q{ '-Next "-Prev ^E-Clear}
      @klp.append_key_label '\'', 'NextSel'
      @klp.append_key_label '"', 'PrevSel'
      @klp.append_key_label 'C-e', 'ClearSel'
      @klp.print_key_labels if @show_key_labels 
    end
  end
  def do_next_selection
    return if @selected.length == 0 
    row = @selected.sort.find { |i| i > @prow }
    row ||= @prow
    @prow = row
  end
  def do_prev_selection
    return if @selected.length == 0 
    row = @selected.sort{|a,b| b <=> a}.find { |i| i < @prow }
    row ||= @prow
    @prow = row
  end
  def do_clear_selection
    @selected.each {|sel| do_select(sel)}
  end
  def get_selected_data
    ret = []
    @selected.each { |sel| ret << @content[sel] }
    return ret
  end

  def handle_goto_ask
    line = getstring "Enter row to go to:"
    oldrow = @prow
    @prow = line.to_i
    @prow -= 1 if @prow > 0
    if @prow > @content.length
      @prow = oldrow
      Ncurses.beep
    #  next
    end
  end
    def do_search_ask
      regex = getstring "Enter pattern to search for:"
      res = search_content regex
      if res.length > 0
        @prow = res[0]
        @klp.append_key_label 'C-n', 'NextMatch'
        @klp.append_key_label 'C-p', 'PrevMatch'
        @klp.print_key_labels if @show_key_labels 
      end
      @message = "Matched %d for %s." % [res.length, regex]
      @search_indices = res
      @search_index = 0
    end
    def do_search_next
      if @search_indices == []
        Ncurses.beep
        @message = "Search next is available after searching"
      end
      @search_index += 1
      if @search_index >= @search_indices.length
        @message = "Reached bottom, continuing at top"
        @search_index = 0
      end
      @prow = @search_indices[@search_index]
    end
    def do_search_prev
      if @search_indices == []
        Ncurses.beep
      end
      @search_index -= 1
      if @search_index < 0
        @message = "Reached top, continuing at bottom"
        @search_index = @search_indices.length-1
      end
      @prow = @search_indices[@search_index]
    end

 
    def goto_start
      @prow = 0
      @toprow = @prow
      @winrow = 0 # 2008-11-12 16:32 
    end
    def goto_end
      @prow = @content_rows-1 
      #@toprow = @prow
      #@winrow = 0     # not putting this was cause prow < toprow !!
      @toprow = @prow - @scrollatrow # ensure screen is filled when we show last. so clear not required
         ## except what if very few rows
      @winrow = @scrollatrow
    end
    def right
      @hscrollcols ||= @cols/2
      @pcol += @hscrollcols if @pcol + @hscrollcols < @padcols
      window_erase @win
    end
    def left
      @hscrollcols ||= @cols/2
      @pcol -= @hscrollcols if @pcol > 0
      @pcol = 0 if @pcol < 0
    end
    def down
#     $log.debug "inside down"
      if @prow >= @content_rows-1
        #Ncurses.beep
        @message = "No more rows"
        return
      end
      if @winrow < @scrollatrow # 20
        @winrow += 1    # move cursor down
      else
        @toprow += 1    # scroll down a row
      end
      @prow += 1        # incr pad row
    end
    def up # UP
      if @prow <= 0
        #Ncurses.beep
        @message = "This is the first row"
        @prow = 0
        return
      else
        @prow -= 1 
      end
      if @winrow > 0 
        @winrow -= 1
      else
        @toprow -= 1 if @toprow > 0
      end
      @toprow = @prow if @prow < @toprow
    end
    def space
      if @toprow + @scrollatrow+1 >= @content_rows
      else
        @toprow += @scrollatrow+1 # @rows-2 2008-11-13 23:41 put toprow here too
      $log.debug "space pr #{@prow}"
        @prow = @toprow
      end
    end
    def minus
      if @prow <= 0
        #Ncurses.beep
        @message = "This is the first row"
        @prow = 0
        #next
      else
        @prow -=  (@scrollatrow+1) #(@rows-2)
        @prow = 0 if @prow < 0
      end
      @toprow = @prow
    end
    def enter
      @selected_data = get_selected_data
      $log.debug("RETURN: #{@selected_data.inspect}")
      stop
    end
    def show string
      @message = string
    end
    def map_keys
      #@keyhandler = VER::KeyHandler.new(self)

      @mapper = Mapper.new(self)
      @keyhandler = @mapper
      @mapper.let :control do

        map('C-x', 'C-d'){ view.down }
        map('C-x', 'C-u'){ view.up }
        map('C-x', 'q'){ view.stop }
        map('C-x', 'C-s'){ view.do_search_ask }
        map('C-x', 'C-x'){ view.do_select }
        map('C-s'){ view.mode = :cx }
        map('q'){ view.stop }
        map('space'){ view.space }
        map('n'){ view.space }
        map('j'){ :down }
        map('k'){ view.up }
        map('p'){ view.minus }
      map('[') { view.goto_start }
      map(']') { view.goto_end }
      map('-') { view.minus }

      map('right') { view.right}
      map('l') { view.right}
      map('left') {view.left}
      map('h') {view.left}
      map('down') { view.down }
      map('j') { view.down }
      map('up') { view.up }
      map('enter') { view.enter  }
      map('g') { view.handle_goto_ask }
      map('/') { view.do_search_ask }
      map('C-n') { view.do_search_next }
      map('C-p') { view.do_search_prev }
      map('x') { view.do_select }
      map('\'') { view.do_next_selection }
      map('"') { view.do_prev_selection }
      map('C-e') { view.do_clear_selection }
      map(/^([[:print:]])$/){ #view.show("Got printable: #{@arg}") 
      }


      map('C-q'){ view.stop }
 
=begin
      @mapper.let :cx do
        map('c'){ view.show(:c) }
        map('a'){ view.show(:a) }
        map('r'){ view.show(:r) }
        map('q'){ view.stop }
        map('i'){ view.mode = :control }
      end
=end
      end
    end
    # from VER
    def stopping?
      @stop
    end

    # without this system hangs if unknown key presed
    def info(message)
      @message = message
      # sorry, hardcoded right now...
    end

    def stop
      @stop = true
      throw(:close)
    end
    def get_key_labels
      key_labels = [
        ['g', 'Goto'], ['/', 'Search'],
        ['x', 'Sel'], ['C-e', 'ClrSel'],
        ['Spc','PgDn'], ['-','PgUp']
      ]
      return key_labels
    end
    def window_erase win
        win.werase # gives less flicker since wclear sems to refresh immed
        @klp.print_key_labels @key_labels if @show_key_labels 
    end

    ## ADD HERE
end # class sqlpopup

  if $0 == __FILE__
    # Initialize curses
    begin
      VER::start_ncurses
      Ncurses.start_color();
=begin
      stdscr = Ncurses.initscr();
      Ncurses.start_color();
      Ncurses.cbreak();
      Ncurses.noecho();
      Ncurses.keypad(stdscr, true);
=end

      # Initialize few color pairs 
      Ncurses.init_pair(1, COLOR_RED, COLOR_BLACK);
      Ncurses.init_pair(2, COLOR_BLACK, COLOR_WHITE);
      Ncurses.init_pair(3, COLOR_BLACK, COLOR_BLUE);
      Ncurses.init_pair(4, COLOR_YELLOW, COLOR_RED); # for selected item
      Ncurses.init_pair(5, COLOR_WHITE, COLOR_BLACK); # for unselected menu items
      Ncurses.init_pair(6, COLOR_WHITE, COLOR_BLUE); # for bottom/top bar
      Ncurses.init_pair(7, COLOR_WHITE, COLOR_RED); # for error messages

      # Create the window to be associated with the form 
      # Un post form and free the memory
      $log = Logger.new("view.log")
      $log.level = Logger::DEBUG
      $db = SQLite3::Database.new('../../out/testd.db')
    catch(:close) do
      tp = SqlPopup.new #15, 50
      tp.header_left = "Contacts"
      $labelcolor = 5
      $datacolor = 2
      tp.sql("select * from contracts ")
#     tp.sql("select seller_company_name, product_name, product_type_name, rate, quantity from contracts ")
 #    tp.sql("select product_name, rate, quantity from contracts ")
      $labelcolor = 2
      $datacolor = 5
      tp.run_tabular
 #     VER::Keyboard.focus = tp
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
