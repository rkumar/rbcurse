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
# Tested with Field, combo and checkbox
# TODO test and integrate with tables.
#
module RubyCurses
  class CellEditor
    include ConfigSetup
    include RubyCurses::Utils
    #dsl_accessor :justify     # :right, :left, :center  # added 2008-12-22 19:02 
    #dsl_accessor :display_length     #  please give this to ensure the we only print this much
    #dsl_accessor :height    # if you want a multiline label.
    #dsl_accessor :text    # text of label
    #dsl_accessor :color, :bgcolor
    #dsl_accessor :row, :col
    #dsl_accessor :parent    #usuall the table to get colors and other default info

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
    def field_getvalue
      @component.getvalue
    end
    def checkbox_getvalue
      @component.getvalue
    end
    def combobox_getvalue
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
        #$log.debug " EDITOR COMBO Gets #{value}"
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
    def prepare_editor parent, row, col,  value
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
      #$log.debug " prepare editor value #{widget.display_length} displlen"
      #widget.display_length = widget.display_length -1
      widget.attr = Ncurses::A_REVERSE
      #$log.debug " prepare editor value #{value} : fr:#{row}, fc:#{col}"
    end
  end # class
end # module
