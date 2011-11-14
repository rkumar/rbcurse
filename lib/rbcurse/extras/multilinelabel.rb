# ----------------------------------------------------------------------------- #
#         File: multilinelabel.rb
#  Description: Prints a label on the screen.
#               This is the original label that was present in rwidgets.rb
#               It allowed for multiple lines. I am simplifying that to a simple
#               single line label. 
#               I am basically moving multiline labels out of hte core package
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2011-11-12 - 12:04
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 2011-11-12 - 12:05
# ----------------------------------------------------------------------------- #
#
module RubyCurses
  
  # print static text on a form, allowing for text to be wrapped.
  #
  class MultiLineLabel < Widget
    dsl_accessor :mnemonic       # keyboard focus is passed to buddy based on this key (ALT mask)

    # justify required a display length, esp if center.
    dsl_property :justify        #:right, :left, :center
    dsl_property :display_length #please give this to ensure the we only print this much
    #dsl_property :height         #if you want a multiline label. already added to widget
    # for consistency with others 2011-11-5 
    alias :width :display_length
    alias :width= :display_length=

    def initialize form, config={}, &block
  
      # this crap was used in position_label, find another way. where is it used ?
      #@row = config.fetch("row",-1)  # why on earth this monstrosity ? 2011-11-5 
      #@col = config.fetch("col",-1) 
      #@bgcolor = config.fetch("bgcolor", $def_bg_color)
      #@color = config.fetch("color", $def_fg_color)
      @text = config.fetch("text", "NOTFOUND")
      @editable = false
      @focusable = false
      super
      @justify ||= :left
      @name ||= @text
      @repaint_required = true
    end
    #
    # get the value for the label
    def getvalue
      @text_variable && @text_variable.value || @text
    end
    def label_for field
      @label_for = field
      #$log.debug " label for: #{@label_for}"
      if @form
        bind_hotkey 
      else
        @when_form ||= []
        @when_form << lambda { bind_hotkey }
      end
    end

    ##
    # for a button, fire it when label invoked without changing focus
    # for other widgets, attempt to change focus to that field
    def bind_hotkey
      if !@mnemonic.nil?
        ch = @mnemonic.downcase()[0].ord   ##  1.9 DONE 
        # meta key 
        mch = ?\M-a.getbyte(0) + (ch - ?a.getbyte(0))  ## 1.9
        if @label_for.is_a? RubyCurses::Button and @label_for.respond_to? :fire
          @form.bind_key(mch, @label_for) { |_form, _butt| _butt.fire }
        else
          $log.debug " bind_hotkey label for: #{@label_for}"
          @form.bind_key(mch, @label_for) { |_form, _field| _field.focus }
        end
      end
    end

    ##
    # XXX need to move wrapping etc up and done once. 
    def repaint
      return unless @repaint_required
      raise "Label row or col nil #{@row} , #{@col}, #{@text} " if @row.nil? || @col.nil?
      r,c = rowcol

      @bgcolor ||= $def_bg_color
      @color   ||= $def_fg_color
      # value often nil so putting blank, but usually some application error
      value = getvalue_for_paint || ""
      lablist = []
      # trying out array values 2011-10-16 more for messageboxes.
      if value.is_a? Array
        lablist = text
        @height = text.size
      elsif @height && @height > 1
        lablist = wrap_text(value, @display_length).split("\n")
      else
        # ensure we do not exceed
        if !@display_length.nil?
          if value.length > @display_length
            value = value[0..@display_length-1]
          end
        end
        lablist << value
      end
      len = @display_length || value.length
      acolor = get_color $datacolor
      $log.debug "label :#{@text}, #{value}, r #{r}, c #{c} col= #{@color}, #{@bgcolor} acolor  #{acolor} j:#{@justify} dlL: #{@display_length} "
      firstrow = r
      _height = @height || 1
      str = @justify.to_sym == :right ? "%*s" : "%-*s"  # added 2008-12-22 19:05 
      # loop added for labels that are wrapped.
      # TODO clear separately since value can change in status like labels
    
      @graphic = @form.window if @graphic.nil? ## HACK messagebox givig this in repaint, 423 not working ??
      0.upto(_height-1) { |i| 
        @graphic.printstring r+i, c, " " * len , acolor,@attr
      }
      lablist.each_with_index do |_value, ix|
        break if ix >= _height
        if @justify.to_sym == :center
          padding = (@display_length - _value.length)/2
          _value = " "*padding + _value + " "*padding # so its cleared if we change it midway
        end
        @graphic.printstring r, c, str % [len, _value], acolor,@attr
        r += 1
      end
      if !@mnemonic.nil?
        ulindex = value.index(@mnemonic) || value.index(@mnemonic.swapcase)
        @graphic.mvchgat(y=firstrow, x=c+ulindex, max=1, Ncurses::A_BOLD|Ncurses::A_UNDERLINE, acolor, nil)
      end
      #@form.window.mvchgat(y=r, x=c, max=len, Ncurses::A_NORMAL, color, nil)
      @repaint_required = false
    end
    # Added 2011-10-22 to prevent some naive components from putting focus here.
    def on_enter
      raise "Cannot enter Label"
    end
    def on_leave
      raise "Cannot leave Label"
    end
  # ADD HERE LABEL
  end # class
end # module
