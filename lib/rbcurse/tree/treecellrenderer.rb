# 2010-09-18 15:35 
require 'rbcurse'
require 'rbcurse/rwidget'
module RubyCurses

  ## 
  # This is a basic list cell renderer that will render the to_s value of anything.
  # 
  # TODO upgrade as per new listcellrenderer
  class TreeCellRenderer
    PLUS_PLUS = "++"
    PLUS_MINUS = "+-"
    PLUS_Q     = "+?"
    include RubyCurses::ConfigSetup
    include RubyCurses::Utils
    dsl_accessor :justify     # :right, :left, :center  # added 2008-12-22 19:02 
    dsl_accessor :display_length     #  please give this to ensure the we only print this much
    dsl_accessor :height    # if you want a multiline label.
    dsl_accessor :text    # text of label
    dsl_accessor :color, :bgcolor
    dsl_accessor :row, :col
    dsl_accessor :parent    #usuall the table to get colors and other default info
    attr_reader :actual_length
    attr_accessor :pcol

    def initialize text="", config={}, &block
      @text = text
      @editable = false
      @focusable = false
      @actual_length = 0
      config_setup config # @config.each_pair { |k,v| variable_set(k,v) }
      instance_eval &block if block_given?
      init_vars
    end
    def init_vars
      @justify ||= :left
      @display_length ||= 10
    end
    def getvalue
      @text
    end
    ##
    # sets @color_pair and @attr
    def prepare_default_colors focussed, selected
        @color_pair = get_color $datacolor
        @attr = @row_attr || Ncurses::A_NORMAL


        ## determine bg and fg and attr
        if selected
          #@attr = Ncurses::A_BOLD if selected
          ## 2010-09-18 18:32 making selected row reverse
          @attr |= Ncurses::A_REVERSE

          # 2010-09-18 18:33 maybe not required, just confuses the whole thing and uglifies it
          #@color_pair =get_color $selectedcolor, @parent.selected_color, @parent.selected_bgcolor unless @parent.nil?
        end
        case focussed
        when :SOFT_FOCUS
          @attr |= Ncurses::A_BOLD
        when true
          # earlier focussed row showed up in reverse, which was confusing since it looked selected
          # now focussed row has cursor on side, and can be bold. that's enough.
          @attr |= Ncurses::A_BOLD
          #@attr |= Ncurses::A_REVERSE
        when false
        end
    end

    ##
    #  paint a list box cell
    #  2010-09-02 15:38 changed focussed to take true, false and :SOFT_FOCUS
    #  SOFT_FOCUS means the form focus is no longer on this field, but this row
    #  was focussed when use was last on this field. This row will take focus
    #  when field is focussed again
    #
    #  @param [Buffer] window or buffer object used for printing
    #  @param [Fixnum] row
    #  @param [Fixnum] column
    #  @param [Fixnum] actual index into data, some lists may have actual data elsewhere and
    #                  display data separate. e.g. rfe_renderer (directory listing)
    #  @param [String] text to print in cell
    #  @param [Boolean, :SOFT_FOCUS] cell focussed, not focussed, cell focussed but field is not focussed
    #  @param [Boolean] cell selected or not
    #renderer.repaint @graphic, r+hh, c+@left_margin, crow, object, content, focus_type, selected, expanded, leaf
    def repaint graphic, r=@row,c=@col, row_index=-1, treearraynode=nil, value=@text, leaf=nil, focussed=false, selected=false, expanded=false
        #$log.debug "label :#{@text}, #{value}, #{r}, #{c} col= #{@color}, #{@bgcolor} acolor= #{acolor} j:#{@justify} dlL: #{@display_length} "

      prepare_default_colors focussed, selected

        value=value.to_s # ??
        #icon = object.is_leaf? ? "-" : "+"
        #icon = leaf ? "-" : "+"

        #level = treearraynode.level
        #node = treearraynode.node
        level = treearraynode.level
        node = treearraynode
        if parent.node_expanded? node
          icon = PLUS_MINUS  # can collapse
        else
          icon = PLUS_PLUS   # can expand
        end
        if node.children.size == 0
          icon = PLUS_Q # either no children or not visited yet
          if parent.has_been_expanded node
            icon = PLUS_MINUS # definitely no children, we've visited
          end
        end
        # adding 2 to level, that's the size of icon
        # XXX FIXME if we put the icon here, then when we scroll right, the icon will show, it shoud not
        # FIXME we ignore truncation etc on previous level and take the object as is !!!
        _value =  "%*s %s" % [ level+2, icon,  node.user_object ]
        @actual_length = _value.length
        pcol = @pcol
        if pcol > 0
          _len = @display_length || @parent.width-2
          _value = _value[@pcol..@pcol+_len-1] 
        end
        _value ||= ""
        if @height && @height > 1
        else
          # ensure we do not exceed
          if !@display_length.nil?
            if _value.length > @display_length
              @actual_length = _value.length
              _value = _value[0..@display_length-1]
            end
          end
          #lablist << value
        end
        len = @display_length || _value.length
        graphic.printstring r, c, "%-*s" % [len, _value], @color_pair,@attr
        #_height = @height || 1
        #0.upto(_height-1) { |i| 
          #graphic.printstring r+i, c, ( " " * len) , @color_pair,@attr
        #}
        #lablist.each_with_index do |_value, ix|
          #break if ix >= _height
          #if @justify.to_sym == :center
            #padding = (@display_length - _value.length)/2
            #_value = " "*padding + _value + " "*padding # so its cleared if we change it midway
          #end
          #graphic.printstring r, c, str % [len, _value], @color_pair,@attr
          #r += 1
        #end
    end
  # ADD HERE 
  end
end
