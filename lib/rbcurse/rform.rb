$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
=begin
  * Name: rform: our own ruby form and field. Hoping to make it simpler to create forms and labels.
  * $Id$
  * Description   Our own form with own simple field to make life easier. Ncurses forms are great, but
  *         honestly the sequence sucks and is a pain after a while for larger scale work.
  *         We need something less restrictive.
  * Author: rkumar
  * Date: 2008-11-14 23:43 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'rubygems'
require 'ncurses'
require 'logger'
require 'lib/ver/ncurses'
require 'lib/ver/keyboard'
require 'lib/ver/window'
require 'lib/rbcurse/mapper'
require 'lib/rbcurse/keylabelprinter'
require 'lib/rbcurse/commonio'

## form needs to know order of fields esp they can be changed.
#include Curses
include Ncurses
module RubyCurses
  class Form
  include CommonIO
    attr_reader :value
    attr_reader :fields
    attr_reader :fieldnames
    attr_reader :current_index
    attr_accessor :window
    attr_accessor :row, :col
#   attr_accessor :color
#   attr_accessor :bgcolor
    attr_reader :field_id_incr
    def initialize win
      @window = win
      @fields = []
      @fieldnames = []
      @active_index = 0
      @field_id_incr = 0
    end
    def add_field field
      field.id = @field_id_incr
      @fields << field
      @field_id_incr += 1 
    end
    def repaint
      @fields.each do |f|
        r,c = f.label_rowcol
        $log.debug "#{f.label}, #{r}, #{c} "
        printstr @window, r, c, f.label #, f.label_color
       @window.mvchgat(y=r, x=c, max=f.label.length, Ncurses::A_NORMAL, f.label_bgcolor, nil)
        r,c = f.rowcol
        printstr @window, r, c, f.getvalue, f.color
        $log.debug "#{f.getvalue}, #{r}, #{c} "
        @window.mvchgat(y=r, x=c, max=f.display_length, Ncurses::A_NORMAL, f.bgcolor, nil)
      end
      @window.wrefresh
    end
    def get_current_field
      @field[@active_index]
    end
    def set_current_field index
      raise "RRRER" if index > @fields.length
      @active_index = index
    end
    def req_first_field
      @active_index = 0
      set_field_cursor @active_index
    end
    def req_last_field
      @active_index = @fields.length-1
      set_field_cursor @active_index
    end
    def req_next_field
      return if @active_index == @fields.length-1
      @active_index += 1
      set_field_cursor @active_index
    end
    def req_prev_field
      return if @active_index == 0
      @active_index -= 1
      set_field_cursor @active_index
    end
    def handle_key key
    end
    def set_field_cursor index
      @active_index = index
     $log.debug " fc: #{@fields[index]}, #{index}"
     @row, @col = @fields[index].rowcol
     $log.debug " set fc: #{@row} #{@col}"
     @window.wmove @row, @col
    end
    # char is fed to the current field
    def putch char
      @fields[@active_index].putch char
      @col += 1
      @window.wmove @row, @col
    end
    def putc c
      @fields[@active_index].putc c
      @col += 1
      @window.wmove @row, @col
    end
    def req_next_char
      @fields[@active_index].curpos += 1
    end
    def req_prev_char
      @fields[@active_index].curpos -= 1
    end

    ## ADD HERE FORM
  end

  class Field
    attr_accessor :order
    attr_accessor :name
    attr_accessor :id
    attr_accessor :maxlen
    attr_accessor :curpos
    attr_accessor :row
    attr_accessor :col
    attr_reader :buffer
    attr_accessor :label
    attr_accessor :default
    attr_accessor :config
    attr_accessor :values
    attr_accessor :valid_regex
    attr_accessor :display_length
    attr_accessor :label_color
    attr_accessor :label_bgcolor
    attr_accessor :bgcolor
    attr_accessor :color

    def initialize name, r,c, type=:varchar, display_length=10, maxlen=-1
      @name = name
      @buffer = String.new
      @maxlen=maxlen 
      @type=type
      @display_length = display_length
      @row, @col = r, c
      @bgcolor = 0
      @color = $datacolor
      @config = {}
      yield self if block_given?
    end
    def putch char
      @buffer.insert(@curpos, char)
      @curpos += 1
    end
    def putc c
      putchar c.chr
    end
    def delete_at index
      ar = @buffer.split
      ar.delete_at index
      @buffer = ar.join
    end
    def rowcol
      return @row, @col
    end
    def label_rowcol
      return @label_row, @label_col
    end
    def set_buffer value
      @buffer = value
    end
    def getvalue
      @buffer
    end
  def set_label name, row=-1, col=-1, color=$datacolor, bgcolor=2
    @label = name
    row = @row if row == -1
    col = @col-(name.length+1) if col == -1
    @label_row, @label_col = row, col
    @label_color = color
    @label_bgcolor = bgcolor
  end
  # ADD HERE FIELD
  end
end # modul

if $0 == __FILE__
  # Initialize curses
  begin
    VER::start_ncurses
    Ncurses.start_color();
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

    catch(:close) do
      @layout = { :height => 0, :width => 0, :top => 0, :left => 0 } 
      @win = VER::Window.new(@layout)
      @window = @win
      @win.bkgd(Ncurses.COLOR_PAIR(5));
      @panel = @win.panel
      @win.wrefresh
      Ncurses::Panel.update_panels
      $labelcolor = 2
      $datacolor = 5
      @form = RubyCurses::Form.new @win
      r = 1; c = 22;
      %w[ name age company].each do |w|
        field = RubyCurses::Field.new w, r, c, nil, 30
        field.set_label(w)
        field.set_buffer("abcd #{w} #{r}")
        @form.add_field field
        r += 1
      end
      @form.repaint
      @form.req_first_field
      @win.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @win.getch()) != KEY_F1 )
      end
      #     VER::Keyboard.focus = tp
    end
  rescue => ex
  ensure
      Ncurses::Panel.del_panel(@panel) if !@panel.nil?   
      Ncurses::Panel.del_panel(@padpanel) if !@padpanel.nil?   
      @win.delwin if !@win.nil?
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
