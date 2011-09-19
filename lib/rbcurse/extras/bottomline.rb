require "date"
require "erb"
require 'pathname'
=begin
  * Name          : bottomline.rb
  * Description   : routines for input at bottom of screen like vim, or anyother line  
  *               :
  * Author        : rkumar
  * Date          : 2010-10-25 12:45 
  * License       :
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

   The character input routines are from io.rb, however, the user-interface to the input
   is copied from the Highline project (James Earl Gray) with permission.
  
   May later use a Label and Field.

=end
module RubyCurses

  # just so the program does not bomb due to a tiny feature
  # I do not raise error on nil array, i create a dummy array
  # which you likely will not be able to use, in any case it will have only one value
  class History < Struct.new(:array, :current_index)
    attr_reader :last_index
    attr_reader :current_index
    attr_reader :array
    def initialize  a=nil, c=0
      #raise "Array passed to History cannot be nil" unless a
      #@max_index = a.size
      @array = a  || []
      @current_index = c
      @last_index = c
    end
    def last
      @current_index = max_index
      @array.last
    end
    def first
      @current_index = 0
      @array.first
    end
    def max_index
      @array.size - 1
    end
    def up
      item = @array[@current_index]
      previous
      return item
    end
    def next
      @last_index = @current_index
      if @current_index + 1 > max_index
        @current_index = 0
      else
        @current_index += 1
      end
      @array[@current_index]
    end
    def previous
      @last_index = @current_index
      if @current_index - 1 < 0
        @current_index = max_index()
      else
        @current_index -= 1
      end
      @array[@current_index]
    end
    def is_last?
      @current_index == max_index()
    end
    def push item
      $log.debug " XXX history push #{item} " if $log.debug? 
      @array.push item
      @current_index = max_index
    end
  end # class
  # some variables are polluting space of including app,
  # we should make this a class.
  class Bottomline 
    attr_accessor :window
    attr_accessor :message_row
    attr_accessor :name # for debugging
    def initialize win=nil, row=nil
      @window = win
      @message_row = row
    end

    class QuestionError < StandardError
      # do nothing, just creating a unique error type
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
        @history      = nil

        # allow block to override settings
        yield self if block_given?

        #$log.debug " XXX default #{@default}" if $log.debug? 
        #$log.debug " XXX history #{@history}" if $log.debug? 

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
      # If not set, a default of 100 is used
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
      # this messes up in ncurses RK 2010-10-24 12:23 
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
      # If the user presses tab in ask(), then this proc is used to fill in
      # values. Typically, for files. e.g.
      #
      #    q.completion_proc = Proc.new {|str| Dir.glob(str +"*") }
      #
      attr_accessor :completion_proc

      #
      # Called when any character is pressed with the string.
      #
      #    q.change_proc = Proc.new {|str| Dir.glob(str +"*") }
      #
      attr_accessor :change_proc
      #
      # text to be shown if user presses M-h
      #
      attr_accessor :helptext
      attr_accessor :color_pair
      attr_accessor :history

      #
      # Returns the provided _answer_string_ or the default answer for this
      # Question if a default was set and the answer is empty.
      # NOTE: in our case, the user actually edits this value (in highline it
      # is used if user enters blank)
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
          #choices.extend(OptionParser::Completion)
          #answer = choices.complete(answer_string)
          answer = choices # bug in completion of optparse
          if answer.nil?
            raise NoAutoCompleteMatch
          end
          if @answer_type.is_a?(Array)
            #answer.last  # we don't need this anylonger
            answer_string # we have already selected
          elsif @answer_type == File
            File.open(File.join(@directory.to_s, answer_string))
          else
            #Pathname.new(File.join(@directory.to_s, answer.last))
            Pathname.new(File.join(@directory.to_s, answer_string))
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
    end # class

    # Menu objects encapsulate all the details of a call to HighLine.choose().
    # Using the accessors and Menu.choice() and Menu.choices(), the block passed
    # to HighLine.choose() can detail all aspects of menu display and control.
    # 
    class Menu < Question
      #
      # Create an instance of HighLine::Menu.  All customization is done
      # through the passed block, which should call accessors and choice() and
      # choices() as needed to define the Menu.  Note that Menus are also
      # Questions, so all that functionality is available to the block as
      # well.
      # 
      def initialize(  )
        #
        # Initialize Question objects with ignored values, we'll
        # adjust ours as needed.
        # 
        super("Ignored", [ ], &nil)    # avoiding passing the block along

        @items           = [ ]
        @hidden_items    = [ ]
        @help            = Hash.new("There's no help for that topic.")

        @index           = :number
        @index_suffix    = ". "
        @select_by       = :index_or_name
        @flow            = :rows
        @list_option     = nil
        @header          = nil
        @prompt          = "?  "
        @layout          = :list
        @shell           = false
        @nil_on_handled  = false

        # Override Questions responses, we'll set our own.
        @responses       = { }
        # Context for action code.
        @highline        = nil

        yield self if block_given?

        init_help if @shell and not @help.empty?
      end

      #
      # An _index_ to append to each menu item in display.  See
      # Menu.index=() for details.
      # 
      attr_reader   :index
      #
      # The String placed between an _index_ and a menu item.  Defaults to
      # ". ".  Switches to " ", when _index_ is set to a String (like "-").
      #
      attr_accessor :index_suffix
      # 
      # The _select_by_ attribute controls how the user is allowed to pick a 
      # menu item.  The available choices are:
      # 
      # <tt>:index</tt>::          The user is allowed to type the numerical
      #                            or alphetical index for their selection.
      # <tt>:index_or_name</tt>::  Allows both methods from the
      #                            <tt>:index</tt> option and the
      #                            <tt>:name</tt> option.
      # <tt>:name</tt>::           Menu items are selected by typing a portion
      #                            of the item name that will be
      #                            auto-completed.
      # 
      attr_accessor :select_by
      # 
      # This attribute is passed directly on as the mode to HighLine.list() by
      # all the preset layouts.  See that method for appropriate settings.
      # 
      attr_accessor :flow
      #
      # This setting is passed on as the third parameter to HighLine.list()
      # by all the preset layouts.  See that method for details of its
      # effects.  Defaults to +nil+.
      # 
      attr_accessor :list_option
      #
      # Used by all the preset layouts to display title and/or introductory
      # information, when set.  Defaults to +nil+.
      # 
      attr_accessor :header
      #
      # Used by all the preset layouts to ask the actual question to fetch a
      # menu selection from the user.  Defaults to "?  ".
      # 
      attr_accessor :prompt
      #
      # An ERb _layout_ to use when displaying this Menu object.  See
      # Menu.layout=() for details.
      # 
      attr_reader   :layout
      #
      # When set to +true+, responses are allowed to be an entire line of
      # input, including details beyond the command itself.  Only the first
      # "word" of input will be matched against the menu choices, but both the
      # command selected and the rest of the line will be passed to provided
      # action blocks.  Defaults to +false+.
      # 
      attr_accessor :shell
      #
      # When +true+, any selected item handled by provided action code, will
      # return +nil+, instead of the results to the action code.  This may
      # prove handy when dealing with mixed menus where only the names of
      # items without any code (and +nil+, of course) will be returned.
      # Defaults to +false+.
      # 
      attr_accessor :nil_on_handled

      #
      # Adds _name_ to the list of available menu items.  Menu items will be
      # displayed in the order they are added.
      # 
      # An optional _action_ can be associated with this name and if provided,
      # it will be called if the item is selected.  The result of the method
      # will be returned, unless _nil_on_handled_ is set (when you would get
      # +nil+ instead).  In _shell_ mode, a provided block will be passed the
      # command chosen and any details that followed the command.  Otherwise,
      # just the command is passed.  The <tt>@highline</tt> variable is set to
      # the current HighLine context before the action code is called and can
      # thus be used for adding output and the like.
      # 
      def choice( name, help = nil, &action )
        @items << [name, action]

        @help[name.to_s.downcase] = help unless help.nil?
        update_responses  # rebuild responses based on our settings
      end

      #
      # A shortcut for multiple calls to the sister method choice().  <b>Be
      # warned:</b>  An _action_ set here will apply to *all* provided
      # _names_.  This is considered to be a feature, so you can easily
      # hand-off interface processing to a different chunk of code.
      # 
      def choices( *names, &action )
        names.each { |n| choice(n, &action) }
      end

      # Identical to choice(), but the item will not be listed for the user.
      def hidden( name, help = nil, &action )
        @hidden_items << [name, action]

        @help[name.to_s.downcase] = help unless help.nil?
      end

      # 
      # Sets the indexing style for this Menu object.  Indexes are appended to
      # menu items, when displayed in list form.  The available settings are:
      # 
      # <tt>:number</tt>::   Menu items will be indexed numerically, starting
      #                      with 1.  This is the default method of indexing.
      # <tt>:letter</tt>::   Items will be indexed alphabetically, starting
      #                      with a.
      # <tt>:none</tt>::     No index will be appended to menu items.
      # <i>any String</i>::  Will be used as the literal _index_.
      # 
      # Setting the _index_ to <tt>:none</tt> a literal String, also adjusts
      # _index_suffix_ to a single space and _select_by_ to <tt>:none</tt>. 
      # Because of this, you should make a habit of setting the _index_ first.
      # 
      def index=( style )
        @index = style

        # Default settings.
        if @index == :none or @index.is_a?(String)
          @index_suffix = " "
          @select_by    = :name
        end
      end

      # 
      # Initializes the help system by adding a <tt>:help</tt> choice, some
      # action code, and the default help listing.
      # 
      def init_help(  )
        return if @items.include?(:help)

        topics    = @help.keys.sort
        help_help = @help.include?("help") ? @help["help"] :
          "This command will display helpful messages about " +
          "functionality, like this one.  To see the help for " +
          "a specific topic enter:\n\thelp [TOPIC]\nTry asking " +
          "for help on any of the following:\n\n" +
          "<%= list(#{topics.inspect}, :columns_across) %>"
        choice(:help, help_help) do |command, topic|
          topic.strip!
          topic.downcase!
          if topic.empty?
            @highline.say(@help["help"])
          else
            @highline.say("= #{topic}\n\n#{@help[topic]}")
          end
        end
      end

      #
      # Used to set help for arbitrary topics.  Use the topic <tt>"help"</tt>
      # to override the default message.
      # 
      def help( topic, help )
        @help[topic] = help
      end

      # 
      # Setting a _layout_ with this method also adjusts some other attributes
      # of the Menu object, to ideal defaults for the chosen _layout_.  To
      # account for that, you probably want to set a _layout_ first in your
      # configuration block, if needed.
      # 
      # Accepted settings for _layout_ are:
      #
      # <tt>:list</tt>::         The default _layout_.  The _header_ if set
      #                          will appear at the top on its own line with
      #                          a trailing colon.  Then the list of menu
      #                          items will follow.  Finally, the _prompt_
      #                          will be used as the ask()-like question.
      # <tt>:one_line</tt>::     A shorter _layout_ that fits on one line.  
      #                          The _header_ comes first followed by a
      #                          colon and spaces, then the _prompt_ with menu
      #                          items between trailing parenthesis.
      # <tt>:menu_only</tt>::    Just the menu items, followed up by a likely
      #                          short _prompt_.
      # <i>any ERb String</i>::  Will be taken as the literal _layout_.  This
      #                          String can access <tt>@header</tt>, 
      #                          <tt>@menu</tt> and <tt>@prompt</tt>, but is
      #                          otherwise evaluated in the typical HighLine
      #                          context, to provide access to utilities like
      #                          HighLine.list() primarily.
      # 
      # If set to either <tt>:one_line</tt>, or <tt>:menu_only</tt>, _index_
      # will default to <tt>:none</tt> and _flow_ will default to
      # <tt>:inline</tt>.
      # 
      def layout=( new_layout )
        @layout = new_layout

        # Default settings.
        case @layout
        when :one_line, :menu_only
          self.index = :none
          @flow  = :inline
        end
      end

      #
      # This method returns all possible options for auto-completion, based
      # on the settings of _index_ and _select_by_.
      # 
      def options(  )
        # add in any hidden menu commands
        @items.concat(@hidden_items)

        by_index = if @index == :letter
                     l_index = "`"
                     @items.map { "#{l_index.succ!}" }
                   else
                     (1 .. @items.size).collect { |s| String(s) }
                   end
        by_name = @items.collect { |c| c.first }

        case @select_by
        when :index then
          by_index
        when :name
          by_name
        else
          by_index + by_name
        end
      ensure
        # make sure the hidden items are removed, before we return
        @items.slice!(@items.size - @hidden_items.size, @hidden_items.size)
      end

      #
      # This method processes the auto-completed user selection, based on the
      # rules for this Menu object.  If an action was provided for the 
      # selection, it will be executed as described in Menu.choice().
      # 
      def select( highline_context, selection, details = nil )
        # add in any hidden menu commands
        @items.concat(@hidden_items)

        # Find the selected action.
        name, action = if selection =~ /^\d+$/
                         @items[selection.to_i - 1]
                       else
                         l_index = "`"
                         index = @items.map { "#{l_index.succ!}" }.index(selection)
                         $log.debug "iindex #{index},  #{@items} " if $log.debug? 
                         @items.find { |c| c.first == selection } or @items[index]
                       end

        # Run or return it.
        if not @nil_on_handled and not action.nil?
          @highline = highline_context
          if @shell
            action.call(name, details)
          else
            action.call(name)
          end
        elsif action.nil?
          name
        else
          nil
        end
      ensure
        # make sure the hidden items are removed, before we return
        @items.slice!(@items.size - @hidden_items.size, @hidden_items.size)
      end

      #
      # Allows Menu objects to pass as Arrays, for use with HighLine.list().
      # This method returns all menu items to be displayed, complete with
      # indexes.
      # 
      def to_ary(  )
        case @index
        when :number
          @items.map { |c| "#{@items.index(c) + 1}#{@index_suffix}#{c.first}" }
        when :letter
          l_index = "`"
          @items.map { |c| "#{l_index.succ!}#{@index_suffix}#{c.first}" }
        when :none
          @items.map { |c| "#{c.first}" }
        else
          @items.map { |c| "#{index}#{@index_suffix}#{c.first}" }
        end
      end

      #
      # Allows Menu to behave as a String, just like Question.  Returns the
      # _layout_ to be rendered, which is used by HighLine.say().
      # 
      def to_str(  )
        case @layout
        when :list
          '<%= if @header.nil? then '' else "#{@header}:\n" end %>' +
            "<%= list( @menu, #{@flow.inspect},
                          #{@list_option.inspect} ) %>" +
            "<%= @prompt %>"
        when :one_line
          '<%= if @header.nil? then '' else "#{@header}:  " end %>' +
            "<%= @prompt %>" +
            "(<%= list( @menu, #{@flow.inspect},
                           #{@list_option.inspect} ) %>)" +
            "<%= @prompt[/\s*$/] %>"
        when :menu_only
          "<%= list( @menu, #{@flow.inspect},
                          #{@list_option.inspect} ) %><%= @prompt %>"
        else
          @layout
        end
      end      

      #
      # This method will update the intelligent responses to account for
      # Menu specific differences.  This overrides the work done by 
      # Question.build_responses().
      # 
      def update_responses(  )
        append_default unless default.nil?
        @responses = @responses.merge(
                                      :ambiguous_completion =>
                                      "Ambiguous choice.  " +
                                        "Please choose one of #{options.inspect}.",
                                        :ask_on_error         =>
                                      "?  ",
                                        :invalid_type         =>
                                      "You must enter a valid #{options}.",
                                        :no_completion        =>
                                      "You must choose one of " +
                                        "#{options.inspect}.",
                                        :not_in_range         =>
                                      "Your answer isn't within the expected range " +
                                        "(#{expected_range}).",
                                        :not_valid            =>
                                        "Your answer isn't valid (must match " +
                                          "#{@validate.inspect})."
                                     )
      end
    end
    def ask(question, answer_type=String, &details)
      #clear_line 80
      @question ||= Question.new(question, answer_type, &details)
      say(@question) #unless @question.echo == true

      @completion_proc = @question.completion_proc
      @change_proc = @question.change_proc
      @default = @question.default
      @helptext = @question.helptext
      @answer_type = @question.answer_type
      if @question.answer_type.is_a? Array
        @completion_proc = Proc.new{|str| @answer_type.dup.grep Regexp.new("^#{str}") }
      end

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
        retry
      rescue ArgumentError, NameError => error
        #raise
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

    #
    # The basic output method for HighLine objects.  
    #
    # The _statement_ parameter is processed as an ERb template, supporting
    # embedded Ruby code.  The template is evaluated with a binding inside 
    # the HighLine instance.
    # NOTE: modified from original highline, does not care about space at end of
    # question. Also, ansi color constants will not work. Be careful what ruby code
    # you pass in.
    #
    def say statement, config={}
      case statement
      when Question

        if config.has_key? :color_pair
          $log.debug "INSIDE QUESTION 2 " if $log.debug? 
        else
          $log.debug "XXXX SAY using #{statement.color_pair} " if $log.debug? 
          config[:color_pair] = statement.color_pair
        end
      else
        $log.debug "XXX INSDIE SAY #{statement.class}  " if $log.debug? 
      end
      statement =  statement.to_str
      template  = ERB.new(statement, nil, "%")
      statement = template.result(binding)
      #puts statement
      @prompt_length = statement.length # required by ask since it prints after 
      @statement = statement # 
      clear_line
      print_str statement, config
    end
    def say_with_pause statement, config={}
      say statement, config
      ch=@window.getchar()
    end
    # A helper method for sending the output stream and error and repeat
    # of the question.
    #
    # FIXME: since we write on one line in say, this often gets overidden
    # by next say or ask
    def explain_error( error )
      say_with_pause(@question.responses[error]) unless error.nil?
      if @question.responses[:ask_on_error] == :question
        say(@question)
      elsif @question.responses[:ask_on_error]
        say(@question.responses[:ask_on_error])
      end
    end

    def print_str(text, config={})
      win = config.fetch(:window, @window) # assuming its in App
      x = config.fetch :x, @message_row # Ncurses.LINES-1
      y = config.fetch :y, 0
      color = config[:color_pair] || $datacolor
      raise "no window for ask print in #{self.class} name: #{name} " unless win
      color=Ncurses.COLOR_PAIR(color);
      win.attron(color);
      #win.mvprintw(x, y, "%-40s" % text);
      win.mvprintw(x, y, "%s" % text);
      win.attroff(color);
      #win.refresh # FFI NW 2011-09-9 
    end

    # actual input routine, gets each character from user, taking care of echo, limit,
    # completion proc, and some control characters such as C-a, C-e, C-k
    # Taken from io.rb, has some improvements to it. However, does not print the prompt
    # any longer
    # Completion proc is vim style, on pressing tab it cycles through options
    def rbgetstr
      r = @message_row
      c = 0
      win = @window
      @limit = @question.limit
      @history = @question.history
      @history_list = History.new(@history) 
      maxlen = @limit || 100 # fixme


      raise "rbgetstr got no window. bottomline.rb" if win.nil?
      ins_mode = false
      oldstr = nil # for tab completion, origal word entered by user
      default = @default || ""
      if @default && @history
        if !@history.include?(default)
          @history_list.push default 
        end
      end

      len = @prompt_length

      # clear the area of len+maxlen
      color = $datacolor
      str = ""
      #str = default
      cpentries = nil
      #clear_line len+maxlen+1
      #print_str(prompt+str)
      print_str(str, :y => @prompt_length+0) if @default
      len = @prompt_length + str.length
      begin
        Ncurses.noecho();
        curpos = str.length
        prevchar = 0
        entries = nil
        while true
          ch=win.getchar()
          $log.debug " XXXX FFI rbgetstr got ch:#{ch}, str:#{str}. "
          case ch
          when 3 # -1 # C-c  # sometimes this causes an interrupt and crash
            return -1, nil
          when ?\C-g.getbyte(0)                              # ABORT, emacs style
            return -1, nil
          when 10, 13 # hits ENTER, complete entry and return
            @history_list.push str
            break
          when ?\C-h.getbyte(0), ?\C-?.getbyte(0), KEY_BSPACE, 263 # delete previous character/backspace
            # C-h is giving 263 i/o 8. 2011-09-19 
            len -= 1 if len > @prompt_length
            curpos -= 1 if curpos > 0
            str.slice!(curpos)
            clear_line len+maxlen+1, @prompt_length
          when 330 # delete character on cursor
            str.slice!(curpos) #rescue next
            clear_line len+maxlen+1, @prompt_length
          when ?\M-h.getbyte(0) #                            HELP KEY
            helptext = @helptext || "No help provided"
            print_help(helptext) 
            clear_line len+maxlen+1
            print_str @statement # UGH
            #return 7, nil
            #next
          when KEY_LEFT
            curpos -= 1 if curpos > 0
            len -= 1 if len > @prompt_length
            win.move r, c+len # since getchar is not going back on del and bs wmove to move FFIWINDOW
            next
          when KEY_RIGHT
            if curpos < str.length
              curpos += 1 #if curpos < str.length
              len += 1 
              win.move r, c+len # since getchar is not going back on del and bs
            end
            next
          when ?\C-a.getbyte(0)
            #olen = str.length
            clear_line len+maxlen+1, @prompt_length
            len -= curpos
            curpos = 0
            win.move r, c+len # since getchar is not going back on del and bs
          when ?\C-e.getbyte(0)
            olen = str.length
            len += (olen - curpos)
            curpos = olen
            clear_line len+maxlen+1, @prompt_length
            win.move r, c+len # since getchar is not going back on del and bs

          when ?\M-i.getbyte(0) 
            ins_mode = !ins_mode
            next
          when ?\C-k.getbyte(0) # delete forward
            @delete_buffer = str.slice!(curpos..-1) #rescue next
            clear_line len+maxlen+1, @prompt_length
          #when ?\C-u.getbyte(0) # clear entire line
            #@delete_buffer = str
            #str = ""
            #curpos = 0
            #clear_line len+maxlen+1, @prompt_length
            #len = @prompt_length
          when ?\C-u.getbyte(0) # delete to the left of cursor till start of line
            @delete_buffer = str.slice!(0..curpos-1) #rescue next
            curpos = 0
            clear_line len+maxlen+1, @prompt_length
            len = @prompt_length
          when ?\C-y.getbyte(0) # paste what's in delete buffer
            if @delete_buffer
              olen = str.length
              str << @delete_buffer if @delete_buffer
              curpos = str.length
              len += str.length - olen
            end
          when KEY_TAB # TAB
            if !@completion_proc.nil?
              # place cursor at end of completion
              # after all completions, what user entered should come back so he can edit it
              if prevchar == 9
                if !entries.nil? and !entries.empty?
                  olen = str.length
                  str = entries.delete_at(0)
                  str = str.to_s.dup
                  #str = entries[@current_index].dup
                  #@current_index += 1
                  #@current_index = 0 if @current_index == entries.length
                  curpos = str.length
                  len += str.length - olen
                  clear_line len+maxlen+1, @prompt_length
                else
                  olen = str.length
                  str = oldstr if oldstr
                  curpos = str.length
                  len += str.length - olen
                  clear_line len+maxlen+1, @prompt_length
                  prevchar = ch = nil # so it can start again completing
                end
              else
                #@current_index = 0
                tabc = @completion_proc unless tabc
                next unless tabc
                oldstr = str.dup
                olen = str.length
                entries = tabc.call(str).dup
                $log.debug "XXX tab [#{str}] got #{entries} "
                str = entries.delete_at(0) unless entries.nil? or entries.empty?
                #str = entries[@current_index].dup unless entries.nil? or entries.empty?
                #@current_index += 1
                #@current_index = 0 if @current_index == entries.length
                str = str.to_s.dup
                if str
                  curpos = str.length
                  len += str.length - olen
                else
                  alert "NO MORE 2"
                end
              end
            else
              # there's another type of completion that bash does, which is irritating
              # compared to what vim does, it does partial completion 
              if cpentries
                olen = str.length
                if cpentries.size == 1
                  str = cpentries.first.dup
                elsif cpentries.size > 1
                  str = shortest_match(cpentries).dup
                end
                curpos = str.length
                len += str.length - olen
              end
            end
          when ?\C-a.getbyte(0) .. ?\C-z.getbyte(0)
            Ncurses.beep
          when KEY_UP
            if @history && !@history.empty?
              olen = str.length
              str = if prevchar == KEY_UP
                       @history_list.previous
                     elsif prevchar == KEY_DOWN
                       @history_list.previous
                     else
                       @history_list.last
                     end
              str = str.dup
              curpos = str.length
              len += str.length - olen
              clear_line len+maxlen+1, @prompt_length
            end
          when KEY_DOWN
            if @history && !@history.empty?
              olen = str.length
              str = if prevchar == KEY_UP
                       @history_list.next
                     elsif prevchar == KEY_DOWN
                       @history_list.next
                     else
                       @history_list.first
                     end
              str = str.dup
              curpos = str.length
              len += str.length - olen
              clear_line len+maxlen+1, @prompt_length
            end

          else
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
            if ins_mode
              str[curpos] = ch.chr
            else
              str.insert(curpos, ch.chr) # FIXME index out of range due to changeproc
            end
            len += 1
            curpos += 1
            break if str.length >= maxlen
          end
          case @question.echo
          when true
            begin
              cpentries = @change_proc.call(str) if @change_proc # added 2010-11-09 23:28 
            rescue => exc
              $log.error "bottomline: change_proc EXC #{exc} " if $log.debug? 
              $log.error( exc) if exc
              $log.error(exc.backtrace.join("\n")) if exc
              Ncurses.error
            end
            print_str(str, :y => @prompt_length+0)
          when false
            # noop, no echoing what is typed
          else
            print_str(@question.echo * str.length, :y => @prompt_length+0)
          end
          win.move r, c+len # more for arrow keys, curpos may not be end
          prevchar = ch
        end
              $log.debug "XXXW bottomline: after while loop"

        str = default if str == ""
      ensure
        Ncurses.noecho();
      end
      return 0, str
    end

    # compares entries in array and returns longest common starting string
    # as happens in bash when pressing tab
    # abc abd abe will return ab
    def shortest_match a
     #return "" if a.nil? || a.empty? # should not be called in such situations
     raise "shortest_match should not be called with nil or empty array" if a.nil? || a.empty? # should not be called in such situations as caller program will err.

      l = a.inject do |memo,word|
        str = ""
        0.upto(memo.size) do |i|
          if memo[0..i] == word[0..i]
            str = memo[0..i]
          else
            break
          end
        end
        str
      end
    end
    # clears line from 0, not okay in some cases
    def clear_line len=100, from=0
      print_str("%-*s" % [len," "], :y => from)
    end

    def print_help(helptext)
      # best to popup a window and hsow that with ENTER to dispell
      print_str("%-*s" % [helptext.length+2," "])
      print_str("%s" % helptext)
      sleep(5)
    end
    def get_response
      return @question.first_answer if @question.first_answer?
      # we always use character reader, so user's value does not matter

      #if @question.character.nil?
      #  if @question.echo == true #and @question.limit.nil?
      ret, str = rbgetstr
      if ret == 0
        return @question.change_case(@question.remove_whitespace(str))                
      end
      return ""
    end
    def agree( yes_or_no_question, character = nil )
      ask(yes_or_no_question, lambda { |yn| yn.downcase[0] == ?y}) do |q|
        q.validate                 = /\Ay(?:es)?|no?\Z/i
        q.responses[:not_valid]    = 'Please enter "yes" or "no".'
        q.responses[:ask_on_error] = :question
        q.character                = character
        q.limit                    = 1 if character

        yield q if block_given?
      end
    end

    # presents given list in numbered format in a window above last line
    # and accepts input on last line
    # The list is a list of strings. e.g.
    #      %w{ ruby perl python haskell }
    # Multiple levels can be given as:
    #      list = %w{ ruby perl python haskell }
    #      list[0] = %w{ ruby ruby1.9 ruby 1.8 rubinius jruby }
    # In this case, "ruby" is the first level option. The others are used
    # in the second level. This might make it clearer. first3 has 2 choices under it.
    #      [ "first1" , "first2", ["first3", "second1", "second2"], "first4"]
    #
    # Currently, we return an array containing each selected level
    #
    # @return [Array] selected option/s from list
    def numbered_menu list1, config={}
      if list1.nil? || list1.empty?
        say_with_pause "empty list passed to numbered_menu" 
        return nil
      end
      prompt = config[:prompt] || "Select one: "
      require 'rbcurse/rcommandwindow'
      layout = { :height => 5, :width => Ncurses.COLS-1, :top => Ncurses.LINES-6, :left => 0 }
      rc = CommandWindow.new nil, :layout => layout, :box => true, :title => config[:title]
      w = rc.window
      # should we yield rc, so user can bind keys or whatever
      # attempt a loop so we do levels.
      retval = []
      begin
        while true
          rc.display_menu list1, :indexing => :number
          ret = ask(prompt, Integer ) { |q| q.in = 1..list1.size }
          val = list1[ret-1]
          if val.is_a? Array
            retval << val[0]
            $log.debug "NL: #{retval} "
            list1 = val[1..-1]
            rc.clear
          else
            retval << val
            $log.debug "NL1: #{retval} "
            break
          end
        end
      ensure
        rc.destroy
        rc = nil
      end
      #list1[ret-1]
            $log.debug "NL2: #{retval} , #{retval.class} "
      retval
    end
    # Allows a selection in which options are shown over prompt. As user types
    # options are narrowed down.
    # FIXME we can put remarks in fron as in memacs such as [No matches] or [single completion]
    # @param [Array]  a list of items to select from
    # NOTE: if you use this please copy it to your app. This does not conform to highline's
    # choose, and I'd like to somehow get it to be identical.
    #
    def choose list1, config={}
      case list1
      when NilClass
        list1 = Dir.glob("*")
      when String
        list1 = Dir.glob(list1)
      when Array
        # let it be, that's how it should come
      else
        # Dir listing as default
        list1 = Dir.glob("*")
      end
      require 'rbcurse/rcommandwindow'
      prompt = config[:prompt] || "Choose: "
      layout = { :height => 5, :width => Ncurses.COLS-1, :top => Ncurses.LINES-6, :left => 0 }
      rc = CommandWindow.new nil, :layout => layout, :box => true, :title => config[:title]
      begin
        w = rc.window
        rc.display_menu list1
        # earlier wmove bombed, now move is (window.rb 121)
        str = ask(prompt) { |q| q.change_proc = Proc.new { |str| w.wmove(1,1) ; w.wclrtobot;  l = list1.select{|e| e.index(str)==0}  ; rc.display_menu l; l} }
        # need some validation here that its in the list TODO
      ensure
        rc.destroy
        rc = nil
      end
    end
    def display_text_interactive text, config={}
      require 'rbcurse/rcommandwindow'
      ht = config[:height] || 15
      layout = { :height => ht, :width => Ncurses.COLS-1, :top => Ncurses.LINES-ht+1, :left => 0 }
      rc = CommandWindow.new nil, :layout => layout, :box => true, :title => config[:title]
      w = rc.window
      #rc.text "There was a quick  brown fox who ran over the lazy dog and then went over the moon over and over again and again"
      rc.display_interactive(text) { |l|
        l.focussed_attrib = 'bold' # Ncurses::A_UNDERLINE
        l.focussed_symbol = '>'
      }
      rc = nil
    end
    #def display_list_interactive text, config={}
    # returns a ListObject since you may not know what the list itself contained
    # You can do ret.list[ret.current_index] to get value
    def display_list text, config={}
      require 'rbcurse/rcommandwindow'
      ht = config[:height] || 15
      layout = { :height => ht, :width => Ncurses.COLS-1, :top => Ncurses.LINES-ht+1, :left => 0 }
      rc = CommandWindow.new nil, :layout => layout, :box => true, :title => config[:title]
      w = rc.window
      ret = rc.display_interactive text
      rc = nil
      ret
    end
    #
    # This method is HighLine's menu handler.  For simple usage, you can just
    # pass all the menu items you wish to display.  At that point, choose() will
    # build and display a menu, walk the user through selection, and return
    # their choice amoung the provided items.  You might use this in a case
    # statement for quick and dirty menus.
    # 
    # However, choose() is capable of much more.  If provided, a block will be
    # passed a HighLine::Menu object to configure.  Using this method, you can
    # customize all the details of menu handling from index display, to building
    # a complete shell-like menuing system.  See HighLine::Menu for all the
    # methods it responds to.
    # 
    # Raises EOFError if input is exhausted.
    # 
    def XXXchoose( *items, &details )
      @menu = @question = Menu.new(&details)
      @menu.choices(*items) unless items.empty?

      # Set _answer_type_ so we can double as the Question for ask().
      @menu.answer_type = if @menu.shell
                            lambda do |command|    # shell-style selection
                              first_word = command.to_s.split.first || ""

                              options = @menu.options
                              options.extend(OptionParser::Completion)
                              answer = options.complete(first_word)

                              if answer.nil?
                                raise Question::NoAutoCompleteMatch
                              end

                              [answer.last, command.sub(/^\s*#{first_word}\s*/, "")]
                            end
                          else
                            @menu.options          # normal menu selection, by index or name
                          end

      # Provide hooks for ERb layouts.
      @header   = @menu.header
      @prompt   = @menu.prompt

      if @menu.shell
        selected = ask("Ignored", @menu.answer_type)
        @menu.select(self, *selected)
      else
        selected = ask("Ignored", @menu.answer_type)
        @menu.select(self, selected)
      end
    end

  # Each member of the _items_ Array is passed through ERb and thus can contain
  # their own expansions.  Color escape expansions do not contribute to the 
  # final field width.
  # 
  def list( items, mode = :rows, option = nil )
    items = items.to_ary.map do |item|
      ERB.new(item, nil, "%").result(binding)
    end
    
    case mode
    when :inline
      option = " or " if option.nil?
      
      case items.size
      when 0
        ""
      when 1
        items.first
      when 2
        "#{items.first}#{option}#{items.last}"
      else
        items[0..-2].join(", ") + "#{option}#{items.last}"
      end
    when :columns_across, :columns_down
      max_length = actual_length(
        items.max { |a, b| actual_length(a) <=> actual_length(b) }
      )

      if option.nil?
        limit  = @wrap_at || 80
        option = (limit + 2) / (max_length + 2)
      end

      items     = items.map do |item|
        pad = max_length + (item.length - actual_length(item))
        "%-#{pad}s" % item
      end
      row_count = (items.size / option.to_f).ceil
      
      if mode == :columns_across
        rows = Array.new(row_count) { Array.new }
        items.each_with_index do |item, index|
          rows[index / option] << item
        end

        rows.map { |row| row.join("  ") + "\n" }.join
      else
        columns = Array.new(option) { Array.new }
        items.each_with_index do |item, index|
          columns[index / row_count] << item
        end
      
        list = ""
        columns.first.size.times do |index|
          list << columns.map { |column| column[index] }.
                          compact.join("  ") + "\n"
        end
        list
      end
    else
      items.map { |i| "#{i}\n" }.join
    end
  end
  end  # module
end # module
if __FILE__ == $PROGRAM_NAME

  #tabc = Proc.new {|str| Dir.glob(str +"*") }
  require 'rbcurse/app'
  require 'forwardable'
  #include Bottomline

  #$tt = Bottomline.new
  #module Kernel
    #extend Forwardable
    #def_delegators :$tt, :ask, :say, :agree, :choose, :numbered_menu
  #end
  App.new do 
    header = app_header "rbcurse 1.2.0", :text_center => "**** Demo", :text_right =>"New Improved!", :color => :black, :bgcolor => :white, :attr => :bold 
    message "Press F1 to exit from here"
  ########  $tt.window = @window; $tt.message_row = @message_row
    #@tt = Bottomline.new @window, @message_row
    #extend Forwardable
    #def_delegators :@tt, :ask, :say, :agree, :choose

    #stack :margin_top => 2, :margin => 5, :width => 30 do
    #end # stack
    #-----------------#------------------

#choose do |menu|
  #menu.prompt = "Please choose your favorite programming language?  "
  ##menu.layout = :one_line
#
  #menu.choice :ruby do say("Good choice!") end
  #menu.choice(:python) do say("python Not from around here, are you?") end
  #menu.choice(:perl) do say("perl Not from around here, are you?") end
  #menu.choice(:rake) do say("rake Not from around here, are you?") end
#end
    entry = {}
    entry[:file]       = ask("File?  ", Pathname)  do |q| 
      q.completion_proc = Proc.new {|str| Dir.glob(str +"*") }
      q.helptext = "Enter start of filename and tab to get completion"
    end
    alert "file: #{entry[:file]} "
    $log.debug "FILE: #{entry[:file]} "
    entry[:command]     = ask("Command?  ", %w{archive delete read refresh delete!}) 
    exit unless agree("Wish to continue? ", false)
    entry[:address]     = ask("Address?  ") { |q| q.color_pair = $promptcolor }
    entry[:company]     = ask("Company?  ") { |q| q.default = "none" }
    entry[:password]        = ask("password?  ") { |q|
      q.echo = '*'
      q.limit = 4
    }
=begin
    entry[:state]       = ask("State?  ") do |q|
      q._case     = :up
      q.validate = /\A[A-Z]{2}\Z/
      q.helptext = "Enter 2 characters for your state"
    end
    entry[:zip]         = ask("Zip?  ") do |q|
    q.validate = /\A\d{5}(?:-?\d{4})?\Z/
    end
    entry[:phone]       = ask( "Phone?  ",
    lambda { |p| p.delete("^0-9").
    sub(/\A(\d{3})/, '(\1) ').
    sub(/(\d{4})\Z/, '-\1') } ) do |q|
    q.validate              = lambda { |p| p.delete("^0-9").length == 10 }
    q.responses[:not_valid] = "Enter a phone numer with area code."
    end
    entry[:age]         = ask("Age?  ", Integer) { |q| q.in = 0..105 }
    entry[:birthday]    = ask("Birthday?  ", Date)
    entry[:interests]   = ask( "Interests?  (comma separated list)  ",
                              lambda { |str| str.split(/,\s*/) } )
    entry[:description] = ask("Enter a description for this contact.") do |q|
      q.whitespace = :strip_and_collapse
  end
=end
    $log.debug "ENTRY: #{entry}  " if $log.debug? 
    #puts entry
  end # app
end # FILE
