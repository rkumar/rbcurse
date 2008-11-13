class KeyLabelPrinter
  # called should respond to get_key_labels
  attr_reader :key_labels
  attr_accessor :mode

  def initialize caller, key_labels, row, mode = :normal
    @caller = caller
    @key_labels = key_labels
    @mode = mode
    @win = nil
    @row = row
    @cols = caller.cols
  end
  def append_key_label key, label, mode=@mode
    @key_labels << [key, label] if !@key_labels.include? [key, label]
  end
  def print_key_labels(arr = @key_labels, mode=@mode)
    #return if !@show_key_labels # XXX
    @win ||= @caller.window
    @padding = @cols / (arr.length/2)
    posx = 0
    even = []
    odd = []
    arr.each_index { |i|
      if i % 2 == 0
        #arr[i+1] = ['',''] if arr[i+1].nil?
        nextarr = arr[i+1] || ['', '']
        keyw = [arr[i][0].length, nextarr[0].length].max
        labelw = [arr[i][1].length, nextarr[1].length].max

        even << [ sprintf("%*s", keyw,  arr[i][0]), sprintf("%-*s", labelw,  arr[i][1]) ]
        odd << [ sprintf("%*s", keyw,  nextarr[0]), sprintf("%-*s", labelw,  nextarr[1]) ]
        $log.debug("loop even: #{even.inspect}")
      else
      end
    }
    $log.debug("even: #{even.inspect}")
    $log.debug("odd : #{odd.inspect}")
    #posy = @barrow-1
    posy = @row
    print_key_labels_row(posy, posx, even)
    posy = @row+1
    print_key_labels_row(posy, posx, odd)
    @win.wrefresh   # needed else secod row not shown after askchoice XXX
  end
  def print_key_labels_row(posy, posx, arr)
    $footer_color_pair ||= 6
    padding = 8
    padding = 4 if arr.length > 5
    padding = 0 if arr.length > 7
    #padding = @padding # XXX 2008-11-13 23:01 
    my_form_win = @win
    #@caller.print_this(@win, "%-*s" % [Ncurses.COLS," "], $footer_color_pair, posy, 0) # 2008-11-13 22:56  XXX
    @caller.print_this(@win, "%-*s" % [@cols," "], $footer_color_pair, posy, 0)
    arr.each do |kl|
      key = kl[0]
      lab = kl[1]
      if key !="" # don't print that white blank space for fillers
        color_pair=2
        x = posx +  (key.length - key.strip.length)
        my_form_win.attron(Ncurses.COLOR_PAIR(color_pair))
        my_form_win.mvprintw(posy, x, "%s" % kl[0].strip );
        my_form_win.attroff(Ncurses.COLOR_PAIR(color_pair))
      end
      color_pair=$footer_color_pair
      posx = posx + kl[0].length 
      my_form_win.attron(Ncurses.COLOR_PAIR(color_pair))

      #lab = sprintf(" %s %*s" , kl[1], padding, " ");
      lab = sprintf(" %s %s" , kl[1], " "*padding);
      my_form_win.mvprintw(posy, posx, lab)
      my_form_win.attroff(Ncurses.COLOR_PAIR(color_pair))
      posx = posx +  lab.length
    end
  end
  ##
  # updates existing label with a new one.
  # @return true if updated, else false
  def update_application_key_label(display_code, new_display_code, text)
    @key_labels.each_index do |ix|
      lab = @key_labels[ix]
      if lab[0] == display_code
        @key_labels[ix] = [new_display_code , text]
        $log.debug("updated #{@key_labels[ix]}")
        return true
      end
    end
    return false
  end
  ##
  # inserts an application label at given index
  # to add the key, use create_datakeys to add bindings
  # remember to call restore_application_key_labels after updating/inserting
  def insert_application_key_label(index, display_code, text)
    @key_labels.insert(index, [display_code , text] )
  end
end
