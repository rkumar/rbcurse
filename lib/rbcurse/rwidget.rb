=begin
  * Name: rwidget: base class and then basic widgets like field, button and label
  * Description   
    Some simple light widgets for creating ncurses applications. No reliance on ncurses
    forms and fields.
        I expect to pass through this world but once. Any good therefore that I can do, 
        or any kindness or ablities that I can show to any fellow creature, let me do it now. 
        Let me not defer it or neglect it, for I shall not pass this way again.  
  * Author: rkumar (arunachalesha)
  * Date: 2008-11-19 12:49 
  * License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
  * Last update: 2011-11-08 - 16:55

  == CHANGES
  * 2011-10-2 Added PropertyVetoException to rollback changes to property
  * 2011-10-2 Returning self from dsl_accessor and dsl_property for chaining
  * 2011-10-2 removing clutter of buffering, a lot of junk code removed too.
  == TODO 
  - make some methods private/protected
  - Add bottom bar also, perhaps allow it to be displayed on a key so it does not take 
  - Can key bindings be abstracted so they can be inherited /reused.
  - some kind of CSS style sheet.


=end
require 'logger'
require 'rbcurse/colormap'
require 'rbcurse/orderedhash'
require 'rbcurse/rinputdataevent' # for FIELD 2010-09-11 12:31 
require 'rbcurse/io'
require 'rbcurse/common/keydefs'

BOLD = FFI::NCurses::A_BOLD
REVERSE = FFI::NCurses::A_REVERSE
UNDERLINE = FFI::NCurses::A_UNDERLINE
NORMAL = FFI::NCurses::A_NORMAL

class Object
# thanks to terminal-table for this method
  def yield_or_eval &block
    return unless block
    if block.arity > 0 
      yield self
    else
      self.instance_eval(&block)
    end 
  end
end
class Module
## others may not want this, sets config, so there's a duplicate hash
  # also creates a attr_writer so you can use =.
  #  2011-10-2 V1.3.1 Now returning self, so i can chain calls
  def dsl_accessor(*symbols)
    symbols.each { |sym|
      #open('myfile.out', 'a') { |f|
          #f.puts "dsl_access #{sym} "
       #}
      class_eval %{
        def #{sym}(*val)
          if val.empty?
            @#{sym}
          else
            #if @frozen # 2011-10-1  prevent object from being changed # changed 2011 dts  
               #return if @frozen && (@frozen_list.nil? || @frozen_list.include?(:#{sym}) )
            #end
            @#{sym} = val.size == 1 ? val[0] : val
            # i am itching to deprecate next line XXX
            @config["#{sym}"]=@#{sym}
            self # 2011-10-2 
          end
        end
      # can the next bypass validations
      # I don't think anyone will expect self to be returned if using = to assign
    attr_writer sym #2011-10-2 
        #def #{sym}=(val)
           ##{sym}(val)
           # self
        #end
      }
    }
  end
  # Besides creating getters and setters,  this also fires property change handler
  # if the value changes, and after the object has been painted once.
  #  2011-10-2 V1.3.1 Now returning self, so i can chain calls
  def dsl_property(*symbols)
    symbols.each { |sym|
      class_eval %{
        def #{sym}(*val)
          if val.empty?
            @#{sym}
          else
            #return(self) if @frozen && (@frozen_list.nil? || @frozen_list.include?(:#{sym}) )
            oldvalue = @#{sym}
            # @#{sym} = val.size == 1 ? val[0] : val
            tmp = val.size == 1 ? val[0] : val
            newvalue = tmp
            # i am itching to deprecate config setting
            if oldvalue.nil? || @_object_created.nil?
               @#{sym} = tmp
               @config["#{sym}"]=@#{sym}
            end
            return(self) if oldvalue.nil? || @_object_created.nil?

            if oldvalue != newvalue
              # trying to reduce calls to fire, when object is being created
               begin
                 @property_changed = true
                 fire_property_change("#{sym}", oldvalue, newvalue) if !oldvalue.nil?
                 @#{sym} = tmp
                 @config["#{sym}"]=@#{sym}
               rescue PropertyVetoException
                  $log.warn "PropertyVetoException for #{sym}:" + oldvalue.to_s + "->  "+ newvalue.to_s
               end
            end # if old
            self
          end # if val
        end # def
    #attr_writer sym
        def #{sym}=val
           # TODO if Variable, take .value NEXT VERSION
           #{sym}(val)
        end
      }
    }
  end

end

# 2009-10-04 14:13 added RK after suggestion on http://www.ruby-forum.com/topic/196618#856703
# these are for 1.8 compatibility
class Fixnum
   def ord
     self
   end
## mostly for control and meta characters
   def getbyte(n)
     self
   end
end unless "a"[0] == "a"

module RubyCurses
  extend self
  include ColorMap
    class FieldValidationException < RuntimeError
    end

    # The property change is not acceptable, undo it. e.g. test2.rb
    # @param [String] text message
    # @param [Event] PropertyChangeEvent object
    # @since 1.4.0
    class PropertyVetoException < RuntimeError
      def initialize(string, event)
        @string = string
        @event = event
        super(string)
      end
      attr_reader :string, :event
    end

    module Utils
      ## this is the numeric argument used to repeat and action by repeatm()
      $multiplier = 0

      # 2010-03-04 18:01 
      ## this may come in handy for methods to know whether they are inside a batch action or not
      # e.g. a single call of foo() may set a var, a repeated call of foo() may append to var
      $inside_multiplier_action = true

      # This has been put here since the API is not yet stable, and i
      # don't want to have to change in many places. 2011-11-10 
      #
      # Converts formatted text into chunkline objects.
      #
      # To print chunklines you may for each row:
      #       window.wmove row+height, col
      #       a = get_attrib @attrib
      #       window.show_colored_chunks content, color, a
      #
      # @param [color_parser] object or symbol :tmux, :ansi
      #       the color_parser implements parse_format, the symbols
      #       relate to default parsers provided.
      # @param [String] string containing formatted text
      def parse_formatted_text(color_parser, formatted_text)
        require 'rbcurse/common/chunk'
        cp = Chunks::ColorParser.new color_parser
        l = []
        formatted_text.each { |e| l << cp.convert_to_chunk(e) }
        return l
      end

      ## 
      # wraps text given max length, puts newlines in it.
      # it does not take into account existing newlines
      # Some classes have @maxlen or display_length which may be passed as the second parameter
      def wrap_text(txt, max )
        txt.gsub(/(.{1,#{max}})( +|$\n?)|(.{1,#{max}})/,
                 "\\1\\3\n") 
      end
      def clean_string! content
        content.chomp! # don't display newline
        content.gsub!(/[\t\n]/, '  ') # don't display tab
        content.gsub!(/[^[:print:]]/, '')  # don't display non print characters
        content
      end
      # needs to move to a keystroke class
      # please use these only for printing or debugging, not comparing
      # I could soon return symbols instead 2010-09-07 14:14 
      def keycode_tos keycode
        case keycode
        when 33..126
          return keycode.chr
        when ?\C-a.getbyte(0) .. ?\C-z.getbyte(0)
          return "C-" + (keycode + ?a.getbyte(0) -1).chr 
        when ?\M-A.getbyte(0)..?\M-z.getbyte(0)
          return "M-"+ (keycode - 128).chr
        when ?\M-\C-A.getbyte(0)..?\M-\C-Z.getbyte(0)
          return "M-C-"+ (keycode - 32).chr
        when ?\M-0.getbyte(0)..?\M-9.getbyte(0)
          return "M-"+ (keycode-?\M-0.getbyte(0)).to_s
        when 32
          return "space" # changed to lowercase so consistent
        when 27
          return "esc" # changed to lowercase so consistent
        when ?\C-].getbyte(0)
          return "C-]"
        when 258
          return "down"
        when 259
          return "up"
        when 260
          return "left"
        when 261
          return "right"
        when FFI::NCurses::KEY_F1..FFI::NCurses::KEY_F12
          return "F"+ (keycode-264).to_s
        when 330
          return "delete"
        when 127
          return "bs"
        when 353
          return "btab"
        when 481
          return "M-S-tab"
        when 393..402
          return "M-F"+ (keycode-392).to_s
        when 0
          return "C-space" # i hope this is correct, just guessing
        when 160
          return "M-space" # at least on OSX Leopard now (don't remember this working on PPC)
        when C_LEFT
          return "C-left"
        when C_RIGHT
          return "C-right"
        when S_F9
          return "S_F9"
        else
          others=[?\M--,?\M-+,?\M-=,?\M-',?\M-",?\M-;,?\M-:,?\M-\,, ?\M-.,?\M-<,?\M->,?\M-?,?\M-/]
          others.collect! {|x| x.getbyte(0)  }  ## added 2009-10-04 14:25 for 1.9
          s_others=%w[M-- M-+ M-= M-' M-"   M-;   M-:   M-, M-. M-< M-> M-? M-/ ]
          if others.include? keycode
            index =  others.index keycode
            return s_others[index]
          end
          # all else failed
          return keycode.to_s
        end
      end

      # if passed a string in second or third param, will create a color 
      # and return, else it will return default color
      # Use this in order to create a color pair with the colors
      # provided, however, if user has not provided, use supplied
      # default.
      # @param [Fixnum] color_pair created by ncurses
      # @param [Symbol] color name such as white black cyan magenta red green yellow
      # @param [Symbol] bgcolor name such as white black cyan magenta red green yellow
      # @example get_color $promptcolor, :white, :cyan
      def get_color default=$datacolor, color=@color, bgcolor=@bgcolor
        return default if color.nil? || bgcolor.nil?
        raise ArgumentError, "Color not valid: #{color}: #{ColorMap.colors} " if !ColorMap.is_color? color
        raise ArgumentError, "Bgolor not valid: #{bgcolor} : #{ColorMap.colors} " if !ColorMap.is_color? bgcolor
        acolor = ColorMap.get_color(color, bgcolor)
        return acolor
      end
      #
      # convert a string to integer attribute
      # FIXME: what if user wishes to OR two attribs, this will give error
      # @param [String] e.g. reverse bold normal underline
      #     if a Fixnum is passed, it is returned as is assuming to be 
      #     an attrib
      def get_attrib str
        return FFI::NCurses::A_NORMAL unless str
        # next line allows us to do a one time conversion and keep the value
        #  in the same variable
        if str.is_a? Fixnum
          if [
            FFI::NCurses::A_BOLD,
            FFI::NCurses::A_REVERSE,    
            FFI::NCurses::A_NORMAL,
            FFI::NCurses::A_UNDERLINE,
            FFI::NCurses::A_STANDOUT,    
            FFI::NCurses::A_DIM,    
            FFI::NCurses::A_BOLD | FFI::NCurses::A_REVERSE,    
            FFI::NCurses::A_BOLD | FFI::NCurses::A_UNDERLINE,    
            FFI::NCurses::A_REVERSE | FFI::NCurses::A_UNDERLINE,    
            FFI::NCurses::A_BLINK
          ].include? str
          return str
          else
            raise ArgumentError, "get_attrib got a wrong value: #{str} "
          end
        end


        att = nil
        str = str.downcase.to_sym if str.is_a? String
        case str #.to_s.downcase
        when :bold
          att = FFI::NCurses::A_BOLD
        when :reverse
          att = FFI::NCurses::A_REVERSE    
        when :normal
          att = FFI::NCurses::A_NORMAL
        when :underline
          att = FFI::NCurses::A_UNDERLINE
        when :standout
          att = FFI::NCurses::A_STANDOUT
        when :bold_reverse
          att = FFI::NCurses::A_BOLD | FFI::NCurses::A_REVERSE
        when :bold_underline
          att = FFI::NCurses::A_BOLD | FFI::NCurses::A_UNDERLINE
        when :dim
          att = FFI::NCurses::A_DIM    
        when :blink
          att = FFI::NCurses::A_BLINK    # unlikely to work
        else
          att = FFI::NCurses::A_NORMAL
        end
        return att
      end

      # returns last line of full screen, should it be current window ?
      def last_line; FFI::NCurses.LINES-1; end
      
      # Create a one line window typically at the bottom
      # should we really put this here, too much clutter ?
      def one_line_window at=last_line(), config={}, &blk
        at ||= last_line()
        at = FFI::NCurses.LINES-at if at < 0
        VER::Window.new(1,0,at,0)
      end
      ## repeats the given action based on how value of universal numerica argument
      ##+ set using the C-u key. Or in vim-mode using numeric keys
      def repeatm
        $inside_multiplier_action = true
        _multiplier = ( ($multiplier.nil? || $multiplier == 0) ? 1 : $multiplier )
        _multiplier.times { yield }
        $multiplier = 0
        $inside_multiplier_action = false
      end

      ##
      # bind an action to a key, required if you create a button which has a hotkey
      # or a field to be focussed on a key, or any other user defined action based on key
      # e.g. bind_key ?\C-x, object, block 
      # added 2009-01-06 19:13 since widgets need to handle keys properly
      #  2010-02-24 12:43 trying to take in multiple key bindings, TODO unbind
      #  TODO add symbol so easy to map from config file or mapping file
      def bind_key keycode, *args, &blk
        $log.debug " #{@name} bind_key received #{keycode} "
        @key_handler ||= {}
        if !block_given?
          blk = args.pop
          raise "If block not passed, last arg should be a method symbol" if !blk.is_a? Symbol
          #$log.debug " #{@name} bind_key received a symbol #{blk} "
        end
        case keycode
        when String
          keycode = keycode.getbyte(0) #if keycode.class==String ##    1.9 2009-10-05 19:40 
          #$log.debug " #{name} Widg String called bind_key BIND #{keycode}, #{keycode_tos(keycode)}  "
          $log.debug " assigning #{keycode}  " if $log.debug? 
          @key_handler[keycode] = blk
        when Array
          # for starters lets try with 2 keys only
          raise "A one key array will not work. Pass without array" if keycode.size == 1
          a0 = keycode[0]
          a0 = keycode[0].getbyte(0) if keycode[0].class == String
          a1 = keycode[1]
          a1 = keycode[1].getbyte(0) if keycode[1].class == String
          @key_handler[a0] ||= OrderedHash.new
          $log.debug " assigning #{keycode} , A0 #{a0} , A1 #{a1} " if $log.debug? 
          @key_handler[a0][a1] = blk
          #$log.debug " XX assigning #{keycode} to  key_handler " if $log.debug? 
        else
          #$log.debug " assigning #{keycode} to  key_handler " if $log.debug? 
          @key_handler[keycode] = blk
        end
        @key_args ||= {}
        @key_args[keycode] = args
      end
      def bind_keys keycodes, *args, &blk
        keycodes.each { |k| bind_key k, *args, &blk }
      end
      # e.g. process_key ch, self
      # returns UNHANDLED if no block for it
      # after form handles basic keys, it gives unhandled key to current field, if current field returns
      # unhandled, then it checks this map.
      # added 2009-01-06 19:13 since widgets need to handle keys properly
      # added 2009-01-18 12:58 returns ret val of blk.call
      # so that if block does not handle, the key can still be handled
      # e.g. table last row, last col does not handle, so it will auto go to next field
      #  2010-02-24 13:45 handles 2 key combinations, copied from Form, must be identical in logic
      #  except maybe for window pointer. TODO not tested
      def _process_key keycode, object, window
        return :UNHANDLED if @key_handler.nil?
        blk = @key_handler[keycode]
        return :UNHANDLED if blk.nil?
        if blk.is_a? OrderedHash
          ch = window.getch
          if ch < 0 || ch > 255
            #next
            return nil
          end
          $log.debug " process_key: got #{keycode} , #{ch} "
          yn = ch.chr
          blk1 = blk[ch]
          window.ungetch(ch) if blk1.nil? # trying  2011-09-27 
          return :UNHANDLED if blk1.nil? # changed nil to unhandled 2011-09-27 
          $log.debug " process_key: found block for #{keycode} , #{ch} "
          blk = blk1
        end
        #$log.debug "called process_key #{object}, kc: #{keycode}, args  #{@key_args[keycode]}"
        if blk.is_a? Symbol
          $log.debug "SYMBOL " if $log.debug? 
          if respond_to? blk
            return send(blk, *@key_args[keycode])
          else
            alert "This ( #{self.class} ) does not respond to #{blk.to_s} "
          end
        else
          $log.debug "rwidget BLOCK called _process_key " if $log.debug? 
          return blk.call object,  *@key_args[keycode]
        end
        #0
      end
      # view a file or array of strings
      def view what, config={} # :yields: textview for further configuration
        require 'rbcurse/extras/viewer'
        RubyCurses::Viewer.view what, config
      end
    end # module

    module EventHandler
      ##
      # bind an event to a block, optional args will also be passed when calling
      def bind event, *xargs, &blk
       #$log.debug "#{self} called EventHandler BIND #{event}, args:#{xargs} "
          if @_events
            $log.warn "#{self.class} does not support this event: #{event}. #{@_events} " if !@_events.include? event
            #raise ArgumentError, "#{self.class} does not support this event: #{event}. #{@_events} " if !@_events.include? event
          else
            # it can come here if bind in initial block, since widgets add to @_event after calling super
            # maybe we can change that.
            $log.warn "BIND #{self.class} (#{event})  XXXXX no events defined in @_events. Please do so to avoid bugs and debugging. This will become a fatal error soon."
          end
        @handler ||= {}
        @event_args ||= {}
        @handler[event] ||= []
        @handler[event] << blk
        @event_args[event] ||= []
        @event_args[event] << xargs
      end
      alias :add_binding :bind   # temporary, needs a proper name to point out that we are adding

      # NOTE: Do we have a way of removing bindings
      # # TODO check if event is valid. Classes need to define what valid event names are
    
      ##
      # Fire all bindings for given event
      # e.g. fire_handler :ENTER, self
      # The first parameter passed to the calling block is either self, or some action event
      # The second and beyond are any objects you passed when using `bind` or `command`.
      # Exceptions are caught here itself, or else they prevent objects from updating, usually the error is 
      # in the block sent in by application, not our error.
      # TODO: if an object throws a subclass of VetoException we should not catch it and throw it back for 
      # caller to catch and take care of, such as prevent LEAVE or update etc.
      def fire_handler event, object
        $log.debug "inside def fire_handler evt:#{event}, o: #{object.class}"
        if !@handler.nil?
          if @_events
            raise ArgumentError, "#{self.class} does not support this event: #{event}. #{@_events} " if !@_events.include? event
          else
            $log.debug "bIND #{self.class}  XXXXX TEMPO no events defined in @_events "
          end
          ablk = @handler[event]
          if !ablk.nil?
            aeve = @event_args[event]
            ablk.each_with_index do |blk, ix|
              #$log.debug "#{self} called EventHandler firehander #{@name}, #{event}, obj: #{object},args: #{aeve[ix]}"
              #$log.debug "#{self} called EventHandler firehander #{@name}, #{event}"
              begin
                blk.call object,  *aeve[ix]
              rescue FieldValidationException => fve
                # added 2011-09-26 1.3.0 so a user raised exception on LEAVE
                # keeps cursor in same field.
                raise fve
              rescue PropertyVetoException => pve
                # added 2011-09-26 1.3.0 so a user raised exception on LEAVE
                # keeps cursor in same field.
                raise pve
              rescue => ex
                ## some don't have name
                #$log.error "======= Error ERROR in block event #{self}: #{name}, #{event}"
                $log.error "======= Error ERROR in block event #{self}:  #{event}"
                $log.error ex
                $log.error(ex.backtrace.join("\n")) 
                #$error_message = "#{ex}" # changed 2010  
                $error_message.value = "#{ex.to_s}"
                Ncurses.beep
              end
            end
          end # if
        end # if
      end
      ## added on 2009-01-08 00:33 
      # goes with dsl_property
      # Need to inform listeners - done 2010-02-25 23:09 
      # Can throw a FieldValidationException or PropertyVetoException
    def fire_property_change text, oldvalue, newvalue
      #$log.debug " FPC #{self}: #{text} #{oldvalue}, #{newvalue}"
      return if oldvalue.nil? || @_object_created.nil? # added 2010-09-16 so if called by methods it is still effective
      if @pce.nil?
        @pce = PropertyChangeEvent.new(self, text, oldvalue, newvalue)
      else
        @pce.set( self, text, oldvalue, newvalue)
      end
      fire_handler :PROPERTY_CHANGE, @pce
      @repaint_required = true # this was a hack and shoudl go, someone wanted to set this so it would repaint (viewport line 99 fire_prop
      repaint_all(true) # for repainting borders, headers etc 2011-09-28 V1.3.1 
    end

    end # module eventh

    module ConfigSetup
      # private
      def variable_set var, val
        #nvar = "@#{var}"
        send("#{var}", val) #rescue send("#{var}=", val)    # 2009-01-08 01:30 BIG CHANGE calling methods too here.
        #instance_variable_set(nvar, val)   # we should not call this !!! bypassing 
      end
      def configure(*val , &block)
        case val.size
        when 1
          return @config[val[0]]
        when 2
          @config[val[0]] = val[1]
          variable_set(val[0], val[1]) 
        end
        instance_eval &block if block_given?
      end
      ## 
      # returns param from hash. Unused and untested. 
      def cget param
        @config[param]
      end
       # this bypasses our methods and sets directly !
      def config_setup aconfig
        @config = aconfig
        # this creates a problem in 1.9.2 since variable_set sets @config 2010-08-22 19:05 RK
        #@config.each_pair { |k,v| variable_set(k,v) }
        keys = @config.keys
        keys.each do |e| 
          variable_set(e, @config[e])
        end
      end
    end # module config
    
    # Adding widget shortcuts here for non-App cases 2011-10-12 . MOVE these to widget shortcuts
    #
    # prints a status line at bottom where mode's statuses et can be reflected
    def status_line config={}, &block
      require 'rbcurse/extras/statusline'
      sl = RubyCurses::StatusLine.new @form, config, &block
    end

    # add a standard application header
    # == Example
    #    header = app_header "rbcurse ", :text_center => "Browser Demo", :text_right =>"New Improved!", 
    #         :color => :black, :bgcolor => :white, :attr => :bold 
    def app_header title, config={}, &block
      require 'rbcurse/applicationheader'
      header = ApplicationHeader.new @form, title, config, &block
    end
    
    # prints pine-like key labels
    def dock labels, config={}, &block
      require 'rbcurse/keylabelprinter'
      klp = RubyCurses::KeyLabelPrinter.new @form, labels, config, &block
    end

    ##
    # Basic widget class superclass. Anything embedded in a form should
    # extend this, if it wants to be repainted or wants focus. Otherwise.
    # form will be unaware of it.
  
 
  class Widget
    include EventHandler
    include ConfigSetup
    include RubyCurses::Utils
    include Io # added 2010-03-06 13:05 
    # common interface for text related to a field, label, textview, button etc
    dsl_property :text

    # next 3 to be checked if used or not. Copied from TK.
    dsl_property :select_foreground, :select_background  # color init_pair
    dsl_property :highlight_foreground, :highlight_background  # color init_pair
    dsl_property :disabled_foreground, :disabled_background  # color init_pair

    # FIXME is enabled used? is menu using it
    dsl_accessor :focusable, :enabled # boolean
    dsl_property :row, :col            # location of object
    dsl_property :color, :bgcolor      # normal foreground and background
    # moved to a method which calculates color 2011-11-12 
    #dsl_property :color_pair           # instead of colors give just color_pair
    dsl_property :attr                 # attribute bold, normal, reverse
    dsl_accessor :name                 # name to refr to or recall object by_name
    attr_accessor :id #, :zorder
    attr_accessor :curpos              # cursor position inside object - column, not row.
    attr_reader  :config             # can be used for popping user objects too
    attr_accessor  :form              # made accessor 2008-11-27 22:32 so menu can set
    attr_accessor :state              # normal, selected, highlighted
    attr_reader  :row_offset, :col_offset # where should the cursor be placed to start with
    dsl_property :visible # boolean     # 2008-12-09 11:29 
    #attr_accessor :modified          # boolean, value modified or not (moved from field 2009-01-18 00:14 )
    dsl_accessor :help_text          # added 2009-01-22 17:41 can be used for status/tooltips

    dsl_property :preferred_width  # added 2009-10-28 13:40 for splitpanes and better resizing
    dsl_property :preferred_height  # added 2009-10-28 13:40 for splitpanes and better resizing
    dsl_property :min_width  # added 2009-10-28 13:40 for splitpanes and better resizing
    dsl_property :min_height  # added 2009-10-28 13:40 for splitpanes and better resizing
    # widget also has height and width as a method

    attr_accessor  :_object_created   # 2010-09-16 12:12 to prevent needless property change firing when object being set
    
    #attr_accessor :frozen # true false
    #attr_accessor :frozen_list # list of attribs that cannot be changed
    ## I think parent_form was not a good idea since i can't add parent widget offsets
    ##+ thus we should use parent_comp and push up.
    attr_accessor :parent_component  # added 2010-01-12 23:28 BUFFERED - to bubble up
    # tired of getting the cursor wrong and guessing, i am now going to try to get absolute
    # coordinates - 2010-02-07 20:17 this should be updated by parent.
    #attr_accessor :ext_col_offset, :ext_row_offset # 2010-02-07 20:16  to get abs position for cursor rem 2011-09-29 
    attr_accessor :rows_panned # moved from form, how many rows scrolled.panned 2010-02-11 15:26 
    attr_accessor :cols_panned # moved from form, how many cols scrolled.panned 2010-02-11 15:26 

    # sometimes inside a container there's no way of knowing if an individual comp is in focus
    # other than the explicitly set it and inquire . 2010-09-02 14:47 @since 1.1.5
    # NOTE state takes care of this and is set by form
    attr_accessor :focussed  # is this widget in focus, so they may paint differently

    def initialize form, aconfig={}, &block
      @form = form
      @row_offset ||= 0
      @col_offset ||= 0
      #@ext_row_offset = @ext_col_offset = 0 # 2010-02-07 20:18  # removed on 2011-09-29 
      @state = :NORMAL
      #@attr = nil    # 2011-11-5 i could be removing what's been entered since super is called

      @handler = nil # we can avoid firing if nil
      @event_args = {}
      # These are standard events for most widgets which will be fired by 
      # Form. In the case of CHANGED, form fires if it's editable property is set, so
      # it does not apply to all widgets.
      @_events ||= []
      @_events.push( *[:ENTER, :LEAVE, :CHANGED, :PROPERTY_CHANGE])

      config_setup aconfig # @config.each_pair { |k,v| variable_set(k,v) }
      #instance_eval &block if block_given?
      if block_given?
        if block.arity > 0
          yield self
        else
          self.instance_eval(&block)
        end
      end
      # 2010-09-20 13:12 moved down, so it does not create problems with other who want to set their
      # own default
      #@bgcolor ||=  "black" # 0
      #@color ||= "white" # $datacolor
      set_form(form) unless form.nil? 
    end
    def init_vars
      # just in case anyone does a super. Not putting anything here
      # since i don't want anyone accidentally overriding
      @buffer_modified = false 
      #@manages_cursor = false # form should manage it, I will pass row and col to it. 
    end

    # modified
    ##
    # typically read will be overridden to check if value changed from what it was on enter.
    # getter and setter for modified (added 2009-01-18 12:31 )
    def modified?
      @modified
    end
    def set_modified tf=true
      @modified = tf
      @form.modified = true if tf
    end
    alias :modified :set_modified
    ##
    # getter and setter for text_variable
    def text_variable(*val)
      if val.empty?
        @text_variable
      else
        @text_variable = val[0] 
        $log.debug " GOING TO CALL ADD DELPENDENT #{self}"
        @text_variable.add_dependent(self)
      end
    end

    ## got left out by mistake 2008-11-26 20:20 
    def on_enter
      @state = :HIGHLIGHTED    # duplicating since often these are inside containers
      @focussed = true
      if @handler && @handler.has_key?(:ENTER)
        fire_handler :ENTER, self
      end
    end
    ## got left out by mistake 2008-11-26 20:20 
    def on_leave
      @state = :NORMAL    # duplicating since often these are inside containers
      @focussed = false
      if @handler && @handler.has_key?(:LEAVE)
        fire_handler :LEAVE, self
      end
    end
    ## 
    # @return row and col of a widget where painting data actually starts
    # row and col is where a widget starts. offsets usually take into account borders.
    # the offsets typically are where the cursor should be positioned inside, upon on_enter.
    def rowcol
    # $log.debug "widgte rowcol : #{@row+@row_offset}, #{@col+@col_offset}"
      return @row+@row_offset, @col+@col_offset
    end
    ## return the value of the widget.
    #  In cases where selection is possible, should return selected value/s
    def getvalue
      @text_variable && @text_variable.value || @text
    end
    ##
    # Am making a separate method since often value for print differs from actual value
    def getvalue_for_paint
      getvalue
    end
    ##
    # default repaint method. Called by form for all widgets.
    #  widget does not have display_length.
    def repaint
        r,c = rowcol
        @bgcolor ||= $def_bg_color # moved down 2011-11-5 
        @color   ||= $def_fg_color
        $log.debug("widget repaint : r:#{r} c:#{c} col:#{@color}" )
        value = getvalue_for_paint
        len = @display_length || value.length
        acolor = @color_pair || get_color($datacolor, @color, @bgcolor)
        @graphic.printstring r, c, "%-*s" % [len, value], acolor, @attr
        # next line should be in same color but only have @att so we can change att is nec
        #@form.window.mvchgat(y=r, x=c, max=len, Ncurses::A_NORMAL, @bgcolor, nil)
        #@buffer_modified = true # required for form to call buffer_to_screen CLEANUP
    end

    def destroy
      $log.debug "DESTROY : widget #{@name} "
      panel = @window.panel
      Ncurses::Panel.del_panel(panel.pointer) if !panel.nil?   
      @window.delwin if !@window.nil?
    end
    # in those cases where we create widget without a form, and later give it to 
    # some other program which sets the form. Dirty, we should perhaps create widgets
    # without forms, and add explicitly. 
    def set_form form
      raise "Form is nil in set_form" if form.nil?
      @form = form
      @id = form.add_widget(self) if !form.nil? and form.respond_to? :add_widget
      # 2009-10-29 15:04 use form.window, unless buffer created
      # should not use form.window so explicitly everywhere.
      # added 2009-12-27 20:05 BUFFERED in case child object needs a form.
      # We don;t wish to overwrite the graphic object
      if @graphic.nil?
        $log.debug " setting graphic to form window for #{self.class}, #{form} "
        @graphic = form.window unless form.nil? # use screen for writing, not buffer
      end
    end
    # puts cursor on correct row.
    def set_form_row
    #  @form.row = @row + 1 + @winrow
      #@form.row = @row + 1 
      r, c = rowcol
      $log.warn " empty set_form_row in widget #{self} r = #{r} , c = #{c}  "
      #raise "trying to set 0, maybe called repaint before container has set value" if row <= 0
      setrowcol row, nil
    end
    # set cursor on correct column, widget
    # Ideally, this should be overriden, as it is not likely to be correct.
    # NOTE: this is okay for some widgets but NOT for containers
    # that will call their own components SFR and SFC
    def set_form_col col1=@curpos
      @curpos = col1 || 0 # 2010-01-14 21:02 
      #@form.col = @col + @col_offset + @curpos
      c = @col + @col_offset + @curpos
      $log.warn " #{@name} empty set_form_col #{c}, #{@form} "
      setrowcol nil, c
    end
    def hide
      @visible = false
    end
    def show
      @visible = true
    end
    def remove
      @form.remove_widget(self)
    end
    # is this required can we remove
    def move row, col
      @row = row
      @col = col
    end
    ##
    # moves focus to this field
    # we must look into running on_leave of previous field
    def focus
      return if !@focusable
      if @form.validate_field != -1
        @form.select_field @id
      end
    end
    ##
    # remove a binding that you don't want
    def unbind_key keycode
      @key_args.delete keycode unless @key_args.nil?
      @key_handler.delete keycode unless @key_handler.nil?
    end

    # e.g. process_key ch, self
    # returns UNHANDLED if no block for it
    # after form handles basic keys, it gives unhandled key to current field, if current field returns
    # unhandled, then it checks this map.
    def process_key keycode, object
      return _process_key keycode, object, @graphic
    end
    ## 
    # to be added at end of handle_key of widgets so instlalled actions can be checked
    def handle_key(ch)
      ret = process_key ch, self
      return :UNHANDLED if ret == :UNHANDLED
      0
    end
    # @since 0.1.3
    def get_preferred_size
      return @preferred_height, @preferred_width
    end


    ##
    # Inform the system that the buffer has been modified
    # and should be blitted over the screen or copied to parent.
    def set_buffer_modified(tf=true)
      @buffer_modified = tf
    end



     ##
     # getter and setter for width - 2009-10-29 22:45 
     # Using dsl_property style
     #
     # @param [val, nil] value to set
     # @return [val] earlier value if nil param
     # @since 0.1.3
     #
     def width(*val)
       #$log.debug " inside  width() #{val}"
       if val.empty?
         return @width
       else
         #$log.debug " inside  width()"
         oldvalue = @width || 0 # is this default okay, else later nil cries
         #@width = val.size == 1 ? val[0] : val
         @width = val[0]
         newvalue = @width
         @config["width"]=@width
         if oldvalue != newvalue
           @property_changed = true
           fire_property_change(:width, oldvalue, newvalue)
           repaint_all(true)  # added 2010-01-08 18:51 so widgets can redraw everything.
         end
         #if is_double_buffered? and newvalue != oldvalue # removed on 2011-09-29 
           #$log.debug " #{@name} w calling resize of screen buffer with #{newvalue}. WARNING: does not change buffering_params"
           #@screen_buffer.resize(0, newvalue)
         #end
       end
     end
     def width=val
       width(val)
     end
     ##
     # getter and setter for height - 2009-10-30 12:25 
     # Using dsl_property style
     # SO WE've finally succumbed and added height to widget
     # @param [val, nil] height to set
     # @return [val] earlier height if nil param
     # @since 0.1.3
     #
     def height(*val)
       #$log.debug " inside  height() #{val[0]}"
       if val.empty?
         return @height
       else
         #$log.debug " inside #{@name} height()"
         oldvalue = @height || 0 # is this default okay, else later nil cries
         @height = val.size == 1 ? val[0] : val
         newvalue = @height
         @config[:height]=@height
         if oldvalue != newvalue
           @property_changed = true
           fire_property_change(:height, oldvalue, newvalue)
           repaint_all true
         end
       end
     end
     def height=val
       height(val)
     end
    # to give simple access to other components, (eg, parent) to tell a comp to either
    # paint its data, or to paint all - borders, headers, footers due to a big change (ht/width)
    def repaint_required(tf=true)
      @repaint_required = tf
    end
    def repaint_all(tf=true)
      @repaint_all = tf
      @repaint_required = tf
    end

     ## 
     # When an enclosing component creates a pad (buffer) and the child component
     #+ should write onto the same pad, then the enclosing component should override
     #+ the default graphic of child. This applies mainly to editor components in
     #+ listboxes and tables. 
     # @param graphic graphic object to use for writing contents
     # @see prepare_editor in rlistbox.
     # added 2010-01-05 15:25 
     def override_graphic gr
       @graphic = gr
     end

     ## passing a cursor up and adding col and row offsets
     ## Added 2010-01-13 13:27 I am checking this out.
     ## I would rather pass the value down and store it than do this recursive call
     ##+ for each cursor display
     # @see Form#setrowcol
     def setformrowcol r, c
           @form.row = r unless r.nil?
           @form.col = c unless c.nil?
           # this is stupid, going through this route i was losing windows top and left
           # And this could get repeated if there are mult objects. 
        if !@parent_component.nil? and @parent_component != self
           r+= @parent_component.form.window.top unless  r.nil?
           c+= @parent_component.form.window.left unless c.nil?
           $log.debug " (#{@name}) calling parents setformrowcol #{r}, #{c} pa: #{@parent_component.name} self: #{name}, #{self.class}, poff #{@parent_component.row_offset}, #{@parent_component.col_offset}, top:#{@form.window.left} left:#{@form.window.left} "
           @parent_component.setformrowcol r, c
        else
           # no more parents, now set form
           $log.debug " name NO MORE parents setting #{r}, #{c}    in #{@form} "
           @form.setrowcol r, c
        end
     end
     ## widget: i am putting one extra level of indirection so i can switch here
     # between form#setrowcol and setformrowcol, since i am not convinced either
     # are giving the accurate result. i am not sure what the issue is.
     def setrowcol r, c
         # 2010-02-07 21:32 is this where i should add ext_offsets
        #$log.debug " #{@name}  w.setrowcol #{r} + #{@ext_row_offset}, #{c} + #{@ext_col_offset}  "
        # commented off 2010-02-15 18:22 
        #r += @ext_row_offset unless r.nil?
        #c += @ext_col_offset unless c.nil?
        if @form
          @form.setrowcol r, c
        #elsif @parent_component
        else
          raise "Parent component not defined for #{self}, #{self.class} " unless @parent_component
          @parent_component.setrowcol r, c
        end
        #setformrowcol r,c 
     end

     # I was removing this altogether but vimsplit needs this, or masterdetail gives form and window
     # to vimsplit. So i 've removed everything but the form and window setting. 2011-09-29 SETBUFF
     # move from TextView
     # parameters relating to buffering - new 2010-02-12 12:09 RFED16
     # I am merging so i can call multiple times
     # WARNING NOTE : this does not set Pad's top and left since Pad may not be created yet, or at all
     def set_buffering params
     
       @target_window ||= params[:target_window]
       @form = params[:form] unless @form
       if @graphic.nil? 
         @graphic = @target_window
       end
     end
 
     def event_list
       return @@events if defined? @@events
       nil
     end
     # 2011-11-12 trying to make color setting a bit sane
     # You may set as a color_pair using get_color which gives a fixnum
     # or you may give 2 color symbols so i can update color, bgcolor and colorpair in one shot
     # if one of them is nil, i just use the existing value
     def color_pair(*val)
       if val.empty?
         return @color_pair
       end

       oldvalue = @color_pair
       case val.size
       when 1
         raise ArgumentError, "Expecting fixnum for color_pair." unless val[0].is_a? Fixnum
         @color_pair = val[0]
         @color, @bgcolor = ColorMap.get_colors_for_pair @color_pair
       when 2
         @color = val.first if val.first
         @bgcolor = val.last if val.last
         @color_pair = get_color $datacolor, @color, @bgcolor
       end
       if oldvalue != @color_pair
         fire_property_change(:color_pair, oldvalue, @color_pair)
         @property_changed = true
         repaint_all true
       end
       self
     end
     ##
    ## ADD HERE WIDGET
  end

  ##
  #
  # TODO: we don't have an event for when form is entered and exited.
  # Current ENTER and LEAVE are for when any widgt is entered, so a common event can be put for all widgets
  # in one place.
  class Form
    include EventHandler
    include RubyCurses::Utils
    attr_reader :value # ???
    
    # array of widgets
    attr_reader :widgets
    
    # related window used for printing
    attr_accessor :window
    
    # cursor row and col
    attr_accessor :row, :col
#   attr_accessor :color
#   attr_accessor :bgcolor
    
    # has the form been modified
    attr_accessor :modified

    # index of active widget
    attr_accessor :active_index
     
    # hash containing widgets by name for retrieval
    #   Useful if one widget refers to second before second created.
    attr_reader :by_name   

    # associated menubar
    attr_reader :menu_bar

    attr_accessor :navigation_policy  # :CYCLICAL will cycle around. Needed to move to other tabs
    ## i need some way to move the cursor by telling the main form what the coords are
    ##+ perhaps this will work
    attr_accessor :parent_form  # added 2009-12-28 23:01 BUFFERED - to bubble up row col changes 

    # how many rows the component is panning embedded widget by
    attr_accessor :rows_panned  # HACK added 2009-12-30 16:01 BUFFERED  USED ??? CLEANUP XXX
    # how many cols the component is panning embedded widget by
    attr_accessor :cols_panned  # HACK added 2009-12-30 16:01 BUFFERED  USED ??? CLEANUP XXX

    ## next 2 added since tabbedpanes offset needs to be accounted by form inside it.
    # NOTE: if you set a form inside another set parent_form in addition to these 2.
    attr_accessor :add_cols # 2010-01-26 20:23 additional columns due to being placed in some container
    attr_accessor :add_rows # 2010-01-26 20:23 additional columns due to being placed in some container

    # name given to form for debugging
    attr_accessor :name # for debugging 2010-02-02 20:12 

    def initialize win, &block
      @window = win
      @widgets = []
      @by_name = {}
      @active_index = -1
      @row = @col = -1
      @add_cols = @add_rows = 0 # 2010-01-26 20:28  CLEANUP
      @handler = {}
      @modified = false
      @focusable = true
      @navigation_policy ||= :CYCLICAL
      @_events = [:ENTER, :LEAVE]
      instance_eval &block if block_given?
      ## I need some counter so a widget knows it has been panned and can send a correct
      ##+ cursor coordinate to system.
      @rows_panned = @cols_panned = 0 # how many rows were panned, typically at a higher level
      @_firsttime = true; # added on 2010-01-02 19:21 to prevent scrolling crash ! 
      @name ||= ""

      # related to emacs kill ring concept for copy-paste

      $kill_ring ||= [] # 2010-03-09 22:42 so textarea and others can copy and paste emacs EMACS
      $kill_ring_pointer = 0 # needs to be incremented with each append, moved with yank-pop
      $append_next_kill = false
      $kill_last_pop_size = 0 # size of last pop which has to be cleared

      $last_key = 0 # last key pressed @since 1.1.5 (not used yet)
      $current_key = 0 # curr key pressed @since 1.1.5 (so some containers can behave based on whether
                    # user tabbed in, or backtabbed in (rmultisplit)

      # for storing error message
      $error_message ||= Variable.new ""

      # what kind of key-bindings do you want, :vim or :emacs
      $key_map ||= :vim ## :emacs or :vim, keys to be defined accordingly. TODO
    end
    ##
    # set this menubar as the form's menu bar.
    # also bind the toggle_key for popping up.
    # Should this not be at application level ?
    def set_menu_bar mb
      @menu_bar = mb
      add_widget mb
      mb.toggle_key ||= Ncurses.KEY_F2
      if !mb.toggle_key.nil?
        ch = mb.toggle_key
        bind_key(ch) do |_form| 
          if !@menu_bar.nil?
            @menu_bar.toggle
            @menu_bar.handle_keys
          end
        end
      end
    end
    ##
    # Add given widget to widget list and returns an incremental id.
    # Adding to widgets, results in it being painted, and focussed.
    # removing a widget and adding can give the same ID's, however at this point we are not 
    # really using ID. But need to use an incremental int in future.
    def add_widget widget
      # this help to access widget by a name
      if widget.respond_to? :name and !widget.name.nil?
        $log.debug "NAME #{self} adding a widget #{@widgets.length} .. #{widget.name} "
        @by_name[widget.name] = widget
      end


      $log.debug " #{self} adding a widget #{@widgets.length} .. #{widget} "
      @widgets << widget
      return @widgets.length-1
    end
    alias :add :add_widget

    # remove a widget
    #  added 2008-12-09 12:18 
   def remove_widget widget
     if widget.respond_to? :name and !widget.name.nil?
       @by_name.delete(widget.name)
     end
     @widgets.delete widget
   end
   # form repaint
   # to be called at some interval, such as after each keypress.
    def repaint
      $log.debug " form repaint:#{self}, #{@name} , r #{@row} c #{@col} " if $log.debug? 
      @widgets.each do |f|
        next if f.visible == false # added 2008-12-09 12:17 
        #$log.debug "XXX: FORM CALLING REPAINT OF WIDGET #{f} IN LOOP"
        #raise "Row or col nil #{f.row} #{f.col} for #{f}, #{f.name} " if f.row.nil? || f.col.nil?
        f.repaint
        f._object_created = true # added 2010-09-16 13:02 now prop handlers can be fired
      end
      #  this can bomb if someone sets row. We need a better way!
      if @row == -1 and @_firsttime == true
        #set_field_cursor 0
        #  this part caused an endless loop on 2010-01-02 19:20 when scrollpane scrolled up
        #$log.debug "form repaint calling select field 0 SHOULD HAPPEN FIRST TIME ONLY"
        select_first_field
        @_firsttime = false
      end
       setpos 
       # XXX this creates a problem if window is a pad
       # although this does show cursor movement etc.
       ### @window.wrefresh
       if @window.window_type == :WINDOW
         #$log.debug " formrepaint #{@name} calling window.wrefresh #{@window} "
         @window.wrefresh
         Ncurses::Panel.update_panels ## added 2010-11-05 00:30 to see if clears the stdscr problems
       else
         $log.warn " XXX formrepaint #{@name} no refresh called  2011-09-19  #{@window} "
       end
    end
    ## 
    # move cursor to where the fields row and col are
    # private
    def setpos r=@row, c=@col
      $log.debug "setpos : (#{self.name}) #{r} #{c} XXX"
      ## adding just in case things are going out of bounds of a parent and no cursor to be shown
      return if r.nil? or c.nil?  # added 2009-12-29 23:28 BUFFERED
      return if r<0 or c<0  # added 2010-01-02 18:49 stack too deep coming if goes above screen
      @window.wmove r,c
    end
    # @return [Widget, nil] current field, nil if no focusable field
    def get_current_field
      select_next_field if @active_index == -1
      return nil if @active_index.nil?   # for forms that have no focusable field 2009-01-08 12:22 
      @widgets[@active_index]
    end
    # take focus to first focussable field
    # we shoud not send to select_next. have a separate method to avoid bugs.
    # but check current_field, in case called from anotehr field TODO FIXME
    def select_first_field
      # this results in on_leave of last field being executed when form starts.
      #@active_index = -1 # FIXME HACK
      #select_next_field
      ix =  index_of_first_focusable_field()
      return unless ix # no focussable field

      # if the user is on a field other than current then fire on_leave
      if @active_index.nil? || @active_index < 0
      elsif @active_index != ix
        f = @widgets[@active_index]
        begin
          #$log.debug " select first field, calling on_leave of #{f} #{@active_index} "
          on_leave f
        rescue => err
         $log.error " Caught EXCEPTION req_first_field on_leave #{err}"
         Ncurses.beep
         #$error_message = "#{err}"
         $error_message.value = "#{err}"
         return
        end
      end
      select_field ix
    end
    # please do not use req_ i will deprecate it soon.
    alias :req_first_field :select_first_field
    # return the offset of first field that takes focus
    def index_of_first_focusable_field
      @widgets.each_with_index do |f, i| 
        if focusable?(f)
          #select_field i
          return i
        end
      end
      nil
    end
    # take focus to last field on form
    def select_last_field
      @active_index = nil 
      select_prev_field
    end

    # please do not use req_ i will deprecate it soon.
    alias :req_last_field :select_last_field

    ## do not override
    # form's trigger, fired when any widget loses focus
    #  This wont get called in editor components in tables, since  they are formless 
    def on_leave f
      return if f.nil? || !f.focusable # added focusable, else label was firing
      f.state = :NORMAL
      # on leaving update text_variable if defined. Should happen on modified only
      # should this not be f.text_var ... f.buffer ?  2008-11-25 18:58 
      #f.text_variable.value = f.buffer if !f.text_variable.nil? # 2008-12-20 23:36 
      f.on_leave if f.respond_to? :on_leave
      fire_handler :LEAVE, f 
      ## to test XXX in combo boxes the box may not be editable by be modified by selection.
      if f.respond_to? :editable and f.modified?
        $log.debug " Form about to fire CHANGED for #{f} "
        f.fire_handler(:CHANGED, f) 
      end
    end
    # form calls on_enter of each object.
    # However, if a multicomponent calls on_enter of a widget, this code will
    # not be triggered. The highlighted part
    def on_enter f
      return if f.nil? || !f.focusable # added focusable, else label was firing 2010-09

      f.state = :HIGHLIGHTED
      # If the widget has a color defined for focussed, set repaint
      #  otherwise it will not be repainted unless user edits !
      if f.highlight_background || f.highlight_foreground
        f.repaint_required true
      end

      f.modified false
      #f.set_modified false
      f.on_enter if f.respond_to? :on_enter
      fire_handler :ENTER, f 
    end
    ## is a field focusable
    # Added a method here, so forms can extend this to avoid focussing on off-screen components
    def focusable?(f)
      return f.focusable
    end
    ##
    # puts focus on the given field/widget index
    # XXX if called externally will not run a on_leave of previous field
    def select_field ix0
      return if @widgets.nil? or @widgets.empty? or !focusable?(@widgets[ix0])
     #$log.debug "inside select_field :  #{ix0} ai #{@active_index}" 
      f = @widgets[ix0]
      if focusable?(f)
        @active_index = ix0
        @row, @col = f.rowcol
        #$log.debug " WMOVE insdie sele nxt field : ROW #{@row} COL #{@col} " 
        on_enter f
        @window.wmove @row, @col # added RK FFI 2011-09-7 = setpos

        f.set_form_row # added 2011-10-5 so when embedded in another form it can get the cursor
        f.set_form_col # this can wreak havoc in containers, unless overridden

        f.curpos = 0 # why was this, okay is it because of prev obj's cursor ?
        repaint
        @window.refresh
      else
        $log.debug "inside select field ENABLED FALSE :   act #{@active_index} ix0 #{ix0}" 
      end
    end
    ##
    # run validate_field on a field, usually whatevers current
    # before transferring control
    # We should try to automate this so developer does not have to remember to call it.
    # # @param field object
    # @return [0, -1] for success or failure
    # NOTE : catches exception and sets $error_message, check if -1
    def validate_field f=@widgets[@active_index]
      begin
        on_leave f
      rescue => err
        $log.error "form: validate_field caught EXCEPTION #{err}"
        $log.error(err.backtrace.join("\n")) 
#        $error_message = "#{err}" # changed 2010  
        $error_message.value = "#{err}"
        Ncurses.beep
        return -1
      end
      return 0
    end
    # put focus on next field
    # will cycle by default, unless navigation policy not :CYCLICAL
    # in which case returns :NO_NEXT_FIELD.
    # FIXME: in the beginning it comes in as -1 and does an on_leave of last field
    def select_next_field
      return :UNHANDLED if @widgets.nil? or @widgets.empty?
      #$log.debug "insdie sele nxt field :  #{@active_index} WL:#{@widgets.length}" 
      if @active_index.nil?  || @active_index == -1 # needs to be tested out A LOT
        @active_index = -1 
      else
        f = @widgets[@active_index]
        begin
          on_leave f
        rescue FieldValidationException => err # added 2011-10-2 v1.3.1 so we can rollback
          $log.error "select_next_field: caught EXCEPTION #{err}"
          $error_message.value = "#{err}"
          raise err
        rescue => err
         $log.error "select_next_field: caught EXCEPTION #{err}"
         $log.error(err.backtrace.join("\n")) 
#         $error_message = "#{err}" # changed 2010  
         $error_message.value = "#{err}"
         Ncurses.beep
         return 0
        end
      end
      index = @active_index + 1
      index.upto(@widgets.length-1) do |i|
        f = @widgets[i]
        #$log.debug "insdie sele nxt field :  i #{i}  #{index} WL:#{@widgets.length}, field #{f}" 
        if focusable?(f)
          select_field i
          return 0
        end
      end
      #req_first_field
      #$log.debug "insdie sele nxt field FAILED:  #{@active_index} WL:#{@widgets.length}" 
      ## added on 2008-12-14 18:27 so we can skip to another form/tab
      if @navigation_policy == :CYCLICAL
        @active_index = nil
        # recursive call worked, but bombed if no focusable field!
        #select_next_field
        0.upto(index-1) do |i|
          f = @widgets[i]
          if focusable?(f)
            select_field i
            return 0
          end
        end
      end
      $log.debug "inside sele nxt field : NO NEXT  #{@active_index} WL:#{@widgets.length}" 
      return :NO_NEXT_FIELD
    end
    ##
    # put focus on previous field
    # will cycle by default, unless navigation policy not :CYCLICAL
    # in which case returns :NO_PREV_FIELD.
    # @return [nil, :NO_PREV_FIELD] nil if cyclical and it finds a field
    #  if not cyclical, and no more fields then :NO_PREV_FIELD
    def select_prev_field
      return :UNHANDLED if @widgets.nil? or @widgets.empty?
      #$log.debug "insdie sele prev field :  #{@active_index} WL:#{@widgets.length}" 
      if @active_index.nil?
        @active_index = @widgets.length 
      else
        f = @widgets[@active_index]
        begin
          on_leave f
        rescue => err
         $log.error " Caught EXCEPTION #{err}"
         Ncurses.beep
#         $error_message = "#{err}" # changed 2010  
         $error_message.value = "#{err}"
         return
        end
      end

      index = @active_index - 1
      (index).downto(0) do |i|
        f = @widgets[i]
        if focusable?(f)
          select_field i
          return
        end
      end
      
      ## added on 2008-12-14 18:27 so we can skip to another form/tab
      # 2009-01-08 12:24 no recursion, can be stack overflows if no focusable field
      if @navigation_policy == :CYCLICAL
        @active_index = nil # HACK !!!
        #select_prev_field
        total = @widgets.length-1
        total.downto(index-1) do |i|
          f = @widgets[i]
          if focusable?(f)
            select_field i
            return
          end
        end
      end
      return :NO_PREV_FIELD
    end
    alias :req_next_field :select_next_field
    alias :req_prev_field :select_prev_field
    ##
    # move cursor by num columns. Form
    def addcol num
      return if @col.nil? || @col == -1
      @col += num
      @window.wmove @row, @col
      ## 2010-01-30 23:45 exchange calling parent with calling this forms setrow
      # since in tabbedpane with table i am not gietting this forms offset. 
      setrowcol nil, col
    end
    ##
    # move cursor by given rows and columns, can be negative.
    # 2010-01-30 23:47 FIXME, if this is called we should call setrowcol like in addcol
    def addrowcol row,col
      return if @col.nil? or @col == -1   # contradicts comment on top
      return if @row.nil? or @row == -1
      @col += col
      @row += row
      @window.wmove @row, @col
      # added on 2010-01-05 22:26 so component widgets like scrollpane can get the cursor
      if !@parent_form.nil? and @parent_form != @form
        $log.debug " #{@name} addrowcol calling parents setrowcol #{row}, #{col}  "
        @parent_form.setrowcol row, col
      end
    end

    ## Form
    # New attempt at setting cursor using absolute coordinates
    # Also, trying NOT to go up. let this pad or window print cursor.
    def setrowcol r, c
      @row = r unless r.nil?
      @col = c unless c.nil?
      r +=  @add_rows unless r.nil? # 2010-01-26 20:31 
      c +=  @add_cols unless c.nil? # 2010-01-26 20:31 
      $log.debug " addcols #{@add_cols} addrow #{@add_rows} : #{self} r = #{r} , c = #{c}, parent: #{@parent_form}  "
      if !@parent_form.nil? and @parent_form != self
        $log.debug " (#{@name}) addrow calling parents setrowcol #{r}, #{c} : pare: #{@parent_form}; self:  #{self}, #{self.class}  "
        #r += @parent_form.window.top unless  r.nil?
        #c += @parent_form.window.left unless c.nil?
        @parent_form.setrowcol r, c
      end
    end
  ##

  # e.g. process_key ch, self
  # returns UNHANDLED if no block for it
  # after form handles basic keys, it gives unhandled key to current field, if current field returns
  # unhandled, then it checks this map.
  # Please update widget with any changes here. TODO: match regexes as in mapper

  def process_key keycode, object
    return _process_key keycode, object, @window
  end

  # Defines how user can give numeric args to a command even in edit mode
  # User either presses universal_argument (C-u) which generates a series of 4 16 64.
  # Or he presses C-u and then types some numbers. Followed by the action.
  # @returns [0, :UNHANDLED] :UNHANDLED implies that last keystroke is still to evaluated
  # by system. ) implies only numeric args were obtained. This method updates $multiplier

  def universal_argument
    $multiplier = ( ($multiplier.nil? || $multiplier == 0) ? 4 : $multiplier *= 4)
        $log.debug " inside UNIV MULT0: #{$multiplier} "
    # See if user enters numerics. If so discard existing varaible and take only 
    #+ entered values
    _m = 0
    while true
      ch = @window.getchar()
      case ch
      when -1
        next 
      when ?0.getbyte(0)..?9.getbyte(0)
        _m *= 10 ; _m += (ch-48)
        $multiplier = _m
        $log.debug " inside UNIV MULT #{$multiplier} "
      when ?\C-u.getbyte(0)
        if _m == 0
          # user is incrementally hitting C-u
          $multiplier *= 4
        else
          # user is terminating some numbers so he can enter a numeric command next
          return 0
        end
      else
        $log.debug " inside UNIV MULT else got #{ch} "
        # here is some other key that is the function key to be repeated. we must honor this
        # and ensure it goes to the right widget
        return ch
        #return :UNHANDLED
      end
    end
    return 0
  end

  def digit_argument ch
    $multiplier = ch - ?\M-0.getbyte(0)
    $log.debug " inside UNIV MULT 0 #{$multiplier} "
    # See if user enters numerics. If so discard existing varaible and take only 
    #+ entered values
    _m = $multiplier
    while true
      ch = @window.getchar()
      case ch
      when -1
        next 
      when ?0.getbyte(0)..?9.getbyte(0)
        _m *= 10 ; _m += (ch-48)
        $multiplier = _m
        $log.debug " inside UNIV MULT 1 #{$multiplier} "
      when ?\M-0.getbyte(0)..?\M-9.getbyte(0)
        _m *= 10 ; _m += (ch-?\M-0.getbyte(0))
        $multiplier = _m
        $log.debug " inside UNIV MULT 2 #{$multiplier} "
      else
        $log.debug " inside UNIV MULT else got #{ch} "
        # here is some other key that is the function key to be repeated. we must honor this
        # and ensure it goes to the right widget
        return ch
        #return :UNHANDLED
      end
    end
    return 0
  end
  #
  # These mappings will only trigger if the current field
  #  does not use them.
  #
  def map_keys
    return if @keys_mapped
    bind_keys([?\M-?,?\?]) { alert(get_current_field.help_text, 'title' => 'Help Text', :bgcolor => 'green', :color => :white) if get_current_field.help_text }
    #bind_key(?\?) { alert(get_current_field.help_text.split(",")) if get_current_field.help_text }
    @keys_mapped = true
  end
  
  ## forms handle keys
  # mainly traps tab and backtab to navigate between widgets.
  # I know some widgets will want to use tab, e.g edit boxes for entering a tab
  #  or for completion.
  # @throws FieldValidationException
  # NOTE : please rescue exceptions when you use this in your main loop and alert() user
  #
  def handle_key(ch)
    map_keys unless @keys_mapped
    handled = :UNHANDLED # 2011-10-4 
        if ch ==  ?\C-u.getbyte(0)
          ret = universal_argument
          $log.debug "C-u FORM set MULT to #{$multiplier}, ret = #{ret}  "
          return 0 if ret == 0
          ch = ret # unhandled char
        elsif ch >= ?\M-1.getbyte(0) && ch <= ?\M-9.getbyte(0)
          if $catch_alt_digits # emacs EMACS
            ret = digit_argument ch
            $log.debug " FORM set MULT DA to #{$multiplier}, ret = #{ret}  "
            return 0 if ret == 0 # don't see this happening
            ch = ret # unhandled char
          end
        end

        $current_key = ch
        case ch
        when -1
          return
        #when Ncurses::KEY_RESIZE # SIGWINCH
        when FFI::NCurses::KEY_RESIZE # SIGWINCH #  FFI
          lines = Ncurses.LINES
          cols = Ncurses.COLS
          x = Ncurses.stdscr.getmaxy
          y = Ncurses.stdscr.getmaxx
          $log.debug " form RESIZE HK #{ch} #{self}, #{@name}, #{ch}  "
          alert "SIGWINCH WE NEED TO RECALC AND REPAINT resize #{lines}, #{cols}: #{x}, #{y} "
          Ncurses.endwin
          @window.wrefresh
        else
          field =  get_current_field
          if $log.debug?
            keycode = keycode_tos(ch)
            $log.debug " form HK #{ch} #{self}, #{@name}, #{keycode}, field: giving to: #{field}, #{field.name}  " if field
          end
          handled = :UNHANDLED 
          handled = field.handle_key ch unless field.nil? # no field focussable
          $log.debug "handled inside Form #{ch} from #{field} got #{handled}  "
          # some widgets like textarea and list handle up and down
          if handled == :UNHANDLED or handled == -1 or field.nil?
            case ch
            when KEY_TAB, ?\M-\C-i.getbyte(0)  # tab and M-tab in case widget eats tab (such as Table)
              ret = select_next_field
              return ret if ret == :NO_NEXT_FIELD
              # alt-shift-tab  or backtab (in case Table eats backtab)
            when FFI::NCurses::KEY_BTAB, 481 ## backtab added 2008-12-14 18:41 
              ret = select_prev_field
              return ret if ret == :NO_PREV_FIELD
            when FFI::NCurses::KEY_UP
              ret = select_prev_field
              return ret if ret == :NO_PREV_FIELD
            when FFI::NCurses::KEY_DOWN
              ret = select_next_field
              return ret if ret == :NO_NEXT_FIELD
            else
              #$log.debug " before calling process_key in form #{ch}  " if $log.debug? 
              ret = process_key ch, self
              $log.debug "FORM process_key #{ch} got ret #{ret} in #{self} "
              return :UNHANDLED if ret == :UNHANDLED
            end
          elsif handled == :NO_NEXT_FIELD || handled == :NO_PREV_FIELD # 2011-10-4 
            return handled
          end
        end
       $log.debug " form before repaint #{self} , #{@name}, ret #{ret}"
       repaint
       $last_key = ch
       ret || 0  # 2011-10-17 
  end
  ##
  # test program to dump data onto log
  # The problem I face is that since widget array contains everything that should be displayed
  # I do not know what all the user wants - what are his data entry fields. 
  # A user could have disabled entry on some field after modification, so i can't use focusable 
  # or editable as filters. I just dump everything?
  # What's more, currently getvalue has been used by paint to return what needs to be displayed - 
  # at least by label and button.
  def DEPRECATED_dump_data # CLEAN
    $log.debug "DEPRECATED DUMPING DATA "
    @widgets.each do |w|
      # we need checkbox and radio button values
      #next if w.is_a? RubyCurses::Button or w.is_a? RubyCurses::Label 
      next if w.is_a? RubyCurses::Label 
      next if !w.is_a? RubyCurses::Widget
      if w.respond_to? :getvalue
        $log.debug " #{w.name} #{w.getvalue}"
      else
        $log.debug " #{w.name} DOES NOT RESPOND TO getvalue"
      end
    end
    $log.debug " END DUMPING DATA "
  end
  ##
  # trying out for splitpane and others who have a sub-form. TabbedPane uses
  def set_parent_buffer b
    @parent_buffer = b
  end
  # 2010-02-07 14:50 to aid in debugging and comparing log files.
  def to_s; @name || self; end

  # NOTE: very experimental, use at risk, can change location or be deprec
  # place given widget below given one, or last added one
  # Does not check for availability or overlap
  def place_below me, other=nil
    w = widgets
    if other.nil?
      other = w[-1]
      # if user calls this after placing this field
      other = w[-2] if other == me
    end
    if other.height.nil? || other.height == 0
      h = 1
    else
      h = other.height
    end
    me.row = other.row + h
    me.col = other.col
    me
  end
  # NOTE: very experimental, use at risk, can change location or be deprec
  # return location to place next widget (below)
  # Does not check for availability or overlap
  def next_position
    w = widgets.last
    if w.height.nil? || w.height == 0
      h = 1
    else
      h = w.height
    end
    row = w.row + h
    col = w.col
    return row, col
  end

    ## ADD HERE FORM
  end
  ## Created and sent to all listeners whenever a property is changed
  # @see fire_property_change
  # @see fire_handler 
  # @since 1.0.5 added 2010-02-25 23:06 
  class PropertyChangeEvent
    attr_accessor :source, :property_name, :oldvalue, :newvalue
    def initialize source, property_name, oldvalue, newvalue
      set source, property_name, oldvalue, newvalue
    end
    def set source, property_name, oldvalue, newvalue
        @source, @property_name, @oldvalue, @newvalue =
        source, property_name, oldvalue, newvalue
    end
    def to_s
      "PROPERTY_CHANGE name: #{property_name}, oldval: #{@oldvalue}, newvalue: #{@newvalue}, source: #{@source}"
    end
    def inspect
      to_s
    end
  end

  ##
  # Text edit field
  # NOTE: To get value use getvalue() 
  # TODO - test text_variable
  # TODO: some methods should return self, so chaining can be done. Not sure if the return value of the 
  #   fire_handler is being checked.
  #   NOTE: i have just added repain_required check in Field before repaint
  #   this may mean in some places field does not paint. repaint_require will have to be set
  #   to true in those cases. this was since field was overriding a popup window that was not modal.
  #  
  class Field < Widget
    dsl_accessor :maxlen             # maximum length allowed into field
    attr_reader :buffer              # actual buffer being used for storage
    #
    # this was unused earlier. Unlike set_label which creates a separate label
    # object, this stores a label and prints it before the string. This is less
    # customizable, however, in some cases when a field is attached to some container
    # the label gets left out. This labels is gauranteed to print to the left of the field
    # 
    dsl_accessor :label              # label of field  Unused earlier, now will print 
    dsl_property :label_color_pair   # label of field  Unused earlier, now will print 
    dsl_property :label_attr   # label of field  Unused earlier, now will print 
    #dsl_accessor :default            # now alias of text 2011-11-5 
    dsl_accessor :values             # validate against provided list
    dsl_accessor :valid_regex        # validate against regular expression
    dsl_accessor :valid_range        # validate against numeric range # 2011-09-29 V1.3.1 

    dsl_accessor :chars_allowed           # regex, what characters to allow, will ignore all else
    dsl_accessor :display_length          # how much to display
    dsl_accessor :show                    # what charactr to show for each char entered (password field)
    dsl_accessor :null_allowed            # allow nulls, don't validate if null # added 2008-12-22 12:38 

    # any new widget that has editable should have modified also
    dsl_accessor :editable          # allow editing

    attr_reader :form
    attr_reader :handler                       # event handler
    attr_reader :type                          # datatype of field, currently only sets chars_allowed
    #attr_reader :curpos                       # cursor position in buffer current, in WIDGET 
    attr_accessor :datatype                    # crrently set during set_buffer
    attr_reader :original_value                # value on entering field
    attr_accessor :overwrite_mode              # true or false INSERT OVERWRITE MODE

    # For consistency, now width equates to display_length
    alias :width :display_length
    alias :width= :display_length=

    def initialize form=nil, config={}, &block
      @form = form
      @buffer = String.new
      #@type=config.fetch("type", :varchar)
      @display_length = 20
      @maxlen = @display_length
      @row = 0
      @col = 0
      #@bgcolor = $def_bg_color
      #@color = $def_fg_color
      @editable = true
      @focusable = true
      @event_args = {}             # arguments passed at time of binding, to use when firing event
      map_keys 
      init_vars
      @_events ||= []
      @_events.push(:CHANGE)
      super
    end
    def init_vars
      @pcol = 0                    # needed for horiz scrolling
      @curpos = 0                  # current cursor position in buffer
      @modified = false
      @repaint_required = true
    end

    #
    # Set Variable as value. 
    #  This allows using Field as a proxy
    #  @param [Variable] variable containing text value
    #
    def text_variable tv
      @text_variable = tv
      set_buffer tv.value
    end
    ##
    # define a datatype, currently only influences chars allowed
    # integer and float. what about allowing a minus sign? 
    def type dtype
      return if @chars_allowed # disallow changing
      dtype = dtype.to_s.downcase.to_sym if dtype.is_a? String
      case dtype # missing to_sym would have always failed due to to_s 2011-09-30 1.3.1
      when :integer
        @chars_allowed = /\d/
      when :numeric, :float
        @chars_allowed = /[\d\.]/ 
      when :alpha
        @chars_allowed = /[a-zA-Z]/ 
      when :alnum
        @chars_allowed = /[a-zA-Z0-9]/ 
      else
        raise ArgumentError, "Field type: invalid datatype specified. Use :integer, :numeric, :float, :alpha, :alnum "
      end
    end

    #
    # add a char to field, and validate
    # NOTE: this should return self for chaining operations and throw an exception
    # if disabled or exceeding size
    # @param [char] a character to add
    # @return [Fixnum] 0 if okay, -1 if not editable or exceeding length
    def putch char
      return -1 if !@editable 
      return -1 if !@overwrite_mode and @buffer.length >= @maxlen
      if @chars_allowed != nil
        return if char.match(@chars_allowed).nil?
      end
      # added insert or overwrite mode 2010-03-17 20:11 
      oldchar = nil
      if @overwrite_mode
        oldchar = @buffer[@curpos] 
        @buffer[@curpos] = char
      else
        @buffer.insert(@curpos, char)
      end
      oldcurpos = @curpos
      @curpos += 1 if @curpos < @maxlen
      @modified = true
      #$log.debug " FIELD FIRING CHANGE: #{char} at new #{@curpos}: bl:#{@buffer.length} buff:[#{@buffer}]"
      # i have no way of knowing what change happened and what char was added deleted or changed
      #fire_handler :CHANGE, self    # 2008-12-09 14:51 
      if @overwrite_mode
        fire_handler :CHANGE, InputDataEvent.new(oldcurpos,@curpos, self, :DELETE, 0, oldchar) # 2010-09-11 12:43 
      end
      fire_handler :CHANGE, InputDataEvent.new(oldcurpos,@curpos, self, :INSERT, 0, char) # 2010-09-11 12:43 
      0
    end

    ##
    # TODO : sending c>=0 allows control chars to go. Should be >= ?A i think.
    def putc c
      if c >= 0 and c <= 127
        ret = putch c.chr
        if ret == 0
          if addcol(1) == -1  # if can't go forward, try scrolling
            # scroll if exceeding display len but less than max len
            if @curpos > @display_length and @curpos <= @maxlen
              @pcol += 1 if @pcol < @display_length 
            end
          end
          set_modified 
          return 0 # 2010-09-11 12:59 else would always return -1
        end
      end
      return -1
    end
    def delete_at index=@curpos
      return -1 if !@editable 
      char = @buffer.slice!(index,1)
      #$log.debug " delete at #{index}: #{@buffer.length}: #{@buffer}"
      @modified = true
      #fire_handler :CHANGE, self    # 2008-12-09 14:51 
      fire_handler :CHANGE, InputDataEvent.new(@curpos,@curpos, self, :DELETE, 0, char)     # 2010-09-11 13:01 
    end
    #
    # silently restores value without firing handlers, use if exception and you want old value
    # @since 1.4.0 2011-10-2 
    def restore_original_value
      @buffer = @original_value.dup
      #@curpos = 0 # this would require restting setformcol
      @repaint_required = true
    end
    ## 
    # should this do a dup ?? YES
    # set value of Field
    # fires CHANGE handler
    def set_buffer value
      @repaint_required = true
      @datatype = value.class
      #$log.debug " FIELD DATA #{@datatype}"
      @delete_buffer = @buffer.dup
      @buffer = value.to_s.dup
      @curpos = 0
      # hope @delete_buffer is not overwritten
      fire_handler :CHANGE, InputDataEvent.new(@curpos,@curpos, self, :DELETE, 0, @delete_buffer)     # 2010-09-11 13:01 
      fire_handler :CHANGE, InputDataEvent.new(@curpos,@curpos, self, :INSERT, 0, @buffer)     # 2010-09-11 13:01 
      self # 2011-10-2 
    end
    # converts back into original type
    #  changed to convert on 2009-01-06 23:39 
    def getvalue
      dt = @datatype || String
      case dt.to_s
      when "String"
        return @buffer
      when "Fixnum"
        return @buffer.to_i
      when "Float"
        return @buffer.to_f
      else
        return @buffer.to_s
      end
    end
  
    # create a label linked to this field
    # Typically one passes a Label, but now we can pass just a String, a label 
    # is created
    # NOTE: 2011-10-20 when field attached to some container, label won't be attached
    # @param [Label, String] label object to be associated with this field
    # FIXME this may not work since i have disabled -1, now i do not set row and col 2011-11-5 
    def set_label label
      # added case for user just using a string
      case label
      when String
        # what if no form at this point
        @label_unattached = true unless @form
        label = Label.new @form, {:text => label}
      end
      @label = label
      # in the case of app it won't be set yet FIXME
      # So app sets label to 0 and t his won't trigger
      # can this be delayed to when paint happens XXX
      if @row
        position_label
      else
        @label_unplaced = true
      end
      label
    end
    # FIXME this may not work since i have disabled -1, now i do not set row and col
    def position_label
      $log.debug "XXX: LABEL row #{@label.row}, #{@label.col} "
      @label.row  @row unless @label.row #if @label.row == -1
      @label.col  @col-(@label.name.length+1) unless @label.col #if @label.col == -1
      @label.label_for(self) # this line got deleted when we redid stuff !
      $log.debug "   XXX: LABEL row #{@label.row}, #{@label.col} "
    end

  ## Note that some older widgets like Field repaint every time the form.repaint
  ##+ is called, whether updated or not. I can't remember why this is, but
  ##+ currently I've not implemented events with these widgets. 2010-01-03 15:00 

  def repaint
    return unless @repaint_required  # 2010-11-20 13:13 its writing over a window i think TESTING
    if @label_unattached
      alert "came here unattachd"
      @label.set_form(@form)
    end
    if @label_unplaced
      alert "came here unplaced"
      position_label
    end
    @bgcolor ||= $def_bg_color
    @color   ||= $def_fg_color
    $log.debug("repaint FIELD: #{id}, #{name}, #{row} #{col},  #{focusable} st: #{@state} ")
    #return if display_length <= 0 # added 2009-02-17 00:17 sometimes editor comp has 0 and that
    # becomes negative below, no because editing still happens
    @display_length = 1 if display_length == 0
    printval = getvalue_for_paint().to_s # added 2009-01-06 23:27 
    printval = show()*printval.length unless @show.nil?
    if !printval.nil? 
      if printval.length > display_length # only show maxlen
        printval = printval[@pcol..@pcol+display_length-1] 
      else
        printval = printval[@pcol..-1]
      end
    end
  
    acolor = @color_pair || get_color($datacolor, @color, @bgcolor)
    if @state == :HIGHLIGHTED
      _bgcolor = @highlight_background || @bgcolor
      _color = @highlight_foreground || @color
      acolor = get_color(acolor, _color, _bgcolor)
    end
    @graphic = @form.window if @graphic.nil? ## cell editor listbox hack 
    #$log.debug " Field g:#{@graphic}. r,c,displen:#{@row}, #{@col}, #{@display_length} c:#{@color} bg:#{@bgcolor} a:#{@attr} :#{@name} "
    r = row
    c = col
    if label.is_a? String
      lcolor = @label_color_pair || $datacolor # this should be the same color as window bg XXX
      lattr = @label_attr || NORMAL
      @graphic.printstring row, col, label, lcolor, lattr
      c += label.length + 2
      @col_offset = c-@col            # required so cursor lands in right place
    end
    @graphic.printstring r, c, sprintf("%-*s", display_length, printval), acolor, @attr
    @repaint_required = false
  end
  def set_focusable(tf)
    @focusable = tf
  end
  def map_keys
    return if @keys_mapped
    bind_key(FFI::NCurses::KEY_LEFT){ cursor_backward }
    bind_key(FFI::NCurses::KEY_RIGHT){ cursor_forward }
    bind_key(FFI::NCurses::KEY_BACKSPACE){ delete_prev_char }
    bind_key(127){ delete_prev_char }
    bind_key(330){ delete_curr_char }
    bind_key(?\C-a){ cursor_home }
    bind_key(?\C-e){ cursor_end }
    bind_key(?\C-k){ delete_eol }
    bind_key(?\C-_){ undo_delete_eol }
    #bind_key(27){ set_buffer @original_value }
    bind_key(?\C-g){ set_buffer @original_value } # 2011-09-29 V1.3.1 ESC did not work
    @keys_mapped = true
  end

  # field
  # 
  def handle_key ch
    @repaint_required = true 
    #map_keys unless @keys_mapped # moved to init
    case ch
    when 32..126
      #$log.debug("FIELD: ch #{ch} ,at #{@curpos}, buffer:[#{@buffer}] bl: #{@buffer.to_s.length}")
      putc ch
    when 27 # cannot bind it
      set_buffer @original_value 
    else
      ret = super
      return ret
    end
    0 # 2008-12-16 23:05 without this -1 was going back so no repaint
  end
  # does an undo on delete_eol, not a real undo
  def undo_delete_eol
    return if @delete_buffer.nil?
    #oldvalue = @buffer
    @buffer.insert @curpos, @delete_buffer 
    fire_handler :CHANGE, InputDataEvent.new(@curpos,@curpos+@delete_buffer.length, self, :INSERT, 0, @delete_buffer)     # 2010-09-11 13:01 
  end
  ## 
  # position cursor at start of field
  def cursor_home
    set_form_col 0
    @pcol = 0
  end
  ##
  # goto end of field, "end" is a keyword so could not use it.
  def cursor_end
    blen = @buffer.rstrip.length
    if blen < @display_length
      set_form_col blen
    else
      @pcol = blen-@display_length
      set_form_col @display_length-1
    end
    @curpos = blen # HACK 
    #  $log.debug " crusor END cp:#{@curpos} pcol:#{@pcol} b.l:#{@buffer.length} d_l:#{@display_length} fc:#{@form.col}"
    #set_form_col @buffer.length
  end
  def delete_eol
    return -1 unless @editable
    pos = @curpos-1
    @delete_buffer = @buffer[@curpos..-1]
    # if pos is 0, pos-1 becomes -1, end of line!
    @buffer = pos == -1 ? "" : @buffer[0..pos]
    #fire_handler :CHANGE, self    # 2008-12-09 14:51 
    fire_handler :CHANGE, InputDataEvent.new(@curpos,@curpos+@delete_buffer.length, self, :DELETE, 0, @delete_buffer)     # 2010-09-11 13:01 
    return @delete_buffer
  end
  def cursor_forward
    if @curpos < @buffer.length 
      if addcol(1)==-1  # go forward if you can, else scroll
        @pcol += 1 if @pcol < @display_length 
      end
      @curpos += 1
    end
   # $log.debug " crusor FORWARD cp:#{@curpos} pcol:#{@pcol} b.l:#{@buffer.length} d_l:#{@display_length} fc:#{@form.col}"
  end
  def cursor_backward
    if @curpos > 0
      @curpos -= 1
      if @pcol > 0 and @form.col == @col + @col_offset
        @pcol -= 1
      end
      addcol -1
    elsif @pcol > 0 #  added 2008-11-26 23:05 
      @pcol -= 1   
    end
 #   $log.debug " crusor back cp:#{@curpos} pcol:#{@pcol} b.l:#{@buffer.length} d_l:#{@display_length} fc:#{@form.col}"
=begin
# this is perfect if not scrolling, but now needs changes
    if @curpos > 0
      @curpos -= 1
      addcol -1
    end
=end
  end
    def delete_curr_char
      return -1 unless @editable
      delete_at
      set_modified 
    end
    def delete_prev_char
      return -1 if !@editable 
      return if @curpos <= 0
      @curpos -= 1 if @curpos > 0
      delete_at
      set_modified 
      addcol -1
    end
    ## add a column to cursor position. Field
    def addcol num
      if num < 0
        if @form.col <= @col + @col_offset
         # $log.debug " error trying to cursor back #{@form.col}"
          return -1
        end
      elsif num > 0
        if @form.col >= @col + @col_offset + @display_length
      #    $log.debug " error trying to cursor forward #{@form.col}"
          return -1
        end
      end
      @form.addcol num
    end
    # upon leaving a field
    # returns false if value not valid as per values or valid_regex
    # 2008-12-22 12:40 if null_allowed, don't validate, but do fire_handlers
    def on_leave
      val = getvalue
      #$log.debug " FIELD ON LEAVE:#{val}. #{@values.inspect}"
      valid = true
      if val.to_s.empty? and @null_allowed
        $log.debug " empty and null allowed"
      else
        if !@values.nil?
          valid = @values.include? val
          raise FieldValidationException, "Field value (#{val}) not in values: #{@values.join(',')}" unless valid
        end
        if !@valid_regex.nil?
          valid = @valid_regex.match(val.to_s)
          raise FieldValidationException, "Field not matching regex #{@valid_regex}" unless valid
        end
        # added valid_range for numerics 2011-09-29 
        if !@valid_range.nil?
          valid = @valid_range.include?(val.to_i)
          raise FieldValidationException, "Field not matching range #{@valid_range}" unless valid
        end
      end
      # here is where we should set the forms modified to true - 2009-01
      if modified?
        set_modified true
      end
      # if super fails we would have still set modified to true
      super
      #return valid
    end
    ## save original value on enter, so we can check for modified.
    #  2009-01-18 12:25 
    #   2011-10-9 I have changed to take @buffer since getvalue returns a datatype
    #   and this causes a crash in set_original on cursor forward.
    def on_enter
      #@original_value = getvalue.dup rescue getvalue
      @original_value = @buffer.dup # getvalue.dup rescue getvalue
      super
    end
    ##
    # overriding widget, check for value change
    #  2009-01-18 12:25 
    def modified?
      getvalue() != @original_value
    end
    #
    # Use this to set a default text to the field. This does not imply that if the field is left
    # blank, this value will be used. It only provides this value for editing when field is shown.
    # @since 1.2.0
    def text(*val)
      if val.empty?
        return getvalue()
      else
        return unless val # added 2010-11-17 20:11, dup will fail on nil
        s = val[0].dup
        set_buffer(s)
      end
    end
    alias :default :text
    def text=(val)
      return unless val # added 2010-11-17 20:11, dup will fail on nil
      set_buffer(val.dup)
    end
  # ADD HERE FIELD
  end
        
  ##
  # Like Tk's TkVariable, a simple proxy that can be passed to a widget. The widget 
  # will update the Variable. A variable can be used to link a field with a label or 
  # some other widget.
  # This is the new version of Variable. Deleting old version on 2009-01-17 12:04 

  class Variable
  
    def initialize value=""
      @update_command = []
      @args = []
      @value = value
      @klass = value.class.to_s
    end

    ## 
    # This is to ensure that change handlers for all dependent objects are called
    # so they are updated. This is called from text_variable property of some widgets. If you 
    # use one text_variable across objects, all will be updated auto. User does not need to call.
    # @ private
    def add_dependent obj
      $log.debug " ADDING DEPENDE #{obj}"
      @dependents ||= []
      @dependents << obj
    end
    ##
    # install trigger to call whenever a value is updated
    # @public called by user components
    def update_command *args, &block
      $log.debug "Variable: update command set " # #{args}"
      @update_command << block
      @args << args
    end
    ##
    # value of the variable
    def get_value val=nil
      if @klass == 'String'
        return @value
      elsif @klass == 'Hash'
        return @value[val]
      elsif @klass == 'Array'
        return @value[val]
      else
        return @value
      end
    end
    ##
    # update the value of this variable.
    # 2008-12-31 18:35 Added source so one can identify multiple sources that are updating.
    # Idea is that mutiple fields (e.g. checkboxes) can share one var and update a hash through it.
    # Source would contain some code or key relatin to each field.
    def set_value val, key=""
      oldval = @value
      if @klass == 'String'
        @value = val
      elsif @klass == 'Hash'
        $log.debug " Variable setting hash #{key} to #{val}"
        oldval = @value[key]
        @value[key]=val
      elsif @klass == 'Array'
        $log.debug " Variable setting array #{key} to #{val}"
        oldval = @value[key]
        @value[key]=val
      else
        oldval = @value
        @value = val
      end
      return if @update_command.nil?
      @update_command.each_with_index do |comm, ix|
        comm.call(self, *@args[ix]) unless comm.nil?
      end
      @dependents.each {|d| d.fire_property_change(d, oldval, val) } unless @dependents.nil?
    end
    ##
    def value= (val)
      raise "Please use set_value for hash/array" if @klass=='Hash' or @klass=='Array'
      oldval = @value
      @value=val
      return if @update_command.nil?
      @update_command.each_with_index do |comm, ix|
        comm.call(self, *@args[ix]) unless comm.nil?
      end
      @dependents.each {|d| d.fire_property_change(d, oldval, val) } unless @dependents.nil?
    end
    def value
      raise "Please use set_value for hash/array: #{@klass}" if @klass=='Hash' #or @klass=='Array'
      @value
    end
    def inspect
      @value.inspect
    end
    def [](key)
      @value[key]
    end
    ## 
    # in order to run some method we don't yet support
    def source
      @value
    end
    def to_s
      inspect
    end
  end
  ##
  # The preferred way of printing text on screen, esp if you want to modify it at run time.
  # Use display_length to ensure no spillage.
  # This can use text or text_variable for setting and getting data (inh from Widget).
  # 2011-11-12 making it simpler, and single line only. The original multiline label
  #    has moved to extras/multilinelabel.rb
  #
  class Label < Widget
    dsl_accessor :mnemonic       # keyboard focus is passed to buddy based on this key (ALT mask)

    # justify required a display length, esp if center.
    dsl_property :justify        #:right, :left, :center
    dsl_property :display_length #please give this to ensure the we only print this much
    #dsl_property :height         #if you want a multiline label. already added to widget
    # for consistency with others 2011-11-5 
    alias :width :display_length
    alias :width= :display_length=

    def initialize form, config={}, &block
  
      # this crap was used in position_label, find another way. where is it used ?
      #@row = config.fetch("row",-1)  # why on earth this monstrosity ? 2011-11-5 
      #@col = config.fetch("col",-1) 
      #@bgcolor = config.fetch("bgcolor", $def_bg_color)
      #@color = config.fetch("color", $def_fg_color)
      @text = config.fetch(:text, "NOTFOUND")
      @editable = false
      @focusable = false
      super
      @justify ||= :left
      @name ||= @text
      @repaint_required = true
    end
    #
    # get the value for the label
    def getvalue
      @text_variable && @text_variable.value || @text
    end
    def label_for field
      @label_for = field
      #$log.debug " label for: #{@label_for}"
      if @form
        bind_hotkey 
      else
        @when_form ||= []
        @when_form << lambda { bind_hotkey }
      end
    end

    ##
    # for a button, fire it when label invoked without changing focus
    # for other widgets, attempt to change focus to that field
    def bind_hotkey
      if @mnemonic
        ch = @mnemonic.downcase()[0].ord   ##  1.9 DONE 
        # meta key 
        mch = ?\M-a.getbyte(0) + (ch - ?a.getbyte(0))  ## 1.9
        if (@label_for.is_a? RubyCurses::Button ) && (@label_for.respond_to? :fire)
          @form.bind_key(mch, @label_for) { |_form, _butt| _butt.fire }
        else
          $log.debug " bind_hotkey label for: #{@label_for}"
          @form.bind_key(mch, @label_for) { |_form, _field| _field.focus }
        end
      end
    end

    ##
    # label's repaint - I am removing wrapping and Array stuff and making it simple 2011-11-12 
    def repaint
      return unless @repaint_required
      raise "Label row or col nil #{@row} , #{@col}, #{@text} " if @row.nil? || @col.nil?
      r,c = rowcol

      @bgcolor ||= $def_bg_color
      @color   ||= $def_fg_color
      # value often nil so putting blank, but usually some application error
      value = getvalue_for_paint || ""

      if value.is_a? Array
        value = value.join " "
      end
      # ensure we do not exceed
      if @display_length
        if value.length > @display_length
          value = value[0..@display_length-1]
        end
      end
      len = @display_length || value.length
      #acolor = get_color $datacolor
      # the user could have set color_pair, use that, else determine color
      # This implies that if he sets cp, then changing col and bg won't have an effect !
      # A general routine that only changes color will not work here.
      acolor = @color_pair || get_color($datacolor, @color, @bgcolor)
      #$log.debug "label :#{@text}, #{value}, r #{r}, c #{c} col= #{@color}, #{@bgcolor} acolor  #{acolor} j:#{@justify} dlL: #{@display_length} "
      str = @justify.to_sym == :right ? "%*s" : "%-*s"  # added 2008-12-22 19:05 
    
      @graphic ||= @form.window
      # clear the area
      @graphic.printstring r, c, " " * len , acolor, @attr
      if @justify.to_sym == :center
        padding = (@display_length - value.length)/2
        value = " "*padding + value + " "*padding # so its cleared if we change it midway
      end
      @graphic.printstring r, c, str % [len, value], acolor, @attr
      if @mnemonic
        ulindex = value.index(@mnemonic) || value.index(@mnemonic.swapcase)
        @graphic.mvchgat(y=r, x=c+ulindex, max=1, Ncurses::A_BOLD|Ncurses::A_UNDERLINE, acolor, nil)
      end
      @repaint_required = false
    end
    # Added 2011-10-22 to prevent some naive components from putting focus here.
    def on_enter
      raise "Cannot enter Label"
    end
    def on_leave
      raise "Cannot leave Label"
    end
  # ADD HERE LABEL
  end
  ##
  # action buttons
  # NOTE: When firing event, an ActionEvent will be passed as the first parameter, followed by anything
  # you may have passed when binding, or calling the command() method. 
  # TODO: phasing out underline, and giving mnemonic and ampersand preference
  #  - Action: may have to listen to Action property changes so enabled, name etc change can be reflected
  class Button < Widget
    dsl_accessor :surround_chars   # characters to use to surround the button, def is square brackets
    dsl_accessor :mnemonic
    def initialize form, config={}, &block
      require 'rbcurse/ractionevent'
      @focusable = true
      @editable = false
      @handler={} # event handler
      @event_args ||= {}
      @_events ||= []
      @_events.push :PRESS
      super


      @surround_chars ||= ['[ ', ' ]'] 
      @col_offset = @surround_chars[0].length 
      @text_offset = 0
    end
    ##
    # set button based on Action
    #  2009-01-21 19:59 
    def action a
      text a.name
      mnemonic a.mnemonic unless a.mnemonic.nil?
      command { a.call }
    end
    ##
    # button:  sets text, checking for ampersand, uses that for hotkey and underlines
    def text(*val)
      if val.empty?
        return @text
      else
        s = val[0].dup
        s = s.to_s if !s.is_a? String  # 2009-01-15 17:32 
        if (( ix = s.index('&')) != nil)
          s.slice!(ix,1)
          # 2011-10-20 NOTE XXX I have removed form check since bindkey is called conditionally
          @underline = ix #unless @form.nil? # this setting a fake underline in messageboxes
          mnemonic s[ix,1]
        end
        @text = s
      end
    end

    ## 
    # FIXME this will not work in messageboxes since no form available
    # if already set mnemonic, then unbind_key, ??
    # NOTE: Some buttons like checkbox directly call mnemonic, so if they have no form
    # then this processing does not happen

    def mnemonic char
      $log.error "ERROR WARN #{self} COULD NOT SET MNEMONIC since form NIL" if @form.nil?
      unless @form
        @when_form ||= []
        @when_form << lambda { mnemonic char }
        return
      end
      #return if @form.nil?
      @mnemonic = char
      ch = char.downcase()[0].ord ##  1.9 
      # meta key 
      mch = ?\M-a.getbyte(0) + (ch - ?a.getbyte(0))
      $log.debug " #{self} setting MNEMO to #{char} #{mch}"
      @form.bind_key(mch, self) { |_form, _butt| _butt.fire }
    end

    ##
    # bind hotkey to form keys. added 2008-12-15 20:19 
    # use ampersand in name or underline
    def bind_hotkey
      if @form.nil? 
        if @underline
          @when_form ||= []
          @when_form << lambda { bind_hotkey }
        end
        return
      end
      _value = @text || getvalue # hack for Togglebutton FIXME
      #_value = getvalue
      $log.debug " bind hot #{_value} #{@underline}"
      ch = _value[@underline,1].downcase()[0].ord ##  1.9  2009-10-05 18:55  TOTEST
      @mnemonic = _value[@underline,1]
      # meta key 
      mch = ?\M-a.getbyte(0) + (ch - ?a.getbyte(0))
      @form.bind_key(mch, self) { |_form, _butt| _butt.fire }
    end

    def getvalue
      @text_variable.nil? ? @text : @text_variable.get_value(@name)
    end

    # ensure text has been passed or action
    def getvalue_for_paint
      ret = getvalue
      @text_offset = @surround_chars[0].length
      @surround_chars[0] + ret + @surround_chars[1]
    end
    def repaint  # button
      if @form
        if @when_form
          $log.debug "XXX:WHEN  calling when_forms commands"
          @when_form.each { |c| c.call()  }
          @when_form = nil
        end
      end

      @bgcolor ||= $def_bg_color
      @color   ||= $def_fg_color
        $log.debug("BUTTON repaint : #{self}  r:#{@row} c:#{@col} , #{@color} , #{@bgcolor} , #{getvalue_for_paint}" )
        r,c = @row, @col #rowcol include offset for putting cursor
        # NOTE: please override both (if using a string), or else it won't work 
        @highlight_foreground ||= $reversecolor
        @highlight_background ||= 0
        _bgcolor = @bgcolor
        _color = @color
        if @state == :HIGHLIGHTED
          _bgcolor = @state==:HIGHLIGHTED ? @highlight_background : @bgcolor
          _color = @state==:HIGHLIGHTED ? @highlight_foreground : @color
        elsif selected? # only for certain buttons lie toggle and radio
          _bgcolor = @selected_background || @bgcolor
          _color   = @selected_foreground || @color
        end
        $log.debug "XXX: button #{text}   STATE is #{@state} color #{_color} , bg: #{_bgcolor} "
        if _bgcolor.is_a?( Fixnum) && _color.is_a?( Fixnum)
        else
          _color = get_color($datacolor, _color, _bgcolor)
        end
        value = getvalue_for_paint
        $log.debug("button repaint :#{self} r:#{r} c:#{c} col:#{_color} bg #{_bgcolor} v: #{value} ul #{@underline} mnem #{@mnemonic} datacolor #{$datacolor} ")
        len = @display_length || value.length
        @graphic = @form.window if @graphic.nil? ## cell editor listbox hack 
        @graphic.printstring r, c, "%-*s" % [len, value], _color, @attr
#       @form.window.mvchgat(y=r, x=c, max=len, Ncurses::A_NORMAL, bgcolor, nil)
        # in toggle buttons the underline can change as the text toggles
        if @underline || @mnemonic
          uline = @underline && (@underline + @text_offset) ||  value.index(@mnemonic) || 
            value.index(@mnemonic.swapcase)
          # if the char is not found don't print it
          if uline
            y=r #-@graphic.top
            x=c+uline #-@graphic.left
            if @graphic.window_type == :PAD
              x -= @graphic.left 
              y -= @graphic.top
            end
            #
            # NOTE: often values go below zero since root windows are defined 
            # with 0 w and h, and then i might use that value for calcaluting
            #
            $log.error "XXX button underline location error #{x} , #{y} " if x < 0 or c < 0
            raise " #{r} #{c}  #{uline} button underline location error x:#{x} , y:#{y}. left #{@graphic.left} top:#{@graphic.top} " if x < 0 or c < 0
            @graphic.mvchgat(y, x, max=1, Ncurses::A_BOLD|Ncurses::A_UNDERLINE, _color, nil)
          end
        end
    end

    ## command of button (invoked on press, hotkey, space)
    # added args 2008-12-20 19:22 
    def command *args, &block
      bind :PRESS, *args, &block
      $log.debug "#{text} bound PRESS"
    end
    ## fires PRESS event of button
    def fire
      $log.debug "firing PRESS #{text}"
      # why the .... am i passing form ? Pass a ActionEvent with source, text() and getvalue()
      #fire_handler :PRESS, @form  changed on 2010-09-12 19:22 
      fire_handler :PRESS, ActionEvent.new(self, :PRESS, text)
    end
    # for campatibility with all buttons, will apply to radio buttons mostly
    def selected?; false; end

    # Button
    def handle_key ch
      case ch
      when FFI::NCurses::KEY_LEFT, FFI::NCurses::KEY_UP
        return :UNHANDLED
        #  @form.select_prev_field
      when FFI::NCurses::KEY_RIGHT, FFI::NCurses::KEY_DOWN
        return :UNHANDLED
        #  @form.select_next_field
      when FFI::NCurses::KEY_ENTER, 10, 13, 32  # added space bar also
        if respond_to? :fire
          fire
        end
      else
        if $key_map == :vim
          case ch
          when ?j.getbyte(0)
            @form.window.ungetch(KEY_DOWN)
            return 0
          when ?k.getbyte(0)
            @form.window.ungetch(KEY_UP)
            return 0
          end

        end
        return :UNHANDLED
      end
    end

    # temporary method, shoud be a proper class
    def self.button_layout buttons, row, startcol=0, cols=Ncurses.COLS-1, gap=5
      col = startcol
      buttons.each_with_index do |b, ix|
        $log.debug " BUTTON #{b}: #{b.col} "
        b.row = row
        b.col col
        $log.debug " after BUTTON #{b}: #{b.col} "
        len = b.text.length + gap
        col += len
      end
    end
  end #BUTTON
  
  ##
  # an event fired when an item that can be selected is toggled/selected
  class ItemEvent 
    # http://java.sun.com/javase/6/docs/api/java/awt/event/ItemEvent.html
    attr_reader :state   # :SELECTED :DESELECTED
    attr_reader :item   # the item pressed such as toggle button
    attr_reader :item_selectable   # item originating event such as list or collection
    attr_reader :item_first   # if from a list
    attr_reader :item_last   # 
    attr_reader :param_string   #  for debugging etc
=begin
    def initialize item, item_selectable, state, item_first=-1, item_last=-1, paramstring=nil
      @item, @item_selectable, @state, @item_first, @item_last =
        item, item_selectable, state, item_first, item_last 
      @param_string = "Item event fired: #{item}, #{state}"
    end
=end
    # i think only one is needed per object, so create once only
    def initialize item, item_selectable
      @item, @item_selectable =
        item, item_selectable
    end
    def set state, item_first=-1, item_last=-1, param_string=nil
      @state, @item_first, @item_last, @param_string =
        state, item_first, item_last, param_string 
      @param_string = "Item event fired: #{item}, #{state}" if param_string.nil?
    end
  end
  ##
  # A button that may be switched off an on. 
  # To be extended by RadioButton and checkbox.
  # TODO: add editable here nd prevent toggling if not so.
  class ToggleButton < Button
    dsl_accessor :onvalue, :offvalue
    dsl_accessor :value
    dsl_accessor :surround_chars 
    dsl_accessor :variable    # value linked to this variable which is a boolean
    dsl_accessor :display_length    #  2009-01-06 00:10 
    # background to use when selected, if not set then default
    dsl_accessor :selected_background 
    dsl_accessor :selected_foreground 

    # For consistency, now width equates to display_length
    alias :width :display_length
    alias :width= :display_length=

    # item_event
    def initialize form, config={}, &block
      super
      
      @value ||= (@variable.nil? ? false : @variable.get_value(@name)==true)
    end
    def getvalue
      @value ? @onvalue : @offvalue
    end
    # added for some standardization 2010-09-07 20:28 
    # alias :text :getvalue # NEXT VERSION
    # change existing text to label
    ##
    # is the button on or off
    # added 2008-12-09 19:05 
    def checked?
      @value
    end
    alias :selected? :checked?

    def getvalue_for_paint
      unless @display_length
        if @onvalue && @offvalue
          @display_length = [ @onvalue.length, @offvalue.length ].max
        end
      end
      buttontext = getvalue().center(@display_length)
      @text_offset = @surround_chars[0].length
      @surround_chars[0] + buttontext + @surround_chars[1]
    end

    # toggle button handle key
    # @param [int] key received
    #
    def handle_key ch
      if ch == 32
        toggle
      else
        super
      end
    end

    ##
    # toggle the button value
    def toggle
      fire
    end

    # called on :PRESS event
    # caller should check state of itemevent passed to block
    def fire
      checked(!@value)
      # added ItemEvent on 2008-12-31 13:44 
      @item_event = ItemEvent.new self, self if @item_event.nil?
      @item_event.set(@value ? :SELECTED : :DESELECTED)
      fire_handler :PRESS, @item_event # should the event itself be ITEM_EVENT
    #  fire_handler :PRESS, @form
    #  super
    end
    ##
    # set the value to true or false
    # user may programmatically want to check or uncheck
    def checked tf
      @value = tf
      if !@variable.nil?
        if @value 
          @variable.set_value((@onvalue || 1), @name)
        else
          @variable.set_value((@offvalue || 0), @name)
        end
      end
      # call fire of button class 2008-12-09 17:49 
    end
  end # class

  ##
  # A checkbox, may be selected or unselected
  # TODO hotkey should work here too.
  #
  class CheckBox < ToggleButton
    dsl_accessor :align_right    # the button will be on the right 2008-12-09 23:41 
    # if a variable has been defined, off and on value will be set in it (default 0,1)
    def initialize form, config={}, &block
      @surround_chars = ['[', ']']    # 2008-12-23 23:16 added space in Button so overriding
      super
    end
    def getvalue
      @value 
    end
      
    def getvalue_for_paint
      buttontext = getvalue() ? "X" : " "
      dtext = @display_length.nil? ? @text : "%-*s" % [@display_length, @text]
      dtext = "" if @text.nil?  # added 2009-01-13 00:41 since cbcellrenderer prints no text
      if @align_right
        @text_offset = 0
        @col_offset = dtext.length + @surround_chars[0].length + 1
        return "#{dtext} " + @surround_chars[0] + buttontext + @surround_chars[1] 
      else
        pretext = @surround_chars[0] + buttontext + @surround_chars[1] 
        @text_offset = pretext.length + 1
        @col_offset = @surround_chars[0].length
        #@surround_chars[0] + buttontext + @surround_chars[1] + " #{@text}"
        return pretext + " #{dtext}"
      end
    end
  end # class

  ##
  # A selectable button that has a text value. It is based on a Variable that
  # is shared by other radio buttons. Only one is selected at a time, unlike checkbox
  # 2008-11-27 18:45 just made this inherited from Checkbox

  class RadioButton < ToggleButton
    dsl_accessor :align_right    # the button will be on the right 2008-12-09 23:41 
    # if a variable has been defined, off and on value will be set in it (default 0,1)
    def initialize form, config={}, &block
      @surround_chars = ['(', ')'] if @surround_chars.nil?
      super
      $log.warn "XXX: FIXME Please set 'value' for radiobutton. If you don't know, try setting it to 'text'" unless @value
      # I am setting value of value here if not set 2011-10-21 
      @value ||= @text
      raise "A single Variable must be set for a group of Radio Buttons for this to work." unless @variable
    end

    # all radio buttons will return the value of the selected value, not the offered value
    def getvalue
      #@text_variable.value
      @variable.get_value @name
    end

    def getvalue_for_paint
      buttontext = getvalue() == @value ? "o" : " "
      dtext = @display_length.nil? ? text : "%-*s" % [@display_length, text]
      if @align_right
        @text_offset = 0
        @col_offset = dtext.length + @surround_chars[0].length + 1
        return "#{dtext} " + @surround_chars[0] + buttontext + @surround_chars[1] 
      else
        pretext = @surround_chars[0] + buttontext + @surround_chars[1] 
        @text_offset = pretext.length + 1
        @col_offset = @surround_chars[0].length
        return pretext + " #{dtext}"
      end
    end

    def toggle
      @variable.set_value @value, @name
      # call fire of button class 2008-12-09 17:49 
      fire
    end

    # added for bindkeys since that calls fire, not toggle - XXX i don't like this
    def fire
      @variable.set_value  @value,@name
      super
    end

    ##
    # ideally this should not be used. But implemented for completeness.
    # it is recommended to toggle some other radio button than to uncheck this.
    def checked tf
      if tf
        toggle
      elsif !@variable.nil? and getvalue() != @value # XXX ???
        @variable.set_value "",""
      end
    end
  end # class radio

  def self.startup
    VER::start_ncurses
    path = File.join(ENV["LOGDIR"] || "./" ,"rbc13.log")
    file   = File.open(path, File::WRONLY|File::TRUNC|File::CREAT) 
    $log = Logger.new(path)
    $log.level = Logger::DEBUG
  end

end # module
include RubyCurses::Utils
