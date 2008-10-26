#!/usr/bin/env ruby
# rkumar 2008 Sep
# added 2008-10-10 23:07 removing tabs and non print characters from multi-line fields
# else not displaying
require 'rubygems'
require 'ncurses'

include Ncurses
include Ncurses::Form
#NLINES=10
NCOLS = 40

=begin
    == Usage 
    #tp = PanelReader.new()
    #tp.header="My new editor"
    #content = tp.edit_file("../TODO")
    ##or
    #tp.view_file("../TODO")
    ##or
    #content = tp.edit_content(text)
    ##or
    #tp.view_content(text)
=end
class PanelReader
  attr_accessor :header
  attr_accessor :editable             # TRUE/FALSE
  attr_reader :content
  attr_reader :content_source
  attr_accessor :box              # TRUE/FALSE
  attr_accessor :footer_row             # by default @rows -1
  attr_accessor :rows             # by Ncurses.LINES

  #def initialize(rows=20, cols=Ncurses.COLS-2)
  def initialize(rows=Ncurses.LINES-0, cols=Ncurses.COLS-1)
    @rows = rows
    @cols = cols
    @fieldwidth = @cols - 2
    @win = nil
    @panel = nil
    @form = nil
    @header = "Editor"
    @content = nil
    @editable = false
    @file = nil
    @box = false
    @header_row = 0
    @header_span = 1 # if box then 3
    @footer_span = 0 # if box then 3
    @content_rows = 0
    @field_span = 0
    @currno = 1
    @footer_row = @rows-1
  end
  def set_content_source(file)
    text = File.open(file,"r").readlines.join 
    @file = file
    @content = text_to_multiline(text, @fieldwidth)
  end
  def edit_file(file)
    @editable = TRUE
    set_content_source(file)
    return run()
  end
  def view_file(file)
    @editable = FALSE
    set_content_source(file)
    run()
  end
  def edit_content(text)
    @editable = TRUE
    @content = text_to_multiline(text, @fieldwidth)
    return run()
  end
  def view_content(text)
    @editable = FALSE
    @content = text_to_multiline(text, @fieldwidth)
    run()
  end

## a multi-line field rejects text containing newlines.
#  So we split incoming text on newline, then pad it to the width of the
# field so it looks just as expected.
# lines longer than width are split and then padded.
# 2008-09-22 19:28 
def text_to_multiline(text, width)
  text.gsub!(/\t/, '  ') # 2008-10-10 22:59 tabs and other chars are still a problem
  lines = text.split("\n")
  lines.map!{ |line|  
    if line.length <= width
      line.gsub!(/[^[:print:]]/, '') # 2008-10-10 22:59 other chars are still a problem
      sprintf("%-#{width}s", line) 
    else
      sublines = line.scan(/.{1,#{width}}/)
      sublines.map!{ |sline| sline.gsub!(/[^[:print:]]/, ''); sprintf("%-#{width}s", sline)  }
      sublines.join
    end
  }
  @content_rows = lines.count
  text = lines.join
  text
end
# in order to save as file, or post out
def multiline_format(text, width)
  # ncurses pads each row with spaces rather than put a newline. Very annoying.
  lines = text.scan(/.{1,#{width}}/)
  lines.map{|l| l.strip!}
  lines = lines.join("\n")
  lines
end
def print_in_middle(win, starty, startx, width, string, color)

    x = Array.new
    y = Array.new
    Ncurses.getyx(win, y, x);
    if(startx != 0)
      x[0] = startx;
    end
    if(starty != 0)
      y[0] = starty;
    end
    if(width == 0)
      width = 80;
    end
    length = string.length;
    temp = (width - length)/ 2;
    x[0] = startx + temp.floor;
    win.attron(color);
    #win.mvprintw(y[0], x[0], "%s", string);
    win.mvprintw(starty, x[0], "%s", string);
    win.attroff(color);
    Ncurses.refresh();
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
  def win_show(win, label, label_color)
    starty = []; startx = []
    height = []; width = []
    win.getbegyx(starty, startx);
    win.getmaxyx( height, width);

    @header_row = 0
    if @box
      win.box( 0, 0);
      win.mvwaddch( 2, 0, ACS_LTEE); 
      win.mvwhline( 2, 1, ACS_HLINE, width[0] - 2); 
      win.mvwaddch( 2, width[0] - 1, ACS_RTEE); 
      @header_row = 1
    end

    print_header_left( sprintf("%*s", @cols, " "))
    print_in_middle(win, @header_row, 0, width[0], label, Ncurses.COLOR_PAIR(label_color));
    win.wrefresh;

  end
  def init_win(wins, label, formm)
    y =2; x=0
    #w  = Ncurses::WINDOW.new(@rows,@cols+2, y , x)
    w  = Ncurses::WINDOW.new(0,0,0,0)
    @win = w
    formm.set_form_win(w);                                      #
    formm.post_form();
    # win show must come after post_form XXX
    win_show(w, label, 6);
    @panel = w.new_panel
    @win.keypad(TRUE);

  end
  def run
    @fields = Array.new

    flen = NCOLS-2
    col = 0
    if @box
      @header_span = 3
      @footer_span = 1
    end
    row = @header_span
    @field_span = @rows-(@header_span+1+@footer_span)
    #@field_span = @rows -2
    field = FIELD.new(@field_span, @fieldwidth, row, col, 0, 0)
    if !@editable
      field.field_opts_off(O_EDIT); 
      field.set_field_back(A_NORMAL)
    else
      field.set_field_back(A_REVERSE)
    end
    field.field_opts_off(O_STATIC); 
    field.field_opts_on(O_WRAP); 
    field.user_object = "MAIN"
    if !@content.nil?
      field.set_field_buffer(0, @content)
    end
    @fields.push(field)

    # create the Ok field
    label = "OK"
    width = label.length+2
    #@footer_row = @rows-2 if @box
    @footer_row -= 1 if @box
    field = FIELD.new(1, width, @footer_row, @cols-20, 0, 0)
    #field.set_field_back(A_UNDERLINE)
    field.field_opts_off(O_EDIT); 
    field.set_field_buffer(0, "[#{label}]")
    field.set_field_just(JUSTIFY_CENTER); 
    field.user_object = label
    @fields.push(field)
    
    # create the Cancel field
    label = "Cancel"
    width = label.length+2
    field = FIELD.new(1, width, @footer_row, @cols-10, 0, 0)
    #field.set_field_back(A_UNDERLINE)
    field.field_opts_off(O_EDIT); 
    field.set_field_buffer(0, "[#{label}]")
    field.set_field_just(JUSTIFY_CENTER); 
    field.user_object = label
    @fields.push(field)

    @form = FORM.new(@fields);
    begin 
    init_win(@win, @header, @form);

    print_header_left(@file) if !@file.nil?
    #@my_panels[0].set_panel_userptr( @my_panels[1]);
    Ncurses::Panel.update_panels
    Ncurses.doupdate()

    @curr_field_ix=0
    field_init_proc = proc {
      x = @form.current_field
      ix = @fields.index(x)
      @curr_field_ix=ix
      @curr_field_name=x.user_object
      if ix != 0
        #@fields[ix].set_field_back(Ncurses.COLOR_PAIR(4))
        @fields[ix].set_field_back(A_REVERSE)
      end
    }
    field_term_proc = proc {
      x = @form.current_field
      ix = @fields.index(x)
      if ix != 0
        @fields[ix].set_field_back(A_NORMAL)
      end
    }

    @form.set_field_init(field_init_proc)
    @form.set_field_term(field_term_proc)
   # x1=[]
   # x2=[]
   # x3=[]
   # @fields[0].dynamic_field_info(x1,x2,x3)
   # @content_rows = x1[0]
    #print_header_right("INFO: #{x1[0]}  #{x2[0]}  #{x3[0]}  #{x4[0]}  #{x5[0]}  #{x6[0]} ")
    print_header_right(sprintf("  %d rows", @content_rows))
    @currno = 0
    @form.form_driver(REQ_FIRST_FIELD);
    while((ch = @win.getch()) != 197)
      case(ch)
      when 9 :
        @form.form_driver(REQ_NEXT_FIELD);
        @currno = 0
      when KEY_DOWN
        if @currno > @content_rows + @field_span
          Ncurses.beep
          next
        end
        ret = @form.form_driver(REQ_NEXT_LINE);
        @currno += 1 #if @currno < @content_rows
      when KEY_UP
        ret = @form.form_driver(REQ_PREV_LINE);
        @currno -= 1 if @currno > 1
      when KEY_RIGHT
        @form.form_driver(REQ_NEXT_CHAR);
      when KEY_LEFT
        @form.form_driver(REQ_PREV_CHAR);
      when 10, KEY_ENTER
        name=@curr_field_name;
        if name == "OK"
          return multiline_format(@content, @fieldwidth)
        elsif name == "Cancel"
          return ""
        end
        @form.form_driver(REQ_NEXT_LINE);
      when KEY_BACKSPACE,127
      @form.form_driver(REQ_DEL_PREV);
    when 1  # c-a
      @form.form_driver(REQ_BEG_LINE);
    when 5  # c-e
      @form.form_driver(REQ_END_LINE);
    when 165  # A-a
      @form.form_driver(REQ_BEG_FIELD);
      @currno = 1
    when 180  # A-e
      @form.form_driver(REQ_END_FIELD);
      @currno = @content_rows
    when 11 # c-k # 154  # A-k
      @form.form_driver(REQ_CLR_EOL);

    else
      if !@editable
        if ch == 32 # space
          if @currno >=  @content_rows
            @currno = @content_rows
            Ncurses.beep
            next
          end
          @form.form_driver(REQ_SCR_FPAGE);
          @currno += @field_span
        elsif ch == ?\-
          ret = @form.form_driver(REQ_SCR_BPAGE);
          @currno -= @field_span if @currno > @field_span
          @currno = 0 if @currno <0 
        end
      end
      @form.form_driver(ch);
    end
      Ncurses::Panel.update_panels();
      Ncurses.doupdate();
      #print_header_right(sprintf(" %d of %d rows", @currno+1, @content_rows))

    end
  ensure
    free_all
  end

  end
  def free_all
    fields = @fields
    if !@form.nil?
      @form.unpost_form();
      @form.free_form();
    end
    fields.each {|f| f.free_field()} if !fields.nil?
    Ncurses::Panel.del_panel(@panel)   # critical or previous screen screwed up
  end

end
if __FILE__ == $0
  begin

    stdscr=Ncurses.initscr
    Ncurses.start_color
    Ncurses.cbreak
    Ncurses.noecho
    Ncurses.keypad(stdscr, true)
    Ncurses.init_pair(1, COLOR_RED, COLOR_BLACK);
    Ncurses.init_pair(2, COLOR_GREEN, COLOR_BLACK);
    Ncurses.init_pair(3, COLOR_BLUE, COLOR_BLACK);
    Ncurses.init_pair(4, COLOR_CYAN, COLOR_BLACK);
    Ncurses.init_pair(6, COLOR_WHITE, COLOR_BLUE); # for bottom/top bar

    tp = PanelReader.new()
    tp.header="My new editor"
    tp.box = FALSE
    #tp.editable=FALSE
    #tp.set_content_source("TODO")
    #content = tp.run
    #content = tp.edit_file("../TODO")
    tp.view_file("test.t")
    #tp.set_content(text)
    # how to define a callback ? XXX
  ensure
    Ncurses.endwin();
  end
end
