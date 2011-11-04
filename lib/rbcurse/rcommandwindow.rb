=begin
  * Name: rcommandwindow: pops up a status message at bottom of screen
          creating a new window, so we don't have to worry about having window
          handle.
          Can use with say, ask etc. wsay wask wagree etc !
  * Description   
  * Author: rkumar (arunachalesha)
  * Date: 2008-11-19 12:49 
  * License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
  * file separated on 2009-01-13 22:39 

=end
require 'rbcurse'

module RubyCurses
  ##
  # 
  #
  class CommandWindow
    include RubyCurses::Utils
    dsl_accessor :box
    dsl_accessor :title
    attr_reader :config
    attr_reader :layout
    attr_reader :window     # required for keyboard or printing
    dsl_accessor :height, :width, :top, :left  #  2009-01-06 00:05 after removing meth missing

    def initialize form=nil, aconfig={}, &block
      @config = aconfig
      @config.each_pair { |k,v| instance_variable_set("@#{k}",v) }
      instance_eval &block if block_given?
      if @layout.nil? 
          set_layout(1,80, -1, 0) 
      end
      @height = @layout[:height]
      @width = @layout[:width]
      @window = VER::Window.new(@layout)
      @start = 0 # row for display of text with paging
      @list = []
      require 'forwardable'
      require 'rbcurse/extras/bottomline'
      @bottomline = Bottomline.new @window, 0
      @bottomline.name = "rcommandwindow's bl"
      extend Forwardable
      def_delegators :@bottomline, :ask, :say, :agree, :choose #, :display_text_interactive
      if @box == :border
        @window.box 0,0
      elsif @box
        @window.attron(Ncurses.COLOR_PAIR($normalcolor) | Ncurses::A_REVERSE)
        @window.mvhline 0,0,1,@width
        @window.printstring 0,0,@title, $normalcolor #, 'normal' if @title
        @window.attroff(Ncurses.COLOR_PAIR($normalcolor) | Ncurses::A_REVERSE)
      else
        #@window.printstring 0,0,@title, $normalcolor,  'reverse' if @title
        title @title
      end
      @window.wrefresh
      @panel = @window.panel
      Ncurses::Panel.update_panels
      @window.wrefresh
      @row_offset = 0
      if @box
        @row_offset = 1
      end
    end
    # modify the window title, or get it if no params passed.
    def title t=nil
      return @title unless t
      @title = t
      @window.printstring 0,0,@title, $normalcolor,  'reverse' if @title
    end
    ##
    ## message box
    def stopping?
      @stop
    end
    # todo handle mappings, so user can map keys TODO
    def handle_keys
      begin
        while((ch = @window.getchar()) != 999 )
          case ch
          when -1
            next
          else
            press ch
            break if @stop
            yield ch if block_given?
          end
        end
      ensure
        destroy  
      end
      return #@selected_index
    end
    # handles a key, commandline
    def press ch 
      ch = ch.getbyte(0) if ch.class==String ## 1.9
      $log.debug " XXX press #{ch} " if $log.debug? 
      case ch
      when -1
        return
      when KEY_F1, 27, ?\C-q.getbyte(0)   
        @stop = true
        return
      when KEY_ENTER, 10, 13
        #$log.debug "popup ENTER : #{@selected_index} "
        #$log.debug "popup ENTER :  #{field.name}" if !field.nil?
        @stop = true
        return
      when ?\C-d.getbyte(0)
        @start += @height-1
        bounds_check
      when KEY_UP
        @start -= 1
        @start = 0 if @start < 0
      when KEY_DOWN
        @start += 1
        bounds_check
      when ?\C-b.getbyte(0)
        @start -= @height-1
        @start = 0 if @start < 0
      when 0
        @start = 0
      end
      Ncurses::Panel.update_panels();
      Ncurses.doupdate();
      @window.wrefresh
    end
    # might as well add more keys for paging.
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

    def set_layout(height=0, width=0, top=0, left=0)
      # negative means top should be n rows from last line. -1 is last line
      if top < 0
        top = Ncurses.LINES-top
      end
      @layout = { :height => height, :width => width, :top => top, :left => left } 
      @height = height
      @width = width
    end
    def destroy
      $log.debug "DESTROY : rcommandwindow"
      if @window
        begin
          panel = @window.panel
          Ncurses::Panel.del_panel(panel.pointer) if panel
          @window.delwin
        rescue => exc
        end
      end
    end
    #
    # Displays list in a window at bottom of screen, if large then 2 or 3 columns.
    # @param [Array] list of string to be displayed
    # @param [Hash]  configuration options: indexing and indexcolor
    # indexing - can be letter or number. Anything else will be ignored, however
    #  it will result in first letter being highlighted in indexcolor
    # indexcolor - color of mnemonic, default green
    def display_menu list, options={}
      indexing = options[:indexing]
      indexcolor = options[:indexcolor] || get_color($normalcolor, :yellow, :black)
      indexatt = Ncurses::A_BOLD
      #
      # the index to start from (used when scrolling a long menu such as file list)
      startindex = options[:startindex] || 0

      max_cols = 3 #  maximum no of columns, we will reduce based on data size
      l_succ = "`"
      act_height = @height
      if @box
        act_height = @height - 2
      end
      lh = list.size
      if lh < act_height
        $log.debug "DDD inside one window" if $log.debug? 
        list.each_with_index { |e, i| 
          text = e
          case e
          when Array
            text = e.first + " ..."
          end
          if indexing == :number
            mnem = i+1
            text = "%d. %s" % [i+1, text] 
          elsif indexing == :letter
            mnem = l_succ.succ!
            text = "%s. %s" % [mnem, text] 
          end
          @window.printstring i+@row_offset, 1, text, $normalcolor  
          if indexing
            window.mvchgat(y=i+@row_offset, x=1, max=1, indexatt, indexcolor, nil)
          end
        }
      else
        $log.debug "DDD inside two window" if $log.debug? 
        row = 0
        h = act_height
        cols = (lh*1.0 / h).ceil
        cols = max_cols if cols > max_cols
        # sometimes elements are large like directory paths, so check size
        datasize = list.first.length
        if datasize > @width/3 # keep safety margin since checking only first row
          cols = 1
        elsif datasize > @width/2
          cols = [2,cols].min
        end
        adv = (@width/cols).to_i
        colct = 0
        col = 1
        $log.debug "DDDcols #{cols}, adv #{adv} size: #{lh} h: #{act_height} w #{@width} " if $log.debug? 
        list.each_with_index { |e, i| 
          text = e
          # signify that there's a deeper level
          case e
          when Array
            text = e.first + "..."
          end
          if indexing == :number
            mnem = i+1
            text = "%d. %s" % [mnem, text] 
          elsif indexing == :letter
            mnem = l_succ.succ!
            text = "%s. %s" % [mnem, text] 
          end
          # print only within range and window height
          if i >= startindex && row < @window.actual_height
            $log.debug "XXX: MENU #{i} > #{startindex} row #{row} col #{col} "
            @window.printstring row+@row_offset, col, text, $normalcolor  
            if indexing
              @window.mvchgat(y=row+@row_offset, x=col, max=1, indexatt, indexcolor, nil)
            end
          colct += 1
          if colct == cols
            col = 1
            row += 1
            colct = 0
          else
            col += adv
          end
          end # startindex
        }
      end
      Ncurses::Panel.update_panels();
      Ncurses.doupdate();
      @window.wrefresh
    end
    # refresh whatevers painted onto the window
    def refresh
      Ncurses::Panel.update_panels();
      Ncurses.doupdate();
      @window.wrefresh
    end
    # clears the window, leaving the title line as is, from row 1 onwards
    def clear
      @window.wmove 1,1
      @window.wclrtobot
      @window.box 0,0 if @box == :border
      # lower line of border will get erased currently since we are writing to 
      # last line FIXME
    end
    def display_interactive text, config={}
      if @to
        @to.content text
      else
        config[:box] = @box
        @to = ListObject.new self, text, config
      end
      yield @to if block_given?
      @to.display_interactive # this returns the item selected
      @to   # this will return the ListObject to the user with list and current_index
    end
    # non interactive list display - EACH CALL IS CREATING A LIST OBJECT
    def udisplay_list text, config={}
      if @to
        @to.content text
      else
        config[:box] = @box
        @to = ListObject.new self, text, config
      end
      #@to ||= ListObject.new self, text, config
      yield @to if block_given?
      @to.display_content
      @to
    end
    # displays a list
    class ListObject
      attr_reader :cw
      attr_reader :list
      attr_reader :current_index
      attr_accessor :focussed_attrib
      attr_accessor :focussed_symbol
      def initialize cw, _list, config={}
        @cw  = cw
        layout = @cw.layout
        @window = @cw.window
        @height = layout[:height]
        @width = layout[:width]
        content(_list)
        @height_adjust = config.fetch(:box, true) == :border ? 3 : 2
        @selected_index = nil
        @current_index = 0
        @row_offset = 1
        @toprow = 0
        $multiplier = 0 # till we can do something

        @focussed_symbol = ''
        @row_selected_symbol = ''
        #@show_selector = true
        if @show_selector
          @row_selected_symbol ||= '*'
          @row_unselected_symbol ||= ' '
          @left_margin ||= @row_selected_symbol.length
        end
        #@show_selector = true
        #@row_selected_symbol = '*'
        #@row_unselected_symbol = ' '
      end
      def content txt, config={}
        @current_index = 0 # sometimes it gets left at a higher value than there are rows to show
        case txt
        when String
          txt = wrap_text(txt, @width-2).split("\n")
        when Array
          # okay
        end
        @list = txt
      end
      # maybe we should just use a textview or label rather than try to 
      # do it all voer again !
      def display_interactive
        display_content
        while !@stop
          @window.wrefresh # FFI 2011-09-12 
          # FIXME only clear and redisplay if change has happened (repaint_require)
          handle_keys { |ch| @cw.clear; display_content }
        end
        return @list[@current_index]
      end
      def is_row_selected row
        @selected_index == row
      end

      def scrollatrow
        @height - 3
      end
      def row_count
        @list.size
      end
      def rowcol
        return @row_offset, @col_offset
      end
      def display_content #:nodoc:

        @graphic = @window
        @start ||= 0
        @toprow ||= 0
        @left_margin ||= @row_selected_symbol.length + @focussed_symbol.length

        #print_borders unless @suppress_borders # do this once only, unless everything changes
        #maxlen = @maxlen ||= @width-2
        tm = @list
        rc = tm.size
        @col_offset = 1
        #@longest_line = @width
        if rc > 0     # just added in case no data passed
          #tr = @start #@toprow
          tr = @toprow
          acolor = get_color $datacolor
          #h = @height - 3 #2
          h = @height - @height_adjust
          r,c = @row_offset, @col_offset
          0.upto(h) do |hh|
            crow = tr+hh
            if crow < rc
              focussed = @current_index == crow  # row focussed ?
              selected = is_row_selected crow
              content = tm[crow]   # 2009-01-17 18:37 chomp giving error in some cases says frozen
              # by now it has to be a String
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
              if focussed
                if @focussed_symbol
                  @graphic.printstring r+hh, c, @focussed_symbol, acolor,@attr
                end
                @graphic.printstring r+hh, c+@left_margin, content, acolor, @focussed_attrib || 'reverse'
              else
                @graphic.printstring r+hh, c+@left_margin, content, acolor,@attr
              end
              #renderer.repaint @graphic, r+hh, c+@left_margin, crow, content, focussed, selected
            else
              # clear rows
              @graphic.printstring r+hh, c, " " * (@width-2), acolor,@attr
            end
          end
        end # rc == 0
        set_form_row
      end
      # listobject
      def press ch # list TODO copy from rbasiclist
        ch = ch.getbyte(0) if ch.class==String ## 1.9
        $log.debug " XXX press #{ch} " if $log.debug? 
        case ch
        when -1
          return
        when KEY_F1, 27, ?\C-q.getbyte(0)   
          @stop = true
          return
        when KEY_ENTER, 10, 13
          #$log.debug "popup ENTER : #{@selected_index} "
          #$log.debug "popup ENTER :  #{field.name}" if !field.nil?
          @stop = true
          return
        when 32, ?\C-d.getbyte(0)
          scroll_forward
          #@start += @height-1
          #bounds_check
        when KEY_UP, ?k.getbyte(0)
          previous_row
          #@start -= 1
          #@current_index -= 1
          #@current_index = 0 if @current_index < 0
          #@start = 0 if @start < 0
        when KEY_DOWN, ?j.getbyte(0)
          next_row
          #@start += 1
          #@current_index += 1
          #bounds_check
        when ?\C-b.getbyte(0)
          scroll_backward
          #@start -= @height-1
          #@start = 0 if @start < 0
        when 0, ?g.getbyte(0)
          goto_top
        when ?G.getbyte(0)
          goto_bottom
        end
        #@form.repaint
        Ncurses::Panel.update_panels();
        Ncurses.doupdate();
        @window.wrefresh
      end

      def previous_row num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
        #return :UNHANDLED if @current_index == 0 # EVIL
        return false if @current_index == 0 
        @oldrow = @current_index
        num.times { 
          @current_index -= 1 if @current_index > 0
        }
        bounds_check
        $multiplier = 0
      end
      alias :up :previous_row
      def next_row num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
        rc = row_count
        return false if @current_index == rc-1 
        @oldrow = @current_index
        @current_index += 1*num if @current_index < rc
        bounds_check
        $multiplier = 0
      end
      alias :down :next_row
      def goto_bottom
        @oldrow = @current_index
        rc = row_count
        @current_index = rc -1
        bounds_check
      end
      alias :goto_end :goto_bottom
      def goto_top
        @oldrow = @current_index
        @current_index = 0
        bounds_check
      end
      alias :goto_start :goto_top
      def scroll_backward
        @oldrow = @current_index
        h = scrollatrow()
        m = $multiplier == 0? 1 : $multiplier
        @current_index -= h * m
        bounds_check
        $multiplier = 0
      end
      def scroll_forward
        @oldrow = @current_index
        h = scrollatrow()
        rc = row_count
        m = $multiplier == 0? 1 : $multiplier
        # more rows than box
        if h * m < rc
          @toprow += h+1 #if @current_index+h < rc
          @current_index = @toprow
        else
          # fewer rows than box
          @current_index = rc -1
        end
        #@current_index += h+1 #if @current_index+h < rc
        bounds_check
      end

      ##
      # please set oldrow before calling this. Store current_index as oldrow before changing. NOTE
      def bounds_check
        h = scrollatrow()
        rc = row_count

        @current_index = 0 if @current_index < 0  # not lt 0
        @current_index = rc-1 if @current_index >= rc && rc>0 # not gt rowcount
        @toprow = rc-h-1 if rc > h && @toprow > rc - h - 1 # toprow shows full page if possible
        # curr has gone below table,  move toprow forward
        if @current_index - @toprow > h
          @toprow = @current_index - h
        elsif @current_index < @toprow
          # curr has gone above table,  move toprow up
          @toprow = @current_index
        end
        set_form_row

      end

      def set_form_row
        r,c = rowcol


        # when the toprow is set externally then cursor can be mispositioned since 
        # bounds_check has not been called
        if @current_index < @toprow
          # cursor is outside table
          @current_index = @toprow # ??? only if toprow 2010-10-19 12:56 
        end

        row = r + (@current_index-@toprow) 
        # row should not be < r or greater than r+height TODO FIXME

        #setrowcol row, nil
        @window.wmove row, c
        @window.wrefresh   # FFI added to keep cursor display in synch with selection
      end
      def OLDbounds_check #:nodoc:
        @start = 0 if @start < 0
        row_offset = 1
        last = (@list.length)-(@height-row_offset-1)
        if @start > last
          @start = last
        end
      end # bounds_check
      def handle_keys #:nodoc:
        begin
          while((ch = @window.getchar()) != 999 )
            case ch
            when -1
              next
            else
              press ch
              break if @stop
              yield ch if block_given?
            end
          end
        ensure
          @cw.destroy  
        end
        return @current_index
      end
    end # class ListObject
  end # class CommandWindow
end # module
