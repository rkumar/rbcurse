=begin
  * Name: InputDataEvent
  * Description: Event created when data modified in Field or TextEdit
  * Author: rkumar (arunachalesha)
  
  --------
  * Date:  2008-12-24 17:27 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

NOTE: this is how we used to write code in the Java days. Anyone reading this source,
this is NOT how to code in rubyland. Please see this link, for how to code such as class:
http://blog.grayproductions.net/articles/all_about_struct

=end

# Event created when data modified in Field or TextEdit
#  2008-12-24 17:54 
module RubyCurses
  class InputDataEvent
    attr_accessor :index0, :index1, :source, :type, :row, :text
    def initialize index0, index1, source, type, row, text
      @index0 = index0
      @index1 = index1
      @source = source
      @type = type
      @row = row
      @text = text
    end
    # until now to_s was returning inspect, but to make it easy for users let us return the value
    # they most expect which is the text that was changed
    def to_s
      inspect
    end
    def inspect
      ## now that textarea.to_s prints content we shouldn pass it here.
      #"#{@type.to_s}, #{@source}, ind0:#{@index0}, ind1:#{@index1}, row:#{@row}, text:#{@text}"
      "#{@type.to_s}, ind0:#{@index0}, ind1:#{@index1}, row:#{@row}, text:#{@text}"
    end
    # this is so that earlier applications were getting source in the block, not an event. they 
    # were doing a fld.getvalue, so we must keep those apps running
    # @since 1.2.0  added 2010-09-11 12:25 
    def getvalue
      @source.getvalue
    end
  end
end
