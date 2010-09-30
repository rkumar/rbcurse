#*******************************************************
# Some common io routines for getting data or putting
# at some point
# Arunachalesha                       
#  2010-03-06 12:10 
#  Some are outdated.
#  Current are:
#    * rbgetstr (and those it calls)
#    * display_cmenu and create_mitem
#*******************************************************#
module Io

  # from which line to print in footer_win
  LINEONE = 1
  FOOTER_COLOR_PAIR = 6
  MAIN_WINDOW_COLOR_PAIR = 5
  ERROR_COLOR_PAIR = 7
                                 

# complex version of get_string that allows for trappng of control character
# such as C-c and C-h and TAB for completion
# validints contains int codes not chars.
  # TODO We should put a field there, make it visible and mv it to after the prompt
  # and handle all editing events on it.
  # @return status_code, string (0 if okay, 7 if help asked for, -1 for abort
  #def rbgetstr(win, r, c, prompt, maxlen, default, labels, validints=[], helptext="")
  def rbgetstr(win, r, c, prompt, maxlen, config={})
    #win ||= @target_window
    $log.debug " inside rbgetstr #{win} r:#{r} c:#{c} p:#{prompt} m:#{maxlen} "
    raise "rbgetstr got no window. io.rb" if win.nil?
    ins_mode = false
    default = config[:default] || ""
    prompt = "#{prompt} [#{default}]: " unless default
    len = prompt.length

    # clear the area of len+maxlen
    color = $datacolor
    str = default
    clear_this win, r, c, color, len+maxlen+1
    print_this(win, prompt+str, color, r, c)
    len = prompt.length + str.length
    #x mylabels=["^G~Help  ", "^C~Cancel"]
    #x mylabels += labels if !labels.nil?
    begin
      Ncurses.echo();
      #x print_key_labels( 0, 0, mylabels)
      #curpos = 0
      curpos = str.length
      prevchar = 0
      entries = nil
      #win.mvwgetnstr(LINEONE-3,askstr.length,yn,maxlen)
      while true
        #ch=win.mvwgetch(r, len) # get to right of prompt - WHY  NOT WORKING ??? 
        ch=win.getchar()
        $log.debug " rbgetstr got ch:#{ch}, str:#{str}. "
        case ch
        when 3 # -1 # C-c
          return -1, nil
        when 10, 13 # hits ENTER
          break
        when ?\C-h.getbyte(0), ?\C-?.getbyte(0), KEY_BSPACE # delete previous character/backspace
          len -= 1 if len > prompt.length
          curpos -= 1 if curpos > 0
          str.slice!(curpos)
          clear_this win, r, c, color, len+maxlen+1
          #print_this(win, prompt+str, color, r, c)
        when 330 # delete character on cursor
          #len -= 1 if len > prompt.length
          #curpos -= 1 if curpos > 0
          str.slice!(curpos) #rescue next
          clear_this win, r, c, color, len+maxlen+1
        when ?\C-g.getbyte(0)
          #x print_footer_help(helptext)
          helptext = config[:helptext] || "No help provided"
          print_help(win, r, c, color, helptext)
          return 7, nil
        when KEY_LEFT
          curpos -= 1 if curpos > 0
          len -= 1 if len > prompt.length
          win.wmove r, c+len # since getchar is not going back on del and bs
          next
        when KEY_RIGHT
          if curpos < str.length
            curpos += 1 #if curpos < str.length
            len += 1 
            win.wmove r, c+len # since getchar is not going back on del and bs
          end
          next
        when ?\M-i.getbyte(0) 
          ins_mode = !ins_mode
          next
        when KEY_TAB # TAB
          if config
            if prevchar == 9
              if !entries.nil? and !entries.empty?
                str = entries.delete_at(0)
              end
            else
              tabc = config[:tab_completion] unless tabc
              next unless tabc
              entries = tabc.call(str)
              $log.debug " tab got #{entries} "
              str = entries.delete_at(0) unless entries.nil? or entries.empty?
            end
          end
        else
          #if validints.include?ch
          #print_status("Found in validints")
          #return ch, nil
          #else
          if ch < 0 || ch > 255
            Ncurses.beep
            next
          end
          # if control char, beep
          if ch.chr =~ /[[:cntrl:]]/
            Ncurses.beep
            next
          end
          # we need to trap KEY_LEFT and RIGHT and what of UP for history ?
          #end
          #str << ch.chr
          if ins_mode
            str[curpos] = ch.chr
          else
            str.insert(curpos, ch.chr)
          end
          len += 1
          curpos += 1
          break if str.length > maxlen
        end
        print_this(win, prompt+str, color, r, c)
        win.wmove r, c+len # more for arrow keys, curpos may not be end
        prevchar = ch
      end
      str = default if str == ""
    ensure
      Ncurses.noecho();
      #x restore_application_key_labels # must be done after using print_key_labels
    end
    return 0, str
  end
  def clear_this win, r, c, color, len
    print_this(win, "%-*s" % [len," "], color, r, c)
  end
  def print_help(win, r, c, color, helptext)
    print_this(win, "%-*s" % [helptext.length+2," "], color, r, c)
    print_this(win, "%s" % helptext, color, r, c)
    sleep(5)
  end
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
    restore_application_key_labels # must be done after using print_key_labels
    return yn
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


    ##
    # prints given text to window, in color at x and y coordinates
    # @param [Window] window to write to
    # @param [String] text to print
    # @param [int] color such as $datacolor or $promptcolor
    # @param [int] x 
    # @param [int] y 
    # @see Window#printstring
    # Consider using Window#printstring
  def print_this(win, text, color, x, y)
    if(win == nil)
      raise "win nil in printthis"
    end
    #$log.debug " printthis #{win} , #{text} , #{x} , #{y} "
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

  @deprecated
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
  @deprecated
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
  @deprecated
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

    begin
      config[yn].call if config.include? yn 
    ensure
      restore_application_key_labels # must be done after using print_key_labels
      win.refresh
    end

    return yn == 'y' 
  end

  #
  # warn user: currently flashes and places error in log file
  # experimental, may change interface later
  # it does not say anything on screen
  # @param [String] text of error/warning to put in log
  # @since 1.1.5
  def warn string
    $log.warn string
    Ncurses.beep
  end

  #def add_item hotkey, label, desc,action
  #
  ## A *simple* way of creating menus that will appear in a single row.
  # This copies the menu at the bottom of "most" upon pressing ":".
  # hotkey is the key to invoke an item (a single digit letter)
  #
  # label is an action name
  #
  # desc is a description displayed after an item is chosen. Usually, its like:
  #+ "Folding has been enabled" or "Searches will now be case sensitive"
  #
  # action may be a Proc or a symbol which will be called if item selected
  #+ action may be another menu, so recursive menus can be built, but each
  #+ should fit in a line, its a simple system.

  CMenuItem = Struct.new( :hotkey, :label, :desc, :action )


  ## An encapsulated form of yesterday's Most Menu
  # It keeps the internals away from the user.
  # Its not really OOP in the sense that the PromptMenu is not a MenuItem. That's how it is in
  # our Menu system, and that led to a lot of painful coding (at least for me). This is quite
  # simple. A submenu contains a PromptMenu in its action object and is evaluated in a switch.
  # A recursive loop handles submenus.
  #
  # Prompting of menu options with suboptions etc.
  # A block of code or symbol or proc is executed for any leaf node
  # This allows us to define different menus for different objects on the screen, and not have to map 
  # all kinds of control keys for operations, and have the user remember them. Only one key invokes the menu
  # and the rest are ordinary characters.
  class PromptMenu
    include Io
    attr_reader :text
    attr_reader :options
    def initialize caller,  text="Choose:"
      @caller = caller
      @text = text
      @options = []
    end
    def add menuitem
      @options << menuitem
    end
    def create_mitem *args
      item = CMenuItem.new(*args.flatten)
    end
    # Display the top level menu and accept user input
    # Calls actions or symbols upon selection, or traverses submenus
    # @return retvalue of last call or send, or 0
    # @param win window
    # @param r, c row and col to display on
    # @param color text color (use $datacolor if in doubt)
    # @param menu array of CMenuItem structs
    def display win, r, c, color
      menu = @options
      $log.debug " DISP MENU "
      ret = 0
      while true
        str = @text.dup
        h = {}
        valid = []
        menu.each{ |item|
          str << "(%c) %s " % [ item.hotkey, item.label ]
          h[item.hotkey] = item
          valid << item.hotkey
        }
        #$log.debug " valid are #{valid} "
        color = $datacolor
        print_this(win, str, color, r, c)
        ch=win.getchar()
        #$log.debug " got ch #{ch} "
        next if ch < 0 or ch > 255
        ch = ch.chr
        index = valid.index ch
        if index.nil?
          clear_this win, r, c, color, str.length
          print_this(win, "Not valid. Valid are #{valid}", color, r,c)
          sleep 1
          next
        end
        #$log.debug " index is #{index} "
        item = h[ch]
        desc = item.desc
        #desc ||= "Could not find desc for #{ch} "
        desc ||= ""
        clear_this win, r, c, color, str.length
        print_this(win, desc, color, r,c)
        action = item.action
        case action
          #when Array
        when PromptMenu
          # submenu
          menu = action.options
          str = "%s: " % action.text 
        when Proc
          ret = action.call
          break
        when Symbol
          ret = @caller.send(action)
          break
        else 
          $log.debug " Unidentified flying class #{action.class} "
          break
        end
      end # while
      return ret # ret val of last send or call
    end
  end # class PromptMenu
  def ask(question, answer_type=String, &details)
    @question ||= Question.new(question, answer_type, &details)
    say(@question) unless (@question.readline and @question.echo == true)
    begin
      @answer = @question.answer_or_default(get_response)
      unless @question.valid_answer?(@answer)
        explain_error(:not_valid)
        raise QuestionError
      end
      
      @answer = @question.convert(@answer)
      
      if @question.in_range?(@answer)
        if @question.confirm
          # need to add a layer of scope to ask a question inside a
          # question, without destroying instance data
          context_change = self.class.new(@input, @output, @wrap_at, @page_at)
          if @question.confirm == true
            confirm_question = "Are you sure?  "
          else
            # evaluate ERb under initial scope, so it will have
            # access to @question and @answer
            template  = ERB.new(@question.confirm, nil, "%")
            confirm_question = template.result(binding)
          end
          unless context_change.agree(confirm_question)
            explain_error(nil)
            raise QuestionError
          end
        end
        
        @answer
      else
        explain_error(:not_in_range)
        raise QuestionError
      end
    rescue QuestionError
      #retry
    rescue ArgumentError, NameError => error
      raise if error.is_a?(NoMethodError)
      if error.message =~ /ambiguous/
        # the assumption here is that OptionParser::Completion#complete
        # (used for ambiguity resolution) throws exceptions containing 
        # the word 'ambiguous' whenever resolution fails
        explain_error(:ambiguous_completion)
      else
        explain_error(:invalid_type)
      end
      retry
    rescue Question::NoAutoCompleteMatch
      explain_error(:no_completion)
      retry
    ensure
      @question = nil    # Reset Question object.
    end
  end
  class Question
    # An internal HighLine error.  User code does not need to trap this.
    class NoAutoCompleteMatch < StandardError
      # do nothing, just creating a unique error type
    end

    #
    # Create an instance of HighLine::Question.  Expects a _question_ to ask
    # (can be <tt>""</tt>) and an _answer_type_ to convert the answer to.
    # The _answer_type_ parameter must be a type recognized by
    # Question.convert(). If given, a block is yeilded the new Question
    # object to allow custom initializaion.
    #
    def initialize( question, answer_type )
      # initialize instance data
      @question    = question
      @answer_type = answer_type
      
      @character    = nil
      @limit        = nil
      @echo         = true
      @readline     = false
      @whitespace   = :strip
      @_case         = nil
      @default      = nil
      @validate     = nil
      @above        = nil
      @below        = nil
      @in           = nil
      @confirm      = nil
      @gather       = false
      @first_answer = nil
      @directory    = Pathname.new(File.expand_path(File.dirname($0)))
      @glob         = "*"
      @responses    = Hash.new
      @overwrite    = false
      
      # allow block to override settings
      yield self if block_given?

      # finalize responses based on settings
      build_responses
    end
    
    # The ERb template of the question to be asked.
    attr_accessor :question
    # The type that will be used to convert this answer.
    attr_accessor :answer_type
    #
    # Can be set to +true+ to use HighLine's cross-platform character reader
    # instead of fetching an entire line of input.  (Note: HighLine's character
    # reader *ONLY* supports STDIN on Windows and Unix.)  Can also be set to
    # <tt>:getc</tt> to use that method on the input stream.
    #
    # *WARNING*:  The _echo_ and _overwrite_ attributes for a question are 
    # ignored when using the <tt>:getc</tt> method.  
    # 
    attr_accessor :character
    #
    # Allows you to set a character limit for input.
    # 
    # *WARNING*:  This option forces a character by character read.
    # 
    attr_accessor :limit
    #
    # Can be set to +true+ or +false+ to control whether or not input will
    # be echoed back to the user.  A setting of +true+ will cause echo to
    # match input, but any other true value will be treated as to String to
    # echo for each character typed.
    # 
    # This requires HighLine's character reader.  See the _character_
    # attribute for details.
    # 
    # *Note*:  When using HighLine to manage echo on Unix based systems, we
    # recommend installing the termios gem.  Without it, it's possible to type
    # fast enough to have letters still show up (when reading character by
    # character only).
    #
    attr_accessor :echo
    #
    # Use the Readline library to fetch input.  This allows input editing as
    # well as keeping a history.  In addition, tab will auto-complete 
    # within an Array of choices or a file listing.
    # 
    # *WARNING*:  This option is incompatible with all of HighLine's 
    # character reading  modes and it causes HighLine to ignore the
    # specified _input_ stream.
    # 
    attr_accessor :readline
    #
    # Used to control whitespace processing for the answer to this question.
    # See HighLine::Question.remove_whitespace() for acceptable settings.
    #
    attr_accessor :whitespace
    #
    # Used to control character case processing for the answer to this question.
    # See HighLine::Question.change_case() for acceptable settings.
    #
    attr_accessor :_case
    # Used to provide a default answer to this question.
    attr_accessor :default
    #
    # If set to a Regexp, the answer must match (before type conversion).
    # Can also be set to a Proc which will be called with the provided
    # answer to validate with a +true+ or +false+ return.
    #
    attr_accessor :validate
    # Used to control range checks for answer.
    attr_accessor :above, :below
    # If set, answer must pass an include?() check on this object.
    attr_accessor :in
    #
    # Asks a yes or no confirmation question, to ensure a user knows what
    # they have just agreed to.  If set to +true+ the question will be,
    # "Are you sure?  "  Any other true value for this attribute is assumed
    # to be the question to ask.  When +false+ or +nil+ (the default), 
    # answers are not confirmed.
    # 
    attr_accessor :confirm
    #
    # When set, the user will be prompted for multiple answers which will
    # be collected into an Array or Hash and returned as the final answer.
    # 
    # You can set _gather_ to an Integer to have an Array of exactly that
    # many answers collected, or a String/Regexp to match an end input which
    # will not be returned in the Array.
    # 
    # Optionally _gather_ can be set to a Hash.  In this case, the question
    # will be asked once for each key and the answers will be returned in a
    # Hash, mapped by key.  The <tt>@key</tt> variable is set before each 
    # question is evaluated, so you can use it in your question.
    # 
    attr_accessor :gather
    # 
    # When set to a non *nil* value, this will be tried as an answer to the
    # question.  If this answer passes validations, it will become the result
    # without the user ever being prompted.  Otherwise this value is discarded, 
    # and this Question is resolved as a normal call to HighLine.ask().
    # 
    attr_writer :first_answer
    #
    # The directory from which a user will be allowed to select files, when
    # File or Pathname is specified as an _answer_type_.  Initially set to
    # <tt>Pathname.new(File.expand_path(File.dirname($0)))</tt>.
    # 
    attr_accessor :directory
    # 
    # The glob pattern used to limit file selection when File or Pathname is
    # specified as an _answer_type_.  Initially set to <tt>"*"</tt>.
    # 
    attr_accessor :glob
    #
    # A Hash that stores the various responses used by HighLine to notify
    # the user.  The currently used responses and their purpose are as
    # follows:
    #
    # <tt>:ambiguous_completion</tt>::  Used to notify the user of an
    #                                   ambiguous answer the auto-completion
    #                                   system cannot resolve.
    # <tt>:ask_on_error</tt>::          This is the question that will be
    #                                   redisplayed to the user in the event
    #                                   of an error.  Can be set to
    #                                   <tt>:question</tt> to repeat the
    #                                   original question.
    # <tt>:invalid_type</tt>::          The error message shown when a type
    #                                   conversion fails.
    # <tt>:no_completion</tt>::         Used to notify the user that their
    #                                   selection does not have a valid
    #                                   auto-completion match.
    # <tt>:not_in_range</tt>::          Used to notify the user that a
    #                                   provided answer did not satisfy
    #                                   the range requirement tests.
    # <tt>:not_valid</tt>::             The error message shown when
    #                                   validation checks fail.
    #
    attr_reader :responses
    #
    # When set to +true+ the question is asked, but output does not progress to
    # the next line.  The Cursor is moved back to the beginning of the question
    # line and it is cleared so that all the contents of the line disappear from
    # the screen.
    #
    attr_accessor :overwrite
   
    #
    # Returns the provided _answer_string_ or the default answer for this
    # Question if a default was set and the answer is empty.
    #
    def answer_or_default( answer_string )
      if answer_string.length == 0 and not @default.nil?
        @default
      else
        answer_string
      end
    end
    
    #
    # Called late in the initialization process to build intelligent
    # responses based on the details of this Question object.
    #
    def build_responses(  )
      ### WARNING:  This code is quasi-duplicated in     ###
      ### Menu.update_responses().  Check there too when ###
      ### making changes!                                ###
      append_default unless default.nil?
      @responses = { :ambiguous_completion =>
                       "Ambiguous choice.  " +
                       "Please choose one of #{@answer_type.inspect}.",
                     :ask_on_error         =>
                       "?  ",
                     :invalid_type         =>
                       "You must enter a valid #{@answer_type}.",
                     :no_completion        =>
                       "You must choose one of " +
                       "#{@answer_type.inspect}.",
                     :not_in_range         =>
                       "Your answer isn't within the expected range " +
                       "(#{expected_range}).",
                     :not_valid            =>
                       "Your answer isn't valid (must match " +
                       "#{@validate.inspect})." }.merge(@responses)
      ### WARNING:  This code is quasi-duplicated in     ###
      ### Menu.update_responses().  Check there too when ###
      ### making changes!                                ###
    end
    
    #
    # Returns the provided _answer_string_ after changing character case by
    # the rules of this Question.  Valid settings for whitespace are:
    #
    # +nil+::                        Do not alter character case. 
    #                                (Default.)
    # <tt>:up</tt>::                 Calls upcase().
    # <tt>:upcase</tt>::             Calls upcase().
    # <tt>:down</tt>::               Calls downcase().
    # <tt>:downcase</tt>::           Calls downcase().
    # <tt>:capitalize</tt>::         Calls capitalize().
    # 
    # An unrecognized choice (like <tt>:none</tt>) is treated as +nil+.
    # 
    def change_case( answer_string )
      if [:up, :upcase].include?(@_case)
        answer_string.upcase
      elsif [:down, :downcase].include?(@_case)
        answer_string.downcase
      elsif @_case == :capitalize
        answer_string.capitalize
      else
        answer_string
      end
    end

    #
    # Transforms the given _answer_string_ into the expected type for this
    # Question.  Currently supported conversions are:
    #
    # <tt>[...]</tt>::         Answer must be a member of the passed Array. 
    #                          Auto-completion is used to expand partial
    #                          answers.
    # <tt>lambda {...}</tt>::  Answer is passed to lambda for conversion.
    # Date::                   Date.parse() is called with answer.
    # DateTime::               DateTime.parse() is called with answer.
    # File::                   The entered file name is auto-completed in 
    #                          terms of _directory_ + _glob_, opened, and
    #                          returned.
    # Float::                  Answer is converted with Kernel.Float().
    # Integer::                Answer is converted with Kernel.Integer().
    # +nil+::                  Answer is left in String format.  (Default.)
    # Pathname::               Same as File, save that a Pathname object is
    #                          returned.
    # String::                 Answer is converted with Kernel.String().
    # Regexp::                 Answer is fed to Regexp.new().
    # Symbol::                 The method to_sym() is called on answer and
    #                          the result returned.
    # <i>any other Class</i>:: The answer is passed on to
    #                          <tt>Class.parse()</tt>.
    #
    # This method throws ArgumentError, if the conversion cannot be
    # completed for any reason.
    # 
    def convert( answer_string )
      if @answer_type.nil?
        answer_string
      elsif [Float, Integer, String].include?(@answer_type)
        Kernel.send(@answer_type.to_s.to_sym, answer_string)
      elsif @answer_type == Symbol
        answer_string.to_sym
      elsif @answer_type == Regexp
        Regexp.new(answer_string)
      elsif @answer_type.is_a?(Array) or [File, Pathname].include?(@answer_type)
        # cheating, using OptionParser's Completion module
        choices = selection
        choices.extend(OptionParser::Completion)
        answer = choices.complete(answer_string)
        if answer.nil?
          raise NoAutoCompleteMatch
        end
        if @answer_type.is_a?(Array)
          answer.last
        elsif @answer_type == File
          File.open(File.join(@directory.to_s, answer.last))
        else
          Pathname.new(File.join(@directory.to_s, answer.last))
        end
      elsif [Date, DateTime].include?(@answer_type) or @answer_type.is_a?(Class)
        @answer_type.parse(answer_string)
      elsif @answer_type.is_a?(Proc)
        @answer_type[answer_string]
      end
    end

    # Returns a english explination of the current range settings.
    def expected_range(  )
      expected = [ ]

      expected << "above #{@above}" unless @above.nil?
      expected << "below #{@below}" unless @below.nil?
      expected << "included in #{@in.inspect}" unless @in.nil?

      case expected.size
      when 0 then ""
      when 1 then expected.first
      when 2 then expected.join(" and ")
      else        expected[0..-2].join(", ") + ", and #{expected.last}"
      end
    end

    # Returns _first_answer_, which will be unset following this call.
    def first_answer( )
      @first_answer
    ensure
      @first_answer = nil
    end
    
    # Returns true if _first_answer_ is set.
    def first_answer?( )
      not @first_answer.nil?
    end
    
    #
    # Returns +true+ if the _answer_object_ is greater than the _above_
    # attribute, less than the _below_ attribute and included?()ed in the
    # _in_ attribute.  Otherwise, +false+ is returned.  Any +nil+ attributes
    # are not checked.
    #
    def in_range?( answer_object )
      (@above.nil? or answer_object > @above) and
      (@below.nil? or answer_object < @below) and
      (@in.nil? or @in.include?(answer_object))
    end
    
    #
    # Returns the provided _answer_string_ after processing whitespace by
    # the rules of this Question.  Valid settings for whitespace are:
    #
    # +nil+::                        Do not alter whitespace.
    # <tt>:strip</tt>::              Calls strip().  (Default.)
    # <tt>:chomp</tt>::              Calls chomp().
    # <tt>:collapse</tt>::           Collapses all whitspace runs to a
    #                                single space.
    # <tt>:strip_and_collapse</tt>:: Calls strip(), then collapses all
    #                                whitspace runs to a single space.
    # <tt>:chomp_and_collapse</tt>:: Calls chomp(), then collapses all
    #                                whitspace runs to a single space.
    # <tt>:remove</tt>::             Removes all whitespace.
    # 
    # An unrecognized choice (like <tt>:none</tt>) is treated as +nil+.
    # 
    # This process is skipped, for single character input.
    # 
    def remove_whitespace( answer_string )
      if @whitespace.nil?
        answer_string
      elsif [:strip, :chomp].include?(@whitespace)
        answer_string.send(@whitespace)
      elsif @whitespace == :collapse
        answer_string.gsub(/\s+/, " ")
      elsif [:strip_and_collapse, :chomp_and_collapse].include?(@whitespace)
        result = answer_string.send(@whitespace.to_s[/^[a-z]+/])
        result.gsub(/\s+/, " ")
      elsif @whitespace == :remove
        answer_string.gsub(/\s+/, "")
      else
        answer_string
      end
    end

    #
    # Returns an Array of valid answers to this question.  These answers are
    # only known when _answer_type_ is set to an Array of choices, File, or
    # Pathname.  Any other time, this method will return an empty Array.
    # 
    def selection(  )
      if @answer_type.is_a?(Array)
        @answer_type
      elsif [File, Pathname].include?(@answer_type)
        Dir[File.join(@directory.to_s, @glob)].map do |file|
          File.basename(file)
        end
      else
        [ ]
      end      
    end
    
    # Stringifies the question to be asked.
    def to_str(  )
      @question
    end

    #
    # Returns +true+ if the provided _answer_string_ is accepted by the 
    # _validate_ attribute or +false+ if it's not.
    # 
    # It's important to realize that an answer is validated after whitespace
    # and case handling.
    #
    def valid_answer?( answer_string )
      @validate.nil? or 
      (@validate.is_a?(Regexp) and answer_string =~ @validate) or
      (@validate.is_a?(Proc)   and @validate[answer_string])
    end
    
    private
    
    #
    # Adds the default choice to the end of question between <tt>|...|</tt>.
    # Trailing whitespace is preserved so the function of HighLine.say() is
    # not affected.
    #
    def append_default(  )
      if @question =~ /([\t ]+)\Z/
        @question << "|#{@default}|#{$1}"
      elsif @question == ""
        @question << "|#{@default}|  "
      elsif @question[-1, 1] == "\n"
        @question[-2, 0] =  "  |#{@default}|"
      else
        @question << "  |#{@default}|"
      end
    end
  end

  ### ADD HERE ###  

end # module
