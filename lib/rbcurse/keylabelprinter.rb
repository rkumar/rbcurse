require 'rbcurse/rwidget'
include Ncurses
include RubyCurses
module RubyCurses
  class KeyLabelPrinter < Widget
    attr_reader :key_labels
    dsl_property :mode

    def initialize form, key_labels, config={}, &block

      super form, config, &block
      @mode ||= :normal
      #@key_labels = key_labels
      @key_hash = {}
      @key_hash[@mode] = key_labels
      @editable = false
      @focusable = false
      @cols ||= Ncurses.COLS-1
      @row ||= Ncurses.LINES-3
      @col ||= 0
      @repaint_required = true
      @footer_color_pair ||= $bottomcolor
      @footer_mnemonic_color_pair ||= $reversecolor #2
    end
    def key_labels mode=@mode
      @key_hash[mode]
    end
    # returns the keys as printed. these may or may not help
    # in validation depedign on what you passed as zeroth index
    def get_current_keys
      a = []
      @key_hash[@mode].each do |arr|
        a << arr[0] unless arr.nil?
      end
      return a
    end
    def getvalue
      @key_hash
    end
    def set_key_labels _key_labels, mode=:normal
      @key_hash[mode] = _key_labels
    end

    ##
    # XXX need to move wrapping etc up and done once. 
    def repaint
      return unless @repaint_required
      r,c = rowcol
      print_key_labels(arr = key_labels(), mode=@mode)
      @repaint_required = false
    end
    def append_key_label key, label, mode=@mode
      @key_labels << [key, label] if !@key_labels.include? [key, label]
      @repaint_required = true
    end
    def print_key_labels(arr = key_labels(), mode=@mode)
      #return if !@show_key_labels # XXX
      @win ||= @form.window
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
          #$log.debug("loop even: #{even.inspect}")
        else
        end
      }
      #$log.debug("even: #{even.inspect}")
      #$log.debug("odd : #{odd.inspect}")
      #posy = @barrow-1
      posy = @row
      print_key_labels_row(posy, posx, even)
      posy = @row+1
      print_key_labels_row(posy, posx, odd)
      #@win.wrefresh   # needed else secod row not shown after askchoice XXX
    end
    def print_key_labels_row(posy, posx, arr)
      # FIXME: this logic of padding needs to take into account
      # width of window
      padding = 8
      padding = 4 if arr.length > 5
      padding = 2 if arr.length > 7
      padding = 0 if arr.length > 9
      #padding = @padding # XXX 2008-11-13 23:01 
      my_form_win = @win
      @win.printstring(posy,0, "%-*s" % [@cols," "], @footer_color_pair, @attr)
      arr.each do |kl|
        key = kl[0]
        lab = kl[1]
        if key !="" # don't print that white blank space for fillers
          color_pair= @footer_mnemonic_color_pair # $reversecolor #2
          x = posx +  (key.length - key.strip.length)
          my_form_win.attron(Ncurses.COLOR_PAIR(color_pair))
          my_form_win.mvprintw(posy, x, "%s" % kl[0].strip );
          my_form_win.attroff(Ncurses.COLOR_PAIR(color_pair))
        end
        color_pair=@footer_color_pair
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
      @repaint_required = true
      labels = key_labels()
      labels.each_index do |ix|
        lab = labels[ix]
        if lab[0] == display_code
          labels[ix] = [new_display_code , text]
          $log.debug("updated #{labels[ix]}")
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
      @repaint_required = true
      labels = key_labels()
      labels.insert(index, [display_code , text] )
    end
    # ADD HERE KEYLABEL
  end
end
