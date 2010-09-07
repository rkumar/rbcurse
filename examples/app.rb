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
#require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'

include Ncurses
include RubyCurses
include RubyCurses::Utils
module RubyCurses
  extend self

  ##
  # A MultiSplit allows user to split N components vertically or horizontally.
  # such as 3 listboxes, each dependent on what is selected in previous.
  # This is the column-browse pattern, as in ruby's rdoc when seen in a browser.
  # Also, this can be used for directory browsing, as in OSX Finder.
  # At some point, it should be possible to keep adding components, and to scroll
  # back and forth, so we can have more components than are visible.
  #
  # @since 1.1.6
  # TODO - 
  # - stack and flow should be objects in Form, put in widget when creating
  # x method: quit
  # - box / rect
  # - animate(n) |i|
  # - move
  # x list_box :choose is the defauly
  # - progress - like a label but fills itself, fraction
  # - para looks like a label that is more than one line, and calculates rows itself based on text
  # - edit_line = fiekd
  # x other buttons: radio, check
  # x edit_box = textarea
  # - combo
  # - menu
  # - table
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
  #class Listbox
    #def text
      #return get_content()[@current_index]
    #end
  #end
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
      #instance_eval &block if block_given?
      @variables = {}
      init_vars
      run &block
    end
    def init_vars
      @quit_key ||= KEY_F1
    end
    def logger; return $log; end
    def close
      #if @close_on_terminate
      @window.destroy if !@window.nil?
      VER::stop_ncurses
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
    def message text
      $message.value = text
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
        col = @stack.last
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
      #message_label = RubyCurses::Label.new @form, {'text_variable' => $message, "name"=>"message_label","row" => 27, "col" => 1, "display_length" => 60,  "height" => 2, 'color' => 'cyan'}

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
        col = @stack.last
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
      config[:width] ||= longest_in_list(config[:list])+2
      #if config.has_key? :choose
      config[:default_values] = config.delete :choose
      # we make the default single unless specified
      config[:selection_mode] = :single unless config.has_key? :selection_mode
      if @instack
        # most likely you won't have row and col. should we check or just go ahead
        col = @stack.last
        config[:row] = @app_row
        config[:col] = col
        @app_row += config[:height] # this needs to take into account height of prev object
      end
      field = Listbox.new @form, config
      # shooz uses CHANGED, which is equivalent to our CHANGE. Our CHANGED means modified and exited
      if block
        field.bind(block_event, &block)
      end
      return field
    end
    
    def toggle *args, &block
      config = {}
      # TODO confirm events
      events = [ :PRESS,  :LEAVE, :ENTER ]
      block_event = :PRESS
      _process_args args, config, block_event, events
      _position(config)
      toggle = ToggleButton.new @form, config
      if block
        toggle.bind(block_event, &block)
      end
      return toggle
    end
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
    def textarea *args, &block
      require 'rbcurse/rtextarea'
      config = {}
      # TODO confirm events many more
      events = [ :CHANGE,  :LEAVE, :ENTER ]
      block_event = events[0]
      _process_args args, config, block_event, events
      config[:width] = config[:display_length] || 10 unless config.has_key? :width
      _position(config)
      w = TextArea.new @form, config
      if block
        w.bind(block_event, &block)
      end
      return w
    end
    

    # ADD new widget above this

    # @endgroup
    
    # @group positioning of components
    
    # line up vertically whatever comes in, ignoring r and c 
    # margin_top to add to margin of existing stack (if embedded) such as extra spacing
    # margin to add to margin of existing stack, or window (0)
    def stack config={}, &block
      @instack = true
      mt =  config[:margin_top] || 1
      mr =  config[:margin] || 0
      @app_row += mt
      mr += @stack.last if @stack.last
      @stack << mr
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
    def flow config={}, &block
      @inflow = true
      mt =  config[:margin_top] || 0
      @app_row += mt
      col = @flowstack.last || @stack.last || @app_col
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

    def longest_in_list list
      longest = list.inject(0) do |memo,word|
        memo >= word.length ? memo : word.length
      end    
      longest
    end    
    def run &block
      begin
        # Initialize curses
        VER::start_ncurses  # this is initializing colors via ColorMap.setup
        $log = Logger.new((File.join(ENV["LOGDIR"] || "./" ,"view.log")))
        $log.level = Logger::DEBUG

        # check if user has passed window coord in config, else root window
        @window = VER::Window.root_window
        catch(:close) do
          colors = Ncurses.COLORS
          $log.debug "START #{colors} colors  --------- #{$0}"
          @form = Form.new @window
          $message = Variable.new
          $message.value = "Message Comes Here"
          message_label = RubyCurses::Label.new @form, {'text_variable' => $message, "name"=>"message_label","row" => 25, "col" => 1, "display_length" => 60,  "height" => 1, 'color' => 'cyan'}
          if block
            begin
              #yield(self, @window, @form)
              instance_eval &block if block_given?
              loop
            rescue => ex
              p ex if ex
              p(ex.backtrace.join("\n")) if ex
              $log.debug( ex) if ex
              $log.debug(ex.backtrace.join("\n")) if ex
            ensure
              close
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
        end
      end
    end # _process
    # position object based on whether in a flow or stack.
    # @app_row is prepared for next object based on this objects ht
    def _position config
      if @inflow
        #col = @flowstack.last
        config[:row] = @app_row
        config[:col] = @flowcol
        @flowcol += config[:text].length + 5 # 5 came from buttons
      elsif @instack
        # most likely you won't have row and col. should we check or just go ahead
        col = @stack.last
        config[:row] = @app_row
        config[:col] = col
        @app_row += config[:height] || 1
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
    @window.printstring 2, 30, "Demo of Listbox - rbcurse", $normalcolor, 'reverse'
    @window.printstring 5, 30, "Hit F1 to quit", $datacolor, 'normal'
    form = @form
    fname = "Search"
    r, c = 7, 30
    c += fname.length + 1
    #field1 = field( [r,c, 30], fname, :bgcolor => "cyan", :block_event => :CHANGE) do |fld|
    stack :margin_top => 2, :margin => 10 do
      lbl = label({:text => fname, :color=>'white',:bgcolor=>'red', :mnemonic=> 's'})
      field1 = field( [r,c, 30], fname, :bgcolor => "cyan") do |fld|
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
        label( [8, 30, 60],{:text => "A label", :color=>'white',:bgcolor=>'blue'} )
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
              $message.value = "Quit aborted"
            end
          end # cancel
          button "Don't know"
        end
        flow :margin_top => 2 do
          button "Another"
          button "Line"
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
      t = textarea :width => 12, :height => 10 do |e|
        #@bluelabel.text = e.to_s.tr("\n",' ')
        @bluelabel.text = e.text.gsub("\n"," ")
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
