require 'ver/ncurses'
module ColorMap
  # 2010-09-20 12:22 changed colors from string to symbol
  ## private
  # returns a color constant for a human color string
  def ColorMap.get_color_const colorstring
    ret = FFI::NCurses.const_get "COLOR_#{colorstring.upcase}"
    #raise  "color const nil ColorMap 8 " if !ret
  end
  ## private
  # creates a new color pair, puts in color map and returns color_pair
  # number
  def ColorMap.install_color fgc, bgc
      #$log.debug " install_color found #{fgc} #{@bgc} "
      @color_id += 1
    fg = ColorMap.get_color_const fgc
    bg = ColorMap.get_color_const bgc
    FFI::NCurses.init_pair(@color_id, fg, bg);
    $color_map[[fgc, bgc]] = @color_id
    return @color_id
  end
  #
  # returns the colors that make up the given pair
  # you may want to find what makes up $bottomcolor and set color and bgcolor with it.
  # @param [Fixnum] color_pair
  # @return [Symbol, Symbol]  foreground and backgrounf color
  # @example 
  #     color, bgcolor = get_colors_for_pair $datacolor
  #
  def ColorMap.get_colors_for_pair pair
    $color_map.invert[pair]
  end
  ## public
  # returns a color_pair for a given foreground and background color
  def ColorMap.get_color fgc, bgc=$def_bg_color
    fgc = fgc.to_sym if fgc.is_a? String
    bgc = bgc.to_sym if bgc.is_a? String
    if $color_map.include? [fgc, bgc]
      #$log.debug " get_color found #{fgc} #{@bgc} "
      return $color_map[[fgc, bgc]]
    else
      #$log.debug " get_color NOT found #{fgc} #{@bgc} "
      return ColorMap.install_color fgc, bgc
    end
  end
  def ColorMap.colors
    @@colors
  end
  # returns true if color is a valid one, else false
  # @param [Symbol] color such as :black :cyan :yellow
  # @return [Boolean] true if valid, else false
  def ColorMap.is_color? color
    @@colors.include? color.to_sym
  end

  ## public
  # setup color map at start of application
  def ColorMap.setup
    @color_id = 0
    $color_map = {}
    FFI::NCurses.start_color();
    # Initialize few color pairs 
    $def_fg_color = :white   # pls set these 2 for your application
    $def_bg_color = :black
    #COLORS = [COLOR_BLACK, COLOR_RED, COLOR_GREEN, COLOR_YELLOW, COLOR_BLUE, 
    #     COLOR_MAGENTA, COLOR_CYAN, COLOR_WHITE]
    @@colors = [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]

    # make foreground colors
    bg = ColorMap.get_color_const $def_bg_color
    @@colors[0...@@colors.size].each_with_index do |color, i|
      next if color == $def_bg_color
      ColorMap.install_color color, $def_bg_color
    end
    $reversecolor = ColorMap.get_color $def_bg_color, $def_fg_color
    $popupcolor = ColorMap.get_color :cyan, $def_fg_color

    $errorcolor = ColorMap.get_color :white, :red
    #$promptcolor = $selectedcolor = ColorMap.get_color(:yellow, :red)
    $promptcolor = ColorMap.get_color(:yellow, :red)
    $normalcolor = $datacolor = ColorMap.get_color(:white, :black)
    $bottomcolor = $topcolor = ColorMap.get_color(:white, :blue)
    $selectedcolor = $datacolor # since we now use reverse attr in list

    $row_selected_attr = Ncurses::A_REVERSE
    $row_focussed_attr = Ncurses::A_BOLD
    $row_attr          = Ncurses::A_NORMAL

#    $log.debug " colormap SETUP: #{$datacolor} #{$reversecolor} "
  end

end # modul
if $0 == __FILE__
require 'logger'
require 'ver/window'
#include Ncurses # FFI 2011-09-8 
include ColorMap
  # Initialize curses
  begin
    $log = Logger.new("rbc13.log")
    VER::start_ncurses
    @window = VER::Window.root_window
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

      

      while((ch = @window.getchar()) != FFI::NCurses::KEY_F1 )
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
