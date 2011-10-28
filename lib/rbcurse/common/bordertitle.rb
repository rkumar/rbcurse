# I am moving the common title and border printing stuff into 
# a separate module.
module BorderTitle
    dsl_accessor :suppress_borders            #to_print_borders
    dsl_accessor :border_attrib, :border_color
    dsl_accessor :title                       #set this on top
    dsl_accessor :title_attrib                #bold, reverse, normal
    def init
      @row_offset = @col_offset = 0 if @suppress_borders 
      @internal_width = 1 if @suppress_borders
    end
    def print_borders
      width = @width
      height = @height-1 # 2010-01-04 15:30 BUFFERED HEIGHT
      window = @graphic  # 2010-01-04 12:37 BUFFERED
      startcol = @col 
      startrow = @row 
      @color_pair = get_color($datacolor)
      #$log.debug "rlistb #{name}: window.print_border #{startrow}, #{startcol} , h:#{height}, w:#{width} , @color_pair, @attr "
      window.print_border startrow, startcol, height, width, @color_pair, @attr
      print_title
    end
    def print_title
      $log.debug "RCONTAINER PRINTING TITLE at #{row} #{col} "
      @graphic.printstring( @row, @col+(@width-@title.length)/2, @title, @color_pair, @title_attrib) unless @title.nil?
    end

end
