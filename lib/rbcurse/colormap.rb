require 'rubygems'
require 'ver/ncurses'
module ColorMap
  ## private
  # returns a color constant for a human color string
  def ColorMap.get_color_const colorstring
    Ncurses.const_get "COLOR_#{colorstring.upcase}"
  end
  ## private
  # creates a new color pair, puts in color map and returns color_pair
  # number
  def ColorMap.install_color fgc, bgc
#      $log.debug " install_color found #{fgc} #{@bgc} "
      @color_id += 1
    fg = ColorMap.get_color_const fgc
    bg = ColorMap.get_color_const bgc
    Ncurses.init_pair(@color_id, fg, bg);
    $color_map[[fgc, bgc]] = @color_id
    return @color_id
  end
  ## public
  # returns a color_pair for a given foreground and background color
  def ColorMap.get_color fgc, bgc=$def_bg_color
    if $color_map.include? [fgc, bgc]
#      $log.debug " get_color found #{fgc} #{@bgc} "
      return $color_map[[fgc, bgc]]
    else
#      $log.debug " get_color NOT found #{fgc} #{@bgc} "
      return ColorMap.install_color fgc, bgc
    end
  end
  def ColorMap.colors
    @@colors
  end

  ## public
  # setup color map at start of application
  def ColorMap.setup
    @color_id = 0
    $color_map = {}
    Ncurses.start_color();
    # Initialize few color pairs 
    $def_fg_color = "white"   # pls set these 2 for your application
    $def_bg_color = "black"
    #COLORS = [COLOR_BLACK, COLOR_RED, COLOR_GREEN, COLOR_YELLOW, COLOR_BLUE, 
    #     COLOR_MAGENTA, COLOR_CYAN, COLOR_WHITE]
    @@colors = %w[black red green yellow blue magenta cyan white]

    # make foreground colors
    bg = ColorMap.get_color_const $def_bg_color
    @@colors[0...@@colors.size].each_with_index do |color, i|
      next if color == $def_bg_color
      ColorMap.install_color color, $def_bg_color
    end
    $reversecolor = ColorMap.get_color $def_bg_color, $def_fg_color
    $popupcolor = ColorMap.get_color 'cyan', $def_fg_color

    $errorcolor = ColorMap.get_color 'white', 'red'
    $promptcolor = $selectedcolor = ColorMap.get_color('yellow', 'red')
    $normalcolor = $datacolor = ColorMap.get_color('white', 'black')
    $bottomcolor = $topcolor = ColorMap.get_color('white', 'blue')

#    $log.debug " colormap SETUP: #{$datacolor} #{$reversecolor} "
  end

end # modul
if $0 == __FILE__
require 'logger'
require 'lib/ver/window'
include Ncurses
include ColorMap
  # Initialize curses
  begin
    VER::start_ncurses
    @window = VER::Window.root_window
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG
    ColorMap.setup

    # Create the window to be associated with the form 
    # Un post form and free the memory

    catch(:close) do
#      $log.debug "START  ---------"
      # need to pass a form, not window.
      r = 1; c = 2; i=0
      attr = Ncurses::A_NORMAL
      @window.printstring  20, c, "press 0-9 to change BG color,  F1/q to quit. r-everse, n-ormal,b-old ", ColorMap.get_color('white')

      

      while((ch = @window.getchar()) != KEY_F1 )
        next if ch == -1
        break if ch == ?q.getbyte(0)
        case ch
        when ?r.getbyte(0)
          attr |= Ncurses::A_REVERSE
        when ?b.getbyte(0)
          attr |= Ncurses::A_BOLD
        when ?n.getbyte(0)
          attr = Ncurses::A_NORMAL
        when ?u.getbyte(0)
          attr |= Ncurses::A_UNDERLINE
        else
        i = ch.chr.to_i
        i = 1 if i > ColorMap::colors.length-1
        end
        bg = ColorMap::colors[i]
    @@colors = %w[black red green yellow blue magenta cyan white]
      @window.printstring  r, c, "%-40s" % "red #{bg}      ", ColorMap.get_color('red',bg) , attr
      @window.printstring  2, c, "%-40s" % "blue #{bg}      ", ColorMap.get_color('blue',bg) , attr
      @window.printstring  3, c, "%-40s" % "white #{bg}      ", ColorMap.get_color('white',bg) , attr
      @window.printstring  4, c, "%-40s" % "green #{bg}      ", ColorMap.get_color('green',bg) , attr
      @window.printstring  5, c, "%-40s" % "cyan #{bg}      ", ColorMap.get_color('cyan',bg) , attr
      @window.printstring  6, c, "%-40s" % "magenta #{bg}      ", ColorMap.get_color('magenta',bg) , attr
      @window.printstring  7, c, "black #{bg}      ", ColorMap.get_color('black',bg) , attr
        @window.wrefresh
      end
      #     VER::Keyboard.focus = tp
    end
  rescue => ex
  ensure
   #  @panel = @window.panel if @window
   #  Ncurses::Panel.del_panel(@panel) if !@panel.nil?   
   #  @window.delwin if !@window.nil?
    @window.destroy unless @window.nil?
      VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
#    $log.debug( ex) if ex
#    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
