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
      #@form = form
      @config = aconfig
      @config.each_pair { |k,v| instance_variable_set("@#{k}",v) }
      instance_eval &block if block_given?
      if @layout.nil? 
          set_layout(1,80, 27, 0) 
      end
      @height = @layout[:height]
      @width = @layout[:width]
      @window = VER::Window.new(@layout)
      @start = 0 # row for display of text with paging
      @list = []
      require 'forwardable'
      require 'rbcurse/extras/bottomline'
      @bottomline = Bottomline.new @window, 0
      extend Forwardable
      def_delegators :@bottomline, :ask, :say, :agree, :choose #, :display_text_interactive
      #if @form.nil?
        #@form = RubyCurses::Form.new @window
      #else
        #@form.window = @window
      #end
      #acolor = get_color $reversecolor
      #color = get_color $datacolor
      #@window.printstring 0,0,"hello there", $normalcolor, 'normal'
      #@window.bkgd(Ncurses.COLOR_PAIR(acolor));
      if @box
        #@window.box 0,0
        @window.attron(Ncurses.COLOR_PAIR($normalcolor) | Ncurses::A_REVERSE)
        @window.mvhline 0,0,1,@width
        @window.printstring 0,0,@title, $normalcolor #, 'normal' if @title
        @window.attroff(Ncurses.COLOR_PAIR($normalcolor) | Ncurses::A_REVERSE)
      else
        @window.printstring 0,0,@title, $normalcolor,  'reverse' if @title
      end
      @window.wrefresh
      @panel = @window.panel
      Ncurses::Panel.update_panels
      #@form.repaint
      @window.wrefresh
      #handle_keys
      @row_offset = 0
      if @box
        @row_offset = 1
      end
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
      #@form.repaint
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
      @layout = { :height => height, :width => width, :top => top, :left => left } 
      @height = height
      @width = width
    end
    def destroy
      $log.debug "DESTROY : rcommandwindow"
      if @window
        begin
          panel = @window.panel
          Ncurses::Panel.del_panel(panel) if panel
          @window.delwin
        rescue => exc
        end
      end
    end
    # do not go more than 3 columns and do not print more than window TODO FIXME
    def display_menu list, options={}
      indexing = options[:indexing]
      max_cols = 3
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
          if indexing == :number
            text = "%d. %s" % [i+1, e] 
          elsif indexing == :letter
            text = "%s. %s" % [l_succ.succ!, e] 
          end
          @window.printstring i+@row_offset, 1, text, $normalcolor  
        }
      else
        $log.debug "DDD inside two window" if $log.debug? 
        row = 0
        h = act_height
        cols = (lh*1.0 / h).ceil
        cols = max_cols if cols > max_cols
        adv = (@width/cols).to_i
        colct = 0
        col = 1
        $log.debug "DDDcols #{cols}, adv #{adv} size: #{lh} h: #{act_height} w #{@width} " if $log.debug? 
        list.each_with_index { |e, i| 
          # check that row + @row_offset < @top + @height or whatever TODO
          text = e
          if indexing == :number
            text = "%d. %s" % [i+1, e] 
          elsif indexing == :letter
            text = "%s. %s" % [l_succ.succ!, e] 
          end
          @window.printstring row+@row_offset, col, text, $normalcolor  
          colct += 1
          if colct == cols
            col = 1
            row += 1
            colct = 0
          else
            col += adv
          end
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
    end
    def display_text_interactive text
      to = TextObject.new self, text
      to.display_text_interactive
    end
    class TextObject
      #attr_reader :text
      attr_reader :cw
      def initialize cw, _text
           @cw  = cw
           layout = @cw.layout
           $log.debug "XXX TextOb layout #{layout.class} #{layout}  " if $log.debug? 
           text(_text)
           @window = @cw.window
           @height = layout[:height]
           @width = layout[:width]
      end
      def text txt, config={}
        case txt
        when String
          txt = wrap_text(txt, @width-2).split("\n")
        when Array
          # okay
        end
        @list = txt
      end
      alias :content :text
      # maybe we should just use a textview or label rather than try to 
      # do it all voer again !
      def display_text
        @start ||= 0
        @start = 0 if @start < 0
        $log.debug "XXX display_text #{@start} " if $log.debug? 
        row_offset = 1
        col = 1
        size = @list.size-1
        row = 0
        @start.upto(@start+@height-1) do |i|
          break if i > size
          #$log.debug " XXX      #{i}  " if $log.debug? 
          line = "#{i} #{@list[i]} "
          line ||= ""
          @window.printstring row+row_offset, col, line, $datacolor
          row += 1
          #break if start+i > @height
        end
        @cw.refresh
      end
      def display_text_interactive
        display_text
        while !@stop
          handle_keys { |ch| @cw.clear; display_text }
        end
      end
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
        when 32, ?\C-d.getbyte(0)
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
        #@form.repaint
        Ncurses::Panel.update_panels();
        Ncurses.doupdate();
        @window.wrefresh
      end
      def bounds_check
        @start = 0 if @start < 0
        row_offset = 1
        last = (@list.length)-(@height-row_offset-1)
        if @start > last
          @start = last
        end
      end # bounds_check
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
          @cw.destroy  
        end
        return #@selected_index
      end
    end # class TextObject
    def display_list_interactive text
      to = ListObject.new self, text
      to.display_list_interactive
    end
    class ListObject
      attr_reader :cw
      def initialize cw, _list
           @cw  = cw
           layout = @cw.layout
           list(_list)
           @window = @cw.window
           @height = layout[:height]
           @width = layout[:width]
           @selected_index = 2
           @current_index = 0
           @row_offset = 1
      @toprow = 0
           $multiplier = 0 # till we can do something

           @row_selected_symbol = ''
           @show_selector = true
           if @show_selector
             @row_selected_symbol ||= '*'
             @row_unselected_symbol ||= ' '
             @left_margin ||= @row_selected_symbol.length
           end
           #@show_selector = true
           #@row_selected_symbol = '*'
           #@row_unselected_symbol = ' '
      end
      def list txt, config={}
        #case txt
        #when String
          #txt = wrap_text(txt, @width-2).split("\n")
        #when Array
          ## okay
        #end
        @list = txt
      end
      alias :content :list
      # maybe we should just use a textview or label rather than try to 
      # do it all voer again !
      def _display_text
        @start ||= 0
        $log.debug "XXX display_text #{@start} " if $log.debug? 
        row_offset = 1
        col = 1
        size = @list.size-1
        row = 0
        @start.upto(@start+@height-1) do |i|
          #break if i > size
          $log.debug " XXX      #{i}  " if $log.debug? 
          line = "#{i} #{@list[i]} "
          line ||= ""
          @window.printstring row+row_offset, col, line, $datacolor
          row += 1
          #break if start+i > @height
        end
        @cw.refresh
      end
      def display_list_interactive
        display_list
        while !@stop
          # FIXME only clear and redisplay if change has happened (repaint_require)
          handle_keys { |ch| @cw.clear; display_list }
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
      def display_list #:nodoc:
        # not sure where to put this, once for all or repeat 2010-02-17 23:07 RFED16
        @graphic = @window
        @start ||= 0
        @toprow ||= 0
        @left_margin ||= @row_selected_symbol.length

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
          h = @height - 2
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
                @graphic.printstring r+hh, c+@left_margin, content, acolor,'reverse'
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
        when KEY_UP
          previous_row
          #@start -= 1
          #@current_index -= 1
          #@current_index = 0 if @current_index < 0
          #@start = 0 if @start < 0
        when KEY_DOWN
          next_row
          #@start += 1
          #@current_index += 1
          #bounds_check
        when ?\C-b.getbyte(0)
          scroll_backward
          #@start -= @height-1
          #@start = 0 if @start < 0
        when 0
          @start = 0
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
      end
      def OLDbounds_check
        @start = 0 if @start < 0
        row_offset = 1
        last = (@list.length)-(@height-row_offset-1)
        if @start > last
          @start = last
        end
      end # bounds_check
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
          @cw.destroy  
        end
        return @current_index
      end
    end # class TextObject
  end # class CommandWindow
end # module
