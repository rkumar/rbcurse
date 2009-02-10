require 'rbcurse/rwidget'
include Ncurses
include RubyCurses
module RubyCurses
  ## encapsulates behaviour allowing centralization
  class Action < Proc
    include EventHandler
    include ConfigSetup
    # name used on button or menu
    dsl_property :name
    dsl_property :enabled
    dsl_accessor :tooltip_text
    dsl_accessor :help_text
    dsl_accessor :mnemonic
    dsl_accessor :accelerator

    def initialize name, config={}, &block
      super &block
      @name = name
      @name.freeze
      @enabled = true
      config_setup config # @config.each_pair { |k,v| variable_set(k,v) }
    end
    def call
      return unless @enabled
      fire_handler :FIRE, self
      super
    end
  end # class
end # module

