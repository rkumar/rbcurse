#require 'ncurses'
require 'logger'
require 'rbcurse'

#include Ncurses # FFI 2011-09-8 
include RubyCurses
module RubyCurses
  extend self
  ##
  # TODO user may want to print a label on progress: like not started or complete.
  class Progress < Widget
    dsl_property :width     #  please give this to ensure the we only print this much
    dsl_property :fraction  #  how much to cover
    dsl_property :char      #  what char to use for filling, default space
    dsl_property :text      #  text to put over bar
    dsl_accessor :style     # :old or nil/anything else
    dsl_accessor :surround_chars     # "[]"

    def initialize form, config={}, &block

      @row = config.fetch("row",-1) 
      @col = config.fetch("col",-1) 
      @bgcolor = config.fetch("bgcolor", $def_bg_color)
      @color = config.fetch("color", $def_fg_color)
      @name = config.fetch("name", "pbar")
      @editable = false
      @focusable = false
      super
      @surround_chars ||= "[]" # for :old style
      @repaint_required = true
    end
    def getvalue
      @fraction || 0.0
    end

    ##
    # 
    def repaint
      return unless @repaint_required
      $log.debug " XXXX PBAR inside repaint #{@color} , #{@fraction} "
      r,c = rowcol
      #value = getvalue_for_paint
      acolor = get_color @bgcolor
      bcolor = get_color @color
      @graphic = @form.window if @graphic.nil? ## HACK messagebox givig this in repaint, 423 not working ??
      len = 0
      w2 = @width - 6 #2 account for brackets and printing of percentage
      if @fraction
        @fraction = 1.0 if @fraction > 1.0
        @fraction = 0 if @fraction < 0
        if @fraction > 0
          len = @fraction * @width
        end
      end
      if @style == :old
        ftext=""
        char = @char || "="
        if @fraction && @fraction >= 0
          len = @fraction * (w2) 
          ftext << sprintf("%3d%s",(@fraction * 100).to_i, "%")
        end
        incomplete = w2 - len
        complete = len
        # I am printing 2 times since sometimes the ending bracket gets printed one position less
        str = @surround_chars[0] + " "*w2 + @surround_chars[1] + ftext
        @graphic.printstring r, c, str , acolor,@attr
        str = char*complete 
        str[-1] = ">" if char == "=" && complete > 2
        @graphic.printstring r, c+1, str , acolor,@attr
      else

        char = @char || " "
        # first print the background horizonal bar
        @graphic.printstring r, c, " " * @width , acolor,@attr

        # if the user has passed a percentage we need to print that in @color
        if @fraction
          #bcolor = get_color @color
          #@fraction = 1.0 if @fraction > 1.0
          #@fraction = 0 if @fraction < 0
          #if @fraction > 0
          #len = @fraction * @width
          #char = @char || " "

          # if text is to printed over the bar
          if @text
            textcolor = get_color $datacolor, 'black'
            txt = @text
            txt = @text[0..@width] if @text.length > @width
            textattr = 'bold'
            # write the text in a color that contrasts with the background
            # typically black
            @graphic.printstring r, c, txt , textcolor, textattr if @text

            # now write the text again, in a color that contrasts with the progress
            # bar color that is expanding. However, the text must be padded to len and truncated 
            # to len as well. it must be exactly len in size.
            txt = sprintf("%-*s", len, txt)
            if len > 0
              if len < txt.length
                txt = txt[0..len]
              end
              textcolor = get_color $datacolor, 'white', @color
              @graphic.printstring r, c, txt , textcolor, textattr if @text
            end
          else
            # no text was given just print a horizontal bar
            @graphic.printstring r, c, char * len , bcolor, 'reverse'
          end
        end # frac > 0
      end # fraction
    end # style
    @repaint_required = false
  end
  def repaint_old
  end
  # ADD HERE progress
end
