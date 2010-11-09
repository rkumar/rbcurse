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
    dsl_accessor :layout
    dsl_accessor :box
    dsl_accessor :title
    attr_reader :config
    attr_reader :window     # required for keyboard or printing
    dsl_accessor :height, :width, :top, :left  #  2009-01-06 00:05 after removing meth missing

    def initialize form=nil, aconfig={}, &block
      #@form = form
      @config = aconfig
      @config.each_pair { |k,v| instance_variable_set("@#{k}",v) }
      instance_eval &block if block_given?
      if @layout.nil? 
          layout(1,80, 27, 0) 
      end
      @height = @layout[:height]
      @width = @layout[:width]
      @window = VER::Window.new(@layout)
      require 'forwardable'
      require 'rbcurse/extras/bottomline'
      @bottomline = Bottomline.new @window, 0
      extend Forwardable
      def_delegators :@bottomline, :ask, :say, :agree, :choose
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
          end
        end
      ensure
        destroy  
      end
      return @selected_index
    end
    def press ch
      ch = ch.getbyte(0) if ch.class==String ## 1.9
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
        end
        #@form.repaint
        Ncurses::Panel.update_panels();
        Ncurses.doupdate();
        @window.wrefresh
    end
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
      @height = height
      @width = width
    end
    def destroy
      #$log.debug "DESTROY : rcommandwindow"
      panel = @window.panel
      Ncurses::Panel.del_panel(panel) if !panel.nil?   
      @window.delwin if !@window.nil?
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
  end
end
