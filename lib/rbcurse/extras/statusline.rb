require 'rbcurse'

module RubyCurses

  #
  # A vim-like application status bar that can display time and various other statuses
  #  at the bottom, typically above the dock (3rd line from last).
  #
  class StatusLine < Widget

    def initialize form, config={}, &block
      if form.window.height == 0
        @row = Ncurses.LINES-3 # fix, what about smaller windows, use window dimensions and watch out for 0,0
      else
        @row = form.window.height-3 # fix, what about smaller windows, use window dimensions and watch out for 0,0
      end
       # in root windows FIXME
      @col = 0
      super
      @focusable = false
      @editable  = false
      @command = nil
      @repaint_required = true
      bind(:PROPERTY_CHANGE) {  |e| @color_pair = nil ; }
    end
    #
    # command that returns a string that populates the status line.
    # See dbdemo.rb
    # e.g. 
    #   @l.command { "%-20s [DB: %-s | %-s ]" % [ Time.now, $current_db || "None", $current_table || "----"] }  
    #
    def command *args, &blk
      @command = blk
      @args = args
    end

    # NOTE: I have not put a check of repaint_required, so this will print on each key-stroke OR
    #   rather whenever form.repaint is called.
    def repaint
      @color_pair ||= get_color($datacolor, @color, @bgcolor) 
      len = @form.window.width
      len = Ncurses.COLS if len == 0

      # first print dashes through
      @form.window.printstring @row, @col, "%s" % "-" * len, @color_pair, Ncurses::A_REVERSE

      # now call the block to get current values
      if @command
        ftext = @command.call(self, @args) if @command
      else
        status = $status_message ? $status_message.value : ""
        ftext = " %-20s | %s" % [Time.now, status] # should we print a default value just in case user doesn't
      end
      @form.window.printstring @row, @col, ftext, $datacolor, Ncurses::A_REVERSE

      @repaint_required = false
    end
    def handle_keys ch
      return :UNHANDLED
    end
    
  end # class
end # module
