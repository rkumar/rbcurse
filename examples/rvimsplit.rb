# this is a test program, 
# testing out if subwins can help in splitpanes
# derwins, although easy to use flunk movement and resizing
# So i've changed Window to use subwins, so top and left are maintained
# We need to create events for resizing so refreshing window can be done.
#
# FIXME - resizing, divider change
# FIXME - left top 2 splits are not expanding to full height. check in draw box mode
# TODO = when resixing a split, if the other one has been split, its children need to be resized.
#
#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'

class Split
  def initialize type, first, second, win
    @c1 = first
    @c2 = second
    @type = type # :VERTICAL or :HORIZONTAL
    @parent = win # needed to draw divider on
  end
  def first_win; @c1; end
  def second_win; @c2; end
  def divider_location y,x
    @y = y
    @x = x
  end

  # change the size of a split
  # still to redo the line etc.
  def increase comp, units=1
    $log.debug " increase got #{comp}, #{comp.class}, #{units}   "
    if @type == :HORIZONTAL
      if comp == @c1
      else
        comp = @c1
        units *= -1
      end
      other = @c2
      #comp.wclear
      #other.wclear
      #comp.wrefresh
      #other.wrefresh
      # increase h
      layout = comp.layout
      $log.debug " layout #{layout} "
      h = layout[:height]
      w = layout[:width]
      top = layout[:top]
      left = layout[:left]
      $log.debug "H1 ht change #{h} , #{h} + #{units} "
      layout[:height]= h + units
      divloc = h + units + 1
      comp.resize_with(layout)
      # decrease second, and push inc top
      layout = other.layout
      h = layout[:height]
      w = layout[:width]
      top = layout[:top]
      left = layout[:left]
      h = layout[:height]
      top = layout[:top]
      layout[:top] = top + units
      layout[:height] = h- units
      $log.debug "H1 c2 ht change #{h} , #{h} - #{units}, top #{top} + #{units}  "
      other.resize_with(layout)
      h = @parent.height
      w = @parent.width
      #@parent.mvwhline( divloc, 0, ACS_HLINE, w+2)
      @y += units
      #@parent.werase #wclear
      @parent.wclear
      # FIXME double line printing ??? after tabbing or hitting a key
      @parent.mvwhline( @y, 0, ACS_HLINE, w)
      comp.wrefresh
      other.wrefresh
      @parent.wrefresh
      # do wnoutrefresh and doupdate
      return
    end
    if @type == :VERTICAL
      if comp == @c1
      else
        units *= -1
        comp = @c1
      end
      other = @c2
      # increase w
      layout = comp.layout
      h = layout[:width]
      layout[:width]= h + units
      $log.debug "V1 ht change #{h} , #{h} + #{units} "
      comp.resize_with(layout)
      # decrease second, and push inc top
      layout = other.layout
      h = layout[:width]
      top = layout[:left]
      layout[:left] = top + units
      layout[:width] = h - units
      $log.debug "V c2 ht change #{h} , #{h} - #{units}, top #{top} + #{units}  "
      other.resize_with(layout)
      # TODO add line here
      comp.wclear
      other.wclear
      return
    end

  end
end
class VimSplit
  def initialize window, lay
    # array of window, to delete later
    @wins = []
    # mapping of a subwin and its Split, so i can resize
    @splits = {}

    # hash of windows and component attached
    @win_comp = {}
    @children = {} # parent and children array, since we have not designed this properly
    # only those windows that can be focused, child windows when split, parent is invisible
    @focusables = []
    # main window
    @window = window
    @splouter = @window._subwin(lay)
  #  (0..@splouter.height).each {|i| @splouter.highlight_line($reversecolor,i,0,@splouter.width)}
    @wins << @splouter
    #@focusables << @splouter
    @splouter.box(0,0)
    @draw_boxes = false

    @str = "" # dummy
  end
  def self.color_window win, color=$datacolor
    (0..win.height).each {|i| win.highlight_line(color,i,0,win.width)}
  end
  # focussed component
  def current
    @current || _switch_split
  end
  # when we make the first split we want to keep the borders. AFter that we always want to start with zero
  # so the window we split is "consumed".
  def get_offset
    if @wins.length == 1
      return 1
    end
    0
  end
  def get_win; @splouter; end 

  # splits horizontally at centre
  # We need to give an initial weight or location for divider
  def split_h win
    h = win.height
    w = win.width
    off = get_offset()
    #lay1 = { :height => h/2-0, :width => w-2, :top => 0, :left => off }
    #lay2 = { :height => h/2-1, :width => w-2, :top => h/2+1, :left => 1 }
    lay1 = { :height => h/2-0, :width => w-2, :top => off, :left => off }
    lay2 = { :height => h/2-1, :width => w-2, :top => h/2+1, :left => off }
    split1 = win._subwin(lay1)
    split2 = win._subwin(lay2)
    win.mvwhline( h/2, 0, ACS_HLINE, w+2)

    if @draw_boxes
      split1.box(0,0)
      split2.box(0,0)
    end
    # if a window is split, then tab doesn't go there, it goes to its two subwins
    @focusables.delete win
    @wins << split1
    @wins << split2
    @focusables << split1 << split2
    spl = Split.new :HORIZONTAL, split1, split2, win
    spl.divider_location(h/2,0)
    @splits[split1] = spl
    @splits[split2] = spl
    @children[win] = [ split1, split2 ]
    #return split1, split2
    return spl
  end
  def split_v win
    h = win.height
    w = win.width
    off = get_offset()
    lay1 = { :height => h-2, :width => w/2-1, :top => off, :left => off }
    lay2 = { :height => h-2, :width => w/2-1, :top => off, :left => w/2+1 }
    split1 = win._subwin(lay1)
    split2 = win._subwin(lay2)
    win.mvwvline( 0, w/2, ACS_VLINE, h+2)
    if @draw_boxes
      split1.box(0,0)
      split2.box(0,0)
    end
    @focusables.delete win
    @wins << split1
    @wins << split2
    @focusables << split1 << split2
    spl = Split.new :VERTICAL, split1, split2, win
    spl.divider_location(0,h/2)
    @splits[split1] = spl
    @splits[split2] = spl
    @children[win] = [ split1, split2 ]
    #return split1, split2
    return spl
  end
  def set_focus_on split
    raise "Given split not focusable" if @focusables.index.nil?
    # actually we can take it's split and keep going down till first. But we don;t have a tree
    @current = split
  end

  def destroy
    @wins.each {|w| w.destroy}
    super
  end
  ## attach a component to a window/split, so that all keys to that win go to the window
  # create the comp without a form.
  def attach win, comp
    # i need to set the window to win.
    comp.override_graphic(win) # i think XXX
    @win_comp[win] = comp
  end
  def _switch_split
    index = @focusables.index @current
    index ||= 0
    index+=1
    if index >= @focusables.length
      index = 0
    end
    @current = @focusables.at index
    @current.wmove 0,0
    @current.wrefresh
    @current
  end
  def handle_key ch
    case ch
    when 9
      _switch_split
      return 0
    #when 32..126
      #char = ch.chr
      #@str << char
      #@current.printstring 0,0, @str, 0
      #@current.wrefresh
    #when 330, 127
      #@str = @str[0..-2]
      ##@current.wclear # casuses a flash
      #@current.printstring 0,0, @str, 0
      #@current.wrefresh
    #when 10,13
      #@str << "\n"
    when ?\M-v.getbyte(0)
      # allow user to split but this does not give the user programmatic control over the splits ??
      # unless we call some events
      split_v @current
      @current.wrefresh
      set_focus_on @focusables.last
      @window.wrefresh
    when ?\M-h.getbyte(0)
      split_h @current
      @current.wrefresh
      set_focus_on @focusables.last
      @window.wrefresh
    when ?\M-+.getbyte(0)
      spl = @splits[@current]
      spl.increase(@current)
    when ?\M--.getbyte(0)
      spl = @splits[@current]
      spl.increase(@current,-1)
    else
      comp = @win_comp[@current]
      ret = :UNHANDLED
      ret = comp.handle_key(ch) unless comp.nil?
      return ret
    end
    ret = :UNHANDLED
  end

end
class TestSubwin
  def initialize
    acolor = $reversecolor
  end
  def run
    @window = VER::Window.root_window 

    h = 20; w = 75; t = 3; l = 4
    @layoutouter = { :height => h, :width => w, :top => t, :left => l }

    @vim = VimSplit.new @window,  @layoutouter
    @splouter = @vim.get_win
    spl = @vim.split_v @splouter
    @splleft = spl.first_win
    @splright = spl.second_win
    spl = @vim.split_h @splleft
    @splleft1 = spl.first_win
    @splleft2 = spl.second_win
    @vim.split_h @splright
    @vim.split_v @splleft1

    @window.printstring(1,10,"Ncurses Subwindow test - splitpanes emulation using subwin",0)
    @splouter.printstring(0,2, " Outer ", 0)
    @splleft.printstring(0,2, "-Left ", 0)
    @splleft1.printstring(0,1, "Top ", 0)
    @splleft2.printstring(0,1, "Bottom ", 0)
    #@vim.set_focus_on @splleft1

        @window.printstring(2,10,"q to quit",2)
        #
    @form = Form.new @window
      @help = "q to quit. "
            RubyCurses::Label.new @form, {'text' => @help, "row" => 1, "col" => 2, "color" => "yellow"}
      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      ctr = 0
      row = 2
      str = "Hello"
      buffers = {}
      while((ch = @window.getchar()) != KEY_F1 )
        ret = @vim.handle_key ch
        if ret == :UNHANDLED
          curr = @vim.current
          buff = buffers[curr]
          if buff.nil?
            buff ||= ""
            buffers[curr] = buff
          end
          case ch
          when 32..126
            char = ch.chr
            buff << char
            curr.printstring 0,0, buff, 0
            curr.wrefresh
          when 330, 127
            buff = buff[0..-2]
            buffers[curr] = buff
            #@current.wclear # casuses a flash
            curr.printstring 0,0, buff, 0
            curr.clrtobot
            curr.wrefresh
          when 10,13
            buff << "\n"
            curr.printstring 0,0, buff, 0
            curr.wrefresh
          end

        end
      end

      @window.destroy

  end
end
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils
  # Initialize curses
  begin
    # XXX update with new color and kb
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG
    n = TestSubwin.new
    n.run
  rescue => ex
  ensure
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
