=begin
  * Name: menu and related classes
  * Description   
  * Author: rkumar
  * I am redoing this totally, since this was one my first ruby programs and needs 
  *  simplification. It was hard to maintain.
TODO 
 -- cursor to be on current menuitem if possible ... UNABLE TO !!
 -- Number and letter indexing for item_list
 -- Use Box characters and hline for separator
  -- MenuSeparator and MenuItem should be common to popups and menus, so we don't need
     2 separate names, there was clobbering the same namespace.

  ??  Also, we should move to Action classes as against just blokcs of code. And action class would have
a user friendly string to identifiy the action, as well as a disabled option.
  
  --------
  * Date: 2011-09-23  (old 2008-11-14 23:43 )
 == Major changes v1.3.1
 2011-09-24 V1.3.1 added item_list for dynamic menuitem generation, see examples/menu1.rb
 2011-09-24 V1.3.1 added multicolumn outputs
 2011-09-24 V1.3.1 left and right keys on menua, C-g to abort

  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
#require 'logger'
require 'rbcurse'

include RubyCurses
module RubyCurses
  extend self


  # The separator that separates menuitems, helping to group them.
  class MenuSeparator
    attr_accessor :enabled
    attr_accessor :parent
    attr_accessor :row
    attr_accessor :col
    attr_accessor :coffset
    attr_accessor :width
    attr_accessor :color, :bgcolor # 2011-09-25 V1.3.1 
    def initialize 
      @enable = false
    end
    def repaint
      acolor = get_color($reversecolor, @color, @bgcolor)
      @parent.window.printstring( @row, 0, "|%s|" % ("-"*@width), acolor)
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
  # Items in menus. These will usually result in an action which closes the entire
  #  menubar.
  class MenuItem
    attr_accessor :parent
#    attr_accessor :window
    attr_accessor :row
    attr_accessor :col
    attr_accessor :coffset
    attr_accessor :width
    attr_writer :accelerator
    attr_accessor :enabled
    attr_accessor :color, :bgcolor # 2011-09-25 V1.3.1 
    attr_accessor :color_pair # 2011-09-25 V1.3.1 
    attr_reader :active_index # 2011-09-24 V1.3.1  trying to do a right
    attr_accessor :text, :mnemonic  # changed reader to accessor 
    def initialize text, mnemonic=nil, &block
      @text = text
      @enabled = true
      # check for mnem that is not one char, could be an accelerator
      if mnemonic
        if mnemonic.length != 1
          $log.error "MenuItem #{text} mnemonic #{mnemonic}  should be one character. Maybe you meant accelerator? " 
          mnemonic = nil
        end
      end
      @mnemonic = mnemonic
      instance_eval &block if block_given?
    end
    def to_s
      "#{@text} #{@accelerator}"
    end
    def command *args, &block 
      $log.debug ">>>command : #{@text} "
      @command = block if block_given?
      alert "Command nil or some error! #{text} " unless @command
      @args = args
    end
    # add accelerator for a menu item
    # NOTE: accelerator means that the application has tied this string to some action, outside
    # of the menu bar. It does not mean that the menu bar will trigger the action. So the app still has to 
    # define the action and bind a key to that accelerator. This is only informative.
    # Had to do this since dsl_accessor was throwing some nilclass does not have []= nomethod error
    # This allows user to put accelerator inside dsl block
    # @example
    #    accelerator "Ctrl-X"
    def accelerator(*val)
      if val.empty?
        return @accelerator
      else
        @accelerator = val[0]
      end
    end
    def on_enter #item
      highlight
      #@parent.window.wmove @row, @col+1  # 2011-09-25 V1.3.1  NO EFFECT
    end
    def on_leave
      highlight false
    end
    ## XXX it could be a menu again
    #  We should not be firing a :NO_MENUITEMS
    def fire
      $log.debug ">>>fire menuitem : #{@text} #{@command} "
      @command.call self, *@args if !@command.nil?
      @parent.clear_menus
      return :CLOSE # added 2009-01-02 00:09 to close only actions, not submenus
    end
    def highlight tf=true
      if @parent.nil? or @parent.window.nil?
        #$log.debug "HL XXX #{self} parent nil"
        #$log.debug "HL XXX #{self} - > #{@parent} parent nil"
      end
      if tf
        #color = $datacolor
        #@parent.window.mvchgat(y=@row, x=1, @width, Ncurses::A_NORMAL, color, nil)
        # above line did not work in vt100, 200 terminals, next works.
#        @parent.window.mvchgat(y=@row, x=1, @width, Ncurses::A_REVERSE, $reversecolor, nil) # changed 2011 dts  2011-09-24  multicolumn, 1 skips the border
        @color_pair  ||= get_color($reversecolor, @color, @bgcolor)
        @parent.window.mvchgat(y=@row, x=@col+1, @width, Ncurses::A_REVERSE, @color_pair, nil)
        #@parent.window.mvaddch @row, @col, "*".ord
        #@parent.window.wmove @row, @col # 2011-09-25 V1.3.1  NO EFFECT
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
      c = @col
      ltext = text
      ltext = "* No Items *" if text == :NO_MENUITEMS
      @color_pair  = get_color($reversecolor, @color, @bgcolor)
      #acolor = $reversecolor
      acolor = @color_pair
      acolor = get_color($reversecolor, 'green', @bgcolor) if !@enabled
#      @parent.window.printstring( @row, 0, "|%-*s|" % [@width, ltext], acolor) # changed 2011 2011-09-24  
      @parent.window.printstring( @row, c, "|%-*s|" % [@width, ltext], acolor)
      if @enabled # 2010-09-10 23:56 
      if !@accelerator.nil?
        # FIXME add c earlier 0 was offset
        @parent.window.printstring( r, (@width+1)-@accelerator.length, @accelerator, acolor)
      elsif !@mnemonic.nil?
        m = @mnemonic
        ix = text.index(m) || text.index(m.swapcase)
        charm = text[ix,1]
        #@parent.window.printstring( r, ix+1, charm, $datacolor) if !ix.nil?
        # prev line changed since not working in vt100 and vt200
        @parent.window.printstring( r, ix+1, charm, $reversecolor, 'reverse') if !ix.nil?
      end
      #@parent.window.wmove r, c # NO EFFECT
      end
    end
    def destroy
     $log.debug "DESTROY menuitem #{@text}"
    end
  end
  ## class Menu. Contains menuitems, and can be a menuitem itself.
  # Opens out another list of menuitems.
  class Menu < MenuItem
    attr_accessor :parent
    attr_accessor :row
    attr_accessor :col
    attr_accessor :coffset
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
      @text = text
      @items = []
      @enabled = true
      @current_menu = []
      super text, nil, &block
      @row ||=10
      @col ||=10
      @coffset = 0
      @@menus ||= []
      @active_index = nil # 2011-09-25 V1.3.1 otherwise crashing in select_right
    end
    ## called upon firing so when we next show menubar there are not any left overs in here.
    def clear_menus
      @@menus = []
    end
    def to_s
      @text
    end
    # item could be menuitem or another menu (precreated)
    def add menuitem
      #$log.debug " YYYY inside add menuitem #{menuitem.text} "
      @items << menuitem
      return self
    end
    alias :<< :add

    # add item method which could be used from blocks
    # add 2010-09-10 12:20 simplifying
    def item text, mnem=nil, &block
      #$log.debug "YYYY inside M: menuitem text #{text}  "
      m =  MenuItem.new text, mnem, &block 
      add m
      return m
    end
    # create a menu within a menu
    # add menu method which could be used from blocks
    # add 2010-09-10 12:20 simplifying
    def menu text, &block
      #$log.debug "YYYY inside M: menu text #{text}  "
      m = Menu.new text, &block 
      add m
      return m
    end
    def insert_separator ix
      @items.insert ix, MenuSeparator.new
    end
    def add_separator 
      @items << MenuSeparator.new
    end
    alias :separator :add_separator

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
    # generate an item list at runtime for this menu
    def item_list *args, &block 
      $log.debug ">>>item_list : #{@text} "
      @item_list = block if block_given?
      @item_list_args = args
    end
    # menu - 
    def fire
      $log.debug "menu fire called: #{text}  " 
      if @window.nil?
        #repaint
        # added 2011-09-24 adding ability to generate list of items
        if @item_list
          # generate a list, but we need to know what to do with that list.
          @items = []
          l = @item_list.call self, *@item_list_args if !@item_list.nil?
          if l.nil? || l.size == 0
            item(:NO_MENUITEMS)
          else
            # for each element returned create a menuitem, and attach the command to it.
            l.each { |e| it = item(e); 
              if @command # there should be a command otherwise what's the point
                it.command(@args) do @command.call(it, it.text) end;
              else
                it.command(@args) do alert("No command attached to #{it.text} ") end;
                $log.warn "No command attached to item_list "
              end
            }
          end
          $log.debug "menu got items #{@items.count} " 
        end
        if @items.empty? # user did not specify any items
            item(:NO_MENUITEMS)
        end
        create_window 
        if !@parent.is_a? RubyCurses::MenuBar 
          @parent.current_menu << self
          @@menus << self # NEW
        end
      else
        ### shouod this not just show ?
        $log.debug "menu fire called: #{text} ELSE XXX WHEN IS THIS CALLED ? 658 #{@items[@active_index].text}  " 
        if @active_index # sometimes no menu item specified 2011-09-24 NEWMENU
          return @items[@active_index].fire # this should happen if selected. else selected()
        end
      end
      #@action.call if !@action.nil?
    end
    # user has clicked down, we shoud display items
    # DRAW menuitems
    def repaint # menu.repaint
      # OMG will not print anything if no items !
      # When we do item generation this list will be empty
      #return if @items.nil? or @items.empty? # commented 2011-09-24 NEWMENU
      #$log.debug "menu repaint: #{text} row #{@row} col #{@col}  " 
      @color_pair  = get_color($reversecolor, @color, @bgcolor)
      if !@parent.is_a? RubyCurses::MenuBar 
        @parent.window.printstring( @row, 0, "|%-*s>|" % [@width-1, text], @color_pair)
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
       #$log.debug "insdie select  item :  #{ix0} active: #{@active_index}" 
      if !@active_index.nil?
        @items[@active_index].on_leave 
      end
      previtem = @active_index
      @active_index = ix0
      if @items[ix0].enabled
        @items[ix0].on_enter
      else
        #$log.debug "insdie sele nxt item ENABLED FALSE :  #{ix0}" 
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
       #$log.debug "insdie sele nxt item :  #{@active_index}" 
      @active_index = -1 if @active_index.nil?
      if @active_index < @items.length-1
        select_item @active_index + 1
      else
      #  select_item 0
      end
    end
    def select_prev_item
      return if @items.nil? or @items.empty?
       #$log.debug "insdie sele prv item :  #{@active_index}" 
      if @active_index > 0
        select_item @active_index - 1
      else
      #select_item @items.length-1
      end
    end
    #
    # If multi-column menuitems then try going to a left item (prev column same row)
    # NOTE It should only come here if items are open, otherwise row and col will be blank. 
    # NOTE active_index nil means no items open
    #
    def select_left_item
      return :UNHANDLED if @items.nil? or @items.empty? or @active_index.nil?
      index = nil
      crow = @items[@active_index].row 
      ccol = @items[@active_index].col 
      @items.each_with_index { |e, i| index = i if e.row == crow && e.col < ccol }
      if index
        select_item index
      else
        return :UNHANDLED
      end
    end
    # @since 1.3.1 2011-09-24 
    # If multi-column menuitems then try going to a right item (next column same row)
    # Only if items are open, not from a menubar menu
    def select_right_item
      return :UNHANDLED if @items.nil? or @items.empty? or @active_index.nil?
      crow = @items[@active_index].row 
      ccol = @items[@active_index].col 
      #alert "inside select right with #{@items.size} #{@items[@active_index].text}: items. r #{crow} col #{ccol}  "
      index = nil
      @items.each_with_index { |e, i| 
        $log.debug " select_right #{e.row} == #{crow} , #{e.col} > #{ccol}  " if $log.debug? 
        if e.row == crow && e.col > ccol 
          index = i
          $log.debug "YYY select_right #{e.row} == #{crow} , #{e.col} > #{ccol} FOUND #{i}  " if $log.debug? 
          break
        end
      }
      if index
        select_item index
      else
        return :UNHANDLED
      end
    end
    def on_enter # menu.on_enter
      #$log.debug "menu onenter: #{text} #{@row} #{@col}  " 
      # call parent method. XXX
        #if @parent.is_a? RubyCurses::MenuBar 
          #acolor = get_color($datacolor, @bgcolor, @color)
          #@parent.window.printstring( @row, @col, " %s " % text, acolor)
        #else
          highlight
        #end
        if !@window.nil? #and @parent.selected
          #$log.debug "menu onenter: #{text} calling window,show"
          @window.show
          select_item 0
        elsif @parent.is_a? RubyCurses::MenuBar and  @parent.selected
          # only on the top level do we open a window if a previous one was opened
          #$log.debug "menu onenter: #{text} calling repaint CLASS: #{@parent.class}"
        #  repaint
          create_window
        end
    end
    def on_leave # menu.on_leave
      #$log.debug "menu onleave: #{text} #{@row} #{@col}  " 
      # call parent method. XXX
      @color_pair  ||= get_color($reversecolor, @color, @bgcolor)
        if @parent.is_a? RubyCurses::MenuBar 
#          @parent.window.printstring( @row, @col, " %s " % text, $reversecolor) # changed 2011 2011-09-24   
          @parent.window.printstring( @row, @col, " %s " % text, @color_pair)
          @window.hide if !@window.nil?
        else
          #$log.debug "MENU SUBMEN. menu onleave: #{text} #{@row} #{@col}  " 
          # parent is a menu
          highlight false
          #@parent.current_menu.pop
          #@@menus.pop
          #destroy
        end
    end
    def highlight tf=true # menu
      if @parent.is_a? RubyCurses::MenuBar  # top level menu
        #acolor = get_color($datacolor, @bgcolor, @color)
        #@parent.window.printstring( @row, @col, " %s " % text, acolor)
        @color_pair  ||= get_color($reversecolor, @color, @bgcolor)
          att =  Ncurses::A_REVERSE
          @parent.window.mvchgat(y=@row, x=@col+1, text.length+1, att, @color_pair, nil)
      else
        #$log.debug "MENU SUBMENU menu highlight: #{text} #{@row} #{@col}, PW #{@parent.width}  " 
        acolor = tf ? $datacolor : $reversecolor
        att = tf ? Ncurses::A_REVERSE : Ncurses::A_NORMAL
        #@parent.window.mvchgat(y=@row, x=1, @width, Ncurses::A_NORMAL, color, nil)
        #@parent.window.mvchgat(y=@row, x=1, @parent.width, Ncurses::A_NORMAL, color, nil)
        # above line did not work with vt100/vt200 next does
        #      @parent.window.mvchgat(y=@row, x=1, @parent.width, att, $reversecolor, nil) # changed 2011 2011-09-24   
        @parent.window.mvchgat(y=@row, x=1, @parent.width, att, @color_pair, nil)
        @parent.window.wrefresh
      end
    end
    def create_window  # menu
      margin = 2 # flush against parent
      @width = array_width(@items) + 1 # adding 1 since menus append a ">" 2011-09-24 
      $log.debug "create window menu #{@text}: r #{@row} ,col #{@col}, wd #{@width}   " 
      t = @row+1
      h = @items.length+3
      ww = @width+margin
      ww1 = @width
      max = Ncurses.LINES-1
      if t + h > max
        t = 2 # one below menubar, not touching
        if h > max
          i = ((h*1.0)/max).ceil
          h = max - 1
          ww = ww * i # FIXME we need to calculate
        end
      end # t + 1
      $log.debug "create window menu #{@text}: t  #{t} ,h #{h}, w: #{ww} , col #{@col}   max #{max}   " 

      #@layout = { :height => @items.length+3, :width => ww, :top => @row+1, :left => @col } 
      # earlier col had the offset to start the next level, I was not using it to print 
      # but with mulitple cols i am using it. So, this col will overwrite existing menu.
      @layout = { :height => h-1, :width => ww, :top => t, :left => @coffset } 
      @win = VER::Window.new(@layout)
      @window = @win
      @color_pair ||= get_color($datacolor, @color, @bgcolor)
      @rev_color_pair ||= get_color($reversecolor, @color, @bgcolor)
      @win.bkgd(Ncurses.COLOR_PAIR(@color_pair));
      @panel = @win.panel
        #@window.printstring( 0, 0, "+%s+" % ("-"*@width), $reversecolor)
        @window.printstring( 0, 0, "+%s+" % ("-"*(ww1)), @rev_color_pair)
        saved_r = 1
        r = 1
        #saved_c = @col+@width+margin # margins???
        saved_c = 0 ; # actual program uses 0 in repain for col
        c = saved_c
            $log.debug "create window menu #{@text}: first col  r  #{r} ,c #{c}" 
        @items.each do |item|
          #break if r > h # added 2011-09-24 for large number of items - causes error
          if r >= h-2
            @window.printstring( h-2, c, "+%s+" % ("-"*(ww1)), @rev_color_pair)
            r = saved_r
            c += (@width + 2)
            @window.printstring( 0, c, "+%s+" % ("-"*(ww1)), @rev_color_pair)
            $log.debug "create window menu #{@text}: new col  r  #{r} ,c #{c}, #{item.text} " 
          end
            item.row = r
            item.col = c
            item.coffset = @coffset+@width+margin # margins???


            item.width = @width
            #item.window = @window
            item.parent = self
            item.color = @color; item.bgcolor = @bgcolor
            item.repaint
          r+=1
        end
#        @window.printstring( r, 0, "+%s+" % ("-"*@width), $reversecolor) # changed 2011 2011-09-24 
        @window.printstring( h-2, 0, "+%s+" % ("-"*(ww1)), @rev_color_pair)
        # in case of multiple rows
        @window.printstring( r, c, "+%s+" % ("-"*(ww1)), @rev_color_pair)
        select_item 0
      @window.refresh
      return @window
    end
    # private
    def array_width a
      longest = a.max {|a,b| a.to_s.length <=> b.to_s.length }
      #$log.debug "array width #{longest}"
      longest.to_s.length
    end
    def destroy
      $log.debug "DESTRY menu #{@text}"
      return if @window.nil?
      @visible = false
      panel = @window.panel
      Ncurses::Panel.del_panel(panel.pointer) if !panel.nil?   
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
        #return cmenu.fire # XXX 2010-10-16 21:39 trying out
        if cmenu.is_a? RubyCurses::Menu 
          #alert "is a menu" # this gets triggered even when we are on items
        end
      when KEY_UP
        cmenu.select_prev_item
      when KEY_ENTER, 10, 13, 32 # added 32 2008-11-27 23:50 
        return cmenu.fire
      when KEY_LEFT
        if cmenu.parent.is_a? RubyCurses::Menu 
       #$log.debug "LEFT IN MENU : #{cmenu.parent.class} len: #{cmenu.parent.current_menu.length}"
       #$log.debug "left IN MENU : #{cmenu.parent.class} len: #{cmenu.current_menu.length}"
        end
        ret = cmenu.select_left_item # 2011-09-24 V1.3.1 attempt to goto left item if columns
        if ret == :UNHANDLED
          if cmenu.parent.is_a? RubyCurses::MenuBar #and !cmenu.parent.current_menu.empty?
            #$log.debug " ABOU TO DESTROY DUE TO LEFT"
            cmenu.current_menu.pop
            @@menus.pop ## NEW
            cmenu.destroy
            return :UNHANDLED
          end
          # LEFT on a menu list allows me to close and return to higher level
          if cmenu.parent.is_a? RubyCurses::Menu #and !cmenu.parent.current_menu.empty?
            #$log.debug " ABOU TO DESTROY DUE TO LEFT"
            cmenu.current_menu.pop
            @@menus.pop ## NEW
            cmenu.destroy
            #return :UNHANDLED
          end
        end
      when KEY_RIGHT
       $log.debug "RIGHTIN MENU : #{text}  "
       if cmenu.active_index
        if cmenu.items[cmenu.active_index].is_a?  RubyCurses::Menu 
          #alert "could fire here cmenu: #{cmenu.text}, par: #{cmenu.parent.text} "
          cmenu.fire
          return
       #$log.debug "right IN MENU : #{cmenu.parent.class} len: #{cmenu.parent.current_menu.length}"
       #$log.debug "right IN MENU : #{cmenu.parent.class} len: #{cmenu.current_menu.length}"
        end
       end
       # This introduces a bug if no open items
       ret = cmenu.select_right_item # 2011-09-24 V1.3.1 attempt to goto right item if columns
       #alert "attempting to select right #{ret} "
        if ret == :UNHANDLED
          #if cmenu.parent.is_a? RubyCurses::Menu and !cmenu.parent.current_menu.empty?
          if cmenu.parent.is_a? RubyCurses::MenuBar #and !cmenu.current_menu.empty?
            $log.debug " ABOU TO DESTROY DUE TO RIGHT"
            cmenu.current_menu.pop
            @@menus.pop
            cmenu.destroy
            return :UNHANDLED
          end
        end
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
        if key == item.mnemonic.downcase && item.enabled # 2010-09-11 00:03 enabled
          ret = item.fire
          return ret #0 2009-01-23 00:45 
        end
      end
      return :UNHANDLED
    end
    ## menu 
    def show # menu.show
      #$log.debug "show (menu) : #{@text} "
      if @window.nil?
        create_window #@col+@width
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
    attr_reader :text # temp 2011-09-24 V1.3.1 
    attr_accessor :visible
    attr_accessor :active_index
    attr_accessor :state              # normal, selected, highlighted
    attr_accessor :toggle_key              # key used to popup, should be set prior to attaching to form
    attr_accessor :color, :bgcolor # 2011-09-25 V1.3.1 
    attr_accessor  :_object_created   # 2011-10-7 if visible then Form will call this
    def initialize &block
      @window = nil
      @text = "menubar"
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
    # add a precreated menu
    def add menu
      #$log.debug "YYYY inside MB: add #{menu.text}  "
      @items << menu
      return self
    end
    alias :<< :add

    # add a menu through the block, this would happen through instance eval
    # 2010-09-10 12:07 added while simplifying the interface
    # this calls add so you get the MB back, not a ref to the menu created NOTE
    def menu text, &block
      #$log.debug "YYYY inside MB: menu text #{text} "
      m = Menu.new text, &block 
      m.color = @color
      m.bgcolor = @bgcolor
      add m
      return m
    end
    def next_menu
      #$log.debug "next meu: #{@active_index}  " 
      if @active_index < @items.length-1
        set_menu @active_index + 1
      else
        set_menu 0
      end
    end
    def prev_menu
      #$log.debug "prev meu: #{@active_index} " 
      if @active_index > 0
        set_menu @active_index-1
      else
        set_menu @items.length-1
      end
    end
    def set_menu index
      #$log.debug "set meu: #{@active_index} #{index}" 
      menu = @items[@active_index]
      menu.on_leave # hide its window, if open
      @active_index = index
      menu = @items[@active_index]
      menu.on_enter #display window, if previous was displayed
      @window.wmove menu.row, menu.col
#     menu.show
#     menu.window.wrefresh # XXX we need this
    end

    def keep_visible flag=nil
      return @keep_visible unless flag
      @keep_visible = flag
      @visible = flag
      self
    end
    # menubar LEFT, RIGHT, DOWN 
    def handle_keys
      @selected = false
      @toggle_key ||= 27 # default switch off with ESC, if nothing else defined
      set_menu 0
      begin
      catch(:menubarclose) do
      while((ch = @window.getchar()) != @toggle_key )
       #$log.debug "menuubar inside handle_keys :  #{ch}"  if ch != -1
        case ch
        when -1
          next
        when KEY_DOWN
          #$log.debug "insdie keyDOWN :  #{ch}" 
          if !@selected
            current_menu.fire
          else
            current_menu.handle_key ch
          end
            
          @selected = true
        when KEY_ENTER, 10, 13, 32
          @selected = true
            #$log.debug " mb insdie ENTER :  #{current_menu}" 
            ret = current_menu.handle_key ch
            #$log.debug "ret = #{ret}  mb insdie ENTER :  #{current_menu}" 
            #break; ## 2008-12-29 18:00  This will close after firing
            #anything
            break if ret == :CLOSE
        when KEY_UP
          #$log.debug " mb insdie keyUPP :  #{ch}" 
          current_menu.handle_key ch
        when KEY_LEFT
          #$log.debug " mb insdie KEYLEFT :  #{ch}" 
          ret = current_menu.handle_key ch
          prev_menu if ret == :UNHANDLED
          #display_items if @selected
        when KEY_RIGHT
          #$log.debug " mb insdie KEYRIGHT :  #{ch}" 
          ret = current_menu.handle_key ch
          next_menu if ret == :UNHANDLED
        when ?\C-g.getbyte(0) # abort
          throw :menubarclose
        else
          #$log.debug " mb insdie ELSE :  #{ch}" 
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
    # called by set_menu_bar in widget.rb (class Form).
    def toggle
      # added keeping it visible, 2011-10-7 being tested in dbdemo
      if @keep_visible
        init_vars
        show
        @items[0].highlight
        @window.ungetch(KEY_DOWN)
        return
      end
      #@items.each { |i| $log.debug " ITEM DDD : #{i.text}" }
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
      @window.hide if !@window.nil? # seems to cause auto-firing when we resume toggle 2011-09-26 
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
    # TODO: check for menu to be flush right (only for last one).
    def repaint
      return if !@visible
      @color_pair = get_color($reversecolor, @color, @bgcolor)
      @window ||= create_window_menubar
#      @window.printstring( 0, 0, "%-*s" % [@cols," "], $reversecolor) # changed 2011 2011-09-24   
      @window.printstring( 0, 0, "%-*s" % [@cols," "], @color_pair)
      c = 1; r = 0;
      @items.each do |item|
        item.row = r; item.col = c; item.coffset = c; item.parent = self
        item.color = @color
        item.bgcolor = @bgcolor
        @window.printstring( r, c, " %s " % item.text, @color_pair)
        # 2011-09-26 V1.3.1 quick dirty highlighting of first menu on menubar
        # on opening since calling highlight was giving bug in parent.width
        #if c == 1
          #att =  Ncurses::A_REVERSE
          #@window.mvchgat(y=r, x=c+1, item.text.length+1, att, @color_pair, nil)
        #end
        c += (item.text.length + 2)
      end
      #@items[0].on_enter # 2011-09-25 V1.3.1  caused issues when toggling, first item fired on DOWN
      @items[0].highlight unless @keep_visible # 2011-09-26 V1.3.1   fixed to take both cases into account
      @window.wrefresh
    end
    def create_window_menubar
      @layout = { :height => 1, :width => 0, :top => 0, :left => 0 } 
      @win = VER::Window.new(@layout)
      @window = @win
      @win.bkgd(Ncurses.COLOR_PAIR(5)); # <---- FIXME
      @panel = @win.panel
      return @window
    end
    def destroy
      $log.debug "DESTRY menubar "
      @items.each do |item|
        item.destroy
      end
      return if @keep_visible
      @visible = false
      panel = @window.panel
      Ncurses::Panel.del_panel(panel.pointer) if !panel.nil?   
      @window.delwin if !@window.nil?
      @window = nil
    end
  end # menubar

  class CheckBoxMenuItem < MenuItem
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
    def repaint # checkbox
      # FIXME need @color_pair here
        @color_pair  ||= get_color($reversecolor, @color, @bgcolor)
      @parent.window.printstring( row, 0, getvalue_for_paint, @color_pair)
      parent.window.wrefresh
    end
    def method_missing(sym, *args)
      if checkbox.respond_to? sym
        #$log.debug("calling CHECKBOXMENU #{sym} called #{args[0]}")
        checkbox.send(sym, args)
      else
        $log.error("ERROR CHECKBOXMENU #{sym} called")
      end
    end
  end # class

end # modul
