=begin
  * Name: rlistbox: editable scrollable lists
  * Description   
  * Author: rkumar (arunachalesha)
  * Date: 2008-11-19 12:49 
  * License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
  * This file started on 2009-01-13 22:18 (broken off rwidgets.rb)
TODO 
=end
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/listcellrenderer'
require 'rbcurse/listkeys'


include Ncurses
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

    def initialize anarray
      @list = anarray.dup
    end
    # changd on 2009-01-14 12:28 based on ..
    # http://www.ruby-forum.com/topic/175637#769030
    def each(&blk)
      @list.each(&blk)
    end
    #def each 
    #  @list.each { |item| yield item }
    #end
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
      lde = ListDataEvent.new(0, @list.size, self, :INTERVAL_REMOVED)
      @list = []
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
    def values
      @list.dup
    end
    def on_enter_row object
      #$log.debug " XXX on_enter_row of list_data"
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
  # pops up a list of values for selection
  # 2008-12-10
  class PopupList
    include DSL
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
      if !@relative_to.nil?
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
      @panel = @window.panel  # useless line ?
      Ncurses::Panel.update_panels
      print_input # creates the listbox
      @form.repaint
      @window.wrefresh
      handle_keys
    end
    def list alist=nil
      return @list if alist.nil?
      @list = ListDataModel.new(alist)
      #  will we need this ? listbox made each time so data should be fresh
      #@list.bind(:LIST_DATA_EVENT) { |e| list_data_changed() }
    end
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
          fire_handler :PRESS, @listbox.focussed_index
          # since Listbox is handling enter, COMBO_SELECT will not be fired
        # $log.debug "popup ENTER : #{@selected_index} "
        # $log.debug "popup ENTER :  #{field.name}" if !field.nil?
          @stop = true
          return
        when 9
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
  # this is the new LISTBOX, based on new scrollable.
  #
  class Listbox < Widget
    require 'rbcurse/listscrollable'
    require 'rbcurse/listselectable'
    require 'rbcurse/defaultlistselectionmodel'
    require 'rbcurse/celleditor'
    include ListScrollable
    include ListSelectable
    include RubyCurses::ListKeys
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
    dsl_accessor :KEY_ROW_SELECTOR
    dsl_accessor :KEY_GOTO_TOP
    dsl_accessor :KEY_GOTO_BOTTOM
    dsl_accessor :KEY_CLEAR_SELECTION
    dsl_accessor :KEY_NEXT_SELECTION
    dsl_accessor :KEY_PREV_SELECTION
    dsl_accessor :valign  # 2009-01-17 18:32 
    attr_accessor :one_key_selection # will pressing a single key select or not

    def initialize form, config={}, &block
      @focusable = true
      @editable = false
      @row = 0
      @col = 0
      # data of listbox
      @list = []
      # any special attribs such as status to be printed in col1, or color (selection)
      @list_attribs = {}
      super
      @current_index ||= 0
      @row_offset = @col_offset = 1
      @content_rows = @list.length
      @selection_mode ||= 'multiple'
      @win = @graphic    # 2010-01-04 12:36 BUFFERED  replace form.window with graphic
      # moving down to repaint so that scrollpane can set should_buffered
      # added 2010-02-17 23:05  RFED16 so we don't need a form.
      @win_left = 0
      @win_top = 0

#x      safe_create_buffer # 2010-01-04 12:36 BUFFERED moved here 2010-01-05 18:07 
#x      print_borders unless @win.nil?   # in messagebox we don;t have window as yet!
      # next 2 lines carry a redundancy
      select_default_values   
      # when the combo box has a certain row in focus, the popup should have the same row in focus

      install_keys
      init_vars
      install_list_keys

      if !@list.selected_index.nil? 
        set_focus_on @list.selected_index # the new version
      end
    end
    def init_vars
      @to_print_borders ||= 1
      @repaint_required = true
      @toprow = @pcol = 0
      if @show_selector
        @row_selected_symbol ||= '>'
        @row_unselected_symbol ||= ' '
        @left_margin ||= @row_selected_symbol.length
      end
      @left_margin ||= 0
      @one_key_selection ||= true
      bind_key(?f){ ask_selection_for_char() }
      bind_key(?\M-v){ @one_key_selection = false }
      bind_key(?j){ next_row() }
      bind_key(?k){ previous_row() }
      bind_key(?G){ goto_bottom() }
      bind_key([?g,?g]){ goto_top() }
      bind_key(?/){ ask_search() }
      bind_key(?n){ find_more() }

    end
    def install_bindings

    end

    ##
    # getter and setter for selection_mode
    # Must be called after creating model, so no duplicate. Since one may set in model directly.
    def selection_mode(*val)
      raise "ListSelectionModel not yet created!" if @list_selection_model.nil?
      if val.empty?
        @list_selection_model.selection_mode
      else
        @list_selection_model.selection_mode = val[0] 
      end
    end
    def row_count
      @list.length
    end
    # added 2009-01-07 13:05 so new scrollable can use
    def scrollatrow
      #@height - 2
      @height - 3 # 2010-01-04 15:30 BUFFERED HEIGHT
    end
    def list alist=nil
      return @list if alist.nil?
      @list = RubyCurses::ListDataModel.new(alist)
      # added on 2009-01-13 23:19 since updates are not automatic now
      @list.bind(:LIST_DATA_EVENT) { |e| list_data_changed() }
      create_default_list_selection_model
    end
    def list_variable alist=nil
      return @list if alist.nil?
      @list = RubyCurses::ListDataModel.new(alist.value)
      # added on 2009-01-13 23:19 since updates are not automatic now
      @list.bind(:LIST_DATA_EVENT) { |e| list_data_changed() }
      create_default_list_selection_model
    end
    def list_data_model ldm=nil
      return @list if ldm.nil?
      raise "Expecting list_data_model" unless ldm.is_a? RubyCurses::ListDataModel
      @list = ldm
      # added on 2009-01-13 23:19 since updates are not automatic now
      @list.bind(:LIST_DATA_EVENT) { |e| list_data_changed() }
      create_default_list_selection_model
    end

    def select_default_values
      return if @default_values.nil?
      @default_values.each do |val|
        row = @list.index val
        #do_select(row) unless row.nil?
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
      #$log.debug "rlistb:  window.print_border #{startrow}, #{startcol} , #{height} , #{width} , @color_pair, @attr "
      window.print_border startrow, startcol, height, width, @color_pair, @attr
      print_title
    end
    def print_title
      #printstring(@graphic, @row, @col+(@width-@title.length)/2, @title, @color_pair, @title_attrib) unless @title.nil?
      # 2010-01-04 15:53 BUFFERED
      # I notice that the old version would print a title that was longer than width,
      #+ but the new version won't print anything if it exceeds width.
      # TODO check title.length and truncate if exceeds width
      @graphic.printstring( @row, @col+(@width-@title.length)/2, @title, @color_pair, @title_attrib) unless @title.nil?
    end
    ### START FOR scrollable ###
    def get_content
      #@list 2008-12-01 23:13 
      @list_variable && @list_variable.value || @list 
    end
    def get_window
      @graphic # 2010-01-04 12:37 BUFFERED
    end
    ### END FOR scrollable ###
    # override widgets text
    def getvalue
      selected_rows
    end
    # Listbox
    def handle_key(ch)
      @current_index ||= 0
      @toprow ||= 0
      h = scrollatrow()
      rc = row_count
      $log.debug " listbxo got ch #{ch}"
      #$log.debug " when kps #{@KEY_PREV_SELECTION}  "
      case ch
      when KEY_UP  # show previous value
        previous_row
      when KEY_DOWN  # show previous value
        next_row
      when @KEY_ROW_SELECTOR # 32
        return if is_popup and @selection_mode == 'single' # not allowing select this way since there will be a difference 
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
        do_next_selection #if @select_mode == 'multiple'
        bounds_check
      when @KEY_PREV_SELECTION # ?"
        @oldrow = @current_index
        $log.debug "insdie prev selection"
        do_prev_selection #if @select_mode == 'multiple'
        bounds_check
      when @KEY_CLEAR_SELECTION
        clear_selection #if @select_mode == 'multiple'
        @repaint_required = true
      when 27, ?\C-c.getbyte(0)
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
          if @one_key_selection
            case ch
            when ?A.getbyte(0)..?Z.getbyte(0), ?a.getbyte(0)..?z.getbyte(0), ?0.getbyte(0)..?9.getbyte(0)
              # simple motion, key press defines motion
              ret = set_selection_for_char ch.chr
            else
              ret = process_key ch, self
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
            $multiplier = 0
            return :UNHANDLED if ret == :UNHANDLED
          end
        end
      end
      $multiplier = 0
    end
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
    ## listbox find_prev
    def OLDfind_prev
        ix = @list.find_prev
        regex = @last_regex 
        if ix.nil?
          alert("No previous matching data for: #{regex}")
        else
          @oldrow = @current_index
          @current_index = ix
          bounds_check
        end
    end
    # table find_next
    def OLDfind_next
        ix = @list.find_next
        regex = @last_regex 
        if ix.nil?
          alert("No more matching data for: #{regex}")
        else
          set_focus_on(ix) unless ix.nil?
        end
    end
    def on_enter
      on_enter_row @current_index
      set_form_row # added 2009-01-11 23:41 
      #$log.debug " ONE ENTER LIST #{@current_index}, #{@form.row}"
      @repaint_required = true
      fire_handler :ENTER, self
    end
    def on_enter_row arow
      #$log.debug " Listbox #{self} ENTER_ROW with curr #{@current_index}. row: #{arow} H: #{@handler.keys}"
      #fire_handler :ENTER_ROW, arow
      fire_handler :ENTER_ROW, self
      @list.on_enter_row self
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
      if @should_create_buffer
        $log.debug " overriding editors comp with GRAPHIC #{@graphic} "
        editor.component.override_graphic(@graphic) #  2010-01-05 00:36 TRYING OUT BUFFERED
      end
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
      return RubyCurses::CellEditor.new RubyCurses::Field.new nil, {"focusable"=>false, "visible"=>false, "display_length"=> @width-2-@left_margin}
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
      return RubyCurses::ListCellRenderer.new "", {"color"=>@color, "bgcolor"=>@bgcolor, "parent" => self, "display_length"=> @width-2-@left_margin}
    end
    ##
    # this method chops the data to length before giving it to the
    # renderer, this can cause problems if the renderer does some
    # processing. also, it pans the data horizontally giving the renderer
    # a section of it.
    def repaint
      safe_create_buffer # 2010-01-04 12:36 BUFFERED moved here 2010-01-05 18:07 
      return unless @repaint_required
      # not sure where to put this, once for all or repeat 2010-02-17 23:07 RFED16
      my_win = @form ? @form.window : @target_window
      @graphic = my_win unless @graphic
      #$log.warn "neither form not target window given!!! TV paint 368" unless my_win
      raise " #{@name} neither form, nor target window given TV paint " unless my_win
      raise " #{@name} NO GRAPHIC set as yet                 TV paint " unless @graphic
      @win_left = my_win.left
      @win_top = my_win.top

      $log.debug " rlistbox repaint graphic #{@graphic} "
      print_borders if @to_print_borders == 1 # do this once only, unless everything changes
      rc = row_count
      maxlen = @maxlen ||= @width-2
      tm = list()
      tr = @toprow
      acolor = get_color $datacolor
      h = scrollatrow()
      r,c = rowcol
      0.upto(h) do |hh|
        crow = tr+hh
        if crow < rc
            focussed = @current_index == crow ? true : false 
            selected = is_row_selected crow
            content = tm[crow]   # 2009-01-17 18:37 chomp giving error in some cases says frozen
            if content.is_a? String
              content = content.dup
              content.chomp!
              content.gsub!(/\t/, '  ') # don't display tab
              content.gsub!(/[^[:print:]]/, '')  # don't display non print characters
              if !content.nil? 
                if content.length > maxlen # only show maxlen
                  content = content[@pcol..@pcol+maxlen-1] 
                else
                  content = content[@pcol..-1]
                end
              end
            elsif content.is_a? TrueClass or content.is_a? FalseClass
            else
              content = content.to_s
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
            renderer = cell_renderer()
            #renderer.show_selector @show_selector
            #renderer.row_selected_symbol @row_selected_symbol
            #renderer.left_margin @left_margin
            #renderer.repaint @graphic, r+hh, c+(colix*11), content, focussed, selected
            ## added crow on 2009-02-06 23:03 
            # since data is being truncated and renderer may need index
            renderer.repaint @graphic, r+hh, c+@left_margin, crow, content, focussed, selected
        else
          # clear rows
          @graphic.printstring r+hh, c, " " * (@width-2), acolor,@attr
        end
      end
      if @cell_editing_allowed
        @cell_editor.component.repaint unless @cell_editor.nil? or @cell_editor.component.form.nil?
      end
      @table_changed = false
      @repaint_required = false
      @buffer_modified = true # required by form to call buffer_to_screen BUFFERED
      buffer_to_window # RFED16 2010-02-17 23:16 
    end
    def list_data_changed
      if row_count == 0 # added on 2009-02-02 17:13 so cursor not hanging on last row which could be empty
        init_vars
        @current_index = 0
        set_form_row
      end
      @repaint_required = true
    end
    def set_form_col col1=0
      # TODO BUFFERED use setrowcol @form.row, col
      # TODO BUFFERED use cols_panned
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
      super
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


    # ADD HERE
  end # class listb


end # module
