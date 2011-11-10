require 'ver/window'

# This contains pad and subwin.
#
# 1. IMHO, subwins and derwins are not very stable. Avoid using them. I've tinkered
#    with them quite a bit and given them up. 
# 2. Pads are quite okay, I tried something too complex, and copywin often can give
#    errors, or seg faults. So i've steered away from the Pad class. I may try a simpler
#    less clever pad approach to textview sometime again.

module VER
##
# Pad
# This is EXPERIMENTAL
# A pad cannot be used interchangeable since some application functions such as wrefresh
# are illegal. Cannot expect the application to take care.
# Internally we can make it easier. Mostly a pad is used to map to one portion of the screen.
# So we allow that to be defined once. Then only start row and col of pad change.
# Maybe we should check pad coordinates so no errors
# Also check screen coordinates (if we know)
# We need padheight and padwidth only to ensure we don't keep recreating.
# Howevre, when comp's height increases, then decreases, pad height remains larger
# but we keep printing an extra row in copywin. so Pad needs to maintain comp height
# and padheight.
# @since 0.1.3
# NOTE used only by TabbedPane. If we rewrite without using it in 1.3.1 then scrap.
# 2011-11-8 Now the new simpler TabbedPane does not use pads. 
# The aim o this class was to act as a replacement for window, making it seamless
# to use a pad instead
class Pad  < VER::Window
  # top and left correspond to screen's top and left wich will mostly be fixed
  attr_accessor :top, :left
  # start row and col correspond to pad's top and left which will change if scrolling
  attr_accessor :pminrow, :pmincol
  # screen's height and width, now it reflects components height and width
  attr_accessor :sheight, :swidth
  attr_reader :otherwin
  # dimensions the pad was created with, used so we don't keep recreating pad, only if increase.
  attr_reader :padheight, :padwidth
  #attr_accessor :name  # more for debugging log files. 2010-02-02 19:58 
  def initialize(height, width)
    @visible = true
    # do we set height and width ?? XXX
    @window = Ncurses.newpad(height, width)
    @padheight = height
    @padwidth = width
    @height = height
    @width = width
    @sheight = height
    @swidth = width
    init_vars
  end
  def init_vars
    super
    @top ||= 0; @left ||= 0
    @pmincol ||= 0 # pad will print from this col
    @pminrow ||= 0 # pad will print from this row
    @window_type = :PAD
    @name ||="#{self}"
    $log.debug "        PAD constructor #{self} , #{@window} "
  end
  #
  # @param layout is a hash (@see Window.initialize)
  def self.create_with_layout(layout)
    @window = Pad.new(layout[:height], layout[:width])
    @window.reset_layout(layout)
    return @window
  end
  ##
  # increases the pad size, since the widget may have been resized
  # checks that one of ht or width has been increased
  # destroys earlier pad and returns new one
  # Updates sheight and swidth even if reduced so copywin works fine.
  # @param [Fixnum] height to resize to
  # @param [Fixnum] width to resize to
  # @return [Pad]
  #  2009-10-29 23:18 
  def resize(ht = 0, w = 0)
    # update sheight and swidth even if reduced, so that pad doesn't overwrite.
    @sheight = ht if ht > 0
    @swidth = w if w > 0
    return if ht < @padheight and w < @padwidth
    @padheight = ht if ht > @padheight
    @padwidth = w if w > @padwidth
    destroy
    $log.debug " L502 resize, creating newpad with #{@padheight} and #{@padwidth} "
    @window = Ncurses.newpad(@padheight, @padwidth)
    $log.debug " L502 resize created #{@window} "
    return @window
  end
  ## used if pad and window are same size only
  # creates a similar sized window
  # assumes window is backed by this pad
  # @param object of Window class
  def self.create_for_window(win)
    # get coordinates for win
    @otherwin = win
    smaxx = win.getmaxx()
    smaxy = win.getmaxy()
    top = win.getminx()
    left = win.getminy()
    sheight = win.height
    swidth = win.width
    # make pad based on size of window
    window = Pad.create_with_layout(layout = { :height => sheight, :width => swidth, :top => top, :left => sleft })
    window.sheight = sheight
    window.swidth = swidth
    return window

  end
  # top and left correspond to screen's top and left wich will mostly be fixed.
  # In cases where the component may float around, as in Splitpanes second component
  # this would be set using component's row and col.
  def set_screen_row_col top, left=-1
    @top = top
    @left = left unless left < 0
  end
  alias :set_screen_pad_left :set_screen_row_col

  ## added user setting screens max row and col (e.g splitpanes first component)
  def set_screen_max_row_col mr, mc
    $log.debug "#{@name} set_screen_max_row_col #{mr},#{mc}. earlier #{@screen_maxrow}, #{@screen_maxcol}  "
    # added || check on 2010-01-09 18:39 since crashing if mr > sh + top ..
    # I removed the check, since it results in a blank area on screen since the 
    # widget has not expanded itself. Without the check it will  crash on copywin so you
    # should increase widget size or disallow  calling this in this situation.
    if mr > (@sheight + @top -1 -@pminrow)
      $log.warn " ->>> ** set_screen_max_row_col #{mr} > #{@sheight} + #{@top} -1 - #{@pminrow} ** "
      $log.warn " ->>> can result in error in copy_win or in some rows not displaying"
      return # some situations actually require this ...
    end unless mr.nil?
    @screen_maxrow = mr unless mr.nil? # || mr > (@sheight + @top -1 -@pminrow)
    @screen_maxcol = mc unless mc.nil?
  end
  # start row and col correspond to pad's top and left which will change if scrolling
  # However, if we use this as a backing store for subwindows it could remain the same
  def set_pad_top_left top, left=-1
    $log.debug "#{@name} inside set_pad_top_left to #{top} #{left} earlier #{@pminrow}, #{@pmincol}"
    @pminrow = top unless top < 0
    @pmincol = left unless left < 0
  end
  # return screen max row which will be used for writing to window
  # XXX what if user sets/overrides sheight
  def smaxrow
    #$log.debug "    ... niside smaxrow #{@sheight} + #{@top} -1 "
    #@sheight + @top -1 
    $log.debug "smr: #{@screen_maxrow}   ... niside smaxrow #{@sheight} + #{@top} -1 - #{@pminrow}"
    @screen_maxrow || @sheight + @top -1 -@pminrow
  end
  ##
  # return screen max col which will be used for writing to window
  def smaxcol
    #$log.debug "    ... niside smaxcol #{@swidth} + #{@left} -1 "
    #@swidth + @left -1
    #      $log.debug "    ... niside smaxcol #{@swidth} + #{@left} -1 - #{@pmincol} "
    @screen_maxcol || @swidth + @left -1 - @pmincol
  end
  ##
  # specify the window or subwin that the pad is writing to
  # 2010-02-20 22:45 - actually since there are pad methods smaxrow used on otherwin
  # therefor it can only be a Pad !! NOTE
  def set_backing_window win
    @otherwin = win
    # XX should we  extract the coordinates and use for printing ??
    # or for setting maxrow and maxcol
  end
  # trying to make things as easy as possible
  # returns -1 if error in prefresh
  def wrefresh
    $log.debug " inside pad's wrefresh #{@window}. minr,minc,top,left,smaxr,c: #{@pminrow}, #{@pmincol}, #{@top} #{@left} #{smaxrow()} #{smaxcol()} self: #{self.name} "

    # caution, prefresh uses maxrow and maxcol not height and width
    # so we have to add top and less one since we are zero based
    ret = @window.prefresh(@pminrow, @pmincol, @top, @left, smaxrow(), smaxcol())
    $log.warn " WREFRESH returns -1 ERROR - width or height must be exceeding " if ret == -1
    @modified = false
    return ret
  end
  ##
  # copy the window to the pad (assumes we are writing onto win and keeping
  # pad as backup
  # also assuming only one win so, window not passed as param
  # @return return value of copywin which should be 0 (-1 is ERR)
  def copy_pad_to_win
    $log.warn " DEPRECATED copy_pad_to_win" # CLEANUP
    raise "DEPREC copy_pad_to_win deprecated. Will be removed. Let me know if it is needed"
    # check that we don't exceed other windows height/maxrow
    smr = smaxrow()
    # SHIT, this means the otherwin has to be a Pad, cannot be a window
    osw = @otherwin.width
    osh = @otherwin.height
    osh = @height if osh == 0 # root window has 0
    osw = @width if osw == 0 # root window has 0
    osmr = @otherwin.smaxrow() rescue osh # TRYING for windows
    osmc = @otherwin.smaxcol() rescue osw
    if smr >= osmr
      $log.debug " adjusted smr from #{smr} to #{osmr} -1 causing issues in viewfooter"
      smr = osmr-1 # XXX causing issues in viewport, wont print footer with this
    end
    if smr > @sheight + @top -1 -@pminrow # 2010-01-17 13:27 
      smr = @sheight + @top -1 -@pminrow 
      $log.debug " adjusted smr to #{smr} to prevent crash "
    end
    smc = smaxcol()
    $log.debug " SMC original = #{smc} "
    if smc >= osmc
      smc = osmc-1
      smc = @width # XXX ??? THIS WAS WORKING< but throwing error in viewport case
      smc = [osmc-1, @width].min # yet another hack
      $log.debug " SMC o-1 #{osmc-1} wdth #{@width}, smc #{smc}  "
    end
    ### XXX commented out since it doesn't let a comp print fully if widget expanded (splitpane)
    #smc = osw -1 if smc >= osw; # added 2009-11-02 17:01 for tabbedpanes

    # dang, this is coming up a lot. 2010-01-16 20:34 
    # the second scrollpane was one row too large in testsplit3a.rb
    if smr - @top > @padheight
      $log.debug " fixing smr to padheight  2010-01-16 20:35 HOPE THIS DOESNT BREAK ANYTHING"
      smr = @padheight
    end
    @pminrow = 0 if @pminrow < 0
    @pmincol = 0 if @pmincol < 0
    $log.debug " COPYING #{self.name} to #{@otherwin.name} "
    $log.debug " calling copy pad #{@pminrow} #{@pmincol}, #{@top} #{@left}, #{smr} #{smc} self #{self.name} "
    $log.debug "  calling copy pad H: #{@height} W: #{@width}, PH #{@padheight} PW #{@padwidth} WIN:#{@window} "
    #      $log.debug "  -otherwin target copy pad #{@otherwin.pminrow} #{@otherwin.pmincol}, #{@otherwin.top} #{@otherwin.left}, #{osmr} #{osmc} OTHERWIN:#{@otherwin.name} "
    ret="-"
    #if ret == -1
    #x XXX        $log.debug "  #{ret} otherwin copy pad #{@otherwin.pminrow} #{@otherwin.pmincol}, #{@otherwin.top} #{@otherwin.left}, #{osmr} #{osmc} "
    $log.debug "  #{ret} otherwin copy pad H: #{osh} W: #{osw}"
    if @top >= osh
      $log.debug "  #{ret} ERROR top exceeds other ht #{@top}   H: #{osh} "
    end
    if @left >= osw
      $log.debug "  #{ret} ERROR left exceeds other wt #{@left}   W: #{osw} "
    end
    if smr >= osh
      $log.debug "  #{ret} ERROR smrow exceeds other ht #{smr}   H: #{osh} "
      smr = osh() -1 # testing 2010-01-31 21:47  , again 2010-02-05 20:22 
    end
    if smc >= osw
      $log.debug "  #{ret} ERROR smcol exceeds other wt #{smc}   W: #{osw} "
    end
    if smc - @left > @padwidth
      $log.debug "  #{ret} ERROR smcol - left  exceeds padwidth   #{smc}- #{@left}   PW: #{@padwidth} "
    end
    if smr - @top > @padheight
      $log.debug "  #{ret} ERROR smr  - top  exceeds padheight   #{smr}- #{@top}   PH: #{@padheight} "
    end
    ret = @window.copywin(@otherwin.get_window,@pminrow,@pmincol, @top, @left, smr, smc, 0)
    $log.debug " copywin ret #{ret} "
    # 2010-01-11 19:42 one more cause of -1 coming is that padheight (actual height which never
    # changes unless pad increases) or padwidth is smaller than area being printed. Solution: increase 
    # buffer by increasing widgets w or h. smc - left should not exceed padwidth. smr-top should not
    # exceed padheight
    #end
    @modified = false
    return ret
  end
  # @deprecated
  def copy_win_to_pad
    $log.warn " DEPRECATED copy_win_to_pad" # CLEANUP 2011-09-29 
    raise "DEPREC copy_win_to_pad deprecated. Will be removed. Let me know if it is needed"
    smr = smaxrow()
    if smr >= @window.smaxrow()
      smr = @window.smaxrow()-1
    end
    $log.debug " copy_win_to_pad #{@otherwin.name}, #{@window.name}, pminr:#{@pminrow} pminc:#{@pmincol} top:#{@top} left:#{@left} smr:#{smr} "
    ret = @otherwin.copywin(@window.get_window,@pminrow,@pmincol, @top, @left, smr, smaxcol(), 1)
    @modified = false
    return ret
  end
  ## 
  #Used to overwrite the pad onto the screen window
  # A window should have been specified as window to back (@see set_backing_window) or (@see create_with_window)
  def overwrite_window
    return @window.overwrite(@otherwin.get_window)
  end

  ## 
  #  convenience method so that pad can use printstring but remove screen's row and col
  #  The absolute row and col will be taken into consideration when printing on screen.
  #  
  # @param [Fixnum] row row to print on
  # @param [Fixnum] col column to print on
  # @param [String] value to print
  # @param [Fixnum] color - color combination
  # @param [Fixnum, nil] attrib defaults to NORMAL

  # Pls remove the raise once the program is working, extra line can slow things down
  # Keep it on when testing.
  # If the raise is thrown, it means your object could be positioned higher than it should be,
  # or at some point you have increased top, without increasing the objects row.
  def printstring(row,col,value,color,attrib=Ncurses::A_NORMAL)
    #$log.debug " pad printstring #{row} - #{@top} , #{col} - #{@left} "
    raise "printstring row < top, pls correct code #{row} #{@top}, #{col} #{@left} " if row < @top or col < @left
    #$log.warn "printstring row < top, pls correct code #{row} #{@top} " if row < @top
    super(row - @top, col - @left, value, color, attrib)
  end # printstring
  #  convenience method so that pad can use print_border but remove screen's row and col
  #  Please note that this requires that buffer have latest top and left.
  def print_border row, col, height, width, color, att=Ncurses::A_NORMAL
    $log.debug " pad printborder #{row} - #{@top} , #{col} - #{@left}, #{height} , #{width}  "
    raise "print_border: row < top, pls correct code #{row} #{@top},  #{col} #{@left} " if row < @top or col < @left
    #$log.warn   "print_border: row < top, pls correct code #{row} #{@top} " if row < @top
    super(row - @top, col - @left, height, width,  color, att)
  end
  def print_border_only row, col, height, width, color, att=Ncurses::A_NORMAL
    $log.debug " pad printborder_only #{row} - #{@top} , #{col} - #{@left}, #{height} , #{width}  "
    raise "print_border row < top, pls correct code #{row} #{@top},  #{col} #{@left} " if row < @top or col < @left
    super(row - @top, col - @left, height, width,  color, att)
  end
  # use in place of mvwhline if your widget could be using a pad or window
  def rb_mvwhline row, col, char, width
    super(row-@top, col-@left, char, width)
  end
  # use in place of mvwvline if your widget could be using a pad or window
  def rb_mvwvline row, col, char, width
    super(row-@top, col-@left, char, width)
  end
  # use in place of mvaddch if your widget could be using a pad or window
  def rb_mvaddch row, col, char
    super(row-@top, col-@left, char)
  end
end # class Pad
#-------------------------------- deprecated stuff ------------------ #
##
# added RK 2009-10-08 23:57 for tabbedpanes
# THIS IS EXPERIMENTAL - 
# I have not called super in the initializer so any methods you try on subwin
# that exist in the superclass which use @window will bomb
# @since 0.1.3 REMOVE UNUSED.
# @deprecated
class SubWindow  < VER::Window
  attr_reader :width, :height, :top, :left
  attr_accessor :layout
  attr_reader   :panel   # XXX reader requires so he can del it in end
  attr_reader   :subwin   # 
  attr_reader   :parent   # 

  def initialize(parent, layout)
    @visible = true
    reset_layout(layout)

    @parent = parent
    #@subwin = @parent.get_window().derwin(@height, @width, @top, @left)
    @subwin = @parent.get_window().subwin(@height, @width, @top, @left)
    $log.debug "SUBWIN init #{@height} #{@width} #{@top} #{@left} "
    #$log.debug "SUBWIN init #{@subwin.getbegx} #{@subwin.getbegy} #{@top} #{@left} "
    @panel = Ncurses::Panel.new_panel(@subwin)

    @window = @subwin # makes more mthods available
    init_vars

  end
  # no need really now 
  def reset_layout layout
    @layout = layout # 2010-02-13 22:23 
    @height = layout[:height]
    @width = layout[:width]
    @top = layout[:top]
    @left = layout[:left]
  end
  def _destroy
    # typically the ensure block should have this
    # or should window do it for all subwins, or would we want to wait that long ?
    $log.debug "subwin destroy"

    Ncurses::Panel.del_panel(panel.pointer) if !panel.nil?    # FFI
    #@window.delwin(@window) if !@window.nil? # added FFI 2011-09-7 
    delwin if !@window.nil? # added FFI 2011-09-7 
  end
end

end
