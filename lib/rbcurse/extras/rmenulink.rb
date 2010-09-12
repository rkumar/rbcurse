require 'rbcurse/extras/rlink'
##
module RubyCurses
  class MenuLink < Link
    dsl_property :description

    def initialize form, config={}, &block
      super
      @col_offset = -1 * @col
      @row_offset = -1 * @row
    end
    # added for some standardization 2010-09-07 20:28 
    # alias :text :getvalue # NEXT VERSION
    # change existing text to label

    def getvalue_for_paint
      "%s      %-12s   -    %-s" % [ @mnemonic , getvalue(), @description ]
    end
    ##
  end # class
end # module
