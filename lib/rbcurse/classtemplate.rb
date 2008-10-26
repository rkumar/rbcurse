=begin
  * Name: rkumar
  * $Id$
  * Description   
  * Author:
  * Date:
  * License:
    This is free software; you can copy and distribute and modify
    this program under the term of Ruby's License
    (http://www.ruby-lang.org/LINCENSE.txt)

=end

# Module/class description comes here
#
#
# Arunachalesha 
# @version 
#
require 'rubygems'
require 'ncurses'
require 'application'

include Ncurses
include Ncurses::Form

class TableApplication < Application
  attr_reader :text
  attr_accessor :value
  def initialize
    super()
    @app_quit = false
  end


  ### ADD HERE ###
end # class
