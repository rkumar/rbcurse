require 'rubygems'
require 'ncurses'
require 'logger'
#require 'lib/rbcurse/rwidget'


##
# This file gives us a mean of using a component as an editor in a list or later table.
# The component is created once and used with each row.
# It does not really have a form associated with it, although we do set a form
# so it can display itself. Otherwise it is not added to the forms widget list, so the 
# form has no idea tha this widget exists.
#
# Tested with Field, combo and checkbox, tables.
#
module RubyCurses
  class CellEditor
    include ConfigSetup
    include RubyCurses::Utils

    def initialize component, config={}, &block
      @component = component
      s = @component.class.to_s.downcase()
      s.slice!("rubycurses::")
      @_class = s.to_sym
      #$log.debug " CELL EIDOTR got #{@_class}"
      config_setup config # @config.each_pair { |k,v| variable_set(k,v) }
      instance_eval &block if block_given?
    end
    def getvalue
      case @_class
      when :field
        return field_getvalue
      when :checkbox
        return checkbox_getvalue
      when :combobox
        return combobox_getvalue
      else
        raise "Unknown class #{@_class} in CellEditor getv"
      end
    end
    # maybe this should check valid (on_leave) and throw exception
    def field_getvalue
      #@component.on_leave # throws exception! Added 2009-01-17 00:47 
      @component.init_vars # 2009-01-18 01:13 should not carry over to next row curpos and pcol
      return @component.getvalue
    end
    def checkbox_getvalue
      @component.getvalue
    end
    def combobox_getvalue
      #@component.on_leave # added 2009-01-19 12:12 
      @component.getvalue
      #@component.selected_item
    end
    def setvalue value
      case @_class
      when :field
        @component.set_buffer value
      when :checkbox
        @component.checked value
      when :combobox
        @component.set_buffer value
        #index = @component.list.index value
        #@component.current_index = index
      else
        raise "Unknown class #{@_class} in CellEditor setv"
      end
    end
    def component
      @component
    end
    # should be called from on_leave_cell of table, but is beng called from editing_stopped FIXME
    def on_leave row, col
      f = @component
      f.on_leave
      if f.respond_to? :editable and f.modified?
        $log.debug " Table about to fire CHANGED for #{f} "
        f.fire_handler(:CHANGED, f) 
      end
    end
    def prepare_editor parent, row, col,  value
      #value = value.dup if value.respond_to? :dup
      value = value.dup rescue value
      setvalue value #.dup
      widget = component()
      widget.row = row
      widget.col = col
      # unfortunately 2009-01-11 19:47 combo boxes editable allows changing value
      # FIXME so combo's can be editable, but no new value added
      if @_class == :combobox
        widget.editable = false if widget.respond_to? :editable  # chb's don't ???
      else
        widget.editable = true if widget.respond_to? :editable  # chb's don't ???
      end
      widget.focusable = true
      widget.visible = true
      widget.form = parent.form
      #$log.debug " prepare editor value #{widget.display_length} displlen #{widget.maxlen}"
      $log.debug " prepare editor form: #{widget.form} "
      #widget.display_length = widget.display_length -1
      widget.bgcolor = 'yellow'
      widget.color = 'black'
      widget.on_enter
      #widget.attr = Ncurses::A_REVERSE | Ncurses::A_BOLD
      #$log.debug " prepare editor value #{value} : fr:#{row}, fc:#{col}"
    end
    #This may not really be necessary since we paint the cell editor only if editing is on
    def cancel_editor
      widget = component()
      # NOOO THIS IS CALLED BY CANCEL AND STOP
      # somehow we need to ensure that if on_leave fails you can't get out. Here its a bit late
      # i think FIXME TODO
      #widget.on_leave # call so any triggers or validations can fire
      widget.focusable = false
      widget.visible = false
      widget.attr = Ncurses::A_REVERSE 
    end
  end # class
end # module
