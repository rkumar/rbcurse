=begin
  * Name: combo box
  * Description: 
  * Author: rkumar
  
  --------
  * Date:  2008-12-16 22:03 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'rubygems'
require 'ncurses'
require 'logger'
require 'lib/ver/ncurses'
require 'lib/ver/window'
require 'lib/rbcurse/rwidget'

include Ncurses
include RubyCurses
module RubyCurses
  META_KEY = 128
  extend self

  # TODO : 
  # i no longer use values, i now use "list" or better "list_data_model"
  # try to make it so values gets converted to list.
  class ComboBox < Field
    include RubyCurses::EventHandler
    dsl_accessor :list_config
    dsl_accessor :insert_policy # NO_INSERT, INSERT_AT_TOP, INSERT_AT_BOTTOM, INSERT_AT_CURRENT
    # INSERT_AFTER_CURRENT, INSERT_BEFORE_CURRENT,INSERT_ALPHABETICALLY

    attr_accessor :current_index

    def initialize form, config={}, &block
      super
      @current_index ||= 0
      set_buffer @list[@current_index].dup
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
    def handle_key(ch)
      @current_index ||= 0
      case ch
      when KEY_UP  # show previous value
        @current_index -= 1 if @current_index > 0
        set_buffer @list[@current_index].dup
        set_modified(true) 
      when KEY_DOWN  # show previous value
        @current_index += 1 if @current_index < @list.length()-1
        set_buffer @list[@current_index].dup
        set_modified(true) 
      when KEY_DOWN+ RubyCurses::META_KEY # alt down
        popup  # pop up the popup
      else
        super
      end
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
      listconfig = @list_config.dup || {}
      dm = @list
      # current item in edit box will be focussed when list pops up
      dm.selected_item = @current_index
      poprow = @row+1 # one row below the edit box
      popcol = @col
      dlength = @display_length
      f = self
      pl = RubyCurses::PopupList.new do
        row  poprow
        col  popcol
        width dlength
        list_data_model dm
        list_select_mode 'single'
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
      end
      @modified = true
      fire_handler :CHANGE, self    # 2008-12-09 14:51 
      0
    end
    ##
    # the sets the next match in the edit field
    def next_match char
      start = @current_index
      start.upto(@list.length-1) do |ix|
        if @list[ix][0,1] == char
          return @list[ix] unless @list[ix] == @buffer
        end
        @current_index += 1
      end
      ## could not find, start from zero
      @current_index = 0
      start = [@list.length()-1, start].min
      0.upto(start) do |ix|
        if @list[ix][0,1] == char
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

  end # class ComboBox

end # module
