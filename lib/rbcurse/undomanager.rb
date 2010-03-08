=begin
  * Name: UndoManager
  * Description: Manages undo of text components
  * Author: rkumar (arunachalesha)

ISSUES 

  We need a mapping of what method to call for undo and redo events such as 
putc or delete_at. 
Currently, i am directly manipulating the structure, since row is also included here,
whereas putc etc already use current_index.
  
  --------
  * Date:  2010-03-07 19:42 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end

# 
#  
module RubyCurses
  class UndoManager
    attr_accessor :index0, :index1, :source, :type, :row, :text
    def initialize index0, index1, source, type, row, text
      @index0 = index0
      @index1 = index1
      @source = source
      @type = type
      @row = row
      @text = text
    end
    def to_s
      inspect
    end
    def inspect
      ## now that textarea.to_s prints content we shouldn pass it here.
      #"#{@type.to_s}, #{@source}, ind0:#{@index0}, ind1:#{@index1}, row:#{@row}, text:#{@text}"
      "#{@type.to_s}, ind0:#{@index0}, ind1:#{@index1}, row:#{@row}, text:#{@text}"
    end
  end
  class SimpleUndo
    #attr_accessor :index0, :index1, :source, :type, :row, :text
    #attr_reader :source
    def initialize _source
      #source=(_source) #if _source
      source(_source) #if _source
      @pointer = 0
      @actions = []
      $log.debug " INSIDE UNDO CONSTR "
    end
    def source(_source)
      $log.debug " calling source= "
      raise "Cannot pass a nil source" unless _source
      @source = _source
      @source.bind(:CHANGE){|eve| handle(eve) }
      @source.undo_handler(self)
      $log.debug " I am listening to change events on #{@source.name} "
    end
    def handle event
      $log.debug " UNDO GOT #{event}: #{event.type}, (#{event.text}), rej: #{@reject_update}  "
      return if @reject_update
      if @pointer < @actions.length
        $log.debug " removing some actions since #{@pointer} < #{@actions.length} "
        @actions.slice!(@pointer..-1)
        $log.debug " removed actions since #{@pointer} , #{@actions.length} "
      end
      @actions << event
      @pointer = @actions.length
    end
    # this has to be bound in source
    def undo
      $log.debug " got UNDO call #{@pointer} "
      return if @pointer == 0
      @reject_update = true
      @pointer -=1 #if @pointer > 0
      act = @actions[@pointer]
      $log.debug " processing #{act} "
      case act.type
      when :INSERT
        row = act.row
        col = act.index0
        howmany = act.index1 - col
        @source.list[row].slice!(col,howmany)
        @source.repaint_required true
      when :DELETE
        # this works fine for single chars but not for a C-k - perhaps Ck moves cursor back, and may delete CR etc
        # i think a CR or newline is coming in here and gets printed as screen border is erased on left
        row = act.row
        col = act.index0
        $log.debug " UNDO processing DELETE #{col}, (#{act.text})  "
        if act.index0 == 0 and act.index1 == 0
          @source.list.insert(row, "") # insert a blank line, since one was deleted
        else
          @source.list[row].insert(col, act.text.chomp)
        end
        @source.repaint_required true
      end
      @reject_update = false
    end
    # this has to be bound in source
    def redo
      $log.debug "UNDO GOT REDO call #{@pointer}, #{@actions.size}  "
      return if @pointer >= @actions.size
      @reject_update = true
      act = @actions[@pointer]
      $log.debug " REDO processing #{act} "
      case act.type
      when :INSERT
        row = act.row
        col = act.index0
        @source.list[row].insert(col, act.text)
        @source.repaint_required true
      when :DELETE
        row = act.row
        col = act.index0
        howmany = act.index1 - col
        if howmany == 0
          @source.list.delete_at row
        else
          @source.list[row].slice!(col,howmany)
        end
        @source.repaint_required true
      end
      @pointer +=1 #if @pointer > 0
      @reject_update = false
    end
    def to_s
      inspect
    end
    def inspect
      ## now that textarea.to_s prints content we shouldn pass it here.
      #"#{@type.to_s}, #{@source}, ind0:#{@index0}, ind1:#{@index1}, row:#{@row}, text:#{@text}"
      "#{@type.to_s}, ind0:#{@index0}, ind1:#{@index1}, row:#{@row}, text:#{@text}"
    end
  end
end # module
