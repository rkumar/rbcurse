require 'rbcurse/rwidget'
#include Ncurses # FFI 2011-09-8 
include RubyCurses
module RubyCurses
  #
  # This paints labels for various keys at the bottom of the screen, in 2 rows. 
  # This is based on alpines last 2 rows. Modes are supported so that the 
  # labels change as you enter a widget.
  # For an example, see dbdemo.rb or rfe.rb
  # NOTE: applications using 'App' use a shortcut "dock" to create this.
  #
  # The most minimal keylabel to print one label in first row, and none in second is:
  #     [["F1", "Help"], nil]
  # To print 2 labels, one over the other:
  #     [["F1", "Help"], ["F10", "Quit"]]
  #
  class KeyLabelPrinter < Widget
    attr_reader :key_labels
    # the current mode (labels are based on mode, changing the mode, changes the labels
    #  displayed)
    dsl_property :mode
    # set the color of the labels, overriding the defaults
    dsl_accessor :footer_color_pair
    # set the color of the mnemonic, overriding the defaults
    dsl_accessor :footer_mnemonic_color_pair

    def initialize form, key_labels, config={}, &block

      case key_labels
      when Hash
        raise "KeyLabelPrinter: KeyLabels cannot be a hash, Array of key labels required. Perhaps you did not pass labels"
      when Array
      else
        raise "KeyLabelPrinter: Array of key labels required. Perhaps you did not pass labels"
      end
      super form, config, &block
      @mode ||= :normal
      #@key_labels = key_labels
      @key_hash = {}
      @key_hash[@mode] = key_labels
      @editable = false
      @focusable = false
      @cols ||= Ncurses.COLS-1
      @row ||= Ncurses.LINES-2
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
      arr = key_labels()
      print_key_labels(arr, mode=@mode)
      @repaint_required = false
    end
    # ?? does not use mode, i think key_labels is unused. a hash is now used 2011-10-11 XXX FIXME
    # WARNING, i have not tested this after changing it. 
    def append_key_label key, label, mode=@mode
      #@key_labels << [key, label] if !@key_labels.include? [key, label]
      @key_hash[mode] << [key, label] if !@key_hash[mode].include? [key, label]
      @repaint_required = true
    end
    def print_key_labels(arr = key_labels(), mode=@mode)
      #return if !@show_key_labels # XXX
      @win ||= @form.window
      $log.debug "XXX: PKL #{arr.length}, #{arr}"
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
      # uncommented next line after ffi-ncurses else not showing till key press FFI 2011-09-17 
      @win.wrefresh   # needed else secod row not shown after askchoice XXX 
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
    # @example update "C-x", "C-x", "Disable"
    def update_application_key_label(display_code, new_display_code, text)
      @repaint_required = true
      labels = key_labels()
      raise "labels are nil !!!" unless labels
      labels.each_index do |ix|
        lab = labels[ix]
        next if lab.nil?
        if lab[0] == display_code
          labels[ix] = [new_display_code , text]
          $log.debug("updated #{labels[ix]}")
          return true
        end
      end
      return false
    end
    alias :update :update_application_key_label
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
