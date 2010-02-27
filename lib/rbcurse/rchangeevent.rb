=begin
  * Name: ChangeEvent
  * Description: Event used to notify interested parties that state of component has changed
  * Author: rkumar (arunachalesha)
  
  --------
  * Date: 2010-02-26 11:32 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
#require 'rubygems'

# Event created when state changed (as in ViewPort)
module RubyCurses
  class ChangeEvent
    attr_accessor :source
    def initialize source
      @source = source
    end
    def to_s
      inspect
    end
    def inspect
      "ChangeEvent #{@source}"
    end
  end
end
