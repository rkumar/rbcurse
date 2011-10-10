require 'rbcurse/rwidget'
#include Ncurses # FFI 2011-09-8 
include RubyCurses
module RubyCurses
  ## encapsulates behaviour allowing centralization
  # == Example
  #    a = Action.new("&New Row") { commands }
  #    a.accelerator "Alt N"
  #    menu.add(a)
  #    b = Button.new form do
  #      action a
  #      ...
  #    end
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
      @_events = [:FIRE]
    end
    def call
      return unless @enabled
      fire_handler :FIRE, self
      super
    end
  end # class
end # module

