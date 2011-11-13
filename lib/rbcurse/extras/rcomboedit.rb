=begin
  * Name: combo box
  * Description: 
  * Author: rkumar
  
  --------
  * Date:  2008-12-16 22:03 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

   TODO:
   Simplify completely. we don't need to use popup list, use something simpler do
   we can control keys.
   Keys: ignore down arrow in field. Use space to popup and space to select from popup.
         Or keep that as default.
   That v character does not position correctly if label used.
=end
require 'rbcurse'
require 'rbcurse/rlistbox'

include RubyCurses
module RubyCurses
  META_KEY = 128
  extend self

  # TODO : 
  # i no longer use values, i now use "list" or better "list_data_model"
  # try to make it so values gets converted to list.
  # NOTE: 2010-10-01 13:25 spacebar and enter will popup in addition to Alt-Down
  class ComboBoxEdit < Field
    include RubyCurses::EventHandler
    dsl_accessor :list_config
    dsl_accessor :insert_policy # NO_INSERT, INSERT_AT_TOP, INSERT_AT_BOTTOM, INSERT_AT_CURRENT
    # INSERT_AFTER_CURRENT, INSERT_BEFORE_CURRENT,INSERT_ALPHABETICALLY

    attr_accessor :current_index
    # the symbol you want to use for combos
    attr_accessor :COMBO_SYMBOL
    attr_accessor :show_symbol # show that funny symbol after a combo to signify its a combo
    dsl_accessor :arrow_key_policy   # :IGNORE :NEXT_ROW :POPUP

    def initialize form, config={}, &block
      @arrow_key_policy = :ignore
      super
      @current_index ||= 0
      # added if  check since it was overriding set_buffer in creation. 2009-01-18 00:03 
      set_buffer @list[@current_index].dup if @buffer.nil? or @buffer.empty?
      init_vars
      @_events.push(*[:CHANGE, :ENTER_ROW, :LEAVE_ROW])
    end
    def init_vars
      @COMBO_SYMBOL = "v".ord  # trying this out
      @show_symbol = true #if @show_symbol.nil? # if set to false don't touch
      super
      #@show_symbol = false if @label  # commented out 2011-11-13 maybe it doesn't place properly if label
      @COMBO_SYMBOL ||= FFI::NCurses::ACS_DARROW #GEQUAL # now this won't work since i've set it above
      bind_key(KEY_UP) { previous_row }
      bind_key(KEY_DOWN) { next_row }
    end
    def selected_item
      @list[@current_index]
    end
    def selected_index
      @current_index
    end

    ##
    # convert given list to datamodel
    def list alist=nil
      return @list if alist.nil?
      @list = RubyCurses::ListDataModel.new(alist)
    end
    ##
    # set given datamodel
    def list_data_model ldm
      raise "Expecting list_data_model" unless ldm.is_a? RubyCurses::ListDataModel
      @list = ldm
    end
    ##
    # combo edit box key handling
    # removed UP and DOWN and bound it, so it can be unbound
    def handle_key(ch)
      @current_index ||= 0
      # added 2009-01-18 22:44 no point moving horiz or passing up to Field if not edit
      if !@editable
        if ch == KEY_LEFT or ch == KEY_RIGHT
          return :UNHANDLED
        end
      end
      case @arrow_key_policy 
      when :ignore
        if ch == KEY_DOWN or ch == KEY_UP
          return :UNHANDLED
        end
      when :popup
        if ch == KEY_DOWN or ch == KEY_UP
          popup
        end
      end
      case ch
      #when KEY_UP  # show previous value
      #  previous_row
      #when KEY_DOWN  # show previous value
      #  next_row
        # adding spacebar to popup combo, as in microemacs 2010-10-01 13:21 
      when 32, KEY_DOWN+ RubyCurses::META_KEY # alt down
        popup  # pop up the popup
      else
        super
      end
    end
    def previous_row
      @current_index -= 1 if @current_index > 0
      set_buffer @list[@current_index].dup
      set_modified(true)  ## ??? not required
      fire_handler :ENTER_ROW, self
      @list.on_enter_row self
    end
    def next_row
      @current_index += 1 if @current_index < @list.length()-1
      set_buffer @list[@current_index].dup
      set_modified(true)  ## ??? not required
      fire_handler :ENTER_ROW, self
      @list.on_enter_row self
    end
    ##
    # calls a popup list
    # TODO: should not be positioned so that it goes off edge
    # user's customizations of list should be passed in
    # The dup of listconfig is due to a tricky feature/bug.
    # I try to keep the config hash and instance variables in synch. So
    # this config hash is sent to popuplist which updates its row col and
    # next time we pop up the popup row and col are zero.
    #
    # 
    # added dup in PRESS since editing edit field mods this
    # on pressing ENTER, value set back and current_index updated
    def popup
      listconfig = (@list_config && @list_config.dup) || {}
      dm = @list
      # current item in edit box will be focussed when list pops up
      #$log.debug "XXX POPUP: #{dm.selected_index} = #{@current_index}, value #{@buffer}"
      # we are having some problms when using this in a list. it retains earlier value
      _index = dm.index @buffer
      dm.selected_index = _index #  @current_index
      poprow = @row+0 # one row below the edit box
      popcol = @col
      dlength = @display_length
      f = self
      @popup = RubyCurses::PopupList.new do
        row  poprow
        col  popcol
        width dlength
        list_data_model dm
        list_selection_mode 'single'
        relative_to f
        list_config listconfig
        bind(:PRESS) do |index|
          f.set_buffer dm[index].dup
          f.set_modified(true) if f.current_index != index
          f.current_index = index
        end
      end
    end

    # Field putc advances cursor when it gives a char so we override this
    def putc c
      if c >= 0 and c <= 127
        ret = putch c.chr
        if ret == 0
          addcol 1 if @editable
          set_modified 
        end
      end
      return -1 # always ??? XXX 
    end
    ##
    # field does not give char to non-editable fields so we override
    def putch char
      @current_index ||= 0
      if @editable 
        super
        return 0
      else
        match = next_match(char)
        set_buffer match unless match.nil?
        fire_handler :ENTER_ROW, self
      end
      @modified = true
      fire_handler :CHANGE, self    # 2008-12-09 14:51  ???
      0
    end
    ##
    # the sets the next match in the edit field
    def next_match char
      start = @current_index
      start.upto(@list.length-1) do |ix|
        if @list[ix][0,1].casecmp(char) == 0
          return @list[ix] unless @list[ix] == @buffer
        end
        @current_index += 1
      end
      ## could not find, start from zero
      @current_index = 0
      start = [@list.length()-1, start].min
      0.upto(start) do |ix|
        if @list[ix][0,1].casecmp(char) == 0
          return @list[ix] unless @list[ix] == @buffer
        end
        @current_index += 1
      end
      @current_index = [@list.length()-1, @current_index].min
      return nil
    end
    ##
    # on leaving the listbox, update the combo/datamodel.
    # we are using methods of the datamodel. Updating our list will have
    # no effect on the list, and wont trigger events.
    # Do not override.
    def on_leave
      if !@list.include? @buffer and !@buffer.strip.empty?
        _insert_policy = @insert_policy || :INSERT_AT_BOTTOM
        case _insert_policy
        when :INSERT_AT_BOTTOM, :INSERT_AT_END
          @list.append  @buffer
        when :INSERT_AT_TOP
          @list.insert(0, @buffer)
        when :INSERT_AFTER_CURRENT
          @current_index += 1
          @list.insert(@current_index, @buffer)

        when :INSERT_BEFORE_CURRENT
          #_index = @current_index-1 if @current_index>0
          _index = @current_index
          @list.insert(_index, @buffer)
        when :INSERT_AT_CURRENT
          @list[@current_index]=@buffer
        when :NO_INSERT
          ; # take a break
        end
      end
      fire_handler :LEAVE, self
    end

    def repaint
      super
      c = @col + @display_length
     # @form.window.mvwvline( @row, c, ACS_VLINE, 1)
      if @show_symbol # 2009-01-11 18:47 
        # i have changed c +1 to c, since we have no right to print beyond display_length
        @form.window.mvwaddch @row, c, @COMBO_SYMBOL # Ncurses::ACS_GEQUAL
        @form.window.mvchgat(y=@row, x=c, max=1, Ncurses::A_REVERSE|Ncurses::A_UNDERLINE, $datacolor, nil)
      end
    end

  end # class ComboBox

end # module
