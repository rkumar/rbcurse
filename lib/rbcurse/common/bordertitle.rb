# I am moving the common title and border printing stuff into 
# a separate module.
module BorderTitle
    dsl_accessor :suppress_borders            #to_print_borders
    dsl_accessor :border_attrib, :border_color
    dsl_accessor :title                       #set this on top
    dsl_accessor :title_attrib                #bold, reverse, normal
    dsl_accessor :border_attrib, :border_color # 

    def bordertitle_init
      @row_offset = @col_offset = 0 if @suppress_borders 
      @internal_width = 1 if @suppress_borders
    end
    # why the dash does it reduce height by one.
    def print_borders
      raise ArgumentError, "Graphic not set" unless @graphic
      width = @width
      height = @height-1
      window = @graphic
      startcol = @col 
      startrow = @row 
      @color_pair = get_color($datacolor)
      bordercolor = @border_color || @color_pair
      borderatt = @border_attrib || Ncurses::A_NORMAL
      window.print_border startrow, startcol, height, width, bordercolor, borderatt
      print_title
    end
    def print_title
      return unless @title
      raise "#{self} needs width" unless @width
      @color_pair ||= get_color($datacolor) # should we not use this ??? XXX 
      #$log.debug " print_title #{@row}, #{@col}, #{@width}  "
      # check title.length and truncate if exceeds width
      _title = @title
      if @title.length > @width - 2
        _title = @title[0..@width-2]
      end
      @graphic.printstring( @row, @col+(@width-_title.length)/2, _title, @color_pair, @title_attrib) unless @title.nil?
    end

end
