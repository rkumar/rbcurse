require 'lib/rbcurse/rwidget'
include Ncurses
include RubyCurses
module RubyCurses
  class Action < Proc
    include EventHandler
    include ConfigSetup
    # name used on button or menu
    dsl_property :name
    dsl_property :enabled
    dsl_accessor :tooltip_text
    dsl_accessor :help_text
    dsl_accessor :mnemonic

    def initialize name, config={}, &block
      super &block
      @name = name
      @enabled = true
      config_setup config # @config.each_pair { |k,v| variable_set(k,v) }
    end
  end # class
end # module

