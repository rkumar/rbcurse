=begin
  * Name: dialogs
  * Description: 
  * Author: rkumar
  
  --------
  * Date:  2008-12-30 12:22 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

TODO:
    Add one get_string(message, len, regex ...)
    Add select_one (message, values, default)
=end
require 'rubygems'
require 'ncurses'
require 'logger'
require 'lib/ver/ncurses'
require 'lib/ver/window'
require 'lib/rbcurse/rwidget'

##
# pops up a modal box with a message and an OK button.
# No return value.
# Usage:
# alert("You did not enter anything!")
# alert("You did not enter anything!", "title"=>"Wake Up")
# alert("You did not enter anything!", {"title"=>"Wake Up", "bgcolor"=>"blue", "color"=>"white"})
# block currently ignored. don't know what to do, can't pass it to MB since alread sending in a block
def alert text, config={}, &block
  title = config['title'] || "Alert"
  #instance_eval &block if block_given?
  @mb = RubyCurses::MessageBox.new nil, config  do
    title title
    message text
    button_type :ok
  end
end
def confirm text, config={}, &block
  title = config['title'] || "Confirm"
  #instance_eval &block if block_given?
  @mb = RubyCurses::MessageBox.new nil, config  do
    title title
    message text
    button_type :yes_no
  end
  return @mb.selected_index == 0 ? :YES : :NO
end

##
# allows user entry of a string.
# In config you may pass Field related properties such as chars_allowed, valid_regex, values, etc.
def get_string(message, len=20, default="", config={})
  config["maxlen"]=len
  title = config["title"] || "Input required"
  @mb = RubyCurses::MessageBox.new nil, config do
    title title
    message message
    type :input
    button_type :ok
    default_value default
  end
  return @mb.input_value
end
 

=begin  
http://www.kammerl.de/ascii/AsciiSignature.php
 ___  
|__ \ 
   ) |
  / / 
 |_|  
 (_)  

 _ 
| |
| |
| |
|_|
(_)
   

 _____       _              _____                         
|  __ \     | |            / ____|                        
| |__) |   _| |__  _   _  | |    _   _ _ __ ___  ___  ___ 
|  _  / | | | '_ \| | | | | |   | | | | '__/ __|/ _ \/ __|
| | \ \ |_| | |_) | |_| | | |___| |_| | |  \__ \  __/\__ \
|_|  \_\__,_|_.__/ \__, |  \_____\__,_|_|  |___/\___||___/
                    __/ |                                 
                   |___/                                  

=end


