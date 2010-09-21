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
require 'ncurses'
require 'logger'
require 'rbcurse'

include Ncurses
include RubyCurses
include RubyCurses::Utils
module RubyCurses
  extend self

  ##
  #
  # @since 1.1.6
  # TODO - 
  # - stack and flow should be objects in Form, put in widget when creating
  # - box / rect
  # - animate(n) |i|
  # - para looks like a label that is more than one line, and calculates rows itself based on text
  # - combo
  # - popup
  # - multicontainer
  # - multitextview, multisplit
  # - tabbedpane
  # / table - more work regarding vim keys, also editable
  # - margin - is left offset
  #    http://lethain.com/entry/2007/oct/15/getting-started-shoes-os-x/
  # - promptmenu
  # - tree
  # - vimsplit
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
  class App
    attr_reader :config
    attr_reader :form
    attr_reader :window
    attr_writer :quit_key


    # i should be able to pass window coords here in config
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
      init_vars
      run &block
    end
    def init_vars
      @quit_key ||= KEY_F1
      # actually this should be maintained inside ncurses pack, so not loaded 2 times.
      # this way if we call an app from existing program, App won't start ncurses.
      unless $ncurses_started
        init_ncurses
      end
      unless $log
        $log = Logger.new((File.join(ENV["LOGDIR"] || "./" ,"view.log")))
        $log.level = Logger::DEBUG
        colors = Ncurses.COLORS
        $log.debug "START #{colors} colors  --------- #{$0}"
      end
    end
    def logger; return $log; end
    def close
      $log.debug " INSIDE CLOSE, #{@stop_ncurses_on_close} "
      @window.destroy if !@window.nil?
      $log.debug " INSIDE CLOSE, #{@stop_ncurses_on_close} "
      if @stop_ncurses_on_close
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
      while((ch = @window.getchar()) != @quit_key )
        str = keycode_tos ch
        @keyblock.call(str.gsub(/-/, "_").to_sym) if @keyblock
        $log.debug  "#{ch} got (#{str})"
        yield ch if block # <<<----
        @form.handle_key ch
        @form.repaint
        @window.wrefresh
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
      @message.value = text
    end
    def message_row row
      @message_label.row = row
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

      args.each do |arg| 
        case arg
        when Array
          #puts "row, col #{arg[0]} #{arg[1]} "
          # we can use r,c, w, h
          row, col, display_length = arg
          config[:row] = row
          config[:col] = col
          config[:display_length] = display_length if display_length
        when Hash
          config.merge!(arg)
          block_event = config.delete(:block_event){ block_event }
          raise "Invalid event. Use #{events}" unless events.include? block_event
          #puts "hash #{config}"
        when String
          title = arg
          config[:name] = title
        end
      end
      if @instack
        # most likely you won't have row and col. should we check or just go ahead
        col = @stack.last.margin
        config[:row] = @app_row
        config[:col] = col
        @app_row += 1
      end
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
      block_event = nil
      config = {}

      args.each do |arg| 
        case arg
        when Array
          row, col, display_length, height = arg
          config[:row] = row
          config[:col] = col
          config[:display_length] = display_length if display_length
          config[:height] = height || 1
        when Hash
          config.merge!(arg)
        when String
          config[:text] = arg
        end
      end
      config[:height] ||= 1
      if @instack
        # most likely you won't have row and col. should we check or just go ahead
        col = @stack.last.margin
        config[:row] = @app_row
        config[:col] = col
        @app_row += config[:height]
      end
      label = Label.new @form, config
      # shooz uses CHANGED, which is equivalent to our CHANGE. Our CHANGED means modified and exited
      return label
    end
    alias :text :label
    def button *args, &block
      config = {}
      events = [ :PRESS,  :LEAVE, :ENTER ]
      block_event = :PRESS

      #process_args args, config, block_event, events
      args.each do |arg| 
        case arg
        when Array
          #puts "row, col #{arg[0]} #{arg[1]} "
          # we can use r,c, w, h
          row, col, display_length, height = arg
          config[:row] = row
          config[:col] = col
          config[:display_length] = display_length if display_length
          config[:height] = height if height
        when Hash
          config.merge!(arg)
          block_event = config.delete(:block_event){ block_event }
          raise "Invalid event. Use #{events}" unless events.include? block_event
          #puts "hash #{config}"
        when String
          config[:text] = arg
          config[:name] = arg
        end
      end
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

      # TODO abstract this into a new method so no copying
      args.each do |arg| 
        case arg
        when Array
          #puts "row, col #{arg[0]} #{arg[1]} "
          # we can use r,c, w, h
          row, col, display_length, height = arg
          config[:row] = row
          config[:col] = col
          config[:display_length] = display_length if display_length
          config[:height] = height if height
        when Hash
          config.merge!(arg)
          block_event = config.delete(:block_event){ block_event }
          raise "Invalid event. Use #{events}" unless events.include? block_event
          #puts "hash #{config}"
        when String
          config[:name] = arg
          config[:title] = arg
        end
      end
      # naive defaults, since list could be large or have very long items
      # usually user will provide
      config[:height] ||= config[:list].length + 2
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
      row = @app_row
      width = config[:width] || 20
      _position config
      col = config[:col] || 1
      @window.mvwhline( row, col, ACS_HLINE, width)
      @app_row += 1
    end
    def app_header title, config={}, &block
      require 'rbcurse/applicationheader'
      header = ApplicationHeader.new @form, title, config, &block
    end
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

    # ADD new widget above this

    # @endgroup
    
    # @group positioning of components
    
    # line up vertically whatever comes in, ignoring r and c 
    # margin_top to add to margin of existing stack (if embedded) such as extra spacing
    # margin to add to margin of existing stack, or window (0)
    Stack = Struct.new(:margin_top, :margin, :width)
    def stack config={}, &block
      @instack = true
      mt =  config[:margin_top] || 1
      mr =  config[:margin] || 0
      # must take into account margin
      defw = Ncurses.COLS - mr
      w =   config[:width] || [50, defw].min
      s = Stack.new(mt, mr, w)
      @app_row += mt
      mr += @stack.last.margin if @stack.last
      #@stack << mr
      @stack << s
      instance_eval &block if block_given?
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
      instance_eval &block if block_given?
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
    def longest_in_list list
      longest = list.inject(0) do |memo,word|
        memo >= word.length ? memo : word.length
      end    
      longest
    end    
    # returns longest item
    def longest_in_list2 list
      longest = list.inject(list[0]) do |memo,word|
        memo.length >= word.length ? memo : word
      end    
      longest
    end    
    def run &block
      begin

        # check if user has passed window coord in config, else root window
        @window = VER::Window.root_window
        catch(:close) do
          @form = Form.new @window
          @message = Variable.new
          @message.value = "Message Comes Here"
          @message_label = RubyCurses::Label.new @form, {:text_variable => @message, :name=>"message_label",:row => Ncurses.LINES-1, :col => 0, :display_length => Ncurses.COLS,  :height => 1, :color => :white}
          $error_message.update_command { @message.set_value($error_message.value) }
          if block
            begin
              #yield(self, @window, @form)
              instance_eval &block if block_given?
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
                puts "=========="
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
    def _process_args args, config, block_event, events
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
    def _position config
      unless @current_object.empty?
        $log.debug " WWWW returning from position #{@current_object.last} "
        return
      end
      if @inflow
        #col = @flowstack.last
        config[:row] = @app_row
        config[:col] = @flowcol
        $log.debug " YYYY config #{config} "
        @flowcol += config[:text].length + 5 # 5 came from buttons
      elsif @instack
        # most likely you won't have row and col. should we check or just go ahead
        col = @stack.last.margin
        config[:row] = @app_row
        config[:col] = col
        @app_row += config[:height] || 1
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
