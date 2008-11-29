$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
module Colormap
  def Colormap.get_color_const colorstring
    Ncurses.const_get "COLOR_#{colorstring.upcase}"
  end
  def Colormap.install_color fgc, bgc
      $log.debug " install_color found #{fgc} #{@bgc} "
      @color_id += 1
    fg = Colormap.get_color_const fgc
    bg = Colormap.get_color_const bgc
    Ncurses.init_pair(@color_id, fg, bg);
    $color_map[[fgc, bgc]] = @color_id
    return @color_id
  end
  def Colormap.get_color fgc, bgc=$def_bg_color
    if $color_map.include? [fgc, bgc]
      $log.debug " get_color found #{fgc} #{@bgc} "
      return $color_map[[fgc, bgc]]
    else
      $log.debug " get_color NOT found #{fgc} #{@bgc} "
      return Colormap.install_color fgc, bgc
    end
  end
  def Colormap.colors
    @@colors
  end

  def Colormap.setup
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
    bg = Colormap.get_color_const $def_bg_color
    @@colors[0...@@colors.size].each_with_index do |color, i|
      next if color == $def_bg_color
      Colormap.install_color color, $def_bg_color
    end
    $reversecolor = Colormap.get_color $def_bg_color, $def_fg_color

    $errorcolor = Colormap.get_color 'white', 'red'
    $promptcolor = $selectedcolor = Colormap.get_color('yellow', 'red')
    $normalcolor = $datacolor = Colormap.get_color('white', 'black')
    $bottomcolor = $topcolor = Colormap.get_color('white', 'blue')
  end

end # modul
if $0 == __FILE__
require 'logger'
#require 'lib/ver/ncurses'
require 'lib/ver/window'
include Ncurses
include Colormap
  # Initialize curses
  begin
    @window = VER::Window.root_window
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG
    Colormap.setup

    # Create the window to be associated with the form 
    # Un post form and free the memory

    catch(:close) do
      $log.debug "START  ---------"
      # need to pass a form, not window.
      r = 1; c = 2; i=0
      attr = Ncurses::A_NORMAL
      @window.printstring  20, c, "press 0-9 to change BG color,  F1/q to quit. r-everse, n-ormal,b-old ", Colormap.get_color('white')

      

      while((ch = @window.getch()) != KEY_F1 )
        next if ch == -1
        break if ch == ?q
        case ch
        when ?r
          attr |= Ncurses::A_REVERSE
        when ?b
          attr |= Ncurses::A_BOLD
        when ?n
          attr = Ncurses::A_NORMAL
        when ?u
          attr |= Ncurses::A_UNDERLINE
        else
        i = ch.chr.to_i
        i = 1 if i > Colormap::colors.length-1
        end
        bg = Colormap::colors[i]
    @@colors = %w[black red green yellow blue magenta cyan white]
      @window.printstring  r, c, "%-40s" % "red #{bg}      ", Colormap.get_color('red',bg) , attr
      @window.printstring  2, c, "%-40s" % "blue #{bg}      ", Colormap.get_color('blue',bg) , attr
      @window.printstring  3, c, "%-40s" % "white #{bg}      ", Colormap.get_color('white',bg) , attr
      @window.printstring  4, c, "%-40s" % "green #{bg}      ", Colormap.get_color('green',bg) , attr
      @window.printstring  5, c, "%-40s" % "cyan #{bg}      ", Colormap.get_color('cyan',bg) , attr
      @window.printstring  6, c, "%-40s" % "magenta #{bg}      ", Colormap.get_color('magenta',bg) , attr
      @window.printstring  7, c, "black #{bg}      ", Colormap.get_color('black',bg) , attr
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
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
