=begin
  * Name: UndoManager
  * Description: Manages undo of text components
  * Author: rkumar (arunachalesha)

ISSUES 

This is a very simple, undo facility. This could change in the near future.

Todo:
We need to handle block updates - several undo ops to be done together.

  
  --------
  * Date:  2010-03-07 19:42 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end

# 
#  
module RubyCurses
  #
  # AbstractUndo has the basic workings of the undo redo facility.
  # It leaves the actual undo and redo to the implementing source object. However,
  # it does the work of storing edits, and passing the correct edit to the implementor
  # when the source object calls for an undo or redo operation. It thus manages the edit (undo) queue.
  #
  class AbstractUndo
    # initialize the source object which will issue undo requests
    def initialize _source
      source(_source) #if _source
      @pointer = 0
      @actions = []
      $log.debug " INSIDE UNDO CONSTR "
    end
    def source(_source)
      $log.debug " calling source= "
      raise "Cannot pass a nil source" unless _source
      @source = _source
      # currently this is very hardcode again. we need to see this in the light of other objects
      #@source.bind(:CHANGE){|eve| add_edit(eve) }
      # a little roundabout but done for getting things up fast
      @source.undo_handler(self)
      $log.debug " I am listening to change events on #{@source.name} "
    end
    # this is called whenever an undoable edit has happened.
    # Currently, it is linked above in the bind statement. We've attached this 
    # method as a listener to the source.
    def add_edit event
      # this debug is very specific. it should be removed later. We do not know about the object
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
    # this has to be bound in source component
    # typically bind C-_ to undo()
    # this method figures out the correct undo object to be sent
    # to the implementor
    def undo
      $log.debug " got UNDO call #{@pointer}, sz:#{@actions.size}  "
      return if @pointer == 0
      @reject_update = true
      @pointer -=1 #if @pointer > 0
      @source.repaint_required true
      @reject_update = false
      edit = @actions[@pointer]
      perform_undo edit
    end
    # this has to be bound in source
    # typically bind C-r to redo()
    # this method figures out the correct redo object to be sent
    # to the implementor
    def redo
      $log.debug "UNDO GOT REDO call #{@pointer}, #{@actions.size}  "
      return if @pointer >= @actions.size
      @reject_update = true
      edit = @actions[@pointer]
      perform_redo edit
      @source.repaint_required true
      @pointer +=1 #if @pointer > 0
      @reject_update = false
    end
    def perform_redo edit
      raise "You must implement this for your undoable component "
    end
    def perform_undo edit
      raise "You must implement this for your undoable component "
      # to be implemented
    end
    #def to_s
      #inspect
    #end
    #def inspect
      ### now that textarea.to_s prints content we shouldn pass it here.
      ##"#{@type.to_s}, #{@source}, ind0:#{@index0}, ind1:#{@index1}, row:#{@row}, text:#{@text}"
      #"#{@type.to_s}, ind0:#{@index0}, ind1:#{@index1}, row:#{@row}, text:#{@text}"
    #end
  end
    ## An implementation of AbstractUndo for textarea.
    # Very basic.
  class SimpleUndo < AbstractUndo
    def initialize _source
      super
    end
    def source(_source)
      super
      _source.bind(:CHANGE){|eve| add_edit(eve) }
    end
    def perform_undo act
      row = act.row
      col = act.index0
      $log.debug " processing #{act} "
      case act.type
      when :INSERT
        howmany = act.index1 - col
        @source.list[row].slice!(col,howmany)
      when :DELETE
        $log.debug " UNDO processing DELETE #{col}, (#{act.text})  "
        @source.list[row].insert(col, act.text.chomp)
      when :DELETE_LINE
        $log.debug " UNDO inside delete-line #{row} "
        #@source.list.insert(row, act.text) # insert a blank line, since one was deleted
        case act.text
        when Array
          index = row
          act.text.each_with_index{|r,i| @source.list.insert index+i, r}
        when String
          @source.list.insert row, act.text
        end
      when :INSERT_LINE
        $log.debug " UNDO inside insert-line #{row} "
        case act.text
        when Array
          act.text.size.times { @source.list.delete_at row }
        when String
          @source.list.delete_at row
        end
      else
        $log.warn "unhandled change type #{act.type} "
      end
      @source.repaint_required true
      @reject_update = false
    end
    # this has to be bound in source
    def perform_redo act
      row = act.row
      col = act.index0
      $log.debug " REDO processing #{act} "
      case act.type
      when :INSERT
        @source.list[row].insert(col, act.text)
      when :DELETE
        row = act.row
        col = act.index0
        howmany = act.index1 - col
        @source.list[row].slice!(col,howmany)
      when :DELETE_LINE
        #$log.debug " UNDO redo got deleteline #{row} "
        @source.list.delete_at row
      when :INSERT_LINE
        case act.text
        when Array
          index = row
          act.text.each_with_index{|r,i| @source.list.insert index+i, r}
        when String
          @source.list.insert row, act.text
        end
      else
        $log.warn "unhandled change type #{act.type} "
      end
    end
  end
end # module
