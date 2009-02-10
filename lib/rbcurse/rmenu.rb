=begin
  * Name: menu and related classes
  * Description   
  * Author: rkumar
TODO 
FIXME : works with 2 levels, but focus does not go into third level. This has been fixed in rpopupmenu
      and needs to be fixed here. DONE 2009-01-21 12:50 
    - menu bar : what to do if adding a menu, or option later.
      we dnt show disabld options in a way that user can know its disabled
    - separate file created on 2008-12-24 17:58 
NOTE : this program works but is one of the first programs and is untouched. It needs to be rewritten
      since its quite crappy.
      Also, we should move to Action classes as against just blokcs of code. And action class would have
a user friendly string to identifiy the action, as well as a disabled option.
  
  --------
  * Date: 2008-11-14 23:43 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'

include Ncurses
include RubyCurses
module RubyCurses
  extend self


  class MenuSeparator
    attr_accessor :enabled
    attr_accessor :parent
    attr_accessor :row
    attr_accessor :col
    attr_accessor :width
    def initialize 
      @enable = false
    end
    def repaint
      @parent.window.printstring( @row, 0, "|%s|" % ("-"*@width), $reversecolor)
    end
    def destroy
    end
    def on_enter
    end
    def on_leave
    end
    def to_s
      ""
    end
  end
  ##
  class MenuItem
    attr_accessor :parent
#    attr_accessor :window
    attr_accessor :row
    attr_accessor :col
    attr_accessor :width
    attr_accessor :accelerator
    attr_accessor :enabled
    attr_accessor :text, :mnemonic  # changed reader to accessor 
    def initialize text, mnemonic=nil, &block
      @text = text
      @enabled = true
      @mnemonic = mnemonic
      instance_eval &block if block_given?
    end
    def to_s
      "#{@text} #{@accelerator}"
    end
    def command *args, &block 
      $log.debug ">>>command : #{@text} "
      @command = block if block_given?
      @args = args
    end
    def on_enter
      $log.debug ">>>on enter menuitem : #{@text} #{@row} #{@width} "
      highlight
    end
    def on_leave
      $log.debug ">>>on leave menuitem : #{@text} "
      highlight false
    end
    ## XXX it could be a menu again
    def fire
      $log.debug ">>>fire menuitem : #{@text} #{@command} "
      @command.call self, *@args if !@command.nil?
      @parent.clear_menus
      return :CLOSE # added 2009-01-02 00:09 to close only actions, not submenus
    end
    def highlight tf=true
      if @parent.nil? or @parent.window.nil?
        $log.debug "HL XXX #{self} parent nil"
        $log.debug "HL XXX #{self} - > #{@parent} parent nil"
      end
      if tf
        color = $datacolor
        #@parent.window.mvchgat(y=@row, x=1, @width, Ncurses::A_NORMAL, color, nil)
        # above line did not work in vt100, 200 terminals, next works.
        @parent.window.mvchgat(y=@row, x=1, @width, Ncurses::A_REVERSE, $reversecolor, nil)
      else
        repaint
      end
      @parent.window.wrefresh  unless @parent.window.nil? ## XXX 2009-01-21 22:00 
    end
    def repaint # menuitem.repaint
      if @parent.nil? or @parent.window.nil?
        $log.debug "repaint #{self} parent nil"
      #  return
      end
      r = @row
      acolor = $reversecolor
      acolor = get_color($reversecolor, 'green', 'white') if !@enabled
      @parent.window.printstring( @row, 0, "|%-*s|" % [@width, text], acolor)
      if !@accelerator.nil?
        @parent.window.printstring( r, (@width+1)-@accelerator.length, @accelerator, acolor)
      elsif !@mnemonic.nil?
        m = @mnemonic
        ix = text.index(m) || text.index(m.swapcase)
        charm = text[ix,1]
        #@parent.window.printstring( r, ix+1, charm, $datacolor) if !ix.nil?
        # prev line changed since not working in vt100 and vt200
        @parent.window.printstring( r, ix+1, charm, $reversecolor, 'reverse') if !ix.nil?
      end
    end
    def destroy
     $log.debug "DESTRY menuitem #{@text}"
    end
  end
  ##class Menu
  class Menu < MenuItem  ## NEW 
    attr_accessor :parent
    attr_accessor :row
    attr_accessor :col
    attr_accessor :width
    attr_accessor :enabled
    attr_reader :text
    attr_reader :items
    attr_reader :window
    attr_reader :panel
    attr_reader :current_menu
    attr_reader :row_margin  ## 2009-01-21 12:06  NEW
    ## this keeps a stack of menus. if we coud somehow put this in
    # menubar would be great.
    @@menus = []
    @@row = 0
    @@col = 0

    def initialize text, &block
      super text, nil, &block
      @text = text
      @items = []
      @enabled = true
      @current_menu = []
      instance_eval &block if block_given?
      @row ||=10
      @col ||=10
      @@menus ||= []
    end
    ## called upon firing so when we next show menubar there are not any left overs in here.
    def clear_menus
      @@menus = []
    end
    def to_s
      @text
    end
    # item could be menuitem or another menu
    def add menuitem
      @items << menuitem
      return self
    end
    def insert_separator ix
      @items.insert ix, MenuSeparator.new
    end
    def add_separator 
      @items << MenuSeparator.new
    end
    ## added 2009-01-21 12:09 NEW
    def get_item i
      @items[i]
    end
    ## added 2009-01-21 12:09 NEW
    def remove n
      if n.is_a? Fixnum
        @items.delete_at n
      else
        @items.delete n
      end
    end
    # menu - 
    def fire
      $log.debug "menu fire called: #{text}  " 
      if @window.nil?
        #repaint
        create_window
        if !@parent.is_a? RubyCurses::MenuBar 
          @parent.current_menu << self
          @@menus << self # NEW
        end
      else
        ### shouod this not just show ?
        $log.debug "menu fire called: #{text} ELSE XXX WHEN IS THIS CALLED ? 658  " 
        return @items[@active_index].fire # this should happen if selected. else selected()
      end
      #@action.call if !@action.nil?
    end
    # user has clicked down, we shoud display items
    # DRAW menuitems
    def repaint # menu.repaint
      return if @items.nil? or @items.empty?
      $log.debug "menu repaint: #{text} row #{@row} col #{@col}  " 
      if !@parent.is_a? RubyCurses::MenuBar 
        @parent.window.printstring( @row, 0, "|%-*s>|" % [@width-1, text], $reversecolor)
        @parent.window.refresh
      end
      if @window.nil?
        #create_window
      else
        @window.show
        select_item 0
        @window.refresh
      end
    end
    ##
    # recursive if given one not enabled goes to next enabled
    def select_item ix0
      return if @items.nil? or @items.empty?
       $log.debug "insdie select  item :  #{ix0} active: #{@active_index}" 
      if !@active_index.nil?
        @items[@active_index].on_leave 
      end
      previtem = @active_index
      @active_index = ix0
      if @items[ix0].enabled
        @items[ix0].on_enter
      else
        $log.debug "insdie sele nxt item ENABLED FALSE :  #{ix0}" 
        if @active_index > previtem
          select_next_item
        else
          select_prev_item
        end
      end
      @window.refresh
    end
    def select_next_item
      return if @items.nil? or @items.empty?
       $log.debug "insdie sele nxt item :  #{@active_index}" 
      @active_index = -1 if @active_index.nil?
      if @active_index < @items.length-1
        select_item @active_index + 1
      else
      #  select_item 0
      end
    end
    def select_prev_item
      return if @items.nil? or @items.empty?
       $log.debug "insdie sele prv item :  #{@active_index}" 
      if @active_index > 0
        select_item @active_index - 1
      else
      #select_item @items.length-1
      end
    end
    def on_enter # menu.on_enter
      $log.debug "menu onenter: #{text} #{@row} #{@col}  " 
      # call parent method. XXX
        if @parent.is_a? RubyCurses::MenuBar 
          @parent.window.printstring( @row, @col, " %s " % text, $datacolor)
        else
          highlight
        end
        if !@window.nil? #and @parent.selected
          $log.debug "menu onenter: #{text} calling window,show"
          @window.show
          select_item 0
        elsif @parent.is_a? RubyCurses::MenuBar and  @parent.selected
          # only on the top level do we open a window if a previous one was opened
          $log.debug "menu onenter: #{text} calling repaint CLASS: #{@parent.class}"
        #  repaint
          create_window
        end
    end
    def on_leave # menu.on_leave
      $log.debug "menu onleave: #{text} #{@row} #{@col}  " 
      # call parent method. XXX
        if @parent.is_a? RubyCurses::MenuBar 
          @parent.window.printstring( @row, @col, " %s " % text, $reversecolor)
          @window.hide if !@window.nil?
        else
          $log.debug "MENU SUBMEN. menu onleave: #{text} #{@row} #{@col}  " 
          # parent is a menu
          highlight false
          #@parent.current_menu.pop
          #@@menus.pop
          #destroy
        end
    end
    def highlight tf=true # menu
          $log.debug "MENU SUBMENU menu highlight: #{text} #{@row} #{@col}, PW #{@parent.width}  " 
      color = tf ? $datacolor : $reversecolor
      att = tf ? Ncurses::A_REVERSE : Ncurses::A_NORMAL
      #@parent.window.mvchgat(y=@row, x=1, @width, Ncurses::A_NORMAL, color, nil)
      #@parent.window.mvchgat(y=@row, x=1, @parent.width, Ncurses::A_NORMAL, color, nil)
      # above line did not work with vt100/vt200 next does
      @parent.window.mvchgat(y=@row, x=1, @parent.width, att, $reversecolor, nil)
      @parent.window.wrefresh
    end
    def create_window # menu
      margin = 3
      @width = array_width @items
      $log.debug "create window menu #{@text}: #{@row} ,#{@col},wd #{@width}   " 
      @layout = { :height => @items.length+3, :width => @width+margin, :top => @row+1, :left => @col } 
      @win = VER::Window.new(@layout)
      @window = @win
      @win.bkgd(Ncurses.COLOR_PAIR($datacolor));
      @panel = @win.panel
        @window.printstring( 0, 0, "+%s+" % ("-"*@width), $reversecolor)
        r = 1
        @items.each do |item|
          #if item == :SEPARATOR
          #  @window.printstring( r, 0, "|%s|" % ("-"*@width), $reversecolor)
          #else
            item.row = r
            item.col = 0
            item.col = @col+@width+margin # margins???
 #         $log.debug "create window menu loop passing col : #{item.col} " 
            item.width = @width
            #item.window = @window
            item.parent = self
            item.repaint
          #end
          r+=1
        end
        @window.printstring( r, 0, "+%s+" % ("-"*@width), $reversecolor)
      select_item 0
      @window.refresh
      return @window
    end
    # private
    def array_width a
      longest = a.max {|a,b| a.to_s.length <=> b.to_s.length }
      $log.debug "array width #{longest}"
      longest.to_s.length
    end
    def destroy
      $log.debug "DESTRY menu #{@text}"
      return if @window.nil?
      @visible = false
      panel = @window.panel
      Ncurses::Panel.del_panel(panel) if !panel.nil?   
      @window.delwin if !@window.nil?
      @items.each do |item|
        #next if item == :SEPARATOR
        item.destroy
      end
      @window = nil
    end
    # menu LEFT, RIGHT, DOWN, UP, ENTER
    # item could be menuitem or another menu
    #
    def handle_key ch
      if !@current_menu.empty?
        cmenu = @current_menu.last
      else 
        cmenu = self
      end
      if !@@menus.empty?
       cmenu = @@menus.last
      else 
       cmenu = self
      end
      case ch
      when KEY_DOWN
          cmenu.select_next_item
      when KEY_UP
        cmenu.select_prev_item
      when KEY_ENTER, 10, 13, 32 # added 32 2008-11-27 23:50 
        return cmenu.fire
      when KEY_LEFT
        if cmenu.parent.is_a? RubyCurses::Menu 
       $log.debug "LEFT IN MENU : #{cmenu.parent.class} len: #{cmenu.parent.current_menu.length}"
       $log.debug "left IN MENU : #{cmenu.parent.class} len: #{cmenu.current_menu.length}"
        end
        if cmenu.parent.is_a? RubyCurses::Menu and !cmenu.parent.current_menu.empty?
       $log.debug " ABOU TO DESTROY DUE TO LEFT"
          cmenu.parent.current_menu.pop
          @@menus.pop ## NEW
          cmenu.destroy
        else
          return :UNHANDLED
        end
      when KEY_RIGHT
       $log.debug "RIGHTIN MENU : "
        if cmenu.parent.is_a? RubyCurses::Menu 
       $log.debug "right IN MENU : #{cmenu.parent.class} len: #{cmenu.parent.current_menu.length}"
       $log.debug "right IN MENU : #{cmenu.parent.class} len: #{cmenu.current_menu.length}"
        end
        if cmenu.parent.is_a? RubyCurses::Menu and !cmenu.parent.current_menu.empty?
          $log.debug " ABOU TO DESTROY DUE TO RIGHT"
          cmenu.parent.current_menu.pop
          @@menus.pop
          cmenu.destroy
        end
        return :UNHANDLED
      else
        ret = check_mnemonics cmenu, ch
        return ret
      end
    end
    ##
    # checks given key against current menu's items and fires key if 
    # added on 2008-11-27 12:07 
    def check_mnemonics cmenu, ch
#     $log.debug "inside check_mnemonics #{ch}"
      key = ch.chr.downcase rescue ""
      cmenu.items.each do |item|
        next if !item.respond_to? :mnemonic or item.mnemonic.nil?
#       $log.debug "inside check_mnemonics #{item.mnemonic}"
        if key == item.mnemonic.downcase
          ret = item.fire
          return ret #0 2009-01-23 00:45 
        end
      end
      return :UNHANDLED
    end
    ## menu 
    def show # menu.show
      $log.debug "show (menu) : #{@text} "
      if @window.nil?
        create_window
      end
        @window.show 
        select_item 0
    end
  end
  ##
  # An application related menubar.
  # Currently, I am adding this to a form. But should this not be application specific ?
  # It should popup no matter which window you are on ?? XXX
  class MenuBar
    attr_reader :items
    attr_reader :window
    attr_reader :panel
    attr_reader :selected
    attr_accessor :visible
    attr_accessor :active_index
    attr_accessor :state              # normal, selected, highlighted
    attr_accessor :toggle_key              # key used to popup, should be set prior to attaching to form
    def initialize &block
      @window = nil
      @items = []
      init_vars
      @visible = false
      @cols = Ncurses.COLS-1
      instance_eval &block if block_given?
    end
    def init_vars
      @active_index = 0
    end
    def focusable
      false
    end
    def add menu
      @items << menu
      return self
    end
    def next_menu
      $log.debug "next meu: #{@active_index}  " 
      if @active_index < @items.length-1
        set_menu @active_index + 1
      else
        set_menu 0
      end
    end
    def prev_menu
      $log.debug "prev meu: #{@active_index} " 
      if @active_index > 0
        set_menu @active_index-1
      else
        set_menu @items.length-1
      end
    end
    def set_menu index
      $log.debug "set meu: #{@active_index} #{index}" 
      menu = @items[@active_index]
      menu.on_leave # hide its window, if open
      @active_index = index
      menu = @items[@active_index]
      menu.on_enter #display window, if previous was displayed
      @window.wmove menu.row, menu.col
#     menu.show
#     menu.window.wrefresh # XXX we need this
    end
    # menubar LEFT, RIGHT, DOWN 
    def handle_keys
      @selected = false
      @toggle_key ||= 27 # default switch off with ESC, if nothing else defined
      set_menu 0
      begin
      catch(:menubarclose) do
      while((ch = @window.getchar()) != @toggle_key )
       $log.debug "menuubar inside handle_keys :  #{ch}"  if ch != -1
        case ch
        when -1
          next
        when KEY_DOWN
          $log.debug "insdie keyDOWN :  #{ch}" 
          if !@selected
            current_menu.fire
          else
            current_menu.handle_key ch
          end
            
          @selected = true
        when KEY_ENTER, 10, 13, 32
          @selected = true
            $log.debug " mb insdie ENTER :  #{current_menu}" 
            ret = current_menu.handle_key ch
            $log.debug "ret = #{ret}  mb insdie ENTER :  #{current_menu}" 
            #break; ## 2008-12-29 18:00  This will close after firing
            #anything
            break if ret == :CLOSE
        when KEY_UP
          $log.debug " mb insdie keyUPP :  #{ch}" 
          current_menu.handle_key ch
        when KEY_LEFT
          $log.debug " mb insdie KEYLEFT :  #{ch}" 
          ret = current_menu.handle_key ch
          prev_menu if ret == :UNHANDLED
          #display_items if @selected
        when KEY_RIGHT
          $log.debug " mb insdie KEYRIGHT :  #{ch}" 
          ret = current_menu.handle_key ch
          next_menu if ret == :UNHANDLED
        else
          $log.debug " mb insdie ELSE :  #{ch}" 
          ret = current_menu.handle_key ch
          if ret == :UNHANDLED
            Ncurses.beep 
          else
            break  # we handled a menu action, close menubar (THIS WORKS FOR MNEMONICS ONLY and always)
          end
        end
        Ncurses::Panel.update_panels();
        Ncurses.doupdate();

        @window.wrefresh
      end
      end # catch
      ensure
        #ensure is required becos one can throw a :close
        $log.debug " DESTROY IN ENSURE"
      current_menu.clear_menus #@@menus = [] # added 2009-01-23 13:21 
      destroy  # Note that we destroy the menu bar upon exit
      end
    end
    def current_menu
      @items[@active_index]
    end
    def toggle
      @items.each { |i| $log.debug " ITEM DDD : #{i.text}" }
      @visible = !@visible
      if !@visible
        hide
      else
        init_vars
        show
      end
    end
    def hide
      @visible = false
      @window.hide if !@window.nil?
    end
    def show
      @visible = true
      if @window.nil?
        repaint  # XXX FIXME
      else
        @window.show 
      end
    end
    ## menubar
    def repaint
      return if !@visible
      @window ||= create_window
      @window.printstring( 0, 0, "%-*s" % [@cols," "], $reversecolor)
      c = 1; r = 0;
      @items.each do |item|
        item.row = r; item.col = c; item.parent = self
        @window.printstring( r, c, " %s " % item.text, $reversecolor)
        c += (item.text.length + 2)
      end
      @window.wrefresh
    end
    def create_window
      @layout = { :height => 1, :width => 0, :top => 0, :left => 0 } 
      @win = VER::Window.new(@layout)
      @window = @win
      @win.bkgd(Ncurses.COLOR_PAIR(5));
      @panel = @win.panel
      return @window
    end
    def destroy
      $log.debug "DESTRY menubar "
      @visible = false
      panel = @window.panel
      Ncurses::Panel.del_panel(panel) if !panel.nil?   
      @window.delwin if !@window.nil?
      @items.each do |item|
        item.destroy
      end
      @window = nil
    end
  end # menubar

  class CheckBoxMenuItem < MenuItem
    include DSL
    attr_reader :checkbox
    def initialize text, mnemonic=nil, &block
      @checkbox = CheckBox.new nil
      @checkbox.text text
      super
    end
    def onvalue
      @checkbox.onvalue onvalue
    end
    def offvalue
      @checkbox.onvalue offvalue
    end
   def text=(t) # stack level too deep if no = .????
    @checkbox.text t
   end
    def to_s
      "    #{text} "
    end
    def getvalue
      checkbox.getvalue
    end
    def getvalue_for_paint
      "|%-*s|" % [@width, checkbox.getvalue_for_paint]
    end
    def fire
      checkbox.toggle
      super
      repaint
      highlight true
    end
    def repaint
      @parent.window.printstring( row, 0, getvalue_for_paint, $reversecolor)
      parent.window.wrefresh
    end
    def method_missing(sym, *args)
      if checkbox.respond_to? sym
        $log.debug("calling CHECKBOXMENU #{sym} called #{args[0]}")
        checkbox.send(sym, args)
      else
        $log.error("ERROR CHECKBOXMENU #{sym} called")
      end
    end

  end
end # modul
