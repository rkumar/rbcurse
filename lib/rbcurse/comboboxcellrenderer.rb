module RubyCurses

  ## 
  # This is a list cell renderer that will render combo boxes.
  # Since a combo box extends a field therefore the repaint of field is used.
  # In other words there is nothing much to do here.
  # 
  class ComboBoxCellRenderer < ListCellRenderer
    include ConfigSetup
    include RubyCurses::Utils

    def initialize text="", config={}, &block
      @text = text
      @editable = false
      @focusable = false
      config_setup config # @config.each_pair { |k,v| variable_set(k,v) }
      instance_eval &block if block_given?
      init_vars
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
