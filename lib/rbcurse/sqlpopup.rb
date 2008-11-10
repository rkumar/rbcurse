#!/usr/bin/ruby

require 'rubygems'
require 'ncurses'
require 'logger'
require 'sqlite3'

include Ncurses
include Ncurses::Form

class SqlPopup

  attr_accessor :header_left   # will print on left what you give
  attr_accessor :labelcolor   # colorpair of label
  attr_accessor :datacolor   # color pair of data
  attr_accessor :promptcolor   # color pair or prompt
  attr_accessor :barcolor   # color pair of bottom bar

  def initialize(rows=Ncurses.LINES-1, cols=Ncurses.COLS-1)
    @rows = rows
    @cols = cols
    @startrow = 2 # 1
    @header_row = 0
    @lastrow = Ncurses.LINES-1 # @rows-1

    @promptcolor = 4 # as in alpine
    @labelcolor = 6
    @datacolor = 5
    @barcolor = 2
    @selectioncolor = 4
    @barrow = @lastrow
    @data_frow = 1  # first row of data
    @padrows = Ncurses.LINES-1
    @scrollatrow = @lastrow - 4 # 2 header, 1 footer, 1 prompt 
    @message = %Q{[-Start ]-End}
    @selected = []
    @stopping = false
  end
  def estimate_column_widths
    colwidths = {}
    @content.each_index do |cix|
      break if cix >= 20
      row = @content[cix]
      row.each_index do |ix|
        col = row[ix]
        colwidths[ix] ||= 0
        colwidths[ix] = [colwidths[ix], col.length].max
      end
    end
    total = 0
    colwidths.each_pair do |k,v|
      name = @columns[k.to_i]
      colwidths[name] = v
      total += v
    end
    colwidths["__TOTAL__"] = total
    return colwidths
  end
        

  def print_tabular_data #:yields pad, ix,  row, labelcol, datacol, column_name, column_value
    @prow = 0
    r = @data_frow
    lc = 1
    @pad.clear

    ## LOOP PRINT
    #printstr(@pad,r, lc, "#" , @labelcolor);
    lc += @numpadding+1
    ## COLUMNS
    @colstring = " # "
    @columns.each do |name|
      @colstring << sprintf("%-*s", @colwidths[name]+1, name)
    #  printstr(@win,0, lc, "%s" % name, @labelcolor);
      lc += @colwidths[name]+1
    end
    r = @data_frow
    ## DATA
    @content.each_with_index do |row, rowid|
      lc = 1
      printstr(@pad, r, lc," %*d" % [@numpadding,(rowid+1)] , @datacolor);
      lc += @numpadding+1
      row.each_index do |ix|
        col = row[ix]
        if block_given?
          yield @pad, r, lc, col
        else
          printstr(@pad, r, lc, " "+col , @datacolor);
          lc += @colwidths[ix]+1
        end
      end
      r += 1
    end
    @win.refresh
  end
  def sql(command)
    db = SQLite3::Database.new('../../out/testd.db')
#    db.results_as_hash = true
    #command = %Q{select * from #{tablename} limit 1}
    @columns, *@datarows = db.execute2(command)
    @datatypes = @datarows[0].types
    @content = @datarows
    db.close
    @numpadding = @content.length.to_s.length
    $log.debug("sql: #{command}")
    $log.debug("scrollat: #{@scrollatrow}")
#    $log.debug("cols: #{@columns.inspect}")
#    $log.debug("dt: #{@datatypes.inspect}")
#    $log.debug("row0: #{@datarows[0].inspect}")
#    $log.debug("rows: #{@datarows.inspect}")
  end
  def do_select
    $log.debug("CALLED SEL #{@prow}")
    if @selected.include? @prow
      @selected.delete @prow
    else
      $log.debug("Adding #{@prow}")
      @selected << @prow
    end
    @message = %q{ '-Next "-Prev ^E-Clear}
=begin
    if @selected[@prow].nil?
      @selected[@prow] = "X"
    else
     @selected[@prow] = nil
    end
=end
  end

  def show_focus_on_row row0, tf=true
    color = tf ? @selectioncolor : @datacolor
    lc = 1
    r = row0+1
    printstr(@pad, r, 0, "%-*s" % [Ncurses.COLS," "], color)
    sel = @selected.include?(row0) ? "X" : " "
    printstr(@pad, r, lc, "#{sel}%*d" % [@numpadding, idx=row0+1] , color);
    lc += @numpadding+1
    row = @content[row0]
    row.each_index do |ix|
      col = row[ix]
      if block_given?
        yield @pad, r, lc, col
      else
        printstr(@pad, r, lc, " "+col , color);
        lc += @colwidths[ix]+1
      end
    end
  end
  def run_tabular
    begin
    @win = WINDOW.new(0,0,0,0)
      # the next line will not obscure footer and header win of prev screen
    @panel = @win.new_panel
    @padrows = [(@content.length) +6, @lastrow+1].max
    @content_rows = @content.length
    @colwidths = estimate_column_widths
    @padcols = @colwidths["__TOTAL__"]  +@columns.length
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
    @win.mvprintw(@header_row+1, 0, "%s", @colstring);
    @win.wrefresh
    show_focus_on_row(0)
    @winrow = 0 # the row on the window we are on
    @pad.prefresh(1,0, @startrow, 0, @rows-2,Ncurses.COLS-1);

    map_keys
    # Loop through to get user requests
    while((ch = @pad.getch()) != KEY_F1 )
#     print_header_left( sprintf("%*s", @cols, " "))
#     print_header_left(@header_left) if !@header_left.nil?
#     @win.wrefresh
      @oldprow = @prow
      @oldwinrow = @winrow
      c = ch.chr rescue 0
      $log.debug("ch: %d %s" % [ch, c])
      break if ch == ?q
      @mapper.press(ch)
=begin
      case ch
      when ?[:      # BEGINNING
        goto_start
      when ?]:       # GOTO END
        goto_end
      when KEY_RIGHT,?l
        right
      when KEY_LEFT, ?h
        left
      when KEY_DOWN, ?j
        down
      when KEY_UP,?k
        up
      when 32, ?n:    # SPACE
        space
      when ?-,?p:
        minus
      when KEY_ENTER, 10
        # selection
        enter
        break
      when ?q, ?\,
        stop!
        break
      when ?g
        handle_goto_ask
      when ?/:
        do_search
      when ?\C-n:
        do_search_next
      when ?\C-p:
        do_search_prev
      when ?x:
        do_select
      when ?':
        do_next_selection
      when ?":
        do_prev_selection
      when ?\C-e:
        do_clear_selection
      end
=end
      break if stopping?
      #@win.wclear
      @toprow = @prow if @prow < @toprow   # ensre search could be 
      @toprow = @prow if @prow > @toprow + @scrollatrow   

      @win.werase # gives less flicker since wclear sems to refresh immed
      print_header_left( sprintf("%*s", @cols, " "))
      print_header_left(@header_left) if !@header_left.nil?
      print_header_right(sprintf("Row %d of %d ", @prow+1, @content.length))
      @win.mvprintw(@header_row+1, 0, "%s", @colstring[@pcol..-1]); # scrolls along with pcol
      printstr(@win, @barrow, 1, "N-NextPg P-PrevPg Q-Quit G-Goto /-Srch X-select  %s" % @message, @barcolor);
      @win.refresh
      show_focus_on_row(@oldprow, false)
      show_focus_on_row(@prow)
      $log.debug("tr:wr:pr #{@toprow} #{@winrow} #{@prow}")
      @pad.prefresh(@toprow+1,@pcol, @startrow,0, @rows-2,Ncurses.COLS-1) 
      Ncurses::Panel.update_panels
      #win.wrefresh # if i don't put this then upon return the other screen is still shown
      # till i press a key
    end # while
    ensure
      Ncurses::Panel.del_panel(@panel) if !@panel.nil?   
      Ncurses::Panel.del_panel(@padpanel) if !@padpanel.nil?   
      @win.delwin if !@win.nil?
    end
    return (@selected_data || [])

  end # run

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
    asel = @selected.dup
    @selected = []
    asel.each {|sel| show_focus_on_row(sel, false)}
#   show_focus_on_row(@prow)
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
    def do_search
      regex = getstring "Enter regex to search for:"
      res = []
      @content.each_with_index do |row, ix| res << ix if row.grep(/#{regex}/) != [] end
      $log.debug("RES: "+ res.inspect)
      if res.length > 0
        @prow = res[0]
      end
      @message = "%d matches for %s. ^N-Next ^P-Prev)" % [res.length, regex]
      @search_indices = res
      @search_index = 0
    end
    def do_search_next
      if @search_indices == []
        Ncurses.beep
      end
      @search_index += 1
      if @search_index >= @search_indices.length
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
        @search_index = @search_indices.length-1
      end
      @prow = @search_indices[@search_index]
    end

    def getstring prompt, r=@lastrow-1, c=1, maxlen = 10, color = @promptcolor
      clear_error @win, r, color
      printstr(@win,r, c, prompt, color);
      ret = ''
      Ncurses.echo();
      @win.attron(Ncurses.COLOR_PAIR(color))
      begin
        @win.mvwgetnstr(r,c+prompt.length+1,ret,maxlen)
      rescue Interrupt => err
        # C-c
        ret = ''
      end
      @win.attroff(Ncurses.COLOR_PAIR(color))
      Ncurses.noecho();
      return ret
    end
    def clear_error win, r = @lastrow, color = @promptcolor
      printstr(win, r, 0, "%-*s" % [Ncurses.COLS," "], color)
    end
    def print_header_left(string)
      @win.attron(Ncurses.COLOR_PAIR(6))
      @win.mvprintw(@header_row, 0, "%s", string);
      @win.attroff(Ncurses.COLOR_PAIR(6))
    end
    def print_header_right(string)
      @win.attron(Ncurses.COLOR_PAIR(6))
      @win.mvprintw(@header_row, @cols-string.length, "%s", string);
      @win.attroff(Ncurses.COLOR_PAIR(6))
    end
    def printstr(pad, r,c,string, color)
      pad.attron(Ncurses.COLOR_PAIR(color))
      pad.mvprintw(r, c, "%s", string);
      pad.attroff(Ncurses.COLOR_PAIR(color))
    end
    def goto_start
      @prow = 0
      @toprow = @prow
    end
    def goto_end
      @prow = @content_rows-1 
      @toprow = @prow
      @winrow = 0     # not putting this was cause prow < toprow !!
    end
    def right
      @pcol += 20 if @pcol + 50 < @padcols
    end
    def left
      @pcol -= 20 if @pcol > 0
      @pcol = 0 if @pcol < 0
    end
    def down
      if @prow >= @content_rows-1
        Ncurses.beep
    #    next
      end
      if @winrow < @scrollatrow # 20
        @winrow += 1
      else
        @toprow += 1 
      end
      @prow += 1 
    end
    def up # UP
      if @prow <= 0
        Ncurses.beep
        @prow = 0
        #  next
      else
        @prow -= 1 
      end
      if @winrow > 0 
        @winrow -= 1
      else
        @toprow -= 1 if @toprow > 0
      end
      $log.error("ERR !!!! #{@winrow} pr #{@prow} tr #{@toprow}") if @prow < @toprow
      @toprow = @prow if @prow < @toprow
    end
    def space
      if @prow + @scrollatrow > @content_rows
    #    next
      else
        @prow += @scrollatrow+1 # @rows-2
        @toprow = @prow
      end
    end
    def minus
      if @prow <= 0
        Ncurses.beep
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
      stop!
    end
    def stop!
      @stopping = true
    end
    def stopping? 
      @stopping
    end
    def map_keys
      @mapper = Mapper.new(self)
      # map keys, methods, desc=""
      @mapper.map [?[], :goto_start
      @mapper.map  [?]], :goto_end
      @mapper.map [32,?n], :space
      @mapper.map [?-,?p], :minus

      @mapper.map  [KEY_RIGHT,?l], :right
      @mapper.map  [KEY_LEFT, ?h], :left
      @mapper.map  [KEY_DOWN, ?j], :down
      @mapper.map  [KEY_UP,?k], :up
      @mapper.map  [KEY_ENTER, 10], :enter 
      @mapper.map  [?q, ?\\], :stop!
      @mapper.map  [?g], :handle_goto_ask
      @mapper.map  [?/], :do_search
      @mapper.map  [?\C-n], :do_search_next
      @mapper.map  [?\C-p], :do_search_prev
      @mapper.map  [?x], :do_select
      @mapper.map  [?'], :do_next_selection
      @mapper.map  [?"], :do_prev_selection
      @mapper.map  [?\C-e], :do_clear_selection
      end
    ## ADD HERE
end # class PadReader
class Mapper
  attr_reader :keymap
  def initialize handler
    @handler = handler
    @keymap = {}
  end
  def map keys, methods, desc=""
    $log.debug("MAP Got: #{keys.inspect} #{methods}")
    keys.each { |key| @keymap[key]=methods }
  end
  def press key
    $log.debug("press Got: #{key}")
    *methods = @keymap[key]
    return if methods.nil? or methods[0].nil?
    $log.debug("Methods: #{methods}")
    methods.each do |m|
      @handler.send(m)
   end
  end
end

  if $0 == __FILE__
    # Initialize curses
    begin
      stdscr = Ncurses.initscr();
      Ncurses.start_color();
      Ncurses.cbreak();
      Ncurses.noecho();
      Ncurses.keypad(stdscr, true);

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
      tp = SqlPopup.new
      tp.header_left = "Contracts"
      tp.labelcolor = 5
      tp.datacolor = 2
      tp.sql("select * from contacts ")
    tp.labelcolor = 2
    tp.datacolor = 5
    tp.run_tabular

  ensure
    Ncurses.endwin();
  end
 end
