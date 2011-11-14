=begin
  * Name: App
  * Description: Experimental Application class
  * Author: rkumar (arunachalesha)
  * file created 2010-09-04 22:10 
Todo: 
  --------
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'logger'
require 'rbcurse'

require 'rbcurse/extras/bottomline'
$tt ||= RubyCurses::Bottomline.new 
$tt.name = "$tt"
require 'forwardable'
module Kernel
  extend Forwardable
  def_delegators :$tt, :ask, :say, :agree, :choose, :numbered_menu, :display_text, :display_text_interactive, :display_list, :say_with_pause, :hide_bottomline, :say_with_wait
end
include RubyCurses
include RubyCurses::Utils
include Io
module RubyCurses
  extend self

  ##
  #
  # @since 1.2.0
  # TODO - 
  # / combo
  # - popup
  # - promptmenu
  # - stack and flow should be objects in Form/App?, put in widget when creating
  # - box / rect
  # - para looks like a label that is more than one line, and calculates rows itself based on text
  # - multicontainer
  # - multitextview, multisplit
  # - tabbedpane
  # / table - more work regarding vim keys, also editable
  # - margin - is left offset
  #    http://lethain.com/entry/2007/oct/15/getting-started-shoes-os-x/
  #  
  
  class Widget
    def changed *args, &block
      bind :CHANGED, *args, &block
    end
    def leave *args, &block
      bind :LEAVE, *args, &block
    end
    def enter *args, &block
      bind :ENTER, *args, &block
    end
    # actually we already have command() for buttons
    def click *args, &block
      bind :PRESS, *args, &block
    end
  end
  class CheckBox
    # a little dicey XXX 
    def text(*val)
      if val.empty?
        @value ? @onvalue : @offvalue
      else
        super
      end
    end
  end
  # This is the Application class which does the job of setting up the 
  # environment, and closing it at the end.
  class App
    attr_reader :config
    attr_reader :form
    attr_reader :window
    attr_writer :quit_key
    # the row on which to prompt user for any inputs
    #attr_accessor :prompt_row # 2011-10-17 14:06:22

    extend Forwardable
    def_delegators :$tt, :ask, :say, :agree, :choose, :numbered_menu, :display_text, :display_text_interactive, :display_list

    # TODO: i should be able to pass window coords here in config
    # :title
    def initialize config={}, &block
      #$log.debug " inside constructor of APP #{config}  "
      @config = config
      @app_row = @app_col = 0
      @stack = [] # stack's coordinates
      @flowstack = []
      @variables = {}
      # if we are creating child objects then we will not use outer form. this object will manage
      @current_object = [] 
      @_system_commands = %w{ bind_global bind_component field_help_text }

      init_vars
      $log.debug "XXX APP CONFIG: #{@config}  " if $log.debug? 
      run &block
    end
    def init_vars
      @quit_key ||= FFI::NCurses::KEY_F10
      # actually this should be maintained inside ncurses pack, so not loaded 2 times.
      # this way if we call an app from existing program, App won't start ncurses.
      unless $ncurses_started
        init_ncurses
      end
      $lastline = Ncurses.LINES - 1
      #@message_row = Ncurses.LINES-1
      #@prompt_row = @message_row # hope to use for ask etc # 2011-10-17 14:06:27
      unless $log
        path = File.join(ENV["LOGDIR"] || "./" ,"rbc13.log")
        file   = File.open(path, File::WRONLY|File::TRUNC|File::CREAT) 
        $log = Logger.new(path)
        $log.level = Logger::DEBUG # change to warn when you've tested your app.
        colors = Ncurses.COLORS
        $log.debug "START #{colors} colors  --------- #{$0} win: #{@window} "
      end
    end
    def logger; return $log; end
    def close
      raw_message_destroy
      $log.debug " INSIDE CLOSE, #{@stop_ncurses_on_close} "
      @window.destroy if !@window.nil?
      $log.debug " INSIDE CLOSE, #{@stop_ncurses_on_close} "
      if @stop_ncurses_on_close
        $tt.destroy  # added on 2011-10-9 since we created a window, but only hid it after use
        VER::stop_ncurses
        $log.debug " CLOSING NCURSES"
      end
      #p $error_message.value unless $error_message.value.nil?
      $log.debug " CLOSING APP"
      #end
    end
    # not sure, but user shuld be able to trap keystrokes if he wants
    # but do i still call handle_key if he does, or give him total control.
    # But loop is already called by framework
    def loop &block
      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      @break_key = ?\C-q.getbyte(0)
      while((ch = @window.getchar()) != @quit_key )
        break if ch == @break_key

        if @keyblock
          str = keycode_tos ch
          @keyblock.call(str.gsub(/-/, "_").to_sym) # not used ever
        end

        yield ch if block # <<<----
        @form.handle_key ch
        #@form.repaint # was this duplicate ?? handle calls repaint not needed
        @window.wrefresh
      end
    end
    # if calling loop separately better to call this, since it will shut off ncurses
    # and print error on screen.
    def safe_loop &block
      begin
        loop &block
      rescue => ex
        $log.debug( "APP.rb rescue reached ")
        $log.debug( ex) if ex
        $log.debug(ex.backtrace.join("\n")) if ex
      ensure
        close
        # putting it here allows it to be printed on screen, otherwise it was not showing at all.
        if ex
          puts "========== EXCEPTION =========="
          p ex 
          puts "==============================="
          puts(ex.backtrace.join("\n")) 
        end
      end
    end
    # returns a symbol of the key pressed
    # e.g. :C_c for Ctrl-C
    # :Space, :bs, :M_d etc
    def keypress &block
     @keyblock = block
    end
    # updates a global var with text. Calling app has to set up a Variable with that name and attach to 
    # a label so it can be printed.
    def message text
      $status_message.value = text # trying out 2011-10-9 
      #@message.value = text # 2011-10-17 14:07:01
    end
    # @deprecated please use {#status_line} instead of a message label
    def message_row row
      raise "Please use create_message_label first as message_label is no longer default behaviour" unless @message_label
      @message_label.row = row 
    end
    # during a process, when you wish to update status, since ordinarily the thread is busy
    # and form does not get control back, so the window won't refresh.
    # This will only update on keystroke since it uses statusline
    # @deprecated please use {#status_line} instead of a message label
    def message_immediate text
      $log.warn "DEPRECATED, use message(), or say_with_pause, or say"
      $status_message.value = text # trying out 2011-10-9 user needs to use in statusline command
      # 2011-10-17 knocking off label, should be printed on status_line
    end
    # Usage: application is inside a long processing loop and wishes to print ongoing status
    # NOTE: if you use this, you must use raw_message_destroy at some stage, after processing
    # or on_leave of object.
    # @deprecated Use say_with_pause or use rdialogs status_window, see test2.rb
    def raw_message text, config={}, &blk
      $raw_window ||= one_line_window last_line(), config, &blk
      width = $raw_window.width == 0 ? FFI::NCurses.COLS : $raw_window.width
      text = "%-*s" % [width, text]
      
      $raw_window.attron(Ncurses.COLOR_PAIR($normalcolor) )
      $raw_window.printstring 0,0,text, $normalcolor #, 'normal' if @title
      $raw_window.wrefresh
     
    end
    def raw_message_destroy
      if $raw_window
        $raw_window.destroy
        $raw_window = nil
      end
    end
    # shows a simple progress bar on last row, using stdscr
    # @param [Float, Array<Fixnum,Fixnum>] percentage, or part/total
    # If Array of two numbers is given then also print part/total on left of bar
    # @deprecated - don't use stdscr at all, use rdialogs status_window (see test2.rb)
    def raw_progress arg
      $log.warning "WARNING: don't use this method as it uses stdscr"
      row = @message_label ? @message_label.row : Ncurses.LINES-1
      s = nil
      case arg
      when Array
        #calculate percentage
        pc = (arg[0]*1.0)/arg[1]
        # print items/total also
        s = "%-10s" % "(#{arg[0]}/#{arg[1]})"
      when
        Float
        pc = arg
      end
      scr = Ncurses.stdscr
      endcol = Ncurses.COLS-1
      startcol = endcol - 12
      stext = ("=" * (pc*10).to_i) 
      text = "[" + "%-10s" % stext + "]"
      Ncurses.mvprintw( row ,startcol-10, s) if s
      Ncurses.mvprintw row ,startcol, text
      #scr.refresh() # XXX FFI NW

    end
    # used only by LiveConsole, if enables in an app, usually only during testing.
    def get_binding
      return binding()
    end
    #
    # suspends curses so you can play around on the shell
    # or in cooked mode like Vim does. Expects a block to be passed.
    # Purpose: you can print some stuff without creating a window, or 
    # just run shell commands without coming out.
    # NOTE: if you pass clear as true, then the screen will be cleared
    # and you can use puts or print to print. You may have to flush.
    # However, with clear as false, the screen will not be cleared. You
    # will have to print using printw, and if you expect user input
    # you must do a "system /bin/stty sane"
    # If you print stuff, you will have to put a getch() or system("read")
    # to pause the screen.
    def suspend clear=true
      return unless block_given?
      Ncurses.def_prog_mode
      if clear
        Ncurses.endwin 
        # NOTE: avoid false since screen remains half off
        # too many issues
      else
        system "/bin/stty sane"
      end
      yield if block_given?
      Ncurses.reset_prog_mode
      if !clear
        # Hope we don't screw your terminal up with this constantly.
        VER::stop_ncurses
        VER::start_ncurses  
        #@form.reset_all # not required
      end
      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
    end
    def get_all_commands
      opts = @_system_commands.dup
      if respond_to? :get_commands
        opts.push(*get_commands())
      end
      opts
    end
    def display_app_help
      if respond_to? :help_text
        arr = help_text
      else
        arr = []
        arr << "    NO HELP SPECIFIED FOR APP "
        arr << "    "
        arr << "     --- General help ---          "
        arr << "    F10         -  exit application "
        arr << "    Alt-x       -  select commands  "
        arr << "    :           -  select commands  "
        arr << "    "
      end
      case arr
      when String
        arr = arr.split("\n")
      when Array
      end
      w = arr.max_by(&:length).length

      require 'rbcurse/extras/viewer'
      RubyCurses::Viewer.view(arr, :layout => [2, 10, [4+arr.size, 24].min, w+2],:close_key => KEY_RETURN, :title => "<Enter> to close", :print_footer => true) do |t|
      # you may configure textview further here.
      #t.suppress_borders true
      #t.color = :black
      #t.bgcolor = :white
      # or
      t.attr = :reverse
      end
    end
    # bind a key to a method at global (form) level
    # Note that individual component may be overriding this.
    # FIXME: why are we using rawmessage and then getchar when ask would suffice
    def bind_global
      opts = get_all_commands
      cmd = ask("Select a command (TAB for choices) : ", opts)
      if cmd.nil? || cmd == ""
        say_with_pause "Aborted."
        return
      end
      key = []
      str = ""
      raw_message "Enter one or 2 keys. Finish with ENTER. Enter first key:"
      #raw_message "Enter first key:"
      ch = @window.getchar()
      raw_message_destroy
      if [KEY_ENTER, 10, 13, ?\C-g.getbyte(0)].include? ch
        say_with_pause "Aborted."
        return
      end
      key << ch
      str << keycode_tos(ch)
      raw_message "Enter second key or hit return:"
      ch = @window.getchar()
      raw_message_destroy
      if ch == 3 || ch == ?\C-g.getbyte(0)
        say_with_pause "Aborted."
        return
      end
      if ch == 10 || ch == KEY_ENTER || ch == 13
      else
        key << ch
        str << keycode_tos(ch)
      end
      if !key.empty?
        say_with_pause "Binding #{cmd} to #{str} "
        key = key[0] if key.size == 1
        #@form.bind_key(key, cmd.to_sym) # not finding it, getting called by that comp
        @form.bind_key(key){ send(cmd.to_sym) }
      end
      #message "Bound #{str} to #{cmd} "
      raw_message_destroy
    end
    def bind_component
      say_with_pause "Todo. <press>"
      # the idea here is to get the current component
      # and bind some keys to some methods.
      # however, how do we divine the methods we can map to
      # and also in some cases the components itself has multiple components
    end
    # displays help_text associated with field. 2011-10-15 
    def field_help_text
      f = @form.get_current_field
      if f.respond_to?('help_text')
        h = f.help_text
        alert "#{h}"
      else
        alert "Could not get field #{f} or does not respond to helptext"
      end
    end
    # prompts user for a command. we need to get this back to the calling app
    # or have some block stuff TODO
    # Actually, this is naive, you would want to pass some values in like current data value
    # or lines ??
    # Also may want command completion, or help so all commands can be displayed
    def get_command_from_user choices=["quit"]
      #code, str = rbgetstr(@window, $lastline, 0, "", 80, :default => ":")
      #return unless code == 0
            @_command_history ||= Array.new
      str = ask("Cmd: ", choices) { |q| q.default = @_previous_command; q.history = @_command_history }
              @_command_history << str unless @_command_history.include? str
      # shell the command
      if str =~ /^!/
        str = str[1..-1]
        suspend(false) { 
          #system(str); 
          $log.debug "XXX STR #{str}  " if $log.debug? 

          output=`#{str}`
          system("echo ' ' ");
          $log.debug "XXX output #{output} " if $log.debug? 
          system("echo '#{output}' ");
          system("echo Press Enter to continue.");
          system("read"); 
        }
        return nil # i think
      else
        # TODO
        # here's where we can take internal commands
        #alert "[#{str}] string did not match :!"
        str = str.to_s #= str[1..-1]
        cmdline = str.split
        cmd = cmdline.shift #.to_sym
        return unless cmd # added 2011-09-11 FFI
        if respond_to?(cmd, true)
          if cmd == "close"
            throw :close # other seg faults in del_panel window.destroy executes 2x
          else
            res = send cmd, *cmdline
          end
        else
          alert "#{self.class} does not respond to #{cmd} "
          ret = false
          ret = execute_this(cmd, *cmdline) if respond_to?(:execute_this, true)
          say_with_pause("#{self.class} does not respond to #{cmd} ", :color_pair => $promptcolor) unless ret
          # should be able to say in red as error
        end
      end
    end
    #
    # @group methods to create widgets easily
    #
    # process arguments based on datatype, perhaps making configuration
    # of some components easier for caller avoiding too much boiler plate code
    # 
    # create a field
    def field *args, &block
      config = {}
      events = [ :CHANGED,  :LEAVE, :ENTER, :CHANGE ]
      block_event = :CHANGED # LEAVE, ENTER, CHANGE

      _process_args args, config, block_event, events
      config.delete(:title)
      _position config
      # hope next line doesn't bonk anything
      config[:display_length] ||= @stack.last.width if @stack.last # added here not sure 2010-11-17 18:43 
      field = Field.new @form, config
      # shooz uses CHANGED, which is equivalent to our CHANGE. Our CHANGED means modified and exited
      if block
        field.bind(block_event, &block)
      end
      return field
    end
      #instance_eval &block if block_given?
      # or
      #@blk = block # for later execution using @blk.call()
      #colorlabel = Label.new @form, {'text' => "Select a color:", "row" => row, "col" => col, "color"=>"cyan", "mnemonic" => 'S'}
      #var = RubyCurses::Label.new @form, {'text_variable' => $results, "row" => r, "col" => fc}

    def label *args
      events = block_event = nil
      config = {}
      _process_args args, config, block_event, events
      config[:text] ||= config[:name]
      config[:height] ||= 1
      config.delete(:title)
      _position(config)
      label = Label.new @form, config
      # shooz uses CHANGED, which is equivalent to our CHANGE. Our CHANGED means modified and exited
      return label
    end
    alias :text :label
    def button *args, &block
      config = {}
      events = [ :PRESS,  :LEAVE, :ENTER ]
      block_event = :PRESS

      _process_args args, config, block_event, events
      config[:text] ||= config[:name]
      config.delete(:title)
      # flow gets precedence over stack
      _position(config)
      button = Button.new @form, config
      # shooz uses CHANGED, which is equivalent to our CHANGE. Our CHANGED means modified and exited
      if block
        button.bind(block_event, &block)
      end
      return button
    end
    #
    # create a list
    # Since we are mouseless, one can traverse without selection. So we have a different
    # way of selecting row/s and traversal. XXX this aspect of LB's has always troubled me hugely.
    def list_box *args, &block
      config = {}
      # TODO confirm events
      # listdataevent has interval added and interval removed, due to multiple
      # selection, we have to make that simple for user here.
      events = [ :LEAVE, :ENTER, :ENTER_ROW, :LEAVE_ROW, :LIST_DATA_EVENT ]
      # TODO how to do this so he gets selected row easily
      block_event = :ENTER_ROW

      _process_args args, config, block_event, events
      # naive defaults, since list could be large or have very long items
      # usually user will provide
      if !config.has_key? :height
        ll = 0
        ll = config[:list].length + 2 if config.has_key? :list
        config[:height] ||= ll
        config[:height] = 15 if config[:height] > 20
      end
      if @current_object.empty?
        $log.debug "1 APP LB w: #{config[:width]} ,#{config[:name]} "
        config[:width] ||= @stack.last.width if @stack.last
        $log.debug "2 APP LB w: #{config[:width]} "
        config[:width] ||= longest_in_list(config[:list])+2
        $log.debug "3 APP LB w: #{config[:width]} "
      end
      # if no width given, expand to flows width XXX SHOULD BE NOT EXPAND ?
      #config[:width] ||= @stack.last.width if @stack.last
      #if config.has_key? :choose
      config[:default_values] = config.delete :choose
      # we make the default single unless specified
      config[:selection_mode] = :single unless config.has_key? :selection_mode
      if @current_object.empty?
      if @instack
        # most likely you won't have row and col. should we check or just go ahead
        col = @stack.last.margin
        config[:row] = @app_row
        config[:col] = col
        @app_row += config[:height] # this needs to take into account height of prev object
      end
      end
      useform = nil
      useform = @form if @current_object.empty?
      field = Listbox.new useform, config
      # shooz uses CHANGED, which is equivalent to our CHANGE. Our CHANGED means modified and exited
      if block
        # this way you can't pass params to the block
        field.bind(block_event, &block)
      end
      return field
    end
    
    # toggle button
    def toggle *args, &block
      config = {}
      # TODO confirm events
      events = [ :PRESS,  :LEAVE, :ENTER ]
      block_event = :PRESS
      _process_args args, config, block_event, events
      config[:text] ||= longest_in_list2( [config[:onvalue], config[:offvalue]])
        #config[:onvalue] # needed for flow, we need a better way FIXME
      _position(config)
      toggle = ToggleButton.new @form, config
      if block
        toggle.bind(block_event, &block)
      end
      return toggle
    end
    # check button
    def check *args, &block
      config = {}
      # TODO confirm events
      events = [ :PRESS,  :LEAVE, :ENTER ]
      block_event = :PRESS
      _process_args args, config, block_event, events
      _position(config)
      toggle = CheckBox.new @form, config
      if block
        toggle.bind(block_event, &block)
      end
      return toggle
    end
    # radio button
    def radio *args, &block
      config = {}
      # TODO confirm events
      events = [ :PRESS,  :LEAVE, :ENTER ]
      block_event = :PRESS
      _process_args args, config, block_event, events
      a = config[:group]
      # FIXME we should check if user has set a varialbe in :variable.
      # we should create a variable, so he can use it if he wants.
      if @variables.has_key? a
        v = @variables[a]
      else
        v = Variable.new
        @variables[a] = v
      end
      config[:variable] = v
      config.delete(:group)
      _position(config)
      radio = RadioButton.new @form, config
      if block
        radio.bind(block_event, &block)
      end
      return radio
    end
    # editable text area
    def textarea *args, &block
      require 'rbcurse/rtextarea'
      config = {}
      # TODO confirm events many more
      events = [ :CHANGE,  :LEAVE, :ENTER ]
      block_event = events[0]
      _process_args args, config, block_event, events
      config[:width] = config[:display_length] unless config.has_key? :width
      _position(config)
      # if no width given, expand to flows width
      config[:width] ||= @stack.last.width if @stack.last
      useform = nil
      useform = @form if @current_object.empty?
      w = TextArea.new useform, config
      if block
        w.bind(block_event, &block)
      end
      return w
    end
    # similar definitions for textview and resultsettextview
    # NOTE This is not allowing me to send blocks,
    # so do not use for containers
    {
      'rbcurse/rtextview' => 'TextView',
      'rbcurse/experimental/resultsettextview' => 'ResultsetTextView',
      'rbcurse/rcontainer' => 'Container',
      'rbcurse/extras/rcontainer2' => 'Container2',
    }.each_pair {|k,p|
      eval(
           "def #{p.downcase} *args, &block
              require \"#{k}\"
      config = {}
      # TODO confirm events many more
      events = [ :PRESS, :LEAVE, :ENTER ]
      block_event = events[0]
      _process_args args, config, block_event, events
      config[:width] = config[:display_length] unless config.has_key? :width
      _position(config)
      # if no width given, expand to flows width
      config[:width] ||= @stack.last.width if @stack.last
      raise \"height needed for #{p.downcase}\" if !config.has_key? :height
      useform = nil
      useform = @form if @current_object.empty?
      w = #{p}.new useform, config
      if block
        w.bind(block_event, &block)
      end
      return w
           end"
           )
    }
    # progress bar
    def progress *args, &block
      require 'rbcurse/rprogress'
      config = {}
      # TODO confirm events many more
      events = [ :CHANGE,  :LEAVE, :ENTER ]
      block_event = nil
      _process_args args, config, block_event, events
      config[:width] = config[:display_length] || 10 unless config.has_key? :width
      _position(config)
      w = Progress.new @form, config
      #if block
        #w.bind(block_event, &block)
      #end
      return w
    end
    
    # table widget
    # @example
    #  data = [["Roger",16,"SWI"], ["Phillip",1, "DEU"]]
    #  colnames = ["Name", "Wins", "Place"]
    #  t = table :width => 40, :height => 10, :columns => colnames, :data => data, :estimate_widths => true
    #    other options are :column_widths => [12,4,12]
    #    :size_to_fit => true
    def table *args, &block
      require 'rbcurse/rtable'
      config = {}
      # TODO confirm events many more
      events = [ :ENTER_ROW,  :LEAVE, :ENTER ]
      block_event = events[0]
      _process_args args, config, block_event, events
      # if user is leaving out width, then we don't want it in config
      # else Widget will put a value of 10 as default, overriding what we've calculated
      if config.has_key? :display_length
        config[:width] = config[:display_length] unless config.has_key? :width
      end
      ext = config.delete :extended_keys

      model = nil
      _position(config)
      # if no width given, expand to flows width
      config[:width] ||= @stack.last.width if @stack.last
      w = Table.new @form, config
      if ext
        require 'rbcurse/extras/tableextended' 
          # so we can increase and decrease column width using keys
        w.extend TableExtended
        w.bind_key(?w){ w.next_column }
        w.bind_key(?b){ w.previous_column }
        w.bind_key(?+) { w.increase_column }
        w.bind_key(?-) { w.decrease_column }
        w.bind_key([?d, ?d]) { w.table_model.delete_at w.current_index }
        w.bind_key(?u) { w.table_model.undo w.current_index}
      end
      if block
        w.bind(block_event, &block)
      end
      return w
    end
    # print a title on first row
    def title string, config={}
      ## TODO center it
      @window.printstring 1, 30, string, $normalcolor, 'reverse'
    end
    # print a sutitle on second row
    def subtitle string, config={}
      @window.printstring 2, 30, string, $datacolor, 'normal'
    end
    # menu bar
    def menubar &block
      require 'rbcurse/rmenu'
      RubyCurses::MenuBar.new &block
    end

    # creates a blank row
    def blank rows=1, config={}
      @app_row += rows
    end
    # displays a horizontal line
    # takes col (column to start from) from current stack
    # take row from app_row
    #
    # requires width to be passed in config, else defaults to 20
    # @example
    #    hline :width => 55  
    def hline config={}
      row = config[:row] || @app_row
      width = config[:width] || 20
      _position config
      col = config[:col] || 1
      @color_pair = config[:color_pair] || $datacolor
      @attrib = config[:attrib] || Ncurses::A_NORMAL
      @window.attron(Ncurses.COLOR_PAIR(@color_pair) | @attrib)
      @window.mvwhline( row, col, FFI::NCurses::ACS_HLINE, width)
      @window.attron(Ncurses.COLOR_PAIR(@color_pair) | @attrib)
      @app_row += 1
    end
    def app_header title, config={}, &block
      require 'rbcurse/applicationheader'
      header = ApplicationHeader.new @form, title, config, &block
    end
    
    # prints pine-like key labels
    def dock labels, config={}, &block
      require 'rbcurse/keylabelprinter'
      klp = RubyCurses::KeyLabelPrinter.new @form, labels, config, &block
    end

    def link *args, &block
      require 'rbcurse/extras/rlink'
      config = {}
      events = [ :PRESS,  :LEAVE, :ENTER ]
      block_event = :PRESS
      _process_args args, config, block_event, events
      _position(config)
      config[:text] ||= config.delete :title
      config[:highlight_foreground] = "yellow"
      config[:highlight_background] = "red"
      toggle = Link.new @form, config
      if block
        toggle.bind(block_event, toggle, &block)
      end
      return toggle
    end
    def menulink *args, &block
      require 'rbcurse/extras/rmenulink'
      config = {}
      events = [ :PRESS,  :LEAVE, :ENTER ]
      block_event = :PRESS
      _process_args args, config, block_event, events
      _position(config)
      config[:text] ||= config.delete :title
      config[:highlight_foreground] = "yellow"
      config[:highlight_background] = "red"
      toggle = MenuLink.new @form, config
      if block
        toggle.bind(block_event, toggle, &block)
      end
      return toggle
    end
    def splitpane *args, &block
      require 'rbcurse/rsplitpane2'
      config = {}
      events = [ :PROPERTY_CHANGE,  :LEAVE, :ENTER ]
      block_event = events[0]
      _process_args args, config, block_event, events
      _position(config)
      # if no width given, expand to flows width
      config[:width] ||= @stack.last.width if @stack.last
      config.delete :title
      useform = nil
      useform = @form if @current_object.empty?

      w = SplitPane.new useform, config
      #if block
        #w.bind(block_event, w, &block)
      #end
      if block_given?
        @current_object << w
        #instance_eval &block if block_given?
        yield w
        @current_object.pop
      end
      return w
    end
    def multisplit *args, &block
      require 'rbcurse/rmultisplit'
      config = {}
      events = [ :PROPERTY_CHANGE,  :LEAVE, :ENTER ]
      block_event = events[0]
      _process_args args, config, block_event, events
      _position(config)
      # if no width given, expand to flows width
      config[:width] ||= @stack.last.width if @stack.last
      config.delete :title
      useform = nil
      useform = @form if @current_object.empty?

      w = MultiSplit.new useform, config
      #if block
        #w.bind(block_event, w, &block)
      #end
      if block_given?
        @current_object << w
        #instance_eval &block if block_given?
        yield w
        @current_object.pop
      end
      return w
    end
    def tree *args, &block
      require 'rbcurse/rtree'
      config = {}
      events = [:TREE_WILL_EXPAND_EVENT, :TREE_EXPANDED_EVENT, :TREE_SELECTION_EVENT, :PROPERTY_CHANGE, :LEAVE, :ENTER ]
      block_event = nil
      _process_args args, config, block_event, events
      config[:height] ||= 10
      _position(config)
      # if no width given, expand to flows width
      config[:width] ||= @stack.last.width if @stack.last
      #config.delete :title
      useform = nil
      useform = @form if @current_object.empty?

      w = Tree.new useform, config, &block
      return w
    end
    def vimsplit *args, &block
      require 'rbcurse/rvimsplit'
      config = {}
      #TODO check these
      events = [:PROPERTY_CHANGE, :LEAVE, :ENTER ]
      block_event = nil
      _process_args args, config, block_event, events
      config[:height] ||= 10
      _position(config)
      # if no width given, expand to flows width
      config[:width] ||= @stack.last.width if @stack.last
      #config.delete :title
      useform = nil
      useform = @form if @current_object.empty?

      w = VimSplit.new useform, config # NO BLOCK GIVEN
      if block_given?
        @current_object << w
        #instance_eval &block if block_given?
        yield w
        @current_object.pop
      end
      return w
    end
    # create a readonly list
    def basiclist *args, &block
      require 'rbcurse/rbasiclistbox'
      config = {}
      #TODO check these
      events = [ :LEAVE, :ENTER, :ENTER_ROW, :LEAVE_ROW, :LIST_DATA_EVENT ]
      # TODO how to do this so he gets selected row easily
      block_event = :ENTER_ROW
      _process_args args, config, block_event, events
      # some guesses at a sensible height for listbox
      if !config.has_key? :height
        ll = 0
        ll = config[:list].length + 2 if config.has_key? :list
        config[:height] ||= ll
        config[:height] = 15 if config[:height] > 20
      end
      _position(config)
      # if no width given, expand to flows width
      config[:width] ||= @stack.last.width if @stack.last
      config[:width] ||= longest_in_list(config[:list])+2
      #config.delete :title
      #config[:default_values] = config.delete :choose
      config[:selection_mode] = :single unless config.has_key? :selection_mode
      useform = nil
      useform = @form if @current_object.empty?

      w = BasicListbox.new useform, config # NO BLOCK GIVEN
      if block_given?
        field.bind(block_event, &block)
      end
      return w
    end
    def master_detail *args, &block
      require 'rbcurse/extras/masterdetail'
      config = {}
      events = [:PROPERTY_CHANGE, :LEAVE, :ENTER ]
      block_event = nil
      _process_args args, config, block_event, events
      #config[:height] ||= 10
      _position(config)
      # if no width given, expand to flows width
      config[:width] ||= @stack.last.width if @stack.last
      #config.delete :title
      useform = nil
      useform = @form if @current_object.empty?

      w = MasterDetail.new useform, config # NO BLOCK GIVEN
      if block_given?
        @current_object << w
        yield_or_eval &block
        @current_object.pop
      end
      return w
    end
    # creates a simple readonly table, that allows users to click on rows
    # and also on the header. Header clicking is for column-sorting.
    def tabular_widget *args, &block
      require 'rbcurse/extras/tabularwidget'
      config = {}
      events = [:PROPERTY_CHANGE, :LEAVE, :ENTER, :CHANGE, :ENTER_ROW, :PRESS ]
      block_event = nil
      _process_args args, config, block_event, events
      config[:height] ||= 10 # not sure if this should be here
      _position(config)
      # if no width given, expand to stack width
      config[:width] ||= @stack.last.width if @stack.last
      #config.delete :title
      useform = nil
      useform = @form if @current_object.empty?

      w = TabularWidget.new useform, config # NO BLOCK GIVEN
      if block_given?
        @current_object << w
        yield_or_eval &block
        @current_object.pop
      end
      return w
    end
    # scrollbar attached to the right of a parent object
    def scrollbar *args, &block
      require 'rbcurse/extras/scrollbar'
      config = {}
      events = [:PROPERTY_CHANGE, :LEAVE, :ENTER  ] # # none really at present
      block_event = nil
      _process_args args, config, block_event, events
      raise "parent needed for scrollbar" if !config.has_key? :parent
      useform = nil
      useform = @form if @current_object.empty?
      sb = Scrollbar.new useform, config
    end
    # divider used to resize neighbouring components TOTEST XXX
    def divider *args, &block
      require 'rbcurse/extras/divider'
      config = {}
      events = [:PROPERTY_CHANGE, :LEAVE, :ENTER, :DRAG_EVENT  ] # # none really at present
      block_event = nil
      _process_args args, config, block_event, events
      useform = nil
      useform = @form if @current_object.empty?
      sb = Divider.new useform, config
    end
    # creates a simple readonly table, that allows users to click on rows
    # and also on the header. Header clicking is for column-sorting.
    def combo *args, &block
      require 'rbcurse/rcombo'
      config = {}
      events = [:PROPERTY_CHANGE, :LEAVE, :ENTER, :CHANGE, :ENTER_ROW, :PRESS ] # XXX
      block_event = nil
      _process_args args, config, block_event, events
      _position(config)
      # if no width given, expand to flows width
      config[:width] ||= @stack.last.width if @stack.last
      #config.delete :title
      useform = nil
      useform = @form if @current_object.empty?

      w = ComboBox.new useform, config # NO BLOCK GIVEN
      if block_given?
        @current_object << w
        yield_or_eval &block
        @current_object.pop
      end
      return w
    end

    # ADD new widget above this

    # @endgroup
    
    # @group positioning of components
    
    # line up vertically whatever comes in, ignoring r and c 
    # margin_top to add to margin of existing stack (if embedded) such as extra spacing
    # margin to add to margin of existing stack, or window (0)
    # NOTE: since these coordins are calculated at start
    # therefore if window resized i can't recalculate.
    Stack = Struct.new(:margin_top, :margin, :width)
    def stack config={}, &block
      @instack = true
      mt =  config[:margin_top] || 1
      mr =  config[:margin] || 0
      # must take into account margin
      defw = Ncurses.COLS - mr
      config[:width] = defw if config[:width] == :EXPAND
      w =   config[:width] || [50, defw].min
      s = Stack.new(mt, mr, w)
      @app_row += mt
      mr += @stack.last.margin if @stack.last
      @stack << s
      yield_or_eval &block if block_given?
      @stack.pop
      @instack = false if @stack.empty?
      @app_row = 0 if @stack.empty?
    end
    # keep adding to right of previous and when no more space
    # move down and continue fitting in.
    # Useful for button positioning. Currently, we can use a second flow
    # to get another row.
    # TODO: move down when row filled
    # TODO: align right, center
    def flow config={}, &block
      @inflow = true
      mt =  config[:margin_top] || 0
      @app_row += mt
      col = @flowstack.last || @stack.last.margin || @app_col
      col += config[:margin] || 0
      @flowstack << col
      @flowcol = col
      yield_or_eval &block if block_given? 
      @flowstack.pop
      @inflow = false if @flowstack.empty?
    end

    private
    def quit
      throw(:close)
    end
    # Initialize curses
    def init_ncurses
      VER::start_ncurses  # this is initializing colors via ColorMap.setup
      #$ncurses_started = true
      @stop_ncurses_on_close = true
    end

    # returns length of longest
    def longest_in_list list  #:nodoc:
      longest = list.inject(0) do |memo,word|
        memo >= word.length ? memo : word.length
      end    
      longest
    end    
    # returns longest item
    # rows = list.max_by(&:length)
    #
    def longest_in_list2 list  #:nodoc:
      longest = list.inject(list[0]) do |memo,word|
        memo.length >= word.length ? memo : word
      end    
      longest
    end    

    # if partial command entered then returns matches
    def _resolve_command opts, cmd
      return cmd if opts.include? cmd
      matches = opts.grep Regexp.new("^#{cmd}")
    end
    # Now i am not creating this unless user wants it. Pls avoid it.
    # Use either say_with_pause, or put $status_message in command of statusline
    # @deprecated please use {#status_line} instead of a message label
    def create_message_label row=Ncurses.LINES-1
      @message_label = RubyCurses::Label.new @form, {:text_variable => @message, :name=>"message_label",:row => row, :col => 0, :display_length => Ncurses.COLS,  :height => 1, :color => :white}
    end

    def run &block
      begin

        # check if user has passed window coord in config, else root window
        @window = VER::Window.root_window
        awin = @window
        catch(:close) do
          @form = Form.new @window
          @form.bind_key([?\C-x, ?c]) { suspend(false) do
            system("tput cup 26 0")
            system("tput ed")
            system("echo Enter C-d to return to application")
            system (ENV['PS1']='\s-\v\$ ')
            system(ENV['SHELL']);
          end
          }
          # this is a very rudimentary default command executer, it does not 
          # allow tab completion. App should use M-x with names of commands
          # as in appgmail
          @form.bind_key(?:) { 
            str = get_command_from_user
          }

          @form.bind_key(?\M-x){
            # TODO previous command to be default
            opts = get_all_commands()
            @_command_history ||= Array.new
            # previous command should be in opts, otherwise it is not in this context
            cmd = ask("Command: ", opts){ |q| q.default = @_previous_command; q.history = @_command_history }
            if cmd.nil? || cmd == ""
            else
              @_command_history << cmd unless @_command_history.include? cmd
              cmdline = cmd.split
              cmd = cmdline.shift
              # check if command is a substring of a larger command
              if !opts.include?(cmd)
                rcmd = _resolve_command(opts, cmd) if !opts.include?(cmd)
                if rcmd.size == 1
                  cmd = rcmd.first
                elsif !rcmd.empty?
                  say_with_pause "Cannot resolve #{cmd}. Matches are: #{rcmd} "
                end
              end
              if respond_to?(cmd, true)
                @_previous_command = cmd
                #raw_message "calling #{cmd} "
                begin
                  send cmd, *cmdline
                rescue => exc
                  $log.error "ERR EXC: send throwing an exception now. Duh. IMAP keeps crashing haha !! #{exc}  " if $log.debug? 
                  if exc
                    $log.debug( exc) 
                    $log.debug(exc.backtrace.join("\n")) 
                    say_with_pause exc.to_s
                  end
                end
              else
                say_with_pause("Command [#{cmd}] not supported by #{self.class} ", :color_pair => $promptcolor)
              end
            end
          }
          @form.bind_key(KEY_F1){ display_app_help }
          @form.bind_key([?q,?q]){ throw :close } if $log.debug?

          #@message = Variable.new
          #@message.value = ""
          $status_message ||= Variable.new # remember there are multiple levels of apps
          $status_message.value = ""
          #$error_message.update_command { @message.set_value($error_message.value) }
          if block
            begin
              #yield(self, @window, @form)
              #instance_eval &block if block_given?
              yield_or_eval &block if block_given? # modified 2010-11-17 20:36 
              loop
            rescue => ex
              $log.debug( "APP.rb rescue reached ")
              $log.debug( ex) if ex
              $log.debug(ex.backtrace.join("\n")) if ex
            ensure
              close
              # putting it here allows it to be printed on screen, otherwise it was not showing at all.
              if ex
                puts "========== EXCEPTION =========="
                p ex 
                puts "==============================="
                puts(ex.backtrace.join("\n")) 
              end
            end
            nil
          else
            #@close_on_terminate = true
            self
          end #if block
        end
      end
    end
    # TODO
    # process args, all widgets should call this
    def _process_args args, config, block_event, events  #:nodoc:
      args.each do |arg| 
        case arg
        when Array
          # we can use r,c, w, h
          row, col, display_length, height = arg
          config[:row] = row
          config[:col] = col
          config[:display_length] = display_length if display_length
          config[:width] = display_length if display_length
          # width for most XXX ?
          config[:height] = height if height
        when Hash
          config.merge!(arg)
          if block_event 
            block_event = config.delete(:block_event){ block_event }
            raise "Invalid event. Use #{events}" unless events.include? block_event
          end
        when String
          config[:name] = arg
          config[:title] = arg # some may not have title
          #config[:text] = arg # some may not have title
        end
      end
    end # _process
    # position object based on whether in a flow or stack.
    # @app_row is prepared for next object based on this objects ht
    def _position config  #:nodoc:
      unless @current_object.empty?
        $log.debug " WWWW returning from position #{@current_object.last} "
        return
      end
      if @inflow
        #col = @flowstack.last
        config[:row] = @app_row
        config[:col] = @flowcol
        $log.debug " YYYY config #{config} "
        if config[:text]
          @flowcol += config[:text].length + 5 # 5 came from buttons
        else
          @flowcol += (config[:length] || 10) + 5 # trying out for combo
        end
      elsif @instack
        # most likely you won't have row and col. should we check or just go ahead
        # what if he has put it 2011-10-19 as in a container
        col = @stack.last.margin
        config[:row] ||= @app_row 
        config[:col] ||= col
        @app_row += config[:height] || 1 #unless config[:no_advance]
        # TODO need to allow stack to have its spacing, but we don't have an object as yet.
      end
    end
  end # class
end # module 
if $0 == __FILE__
  include RubyCurses
  #app = App.new
  #window = app.window
  #window.printstring 2, 30, "Demo of Listbox - rbcurse", $normalcolor, 'reverse'
  #app.logger.info "beforegetch"
  #window.getch
  #app.close
  # this was the yield example, but now we've moved to instance eval
  App.new do 
    @window.printstring 0, 30, "Demo of Listbox - rbcurse", $normalcolor, 'reverse'
    @window.printstring 1, 30, "Hit F1 to quit", $datacolor, 'normal'
    form = @form
    fname = "Search"
    r, c = 7, 30
    c += fname.length + 1
    #field1 = field( [r,c, 30], fname, :bgcolor => "cyan", :block_event => :CHANGE) do |fld|
    stack :margin_top => 2, :margin => 10 do
      lbl = label({:text => fname, :color=>'white',:bgcolor=>'red', :mnemonic=> 's'})
      field1 = field( [r,c, 30], fname, :bgcolor => "cyan",:block_event => :CHANGE) do |fld|
        message("You entered #{fld.getvalue}. To quit enter quit and tab out")
        if fld.getvalue == "quit"
          logger.info "you typed quit!" 
          throw :close
        end
      end
      #field1.set_label Label.new @form, {:text => fname, :color=>'white',:bgcolor=>'red', :mnemonic=> 's'}
      field1.set_label( lbl )
      field1.enter do 
        message "you entered this field"
      end

      stack :margin_top => 2, :margin => 0 do
        #label( [8, 30, 60],{:text => "A label", :color=>'white',:bgcolor=>'blue'} )
      end

      @bluelabel = label( [8, 30, 60],{:text => "B label", :color=>'white',:bgcolor=>'blue'} )

      stack :margin_top => 2, :margin => 0 do
        toggle :onvalue => " Toggle Down ", :offvalue => "  Untoggle   ", :mnemonic => 'T', :value => true

        toggle :onvalue => " On  ", :offvalue => " Off ", :value => true do |e|
          alert "You pressed me #{e.state}"
        end
        check :text => "Check me!", :onvalue => "Checked", :offvalue => "Unchecked", :value => true do |e|
          # this works but long and complicated
          #@bluelabel.text = e.item.getvalue ? e.item.onvalue : e.item.offvalue
          @bluelabel.text = e.item.text
        end
        radio :text => "red", :value => "RED", :color => "red", :group => :colors
        radio :text => "green", :value => "GREEN", :color => "green", :group => :colors
        flow do
          button_row = 17
          ok_button = button( [button_row,30], "OK", {:mnemonic => 'O'}) do 
            alert("About to dump data into log file!")
            message "Dumped data to log file"
          end

          # using ampersand to set mnemonic
          cancel_button = button( [button_row, 40], "&Cancel" ) do
            if confirm("Do your really want to quit?")== :YES
              #throw(:close); 
              quit
            else
              message "Quit aborted"
            end
          end # cancel
          button "Don't know"
        end
        flow :margin_top => 2 do
          button "Another"
          button "Line"
        end
        stack :margin_top => 2, :margin => 0 do
          @pbar = progress :width => 20, :bgcolor => 'white', :color => 'red'
          @pbar1 = progress :width => 20, :style => :old
        end
      end
    end # stack
    # lets make another column
    stack :margin_top => 2, :margin => 70 do
      l = label "Column 2"
      f1 = field "afield", :bgcolor => 'white', :color => 'black'
      list_box "A list", :list => ["Square", "Oval", "Rectangle", "Somethinglarge"], :choose => ["Square"]
      lb = list_box "Another", :list => ["Square", "Oval", "Rectangle", "Somethinglarge"] do |list|
        #f1.set_buffer list.text
        #f1.text list.text
        f1.text = list.text
        l.text = list.text.upcase
      end
      t = textarea :height => 10 do |e|
        #@bluelabel.text = e.to_s.tr("\n",' ')
        @bluelabel.text = e.text.gsub("\n"," ")
        len = e.source.get_text.length
        len = len % 20 if len > 20
        $log.debug " PBAR len of text is #{len}: #{len/20.0} "
        @pbar.fraction(len/20.0)
        @pbar1.fraction(len/20.0)
        i = ((len/20.0)*100).to_i
        @pbar.text = "completed:#{i}"
      end
      t.leave do |c|
        @bluelabel.text = c.get_text.gsub("\n"," ")
      end

    end

    # Allow user to get the keys
    keypress do |key|
      if key == :C_c
        message "You tried to cancel"
        #throw :close
        quit
      else
        #app.message "You pressed #{key}, #{char} "
        message "You pressed #{key}"
      end
    end
  end
end
