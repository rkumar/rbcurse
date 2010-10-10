# Allow some objects to take focus when a certain key is pressed.
# This is for objects like scrollbars and grabbars. We don't want these always
# getting focus, only sometimes when we want to resize panes.
# This will not only be included by Form but by containers such as Vimsplit
# or MasterDetail.
# Usage: the idea is that when you create grabbars, you would add them to the FocusManager
# Thus they would remain non-focusable on creation. When hte user presses (say F3) then
# make_focusable is called, or toggle_focusable. Now user can press TAB and access
# these bars. When he is done he can toggle again.
# TODO: we might add a Circular class here so user can traverse only these objects
module RubyCurses
  module FocusManager
    extend self
    attr_reader :focusables
    # add a component to this list so it can be made focusable later
    def add component
      @focusables ||= []
      @focusables << component
      self
    end
    def make_focusable bool=true
      @focusing = bool
      @focusables.each { |e| e.focusable(bool) }
    end
    def toggle_focusable
      return unless @focusables
      alert "FocusManager Making #{@focusables.length} objects #{!@focusing} "
      make_focusable !@focusing
    end
  end
end
