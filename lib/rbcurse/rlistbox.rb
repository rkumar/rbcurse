=begin
  * Name: rlistbox: editable scrollable lists
  * Description   
  * Author: rkumar (arunachalesha)
  * Date: 2008-11-19 12:49 
  * License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
  * This file started on 2009-01-13 22:18 (broken off rwidgets.rb)
NOTE: listbox now traps RETURN/ENTER/13 so if you are trapping it, please use bind :PRESS
TODO 
  Perhaps keep printed data created by convert_value_to_text cached, and used for searching
  cursor movement and other functions. 
=end
require 'rbcurse'
require 'rbcurse/listcellrenderer'
require 'rbcurse/listkeys'
require 'forwardable'


#include Ncurses # FFI 2011-09-8 
module RubyCurses
  extend self
  ##
  # When an event is fired by Listbox, contents are changed, then this object will be passed 
  # to trigger
  # shamelessly plugged from a legacy language best unnamed
  # type is CONTENTS_CHANGED, INTERVAL_ADDED, INTERVAL_REMOVED
  class ListDataEvent
    attr_accessor :index0, :index1, :source, :type
    def initialize index0, index1, source, type
      @index0 = index0
      @index1 = index1
      @source = source
      @type = type
    end
    def to_s
      "#{@type.to_s}, #{@source}, #{@index0}, #{@index1}"
    end
    def inspect
      "#{@type.to_s}, #{@source}, #{@index0}, #{@index1}"
    end
  end
  # http://www.java2s.com/Code/JavaAPI/javax.swing.event/ListDataEventCONTENTSCHANGED.htm
  # should we extend array of will that open us to misuse
  class ListDataModel
    include Enumerable
    include RubyCurses::EventHandler
    attr_accessor :selected_index
    attr_reader :last_regex # should i really keep here as public or maintain in listbox

    def initialize anarray=[]
      @list = anarray.dup
      @_events = [:LIST_DATA_EVENT, :ENTER_ROW]
    end
    # changd on 2009-01-14 12:28 based on ..
    # http://www.ruby-forum.com/topic/175637#769030
    def each(&blk)
      @list.each(&blk)
    end
    # not sure how to do this XXX  removed on 2009-01-14 12:28 
    #def <=>(other)
    #  @list <=> other
    #end
    def index obj
      @list.index(obj)
    end
    def length ; @list.length; end
    alias :size :length

    def insert off0, *data
      @list.insert off0, *data
      lde = ListDataEvent.new(off0, off0+data.length-1, self, :INTERVAL_ADDED)
      fire_handler :LIST_DATA_EVENT, lde
    end
    def append data
      @list << data
      lde = ListDataEvent.new(@list.length-1, @list.length-1, self, :INTERVAL_ADDED)
      fire_handler :LIST_DATA_EVENT, lde
    end
    def update off0, data
      @list[off0] = data
      lde = ListDataEvent.new(off0, off0, self, :CONTENTS_CHANGED)
      fire_handler :LIST_DATA_EVENT, lde
    end
    def []=(off0, data)
      update off0, data
    end
    def [](off0)
      @list[off0]
    end
    def delete_at off0
      ret=@list.delete_at off0
      lde = ListDataEvent.new(off0, off0, self, :INTERVAL_REMOVED)
      fire_handler :LIST_DATA_EVENT, lde
      return ret
    end
    def remove_all
      return if @list.nil? || @list.empty? # 2010-09-21 13:25 
      lde = ListDataEvent.new(0, @list.size, self, :INTERVAL_REMOVED)
      @list = []
      @current_index = 0
      fire_handler :LIST_DATA_EVENT, lde
    end
    def delete obj
      off0 = @list.index obj
      return nil if off0.nil?
      ret=@list.delete_at off0
      lde = ListDataEvent.new(off0, off0, self, :INTERVAL_REMOVED)
      fire_handler :LIST_DATA_EVENT, lde
      return ret
    end
    def include?(obj)
      return @list.include?(obj)
    end
    # returns a `dup()` of the list
    def values
      @list.dup
    end
    # why do we have this here in data, we should remove this
    # @deprecated this was just eye candy for some demo
    def on_enter_row object
      $log.debug " XXX on_enter_row of list_data"
      fire_handler :ENTER_ROW, object
    end
    # ##
    # added 2009-01-14 01:00 
    # searches between given range of rows (def 0 and end)
    # returns row index of first match of given regex (or nil if not found)
    def find_match regex, ix0=0, ix1=length()
      $log.debug " find_match got #{regex} #{ix0} #{ix1}"
      @last_regex = regex
      @search_start_ix = ix0
      @search_end_ix = ix1
      #@search_found_ix = nil
      @list.each_with_index do |row, ix|
        next if ix < ix0
        break if ix > ix1
        if !row.match(regex).nil?
          @search_found_ix = ix
          return ix 
        end
      end
      return nil
    end
    ##
    # continues previous search
    def find_next
      raise "No previous search" if @last_regex.nil?
      start = @search_found_ix && @search_found_ix+1 || 0
      return find_match @last_regex, start, @search_end_ix
    end
    ##
    # find backwards, list_data_model
    # Using this to start a search or continue search
    def find_prev regex=@last_regex, start = @search_found_ix 
      raise "No previous search" if regex.nil? # @last_regex.nil?
      $log.debug " find_prev #{@search_found_ix} : #{@current_index}"
      start -= 1 unless start == 0
      @last_regex = regex
      @search_start_ix = start
      start.downto(0) do |ix| 
        row = @list[ix]
        if !row.match(regex).nil?
          @search_found_ix = ix
          return ix 
        end
      end
      return nil
      #return find_match @last_regex, start, @search_end_ix
    end
    ##
    # added 2010-05-23 12:10 for listeditable
    def slice!(line, howmany)
      ret = @list.slice!(line, howmany)
      lde = ListDataEvent.new(line, line+howmany-1, self, :INTERVAL_REMOVED)
      fire_handler :LIST_DATA_EVENT, lde
      return ret
    end

    alias :to_array :values
  end # class ListDataModel
  ## 
  # scrollable, selectable list of items
  # TODO Add events for item add/remove and selection change
  #  added event LIST_COMBO_SELECT fired whenever a select/deselect is done.
  #    - I do not know how this works in Tk so only the name is copied..
  #    - @selected contains indices of selected objects.
  #    - currently the first argument of event is row (the row selected/deselected). Should it
  #    be the object.
  #    - this event could change when range selection is allowed.
  #  

  ##
  # TODO CAN WE MOVE THIS OUT TO ANOTHER FILE as confusing me
  # pops up a list of values for selection
  # 2008-12-10
  class PopupList
    include RubyCurses::EventHandler
    dsl_accessor :title
    dsl_accessor :row, :col, :height, :width
    dsl_accessor :layout
    attr_reader :config
    attr_reader :selected_index     # button index selected by user
    attr_reader :window     # required for keyboard
    dsl_accessor :list_selection_mode  # true or false allow multiple selection
    dsl_accessor :relative_to   # a widget, if given row and col are relative to widgets windows 
                                # layout
    dsl_accessor :max_visible_items   # how many to display
    dsl_accessor :list_config       # hash with values for the list to use 
    dsl_accessor :valign
    attr_reader :listbox

    def initialize aconfig={}, &block
      @config = aconfig
      @selected_index = -1
      @list_config ||= {}
      @config.each_pair { |k,v| instance_variable_set("@#{k}",v) }
      instance_eval &block if block_given?
      @list_config.each_pair { |k,v|  instance_variable_set("@#{k}",v) }
      @height ||= [@max_visible_items || 10, @list.length].min 
      $log.debug " POPUP XXX #{@max_visible_items} ll:#{@list.length} h:#{@height}"
      # get widgets absolute coords
      if @relative_to
        layout = @relative_to.form.window.layout
        @row = @row + layout[:top]
        @col = @col + layout[:left]
      end
      if !@valign.nil?
        case @valign.to_sym
        when :BELOW
          @row += 1
        when :ABOVE
          @row -= @height+1
          @row = 0 if @row < 0
        when :CENTER
          @row -= @height/2
          @row = 0 if @row < 0
        else
        end
      end

      layout(1+height, @width+4, @row, @col) # changed 2 to 1, 2008-12-17 13:48 
      @window = VER::Window.new(@layout)
      @form = RubyCurses::Form.new @window
      @window.bkgd(Ncurses.COLOR_PAIR($reversecolor));
      @window.wrefresh
      #@panel = @window.panel  # useless line ?
      Ncurses::Panel.update_panels
      print_input # creates the listbox
      @form.repaint
      @window.wrefresh
      handle_keys
    end
    # class popup
    def list alist=nil
      return @list if alist.nil?
      @list = ListDataModel.new(alist)
      @repaint_required = true
      #  will we need this ? listbox made each time so data should be fresh
      #@list.bind(:LIST_DATA_EVENT) { |e| list_data_changed() }
    end
    # class popup
    def list_data_model ldm
      raise "Expecting list_data_model" unless ldm.is_a? RubyCurses::ListDataModel
      @list = ldm
      #  will we need this ? listbox made each time so data should be fresh
      #@list.bind(:LIST_DATA_EVENT) { |e| list_data_changed() }
    end
    ##
    def input_value
      #return @listbox.getvalue if !@listbox.nil?
      return @listbox.focussed_index if !@listbox.nil?
    end
    ## popuplist
    def stopping?
      @stop
    end
    ## popuplist
    def handle_keys
      begin
        while((ch = @window.getchar()) != 999 )
          case ch
          when -1
            next
          else
            press ch
            break if @stop
          end
        end
      ensure
        destroy  
      end
      return 0 #@selected_index
    end
    ##
    # TODO get next match for key
    def press ch
       $log.debug "popup handle_keys :  #{ch}"  if ch != -1
        case ch
        when -1
          return
        when KEY_F1, 27, ?\C-q   # 27/ESC does not come here since gobbled by keyboard.rb
          @stop = true
          return
        when KEY_ENTER, 10, 13
          # if you press ENTER without selecting, it won't come here
          # it will fire button OK's fire, if that's the default button

          # returns an array of indices if multiple selection
          if @listbox.selection_mode == :multiple
            fire_handler :PRESS, @listbox
          else
            fire_handler :PRESS, @listbox.focussed_index
          end
          # since Listbox is handling enter, COMBO_SELECT will not be fired
        # $log.debug "popup ENTER :  #{field.name}" if !field.nil?
          @stop = true
          return
        when KEY_TAB
          @form.select_next_field 
        else
          # fields must return unhandled else we will miss hotkeys. 
          # On messageboxes, often if no edit field, then O and C are hot.
          field =  @form.get_current_field
          handled = field.handle_key ch

          if handled == :UNHANDLED
              @stop = true
              return
          end
        end
        @form.repaint
        Ncurses::Panel.update_panels();
        Ncurses.doupdate();
        @window.wrefresh
    end
    def print_input
      r = c = 0
      width = @layout[:width]
      #$log.debug " print_input POPUP ht:#{@height} lh:#{@layout[:height]} "
      height = @layout[:height]
      #height = @height # 2010-01-06 12:52 why was this overriding previous line. its one less than layout
      # i am now using layout height since it gives a closer size to whats asked for.
      parent = @relative_to
      defaultvalue = @default_value || ""
      list = @list
      selection_mode = @list_selection_mode 
      default_values = @default_values
      @list_config['color'] ||= 'black'
      @list_config['bgcolor'] ||= 'yellow'
        @listbox = RubyCurses::Listbox.new @form, @list_config do
          name   "input" 
          row  r 
          col  c 
#         attr 'reverse'
          width width
          height height
          list_data_model  list
# ?? XXX          display_length  30
#         set_buffer defaultvalue
          selection_mode selection_mode
          default_values default_values
          is_popup true
          #add_observer parent
        end
    end
    # may need to be upgraded to new one XXX FIXME
    def configure(*val , &block)
      case val.size
      when 1
        return @config[val[0]]
      when 2
        @config[val[0]] = val[1]
        instance_variable_set("@#{val[0]}", val[1]) 
      end
      instance_eval &block if block_given?
    end
    def cget param
      @config[param]
    end

    def layout(height=0, width=0, top=0, left=0)
      @layout = { :height => height, :width => width, :top => top, :left => left } 
    end
    def destroy
      @window.destroy if !@window.nil?
    end
  end # class PopupList
  ##
  # A control for displaying a list of data or values. 
  # The list will be editable if @cell_editing_allowed
  # is set to true when creating. By default, multiple selection is allowed, but may be set to :single.
  # TODO: were we not going to force creation of datamodel and listener on startup by putting a blank
  # :list in config, if no list or list_variable or model is there ?
  # Or at end of constructor check, if no listdatamodel then create default.
  # TODO : perhaps when datamodel created, attach listener to it, so we can fire to callers when
  # they want to be informed of changes. As we did with selection listeners.
  #
  class Listbox < Widget

    require 'rbcurse/listscrollable'
    require 'rbcurse/listselectable'
    require 'rbcurse/defaultlistselectionmodel'
    require 'rbcurse/celleditor'
    include ListScrollable
    include ListSelectable
    include RubyCurses::ListKeys
    extend Forwardable
    dsl_accessor :height
    dsl_accessor :title
    dsl_property :title_attrib   # bold, reverse, normal
#   dsl_accessor :list    # the array of data to be sent by user
    attr_reader :toprow
  #  attr_reader :prow
  #  attr_reader :winrow
  #  dsl_accessor :selection_mode # allow multiple select or not
#   dsl_accessor :list_variable   # a variable values are shown from this
    dsl_accessor :default_values  # array of default values
    dsl_accessor :is_popup       # if it is in a popup and single select, selection closes
    attr_accessor :current_index
    #dsl_accessor :cell_renderer
    dsl_accessor :selected_color, :selected_bgcolor, :selected_attr
    dsl_accessor :max_visible_items   # how many to display 2009-01-11 16:15 
    dsl_accessor :cell_editing_allowed
    dsl_property :show_selector
    dsl_property :row_selected_symbol # 2009-01-12 12:01 changed from selector to selected
    dsl_property :row_unselected_symbol # added 2009-01-12 12:00 
    dsl_property :left_margin
    # please set these in he constructor block. Settin them later will have no effect
    # since i would have bound them to actions
    dsl_accessor :KEY_ROW_SELECTOR          # editable lists may want to use 0 or some other key
    dsl_accessor :KEY_GOTO_TOP          # this is going to go
    dsl_accessor :KEY_GOTO_BOTTOM          # this is going to go
    dsl_accessor :KEY_CLEAR_SELECTION          # this is going to go
    dsl_accessor :KEY_NEXT_SELECTION          # this is going to go
    dsl_accessor :KEY_PREV_SELECTION          # this is going to go
    dsl_accessor :valign  # 2009-01-17 18:32  vertical alignment used in combos
    dsl_accessor :justify  #  2010-09-27 12:41 used by renderer
    attr_accessor :one_key_selection # will pressing a single key select or not
    dsl_accessor :border_attrib, :border_color # 
    dsl_accessor :sanitization_required
    dsl_accessor :suppress_borders #to_print_borders


    def initialize form, config={}, &block
      @focusable = true
      @editable = false
      @sanitization_required = true
      @row = 0
      @col = 0
      # data of listbox this is not an array, its a pointer to the  listdatamodel
      @list = nil 
      # any special attribs such as status to be printed in col1, or color (selection)
      @list_attribs = {}
      @suppress_borders = false
      @row_offset = @col_offset = 1 # for borders
      super
      @_events.push(*[:ENTER_ROW, :LEAVE_ROW, :LIST_SELECTION_EVENT, :PRESS])
      @current_index ||= 0
      @selection_mode ||= :multiple # default is multiple, anything else given becomes single
      @win = @graphic    # 2010-01-04 12:36 BUFFERED  replace form.window with graphic
      # moving down to repaint so that scrollpane can set should_buffered
      # added 2010-02-17 23:05  RFED16 so we don't need a form.
      @win_left = 0
      @win_top = 0

      # next 2 lines carry a redundancy
      select_default_values   
      # when the combo box has a certain row in focus, the popup should have the same row in focus

      install_keys
      init_vars
      install_list_keys
      # OMG What about people whove installed custom renders such as rfe.rb 2011-10-15 
      #bind(:PROPERTY_CHANGE){|e| @cell_renderer = nil } # will be recreated if anything changes 2011-09-28 V1.3.1  
      bind(:PROPERTY_CHANGE){|e| 
        # I can't delete the cell renderer, but this may not have full effect if one color is passed.
        if @cell_renderer.respond_to? e.property_name
          @cell_renderer.send(e.property_name.to_sym, e.newvalue)
        end
      } # will be recreated if anything changes 2011-09-28 V1.3.1  

      if @list && !@list.selected_index.nil? 
        set_focus_on @list.selected_index # the new version
      end
    end
    # this is called several times, from constructor
    # and when list data changed, so only put relevant resets here.
    # why can't current_index be set to 0 here
    def init_vars
      @repaint_required = true
      @toprow = @pcol = 0

      @row_offset = @col_offset = 0 if @suppress_borders
      if @show_selector
        @row_selected_symbol ||= '>'
        @row_unselected_symbol ||= ' '
        @left_margin ||= @row_selected_symbol.length
      end
      @left_margin ||= 0
      @one_key_selection = true if @one_key_selection.nil?
      # we reduce internal_width from width while printing
      @internal_width = 2 # taking into account borders accounting for 2 cols
      @internal_width = 0 if @suppress_borders # should it be 0 ???

    end
    def map_keys
      return if @keys_mapped
      bind_key(?f){ ask_selection_for_char() }
      bind_key(?\M-v){ @one_key_selection = false }
      bind_key(?j){ next_row() }
      bind_key(?k){ previous_row() }
      bind_key(?G){ goto_bottom() }
      bind_key([?g,?g]){ goto_top() }
      bind_key(?/){ ask_search() }
      bind_key(?n){ find_more() }
      #bind_key(32){ toggle_row_selection() } # some guys may want another selector
      if @cell_editing_allowed && @KEY_ROW_SELECTOR == 32
        @KEY_ROW_SELECTOR = 0 # Ctrl-Space
      end
      bind_key(@KEY_ROW_SELECTOR){ toggle_row_selection() }
      bind_key(10){ fire_action_event }
      bind_key(13){ fire_action_event }
      @keys_mapped = true
    end

    ##
    # getter and setter for selection_mode
    # Must be called after creating model, so no duplicate. Since one may set in model directly.
    def selection_mode(*val)
      #raise "ListSelectionModel not yet created!" if @list_selection_model.nil?

      if val.empty?
        if @list_selection_model
          return @list_selection_model.selection_mode
        else
          return @tmp_selection_mode
        end
      else
        if @list_selection_model.nil?
          @tmp_selection_mode = val[0] 
        else
          @list_selection_model.selection_mode = val[0].to_sym
        end
      end
    end
    def row_count
      return 0 if @list.nil?
      @list.length
    end
    # added 2009-01-07 13:05 so new scrollable can use
    def scrollatrow
      if @suppress_borders
        return @height - 1
      else
        return @height - 3
      end
    end
    # provide data to List in the form of an Array or Variable or
    # ListDataModel. This will create a default ListSelectionModel.
    #
    # CHANGE as on 2010-09-21 12:53:
    # If explicit nil passed then dummy datamodel and selection model created
    # From now on, constructor will call this, so this can always
    # happen.
    #
    # NOTE: sometimes this can be added much after its painted.
    # Do not expect this to be called from constructor, although that
    # is the usual case. it can be dependent on some other list or tree.
    # @param [Array, Variable, ListDataModel] data to populate list with
    # @return [ListDataModel] just created or assigned
    
    def list *val
      return @list if val.empty?
      clear_selection if @list # clear previous selections if any
      @default_values = nil if @list # clear previous selections if any
      alist = val[0]
      case alist
      when Array
        if @list
          @list.remove_all
          @list.insert 0, *alist
          @current_index = 0
        else
          @list = RubyCurses::ListDataModel.new(alist)
        end
      when NilClass
        if @list
          @list.remove_all
        else
          @list = RubyCurses::ListDataModel.new(alist)
        end
      when Variable
        @list = RubyCurses::ListDataModel.new(alist.value)
      when RubyCurses::ListDataModel
        @list = alist
      else
        raise ArgumentError, "Listbox list(): do not know how to handle #{alist.class} " 
      end
      # added on 2009-01-13 23:19 since updates are not automatic now
      @list.bind(:LIST_DATA_EVENT) { |e| list_data_changed() }
      create_default_list_selection_model
      @list_selection_model.selection_mode = @tmp_selection_mode if @tmp_selection_mode
      @repaint_required = true
      @list
    end
    # populate using a Variable which should contain a list
    # NOTE: This explicilty overwrites any existing datamodel such as the
    # default one. You may lose any events you have bound to the listbox
    # prior to this call.
    def list_variable alist=nil
      return @list if alist.nil?
      @list = RubyCurses::ListDataModel.new(alist.value)
      # added on 2009-01-13 23:19 since updates are not automatic now
      @list.bind(:LIST_DATA_EVENT) { |e| list_data_changed() }
      create_default_list_selection_model
    end
    # populate using a custom data model
    # NOTE: This explicilty overwrites any existing datamodel such as the
    # default one. You may lose any events you have bound to the listbox
    # prior to this call. 
    
    def list_data_model ldm=nil
      return @list if ldm.nil?
      raise "Expecting list_data_model" unless ldm.is_a? RubyCurses::ListDataModel
      @list = ldm
      # added on 2009-01-13 23:19 since updates are not automatic now
      @list.bind(:LIST_DATA_EVENT) { |e| list_data_changed() }
      create_default_list_selection_model
    end
    # create a default list selection model and set it
    # NOTE: I am now checking if one is not already created, since
    # a second creation would wipe out any listeners on it.
    # @see ListSelectable 
    # @see DefaultListSelectionModel
    def create_default_list_selection_model
      if @list_selection_model.nil?
        list_selection_model DefaultListSelectionModel.new(self)
      end
    end
    # added 2010-09-15 00:11 to make life easier
    def_delegators :@list, :insert, :remove_all, :delete_at, :include?, :each, :values, :size
    # get element at
    # @param [Fixnum] index for element
    # @return [Object] element
    # @since 1.2.0  2010-09-06 14:33 making life easier for others.
    def [](off0)
      @list[off0]
    end
    # return object under cursor
    # Note: this should not be confused with selected row/s. User may not have selected this.
    # This is only useful since in some demos we like to change a status bar as a user scrolls down
    # @since 1.2.0  2010-09-06 14:33 making life easier for others.
    def current_value
      @list[@current_index]
    end
    # avoid using "row", i'd rather stick with "index" and "value".
    alias :current_row :current_value
    alias :text :current_value  # thanks to shoes, not sure how this will impact since widget has text.

    # XXX can this not be done at repaint
    def select_default_values
      return if @default_values.nil?
      @default_values.each do |val|
        row = @list.index val
        add_row_selection_interval row, row unless row.nil?
      end
    end
    def print_borders
      width = @width
      height = @height-1 # 2010-01-04 15:30 BUFFERED HEIGHT
      window = @graphic  # 2010-01-04 12:37 BUFFERED
      startcol = @col 
      startrow = @row 
      @color_pair = get_color($datacolor)
#      bordercolor = @border_color || $datacolor # changed 2011 dts  
      bordercolor = @border_color || @color_pair
      borderatt = @border_attrib || Ncurses::A_NORMAL

      #$log.debug "rlistb #{name}: window.print_border #{startrow}, #{startcol} , h:#{height}, w:#{width} , @color_pair, @attr "
      window.print_border startrow, startcol, height, width, bordercolor, borderatt
      print_title
    end
    def print_title
      @color_pair ||= get_color($datacolor)
      # check title.length and truncate if exceeds width
      return unless @title
      _title = @title
      if @title.length > @width - 2
        _title = @title[0..@width-2]
      end
      @graphic.printstring( @row, @col+(@width-_title.length)/2, _title, @color_pair, @title_attrib) unless @title.nil?
    end
    ### START FOR scrollable ###
    def get_content
      #@list 2008-12-01 23:13 
      # NOTE: we never stored the listvariable, so its redundant, we used its value to set list
      @list_variable && @list_variable.value || @list 
    end
    def get_window
      @graphic # 2010-01-04 12:37 BUFFERED
    end
    ### END FOR scrollable ###
    # override widgets text
    # returns indices of selected rows
    def getvalue
      selected_rows
    end
    # Listbox
    def handle_key(ch)
      map_keys unless @keys_mapped
      @current_index ||= 0
      @toprow ||= 0
      h = scrollatrow()
      rc = row_count
      $log.debug " listbox got ch #{ch}"
      #$log.debug " when kps #{@KEY_PREV_SELECTION}  "
      case ch
      when 10,13, KEY_ENTER
        # this means you cannot just bind_key 10 or 13 like we once did
        fire_action_event # trying out REMOVE 2011-09-16 FFI
        $log.debug " 333 listbox catching 10,13 fire_action_event "
        return 0
      when KEY_UP  # show previous value
        return previous_row
      when KEY_DOWN  # show previous value
        return next_row
      when @KEY_ROW_SELECTOR # 32
        return if is_popup && @selection_mode != :multiple # not allowing select this way since there will be a difference 
        toggle_row_selection @current_index #, @current_index
        @repaint_required = true
      when @KEY_SCROLL_FORWARD # ?\C-n
        scroll_forward
      when @KEY_SCROLL_BACKWARD #  ?\C-p
        scroll_backward
      when @KEY_GOTO_TOP # 48, ?\C-[
        # please note that C-[ gives 27, same as esc so will respond after ages
        goto_top
      when @KEY_GOTO_BOTTOM # ?\C-]
        goto_bottom
      when @KEY_NEXT_SELECTION # ?'
        $log.debug "insdie next selection"
        @oldrow = @current_index
        do_next_selection 
        bounds_check
      when @KEY_PREV_SELECTION # ?"
        @oldrow = @current_index
        $log.debug "insdie prev selection"
        do_prev_selection 
        bounds_check
      when @KEY_CLEAR_SELECTION
        clear_selection 
        @repaint_required = true
      when 27, ?\C-c.getbyte(0), ?\C-g.getbyte(0)
        editing_canceled @current_index if @cell_editing_allowed
        cancel_block # block
        $multiplier = 0
      when @KEY_ASK_FIND_FORWARD
      # ask_search_forward
      when @KEY_ASK_FIND_BACKWARD
      # ask_search_backward
      when @KEY_FIND_NEXT
      # find_next
      when @KEY_FIND_PREV
      # find_prev
      when @KEY_ASK_FIND
        ask_search
      when @KEY_FIND_MORE
        find_more
      when @KEY_BLOCK_SELECTOR
        mark_block #selection
      #when ?\C-u.getbyte(0)
        # multiplier. Series is 4 16 64
        # TESTING @multiplier = (@multiplier == 0 ? 4 : @multiplier *= 4)
      #  return 0
      when ?\C-c.getbyte(0)
        @multiplier = 0
        return 0
      else
        # this has to be fixed, if compo does not handle key it has to continue into next part FIXME
        ret = :UNHANDLED # changed on 2009-01-27 13:14 not going into unhandled, tab not released
        if @cell_editing_allowed
          @repaint_required = true
          # hack - on_enter_row should fire when this widget gets focus. first row that is DONE
          begin
            ret = @cell_editor.component.handle_key(ch)
          rescue
            on_enter_row @current_index
            ret = @cell_editor.component.handle_key(ch)
          end
        end
        if ret == :UNHANDLED
          # beware one-key eats up numbers. we'll be wondering why
          if @one_key_selection
            case ch
            #when ?A.getbyte(0)..?Z.getbyte(0), ?a.getbyte(0)..?z.getbyte(0), ?0.getbyte(0)..?9.getbyte(0)
            when ?A.getbyte(0)..?Z.getbyte(0), ?a.getbyte(0)..?z.getbyte(0)
              # simple motion, key press defines motion
              ret = set_selection_for_char ch.chr
            else
              ret = process_key ch, self
      $log.debug "111 listbox #{@current_index} "
              @multiplier = 0
              return :UNHANDLED if ret == :UNHANDLED
            end
          else
            # no motion on single key, we can freak out like in vim, pref f <char> for set_selection
            case ch
            when ?0.getbyte(0)..?9.getbyte(0)
              $multiplier *= 10 ; $multiplier += (ch-48)
              #$log.debug " setting mult to #{$multiplier} in list "
              return 0
            end
            ret = process_key ch, self
            return :UNHANDLED if ret == :UNHANDLED
          end
        end
      end
      $multiplier = 0
    end
    # fire handler when user presses ENTER/RETURN
    # @since 1.2.0
    # listbox now traps ENTER key and fires action event
    # to trap please bind :PRESS
    #
    def fire_action_event
      # this does not select the row ???? FIXME ??
      require 'rbcurse/ractionevent'
      # should have been callled :ACTION_EVENT !!!
      fire_handler :PRESS, ActionEvent.new(self, :PRESS, text)
    end
    # get a keystroke from user and go to first item starting with that key
    def ask_selection_for_char
      ch = @graphic.getch
      if ch < 0 || ch > 255
        return :UNHANDLED
      end
      ret = set_selection_for_char ch.chr
    end
    def ask_search_forward
        regex =  get_string("Enter regex to search")
        ix = @list.find_match regex
        if ix.nil?
          alert("No matching data for: #{regex}")
        else
          set_focus_on(ix)
        end
    end
    # gets string to search and calls data models find prev
    def ask_search_backward
      regex =  get_string("Enter regex to search (backward)")
      @last_regex = regex
      ix = @list.find_prev regex, @current_index
      if ix.nil?
        alert("No matching data for: #{regex}")
      else
        set_focus_on(ix)
      end
    end
    # please check for error before proceeding
    # @return [Boolean] false if no data
    def on_enter
      if @list.nil? || @list.size == 0
        #Ncurses.beep
        get_window.ungetch($current_key) # 2011-10-4 push key back so form can go next
        return :UNHANDLED
      end
      on_enter_row @current_index
      set_form_row # added 2009-01-11 23:41 
      #$log.debug " ONE ENTER LIST #{@current_index}, #{@form.row}"
      @repaint_required = true
      super
      #fire_handler :ENTER, self
      true
    end
    def on_enter_row arow
      #$log.debug " Listbox #{self} ENTER_ROW with curr #{@current_index}. row: #{arow} H: #{@handler.keys}"
      #fire_handler :ENTER_ROW, arow
      fire_handler :ENTER_ROW, self
      @list.on_enter_row self  ## XXX WHY THIS ???
      edit_row_at arow
      @repaint_required = true
    end
    def edit_row_at arow
      if @cell_editing_allowed
        #$log.debug " cell editor on enter #{arow} val of list[row]: #{@list[arow]}"
        editor = cell_editor
        prepare_editor editor, arow
      end
    end
    ## 
    # private
    def prepare_editor editor, row
      r,c = rowcol
      value =  @list[row] # .chomp
      value = value.dup rescue value # so we can cancel
      row = r + (row - @toprow) #  @form.row
      col = c+@left_margin # @form.col
      # unfortunately 2009-01-11 19:47 combo boxes editable allows changing value
      editor.prepare_editor self, row, col, value
      editor.component.curpos = 0 # reset it after search, if user scrols down
      #editor.component.graphic = @graphic #  2010-01-05 00:36 TRYING OUT BUFFERED
      ## override is required if the listbox uses a buffer
      #if @should_create_buffer # removed on 2011-09-29 
        #$log.debug " overriding editors comp with GRAPHIC #{@graphic} "
        #editor.component.override_graphic(@graphic) #  2010-01-05 00:36 TRYING OUT BUFFERED
      #end
      set_form_col 0 #@left_margin

      # set original value so we can cancel
      # set row and col,
      # set value and other things, color and bgcolor
    end
    def on_leave_row arow
      #$log.debug " Listbox #{self} leave with (cr: #{@current_index}) #{arow}: list[row]:#{@list[arow]}"
      #$log.debug " Listbox #{self} leave with (cr: #{@current_index}) #{arow}: "
      #fire_handler :LEAVE_ROW, arow
      fire_handler :LEAVE_ROW, self
      editing_completed arow
    end
    def editing_completed arow
      if @cell_editing_allowed
        if !@cell_editor.nil?
      #    $log.debug " cell editor (leave) setting value row: #{arow} val: #{@cell_editor.getvalue}"
          $log.debug " cell editor #{@cell_editor.component.form.window} (leave) setting value row: #{arow} val: #{@cell_editor.getvalue}"
          @list[arow] = @cell_editor.getvalue #.dup 2009-01-10 21:42 boolean can't duplicate
        else
          $log.debug "CELL EDITOR WAS NIL, #{arow} "
        end
      end
      @repaint_required = true
    end
    def editing_canceled arow=@current_index
      return unless @cell_editing_allowed
      prepare_editor @cell_editor, arow
      @repaint_required = true
    end

    ##
    # getter and setter for cell_editor
    def cell_editor(*val)
      if val.empty?
        @cell_editor ||= create_default_cell_editor
      else
        @cell_editor = val[0] 
      end
    end
    def create_default_cell_editor
      return RubyCurses::CellEditor.new RubyCurses::Field.new nil, {"focusable"=>false, "visible"=>false, "display_length"=> @width-@internal_width-@left_margin}
    end
    ##
    # getter and setter for cell_renderer
    def cell_renderer(*val)
      if val.empty?
        @cell_renderer ||= create_default_cell_renderer
      else
        @cell_renderer = val[0] 
      end
    end
    def create_default_cell_renderer
      return RubyCurses::ListCellRenderer.new "", {"color"=>@color, "bgcolor"=>@bgcolor, "parent" => self, "display_length"=> @width-@internal_width-@left_margin}
    end
    ##
    # this method chops the data to length before giving it to the
    # renderer, this can cause problems if the renderer does some
    # processing. also, it pans the data horizontally giving the renderer
    # a section of it.
    def repaint
      return unless @repaint_required
      # not sure where to put this, once for all or repeat 2010-02-17 23:07 RFED16
      my_win = @form ? @form.window : @target_window
      @graphic = my_win unless @graphic
      raise " #{@name} neither form, nor target window given LB paint " unless my_win
      raise " #{@name} NO GRAPHIC set as yet                 LB paint " unless @graphic
      @win_left = my_win.left
      @win_top = my_win.top

      #$log.debug "rlistbox repaint  #{@name} r,c, #{@row} #{@col} , width: #{@width}  "
      print_borders unless @suppress_borders # do this once only, unless everything changes
      #maxlen = @maxlen || @width-@internal_width
      renderer = cell_renderer()
      renderer.display_length(@width-@internal_width-@left_margin) # just in case resizing of listbox
      tm = list()
      rc = row_count
      @longest_line = @width
      $log.debug " rlistbox repaint #{row_count} #{name} "
      if rc > 0     # just added in case no data passed
        tr = @toprow
        acolor = get_color $datacolor # should be set once, if color or bgcolor changs TODO FIXME
        h = scrollatrow()
        r,c = rowcol
        0.upto(h) do |hh|
          crow = tr+hh
          if crow < rc
            _focussed = @current_index == crow ? true : false  # row focussed ?
            focus_type = _focussed 
            # added 2010-09-02 14:39 so inactive fields don't show a bright focussed line
            #focussed = false if focussed && !@focussed
            focus_type = :SOFT_FOCUS if _focussed && !@focussed
            selected = is_row_selected crow
            content = tm[crow]   # 2009-01-17 18:37 chomp giving error in some cases says frozen
            content = convert_value_to_text content, crow # 2010-09-23 20:12 
            # by now it has to be a String
            if content.is_a? String
              content = content.dup
              sanitize content if @sanitization_required
              truncate content
            end
            ## set the selector symbol if requested
            selection_symbol = ''
            if @show_selector
              if selected
                selection_symbol = @row_selected_symbol
              else
                selection_symbol =  @row_unselected_symbol
              end
              @graphic.printstring r+hh, c, selection_symbol, acolor,@attr
            end
            #renderer = get_default_cell_renderer_for_class content.class.to_s
            renderer.repaint @graphic, r+hh, c+@left_margin, crow, content, focus_type, selected
          else
            # clear rows
            @graphic.printstring r+hh, c, " " * (@width-@internal_width), acolor,@attr
          end
        end
        if @cell_editing_allowed
          @cell_editor.component.repaint unless @cell_editor.nil? or @cell_editor.component.form.nil?
        end
      end # rc == 0
      #@table_changed = false
      @repaint_required = false
    end
    # the idea here is to allow users who subclass Listbox to easily override parts of the cumbersome repaint
    # method. This assumes your List has some data, but you print a lot more. Now you don't need to
    # change the data in the renderer, or keep formatted data in the list itself.
    # e.g. @list contains file names, or File objects, and this converts to a long listing.
    # If the renderer did that, the truncation would be on wrong data.
    # @since 1.2.0
    def convert_value_to_text value, crow
      case value
      when TrueClass, FalseClass
        value
      else
        value.to_s if value
      end
    end
    # takes a block, this way anyone extending this class can just pass a block to do his job
    # This modifies the string
    def sanitize content
      if content.is_a? String
        content.chomp!
        content.gsub!(/\t/, '  ') # don't display tab
        content.gsub!(/[^[:print:]]/, '')  # don't display non print characters
      else
        content
      end
    end
    # returns only the visible portion of string taking into account display length
    # and horizontal scrolling. MODIFIES STRING
    # if you;ve truncated the data, it could stay truncated even if lb is increased. be careful
    # FIXME if _maxlen becomes 0 then maxlen -1 will print whole string again
    def truncate content
      _maxlen = @maxlen || @width-@internal_width
      _maxlen = @width-@internal_width if _maxlen > @width-@internal_width
      #$log.debug "TRUNCATE: listbox maxlen #{@maxlen}, #{_maxlen} width #{@width}: #{content} "
      if !content.nil? 
        if content.length > _maxlen # only show maxlen
          @longest_line = content.length if content.length > @longest_line
          #content = content[@pcol..@pcol+maxlen-1] 
          content.replace content[@pcol..@pcol+_maxlen-1] 
        else
          # can this be avoided if pcol is 0 XXX
          content.replace content[@pcol..-1] if @pcol > 0
        end
      end
      #$log.debug " content: #{content}" 
      content
    end

    def list_data_changed
      if row_count == 0 # added on 2009-02-02 17:13 so cursor not hanging on last row which could be empty
        init_vars
        @current_index = 0
        # I had placed this at some time to get cursor correct. But if this listbox is updated
        # during entry in another field, then this steals the row. e.g. test1.rb 5
        #set_form_row
      end
      @repaint_required = true
    end
    # set cursor column position
    # if i set col1 to @curpos, i can move around left right if key mapped
    def set_form_col col1=0
      # TODO BUFFERED use setrowcol @form.row, col
      # TODO BUFFERED use cols_panned
      #col1 ||= 0
      @cols_panned ||= 0 # RFED16 2010-02-17 23:40 
      # editable listboxes will involve changing cursor and the form issue
      ## added win_col on 2010-01-04 23:28 for embedded forms BUFFERED TRYING OUT
      #win_col=@form.window.left
      win_col = 0 # 2010-02-17 23:19 RFED16
      #col = win_col + @orig_col + @col_offset + @curpos + @form.cols_panned
      col2 = win_col + @col + @col_offset + col1 + @cols_panned + @left_margin
      $log.debug " set_form_col in rlistbox #{@col}+ left_margin #{@left_margin} ( #{col2} ) "
      #super col+@left_margin
      #@form.setrowcol @form.row, col2   # added 2009-12-29 18:50 BUFFERED
      setrowcol nil, col2 # 2010-02-17 23:19 RFED16
    end
    #def rowcol
    ##  $log.debug "rlistbox rowcol : #{@row+@row_offset+@winrow}, #{@col+@col_offset}"
      #win_col=@form.window.left
      #col2 = win_col + @col + @col_offset + @form.cols_panned + @left_margin
      #return @row+@row_offset, col2
    #end
    # experimental selection of multiple rows via block
    # specify a block start and then a block end
    # usage: bind mark_selection to a key. It works as a toggle.
    # C-c will cancel any selection  that has begun.
    # added on 2009-02-19 22:37 
    def mark_block #selection
      if @inside_block
        @inside_block = false
        end_block #selection
      else
        @inside_block = true
        start_block #selection
      end
    end
    # added on 2009-02-19 22:37 
    def cancel_block
      @first_index = @last_index = nil
      @inside_block = false
    end
    # sets marker for start of block
    # added on 2009-02-19 22:37 
    def start_block #selection
      @first_index = @current_index
      @last_index = nil
    end
    # sets marker for end of block
    # added on 2009-02-19 22:37 
    def end_block #selection
      @last_index = current_index
      lower = [@first_index, @last_index].min
      higher = [@first_index, @last_index].max
      #lower.upto(higher) do |i| @list.toggle_row_selection i; end
      add_row_selection_interval(lower, higher)
      @repaint_required = true
    end
    # 2010-02-18 11:40 
    # TRYING OUT - canceling editing if resized otherwise drawing errors can occur
    # the earlier painted edited comp in yellow keeps showing until a key is pressed
 
    def set_buffering params
      $log.warn "CALLED set_buffering in LISTBOX listbox " if $log.debug? 
      super # removed from widget 2011-09-29 
      ## Ensuring that changes to top get reflect in editing comp
      #+ otherwise it raises an exception. Still the earlier cell_edit is being
      #+ printed where it was , until a key is moved
      # FIXME - do same for col
      if @cell_editor
        r,c = rowcol
        if @cell_editor.component.row < @row_offset + @buffer_params[:screen_top]
          @cell_editor.component.row = @row_offset +  @buffer_params[:screen_top]
        end
        # TODO next block to be tested by placing a listbox in right split of vertical
        if @cell_editor.component.col < @col_offset + @buffer_params[:screen_left]
          @cell_editor.component.col = @col_offset +  @buffer_params[:screen_left]
        end
        #editing_canceled @current_index if @cell_editing_allowed and @cell_editor
      end
      #set_form_row
      @repaint_required = true
    end

    # trying to simplify usage. The Java way has made listboxes very difficult to use
    # Returns selected indices
    # Indices are often required since the renderer may modify the values displayed
    #
    def get_selected_indices
      @list_selection_model.get_selected_indices
    end

    # Returns selected values
    #
    def get_selected_values
      selected = []
      @list_selection_model.get_selected_indices.each { |i| selected << list_data_model[i] }
      return selected
    end
    alias :selected_values :get_selected_values
    alias :selected_indices :get_selected_indices

    # ADD HERE
  end # class listb


end # module
