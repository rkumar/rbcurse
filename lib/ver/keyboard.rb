module VER
  module Keyboard # avoid initialize
    ESC         = 27 # keycode
    @polling = false

    module_function

    def focus=(receiver)
      @stack = []
      @focus = receiver
      poll unless @polling
    end

    def poll
      @polling = true

      while char = @focus.window.getch
        break if @focus.stopping? # XXX
        #break if VER.stopping?
        $log.debug("char: #{char} stakc: #{@stack.inspect}") if char != Ncurses::ERR
        if char == Ncurses::ERR # timeout or signal
          @focus.press('esc') if @stack == [ESC]
          @stack.clear
        elsif ready = resolve(char)
$log.debug("char: #{char} ready: #{ready}")
          @stack.clear
          @focus.press(ready)
        end
      end

    ensure
      @polling = false
    end

    def resolve(char)
      @stack << char

      if @stack.first == ESC
        MOD_KEYS[@stack] || SPECIAL_KEYS[@stack]
      else
        NCURSES_KEYS[char] || CONTROL_KEYS[char] || PRINTABLE_KEYS[char]
      end
    end

    # TODO: make this section sane

    ASCII     = (0..255).map{|c| c.chr }
    CONTROL   = ASCII.grep(/[[:cntrl:]]/)
    PRINTABLE = ASCII.grep(/[[:print:]]/)

    SPECIAL_KEYS = {
      [27, 79, 50, 81]              => 'F14',
      [27, 79, 50, 82]              => 'F15',
      [27, 79, 70]                  => 'end',
      [27, 79, 70]                  => 'end',
      [27, 79, 72]                  => 'home',
      [27, 79, 80]                  => 'F1',
      [27, 79, 81]                  => 'F2',
      [27, 79, 82]                  => 'F3',
      [27, 79, 83]                  => 'F4',
      [27, 91, 49, 126]             => 'end',
      [27, 91, 49, 126]             => 'home',
      [27, 91, 49, 49, 126]         => 'F1',
      [27, 91, 49, 50, 126]         => 'F2',
      [27, 91, 49, 51, 126]         => 'F3',
      [27, 91, 49, 52, 126]         => 'F4',
      [27, 91, 49, 52, 126]         => 'F4',
      [27, 91, 49, 53, 126]         => 'F5',
      [27, 91, 49, 55, 126]         => 'F6',
      [27, 91, 49, 56, 59, 50, 126] => 'F19',
      [27, 91, 49, 56, 59, 51, 126] => 'F7',
      [27, 91, 49, 59, 51, 65]      => 'ppage',
      [27, 91, 49, 59, 51, 66]      => 'npage',
      [27, 91, 49, 59, 53, 65]      => 'ppage',
      [27, 91, 49, 59, 53, 66]      => 'npage',
      [27, 91, 49, 59, 53, 70]      => 'M-<',
      [27, 91, 49, 59, 53, 72]      => 'M->',
      [27, 91, 50, 54, 126]         => 'F14',
      [27, 91, 50, 56, 126]         => 'F15',
      [27, 91, 51, 59, 51, 126]     => 'del',
      [27, 91, 52, 126]             => 'end',
      [27, 91, 55, 126]             => 'home',
      [27, 91, 55, 126]             => 'home',
      [27, 91, 56, 126]             => 'end',
      [27, 91, 56, 126]             => 'end',
      [27, 91, 65]                  => 'up',
      [27, 91, 66]                  => 'down',
      [27, 91, 67]                  => 'right',
      [27, 91, 68]                  => 'left',
      [27, 91, 70]                  => 'end',
      [27, 91, 72]                  => 'end',
      [27, 91, 72]                  => 'home',
      [27, 91, 91, 65]              => 'F1',
      [27, 91, 91, 66]              => 'F2',
      [27, 91, 91, 67]              => 'F3',
      [27, 91, 91, 68]              => 'F4',
      [27, 91, 91, 69]              => 'F5',
    }

    CONTROL_KEYS = {
      0   => 'C-space',
      1   => 'C-a',
      2   => 'C-b',
      3   => 'C-c',
      4   => 'C-d',
      5   => 'C-e',
      6   => 'C-f',
      7   => 'C-g',
      8   => 'C-h',
      9   => 'tab',
      10  => 'return', # C-j
      11  => 'C-k',
      12  => 'C-l',
      13  => 'return', # C-m
      14  => 'C-n',
      15  => 'C-o',
      16  => 'C-p',
      17  => 'C-q',
      18  => 'C-r',
      19  => 'C-s',
      20  => 'C-t',
      21  => 'C-u',
      22  => 'C-v',
      23  => 'C-w',
      24  => 'C-x',
      25  => 'C-y',
      26  => 'C-z', # FIXME: is usually suspend in shell job control
      # 27  => 'esc',
      32  => 'space',
      127 => 'backspace',
    }

    PRINTABLE_KEYS = {}
    MOD_KEYS = {}

    PRINTABLE.each do |key|
      code = key.unpack('c')[0] # using unpack to be compatible with 1.9
      PRINTABLE_KEYS[code] = key
      MOD_KEYS[[ESC, code]] = "M-#{key}" unless key == '[' # don't map esc
    end

    NCURSES_KEYS = {}
    Ncurses.constants.grep(/^KEY_/).each do |const|
      value = Ncurses.const_get(const)
      key = const[/^KEY_(.*)/, 1]
      key = key =~ /^F/ ? key : key.downcase # function keys
      NCURSES_KEYS[value] = key
    end
  end
end
