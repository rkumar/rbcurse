$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
=begin
  * Name: rwidget: base class and then popup and other derived widgets
  * $Id$
  * Description   
  * Author: rkumar
TODO 
  * Date: 2008-11-19 12:49 
  * License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

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
#require 'lib/rbcurse/rform'

module DSL
## others may not want this, if = sent, it creates DSL and sets
  def method_missing(sym, *args)
    #if "#{sym}"[-1].chr=="="
    #  sym = "#{sym}"[0..-2]
    #else
    self.class.dsl_accessor sym
    #end
    send(sym, *args)
  end
end
class Module
## others may not want this, sets config, so there's a duplicate hash
  # also creates a attr_writer so you can use =.
  def dsl_accessor(*symbols)
    symbols.each { |sym|
      class_eval %{
        def #{sym}(*val)
          if val.empty?
            @#{sym}
          else
            @#{sym} = val.size == 1 ? val[0] : val
            @config["#{sym}"]=@#{sym}
          end
        end
    attr_writer sym
      }
    }
  end
end
           #$log.debug "SETTING :   @#{sym}" 
           #$log.debug "getting :  @#{sym}" 

include Ncurses
module RubyCurses
  extend self
  class Widget
    include CommonIO
    include DSL
    dsl_accessor :text, :textvariable
    dsl_accessor :underline                        # offset of text to underline
    dsl_accessor :width                # desired width of text
    dsl_accessor :wrap_length                      # wrap length of text, if applic
    dsl_accessor :select_foreground, :select_background  # color init_pair
    dsl_accessor :highlight_foreground, :highlight_background  # color init_pair
    dsl_accessor :disabled_foreground, :disabled_background  # color init_pair
    dsl_accessor :focusable, :enabled # boolean
    dsl_accessor :row, :col
    dsl_accessor :color, :bgcolor      # normal foreground and background
    dsl_accessor :name                 # name to refr to or recall object by_name
    attr_accessor :id, :zorder
    attr_accessor :curpos              # cursor position inside object
    attr_reader  :config
    attr_reader  :form
    
    def initialize form, aconfig={}, &block
      @form = form
      @config = aconfig
      @config.each_pair { |k,v| variable_set(k,v) }
      instance_eval &block if block_given?
      @bgcolor ||= 0
      @color ||= $datacolor
      @id = form.add_widget(self) if !form.nil?
    end
    def variable_set var, val
        var = "@#{var}"
        instance_variable_set(var, val) 
    end
    def rowcol
      return @row, @col
    end
    def configure(*val , &block)
      case val.size
      when 1
        return @config[val[0]]
      when 2
        @config[val[0]] = val[1]
        variable_set(val[0], val[1]) 
      end
      instance_eval &block if block_given?
    end
    def cget param
      @config[param]
    end
    def getvalue
      @text
    end
    def repaint
        r,c = rowcol
        printstr @form.window, r, c, getvalue, @color
        @form.window.mvchgat(y=r, x=c, max=@text.length, Ncurses::A_NORMAL, @bgcolor, nil)
#     raise "error please override repaint "
    end

  end

  class Form
  include CommonIO
    attr_reader :value
    attr_reader :fields
    attr_reader :widgets
    attr_reader :focusables
    attr_reader :fieldnames
    attr_reader :current_index
    attr_accessor :window
    attr_accessor :row, :col
#   attr_accessor :color
#   attr_accessor :bgcolor
#   attr_reader :field_id_incr
    attr_accessor :padx
    attr_accessor :pady
    attr_accessor :modified
    attr_reader :by_name   # hash containing widgets by name for retrieval
    attr_reader :menu_bar
    def initialize win, &block
      @window = win
      @fields = []
      @widgets = []
      @by_name = {}
      @fieldnames = []
      @active_index = -1
#     @field_id_incr = 0
      @padx = @pady = 0
      @row = @col = -1
      @handler = {}
      @modified = false
      @focusable = true
      @focusables = []
      instance_eval &block if block_given?
    end
    def OLDadd_field field
      id = @field_id_incr
      @fields << field
      @field_id_incr += 1 
      if !field.name.nil?
        $log.debug "adding to byname: #{field.name} " 
        @by_name[field.name] = field
      else
        $log.debug "NOT adding to byname: #{id} " 
      end
      add_widget field
      return id
    end
    def set_menu_bar mb
      @menu_bar = mb
      add_widget mb
    end
   def add_widget widget
      if widget.respond_to? :name and !widget.name.nil?
        $log.debug "adding to byname: #{widget.name} " 
        @by_name[widget.name] = widget
      end
      $log.debug "adding to widgets: #{widget.class} " 
     @widgets << widget
     if widget.focusable
#      $log.debug "adding widget to focusabe: #{widget.name}" 
#      @focusables << widget 
#      widget.zorder = @focusables.length-1
     end
     return @widgets.length-1
   end
    def repaint
      @widgets.each do |f|
        f.repaint
      end
      if @row == -1
        #set_field_cursor 0
       $log.debug "repaint calling select field 0"
        #select_field 0
        req_first_field
      end
      setpos
      @window.wrefresh
    end
    def setpos r=@row, c=@col
     @window.wmove r,c
    end
    def get_current_field
      @widgets[@active_index]
    end
    def req_first_field
      @active_field = -1 # FIXME HACK
      select_next_field
    end
    def req_last_field
      @active_field = -1 # FIXME HACK
      select_prev_field
    end
    def on_leave f
      return if f.nil?
      f.on_leave if f.respond_to? :on_leave
      fire_handler :LEAVE, f 
    end
    def on_enter f
      return if f.nil?
      f.on_enter if f.respond_to? :on_enter
      fire_handler :ENTER, f 
    end
    def select_field ix0
      return if @widgets.nil? or @widgets.empty?
      $log.debug "insdie select  field :  #{ix0} ai #{@active_index}" 
      @active_index = ix0
      f = @widgets[@active_index]
      if f.focusable
        on_enter f
        @row, @col = f.rowcol
        @window.wmove f.row, f.col
        f.curpos = 0
        @window.refresh
      else
        $log.debug "insdie sele nxt field ENABLED FALSE : prev #{previtem} act #{@active_index}  #{ix0}" 
      end
    end
    def select_next_field
      return if @widgets.nil? or @widgets.empty?
       $log.debug "insdie sele nxt field :  #{@active_index} WL:#{@widgets.length}" 
      if @active_index.nil?
        @active_index = -1 
      else
        f = @widgets[@active_index]
        on_leave f
      end
      index = @active_index + 1
      index.upto(@widgets.length-1) do |i|
        f = @widgets[i]
        if f.focusable
          select_field i
          return
        end
      end
      #req_first_field
       $log.debug "insdie sele nxt field FAILED:  #{@active_index} WL:#{@widgets.length}" 
        @active_index = nil
        select_next_field
    end
    def select_prev_field
      return if @widgets.nil? or @widgets.empty?
       $log.debug "insdie sele prev field :  #{@active_index} WL:#{@widgets.length}" 
      if @active_index.nil?
        @active_index = @widgets.length 
      else
        f = @widgets[@active_index]
        on_leave f
      end
      #@active_index -= 1
      index = @active_index - 1
      (index).downto(0) do |i|
        f = @widgets[i]
        if f.focusable
          select_field i
          return
        end
      end
       $log.debug "insdie sele prev field FAILED:  #{@active_index} WL:#{@widgets.length}" 
        @active_index = nil # HACK !!!
        select_prev_field
      #req_last_field
    end
    def addcol num
      return if @col.nil? or @col == -1
      @col += num
      @window.wmove @row, @col
    end
  def bind event, &blk
    @handler[event] = blk
  end
  def fire_handler event, object
#   $log.debug "called firehander #{object}"
    blk = @handler[event]
    return if blk.nil?
    blk.call object
  end
  ## forms handle keys
  def handle_key(ch)
        case ch
        when -1
          return
        when KEY_F2
          #@menu_bar.show
          @menu_bar.toggle
          @menu_bar.handle_keys
        when 9
          select_next_field
        when KEY_UP
          select_prev_field
        when KEY_DOWN
          select_next_field
        else
          field =  get_current_field
          handled = field.handle_key ch
        end
        repaint
  end

    ## ADD HERE FORM
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
    $reversecolor = 2
    $errorcolor = 7
    $promptcolor = $selectedcolor = 4
    $normalcolor = $datacolor = 5
    @bottomcolor = $topcolor = 6

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
      $log.debug "START  ---------"
      @form = RubyCurses::Widget.new @win do
        row 21
        col 89
        width 21
        focusable true
        enabled true
      end
      
      $log.debug "AFTER CREATE : #{@form.inspect} "
      $log.debug "row : #{@form.row} "
      $log.debug "col : #{@form.col} "
      $log.debug "Config : #{@form.config.inspect} "
      @form.configure "row", 23
      @form.configure "col", 83
      $log.debug "row : #{@form.row} "
      x = @form.row
     @form.depth   21
     @form.depth = 22
     @form.depth   24
     @form.depth = 25
      $log.debug "col : #{@form.col} "
      $log.debug "config : #{@form.config.inspect} "
      $log.debug "row : #{@form.configure('row')} "
      #$log.debug "mrgods : #{@form.public_methods.sort.inspect}"
      while((ch = @win.getch()) != KEY_F1 )
        @win.wrefresh
      end
      #     VER::Keyboard.focus = tp
    end
  rescue => ex
  ensure
      Ncurses::Panel.del_panel(@panel) if !@panel.nil?   
      @win.delwin if !@win.nil?
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
