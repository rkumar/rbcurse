require 'rbcurse/listcellrenderer'
module RubyCurses

  ## 
  # This is a basic list cell renderer that will render the to_s value of anything.
  # Using alignment one can use for numbers too.
  # However, for booleans it will print true and false. If editing, you may want checkboxes
  class CheckBoxCellRenderer < ListCellRenderer
    dsl_accessor :value    # text of label
    dsl_accessor :surround_chars

    def initialize boolean=nil, config={}, &block
      @value = boolean
      @text = "" # what if someone wants to show a label later. ??? XXX
      @editable = false
      @focusable = false
      config_setup config # @config.each_pair { |k,v| variable_set(k,v) }
      instance_eval &block if block_given?
      init_vars
    end
    def init_vars
      @justify ||= :left
      @display_length ||= 5
      @surround_chars = ['[',']']
    end
    def getvalue
      @value
    end

    ##
    # 
    def repaint graphic, r=@row,c=@col, row_index=-1,value=@value, focussed=false, selected=false
        #$log.debug "label :#{@text}, #{value}, #{r}, #{c} col= #{@color}, #{@bgcolor} acolor= #{acolor} j:#{@justify} dlL: #{@display_length} "

      prepare_default_colors focussed, selected

      buttontext = value ? "X" : " "
      # HOW TO DO THE TEXT ??? XXX
      # the space in dtext next line is a cheat, to clear off the space that the
      # editor is leaving.
      dtext = " " #@display_length.nil? ? @text : "%-*s" % [@display_length, @text]
      if @align_right
        #@text_offset = 0
        #@col_offset = dtext.length + @surround_chars[0].length + 1
        str = "#{dtext} " + @surround_chars[0] + buttontext + @surround_chars[1] 
      else
        pretext = @surround_chars[0] + buttontext + @surround_chars[1] 
        #@text_offset = pretext.length + 1
        #@col_offset = @surround_chars[0].length
        #@surround_chars[0] + buttontext + @surround_chars[1] + " #{@text}"
        str = pretext + " #{dtext}"
      end
      graphic.printstring r, c, str, @color_pair,@attr
    end
  # ADD HERE 
  end
end
