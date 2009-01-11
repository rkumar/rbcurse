require 'rubygems'
require 'ncurses'
require 'logger'
#require 'lib/rbcurse/rwidget'
module RubyCurses

  ## 
  # This is a list cell renderer that will render combo boxes.
  # Since a combo box extends a field therefore the repaint of field is used.
  # In other words there is nothing much to do here.
  # 
  class ComboBoxCellRenderer < ListCellRenderer
    include ConfigSetup
    include RubyCurses::Utils
    dsl_accessor :justify     # :right, :left, :center  # added 2008-12-22 19:02 
    dsl_accessor :display_length     #  please give this to ensure the we only print this much
    dsl_accessor :height    # if you want a multiline label.
    dsl_accessor :text    # text of label
    dsl_accessor :color, :bgcolor
    dsl_accessor :row, :col
    dsl_accessor :parent    #usuall the table to get colors and other default info

    def initialize text="", config={}, &block
      @text = text
      @editable = false
      @focusable = false
      config_setup config # @config.each_pair { |k,v| variable_set(k,v) }
      instance_eval &block if block_given?
      init_vars
    end
    def init_vars
      @justify ||= :left
      @display_length ||= 10
    end
    ## me thinks this is unused
    def getvalue
      raise "I think this is unused. comboboxcellrenderer line 36"
      @text
    end

    ##
    # 
  # ADD HERE 
  end
end
