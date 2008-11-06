#*******************************************************#
# Note: all method here require the presence of a footer_win
# and header_win to have been created,
# with the exception of print_help_page.
#                                      
# Arunachalesha                       
# $Id$  #
#*******************************************************#
module Commons1

  # from which line to print in footer_win
  LINEONE = 1
  FOOTER_COLOR_PAIR = 6
  MAIN_WINDOW_COLOR_PAIR = 5
  ERROR_COLOR_PAIR = 7
                                 
  # @table_width is a constant in caller based on which we decide where to show
  # key_labels and error messages.
  # WHEN WE CREATE A PANEL BWLOW we can do away wit that. FIXME XXX
  # return true for y, false for n
  #  e.g.
  #  <code>
  #  ret =  @main.askyesno(nil, "Are you sure you wish to proceed?")
  #  </code>
  #   2008-10-09 18:27 added call to print_footer_help
  def askyesno(win, askstr, default = "N", helptext="Helptext for this question")
    win ||= @footer_win
    askstr = "#{askstr} [#{default}]: "
    len = askstr.length

    clear_error # 2008-10-13 20:26 
    print_this(win, askstr, 4, LINEONE, 0)
    labels=["?~Help  "," ~      ", "N~No    ", "Y~Yes   "]
    print_key_labels( 0, 0, labels)
    win.refresh
    #Ncurses.echo();
    yn=''
    #win.mvwgetnstr(Ncurses.LINES-3,askstr.length,yn,maxlen)
    while true
      ch=win.mvwgetch(LINEONE,askstr.length)
      if ch < 0 || ch > 255
        next
      end
      yn = ch.chr
      yn = default if yn == '' or ch == 10 # KEY_ENTER
      yn.downcase!
      break if yn =~/[yn]/
      if yn == '?'
        print_footer_help(helptext) 
        print_key_labels( 0, 0, labels)
        next
      end
      Ncurses.beep
    end
    #Ncurses.noecho();
    clear_error # 2008-11-06 19:27 
    restore_application_key_labels # must be done after using print_key_labels
    win.refresh
    return yn == 'y' 
  end

  # return y or n or c
  
  def askyesnocancel(win, askstr, default = "N")
    win ||= @footer_win
    askstr = "#{askstr} [#{default}]: "
    len = askstr.length

    clear_error # 2008-10-13 20:26 
    print_this(win, askstr, 4, LINEONE, 0)
    labels=["N~No    ", "Y~Yes   ","C~Cancel"," ~    "]
    print_key_labels( 0, 0, labels)
    win.refresh
    #Ncurses.echo();
    yn=''
    #win.mvwgetnstr(LINEONE,askstr.length,yn,maxlen)
    while true
      ch=win.mvwgetch(LINEONE,askstr.length)
      yn = ch.chr
      yn = default if yn == '' or ch == 10 # KEY_ENTER
      yn.downcase!
      break if yn =~/[ync]/
      Ncurses.beep
    end
    #Ncurses.noecho();
    restore_application_key_labels # must be done after using print_key_labels
    return yn
  end

  # return single digit from given choices
  # e.g.
  #  <code>
  #  labels=["N~No    ", "Y~Yes   ","C~Cancel"," ~      ","S~SurpiseMe","G~GoAway!  "]
  #  ret =  @main.askchoice(nil, "Are you sure you wish to proceed?","N",labels,"NYCSG")
  #  @main.clear_error
  #  </code>

  def askchoice(win, askstr, default, labels, validchars, config={})
    win ||= @footer_win
    askstr = "#{askstr} [#{default}]: "
    len = askstr.length
    helptext = config.fetch("helptext", "No helptext provided for this action")

    clear_error # 2008-10-13 20:26 
    print_this(win, askstr, 4, LINEONE, 0)
    #labels=["N~No    ", "Y~Yes   ","C~Cancel"," ~    "]
    print_key_labels( 0, 0, labels)
    #Ncurses.echo();
    yn=''
    validchars.downcase!
    #win.mvwgetnstr(LINEONE-3,askstr.length,yn,maxlen)
    while true
      ch=win.mvwgetch(LINEONE,askstr.length)
      yn = ch.chr
      # 2008-10-31 18:08 
      if ch == ?\C-g or yn == '?'
        print_footer_help(helptext)
        print_key_labels( 0, 0, labels)
        next
      end
      yn = default if yn == '' or ch == 10 # KEY_ENTER
      yn.downcase!
      break if validchars.include?yn
      Ncurses.beep
    end
    #Ncurses.noecho();
    restore_application_key_labels # must be done after using print_key_labels
    return yn
  end
# complex version of get_string that allows for trappng of control character
# such as C-c and C-h and TAB for completion
# validints contains int codes not chars.
  # TODO We should put a field there, make it visible and mv it to after the prompt
  # and handle all editing events on it.
  def ask_string(win, askstr, maxlen, default, labels, validints=[], helptext="")
    win ||= @footer_win
    askstr = "#{askstr} [#{default}]: "
    len = askstr.length

    clear_error # 2008-10-13 20:26 
    print_this(win, askstr, 4, LINEONE, 0)
    mylabels=["^G~Help  ", "^C~Cancel"]
    mylabels += labels if !labels.nil?
    begin
    print_key_labels( 0, 0, mylabels)
    Ncurses.echo();
    yn=""
    #win.mvwgetnstr(LINEONE-3,askstr.length,yn,maxlen)
    while true
      ch=win.mvwgetch(LINEONE,len)
      case ch
      when 3 # -1 # C-c
        return -1, nil
      when 10
        break
      when ?\C-h, ?\C-?
        len -= 1
        yn.chop!
      when ?\C-g
        print_footer_help(helptext)
        return 7, nil
      else
        if validints.include?ch
          print_status("Found in validints")
          return ch, nil
        else
          # if in allowed character allow entry, otherwise beep
          if ch.chr =~ /[[:cntrl:]]/
            Ncurses.beep
            next
          end
        end
        yn << ch.chr
        len += 1
      end
    end
    yn = default if yn == ""
    ensure
      Ncurses.noecho();
      restore_application_key_labels # must be done after using print_key_labels
    end
    return 0, yn
  end
    def get_string(win, askstr, maxlen=20, default="", labels=nil )
    win ||= @footer_win
    askstr = "#{askstr} [#{default}]: "
    len = askstr.length

    clear_error #  2008-11-06 19:25 
    print_this(win, askstr, 4, LINEONE, 0)
    #labels=["N~No    ", "Y~Yes   ","C~Cancel"," ~    "]
    mylabels = ["^G~Help  ", "^C~Cancel"]
    mylabels = (mylabels + labels) if !labels.nil?

    print_key_labels( 0, 0, mylabels)
    Ncurses.echo();
    yn=''
    begin
      Signal.trap("INT"){ return nil }
      win.mvwgetnstr(LINEONE,askstr.length,yn,maxlen)
    rescue
      yn=''
    ensure
    Ncurses.noecho();
    clear_error #  2008-11-02 11:51 
    restore_application_key_labels # must be done after using print_key_labels
    end
    yn = default if yn == "" # 2008-10-31 18:59 
    return yn
  end


  def print_this(win, text, color, x, y)
    if(win == nil)
      raise "win nil in printthis"
    end
    color=Ncurses.COLOR_PAIR(color);
    win.attron(color);
    #win.mvprintw(x, y, "%-40s" % text);
    win.mvprintw(x, y, "%s" % text);
    win.attroff(color);
    win.refresh
  end
  # prints error in footer_win only
  def print_error(text)
    clear_error
    print_in_middle(@footer_win, LINEONE, 10, 80, text, Ncurses.COLOR_PAIR(ERROR_COLOR_PAIR))
  end
  # prints status in footer_win only
  def print_status(text)
    text = text[text.length-80..-1] if text.length > 80
    print_error(text)
  end
  # clear previous error, call inside getch loop after each ch.
  def clear_error
    print_this(@footer_win, "%-*s" % [Ncurses.COLS," "], 5, LINEONE, 0)
  end
  # This is only for the menu program, in which we print current action/menu string in the
  # key labels below.
  # Its a dirty hack edpending on:
  #   * String CurRow present in key labels
  #   * field_init_proc called this method to set it.
  def print_action(text)
    print_this(@footer_win, " %-10s" % ("["+text+"]"), FOOTER_COLOR_PAIR, @action_posy, @action_posx)
  end

  # the old historical program which prints a string in middle of whereever
  # thanks to this i was using stdscr which must never be used

  def print_in_middle(win, starty, startx, width, string, color)
    if(win == nil)
       raise "window is nil"
    end
    x = Array.new
    y = Array.new
    Ncurses.getyx(win, y, x);
    if(startx != 0)
      x[0] = startx;
    end
    if(starty != 0)
      y[0] = starty;
    end
    if(width == 0)
      width = 80;
    end
    length = string.length;
    temp = (width - length)/ 2;
    x[0] = startx + temp.floor;
    win.attron(color);
    win.mvprintw(y[0], x[0], "%s", string);
    win.attroff(color);
    win.refresh();
  end
  # splits that bad hack array into even and odd arrays
  # and prints on last 2 lines

  def print_key_labels(posy, posx, arr)
      ## paint so-called key bindings from key_labels
      posx = 0
      even = []
      odd = []
      arr.each_index { |i| 
        if i % 2 == 0
          even << arr[i]
        else
          odd << arr[i]
        end
      }
      posy = LINEONE+1
      print_key_labels_row(posy, posx, even)
      posy = LINEONE+2
      print_key_labels_row(posy, posx, odd)
      # 2008-09-29 21:58 
      @footer_win.wrefresh   # needed else secod row not shown after askchoice XXX
  end
    
  def print_key_labels_row(posy, posx, arr)
    #clear first
    my_form_win = @footer_win
    # first clear the line
    print_this(my_form_win, "%-*s" % [Ncurses.COLS," "], FOOTER_COLOR_PAIR, posy, 0)
    padding = 8
    padding = 4 if arr.length > 5
    padding = 0 if arr.length > 7
    arr.each_index { |i| 
          kl = arr[i].split('~')
          if kl[0].strip !="" # don't print that white blank space for fillers
            color_pair=2
            my_form_win.attron(Ncurses.COLOR_PAIR(color_pair))
            my_form_win.mvprintw(posy, posx, "%s" % kl[0] );
            my_form_win.attroff(Ncurses.COLOR_PAIR(color_pair))
          end
          color_pair=FOOTER_COLOR_PAIR
          posx = posx + kl[0].length 
          my_form_win.attron(Ncurses.COLOR_PAIR(color_pair))
          lab = sprintf(" %s %*s" , kl[1], padding, " ");
          # hack
          if kl[1].strip == "CurRow"
            @action_posx = posx
            @action_posy = posy
          end 
          my_form_win.mvprintw(posy, posx, lab)
          my_form_win.attroff(Ncurses.COLOR_PAIR(color_pair))
          posx = posx +  lab.length
      }
  end

  # since it must always be @header_win, we should remove the first param
  # why should user have any direct access to those 2 windows.
  def old_print_header(win, htext, posy = 0, posx = 0)
    win.attron(Ncurses.COLOR_PAIR(6))
    win.mvprintw(posy, posx, "%-*s" % [Ncurses.COLS, htext] );
    win.attroff(Ncurses.COLOR_PAIR(6))
  end
  def print_header(htext, posy = 0, posx = 0)
    win = @header_win
    win.attron(Ncurses.COLOR_PAIR(6))
    win.mvprintw(posy, posx, "%-*s" % [Ncurses.COLS, htext] );
    win.attroff(Ncurses.COLOR_PAIR(6))
  end

  # since it must always be @header_win, we should remove the first param
  # why should user have any direct access to those 2 windows.
  def old_print_top_right(win, htext)
    hlen = htext.length
    win.attron(Ncurses.COLOR_PAIR(6))
    win.mvprintw(0, Ncurses.COLS-hlen, htext );
    win.attroff(Ncurses.COLOR_PAIR(6))
    #win.refresh
  end
  def print_top_right(htext)
    hlen = htext.length
    win = @header_win
    win.attron(Ncurses.COLOR_PAIR(6))
    win.mvprintw(0, Ncurses.COLS-hlen, htext );
    win.attroff(Ncurses.COLOR_PAIR(6))
    #win.refresh
  end
  # prints labels defined by user in the DSL. 
  #
  # Array of labels with:
  #
  #     * position = [y,x] i.e, row, column
  #     * text = "label text"
  #     * color_pair = 6 (optional, default 6)

  def print_screen_labels(my_form_win, labelarr)
    table_width = @table_width || Ncurses.LINES-1
    return if labelarr.nil?
      labelarr.each{ |lhash|
        posy, posx = lhash["position"]
        posy = table_width + posy if posy < 0
        posx = Ncurses.COLS + posy if posx < 0

        text = lhash["text"]
        color_pair = lhash["color_pair"] || 6
        my_form_win.attron(Ncurses.COLOR_PAIR(color_pair))
        my_form_win.mvprintw(posy, posx, "%-s" % text );
        my_form_win.attroff(Ncurses.COLOR_PAIR(color_pair))
      }
  end

  def print_headers(form_hash)
    header = form_hash["header"]
    header_top_left = form_hash["header_top_left"] || ""
    header_top_center = form_hash["header_top_center"] || ""
    header_top_right = form_hash["header_top_right"] || ""
    posy = 0
    posx = 0
    htext = "  <APP NAME>  <VERSION>          MAIN MENU"

    posy, posx, htext = header if !header.nil?
    print_header(htext + " %15s " % header_top_left + " %20s" % header_top_center , posy, posx)
    print_top_right(header_top_right)
    @header_win.wrefresh();
  end
 

  #   2008-10-09 18:27 askyesno and ask_string can be passed some text
  #   to be popped up when a user enters ?
  def print_footer_help(helptext)
    print_this(@footer_win, "%-*s" % [Ncurses.COLS," "], 6, LINEONE+1, 0)
    print_this(@footer_win, "%-*s" % [Ncurses.COLS," "], 6, LINEONE+2, 0)
    print_this(@footer_win, "%s" % helptext, 6, LINEONE+1, 0)
    sleep(5)
  end
  def print_help_page(filename = "TODO")
    #require 'transactionviewer'
    #tp = TransactionViewer.new(nil)
    #tp.run
    require 'panelreader'
    tp = PanelReader.new()
    tp.view_file(filename)
    
    #require 'padreader'
    #tp = PadReader.new()
    #tp.view_file(filename)
  end
  #def newaskyesno(win, askstr, default = "N", helptext="Helptext for this question")
  ## 
  # user may pass in actions for each key along with other config values in config hash.
  # config can contain default, helptext, labels and 'y', 'n'
  def newaskyesno(win, askstr, config = {})
    win ||= @footer_win
    default = config.fetch("default", "N")
    helptext = config.fetch("helptext", "This is helptext for this action")
    askstr = "#{askstr} [#{default}]: "
    len = askstr.length

    clear_error # 2008-10-13 20:26 
    print_this(win, askstr, 4, LINEONE, 0)
    labels=config.fetch("labels", ["?~Help  "," ~      ", "N~No    ", "Y~Yes   "])
    print_key_labels( 0, 0, labels)
    win.refresh
    #Ncurses.echo();
    yn=''
    #win.mvwgetnstr(Ncurses.LINES-3,askstr.length,yn,maxlen)
    while true
      ch=win.mvwgetch(LINEONE,askstr.length)
      if ch < 0 || ch > 255
        next
      end
      yn = ch.chr
      yn = default if yn == '' or ch == 10 # KEY_ENTER
      yn.downcase!
      break if yn =~/[yn]/
      if yn == '?'
        print_footer_help(helptext) 
        print_key_labels( 0, 0, labels)
        next
      end
      Ncurses.beep
    end # while
    #Ncurses.noecho();

    begin
      config[yn].call if config.include? yn 
    ensure
      restore_application_key_labels # must be done after using print_key_labels
      win.refresh
    end

    return yn == 'y' 
  end
  ### ADD HERE ###  
end
