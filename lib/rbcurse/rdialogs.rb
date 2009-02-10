=begin
  * Name: dialogs so user can do basic stuff in one line.
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
require 'rbcurse/rwidget'
require 'rbcurse/rmessagebox'

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
  mb = RubyCurses::MessageBox.new nil, config  do
    title title
    message text
    button_type :ok
  end
end
def confirm text, config={}, &block
  title = config['title'] || "Confirm"
  #instance_eval &block if block_given?
  mb = RubyCurses::MessageBox.new nil, config  do
    title title
    message text
    button_type :yes_no
  end
  return mb.selected_index == 0 ? :YES : :NO
end

##
# allows user entry of a string.
# In config you may pass Field related properties such as chars_allowed, valid_regex, values, etc.
def get_string(message, len=20, default="", config={})
  config["maxlen"]=len
  title = config["title"] || "Input required"
  mb = RubyCurses::MessageBox.new nil, config do
    title title
    message message
    type :input
    button_type :ok
    default_value default
  end
  return mb.input_value
end
 
##
# Added 2009-02-05 13:16 
# get a string from user with some additional checkboxes and optionally supply default values
# Usage:
  #sel, inp, hash = get_string_with_options("Enter a filter pattern", 20, "*", {"checkboxes" => ["case sensitive","reverse"], "checkbox_defaults"=>[true, false]})
 # sel, inp, hash = get_string_with_options("Enter a filter pattern", 20, "*", {"checkboxes" => ["case sensitive","reverse"]})
 # $log.debug " POPUP: #{sel}: #{inp}, #{hash['case sensitive']}, #{hash['reverse']}"
#
# @param: message to print, 
# @param: length of entry field
# @param: default value of field
# @param: configuration of box or field
#         checkboxes: array of strings to use as checkboxes
#         checkbox_defaults : array of true/false default values for each cb
# @return: int 0 OK, 1 cancel pressed
# @return: string value entered
# @return: hash of strings and booleans for checkboxes and values
#
def get_string_with_options(message, len=20, default="", config={})
  title = config["title"] || "Input required"
  input_config = config["input_config"] || {}
  checks = config["checkboxes"] 
  checkbox_defaults = config["checkbox_defaults"] || []

  height = config["height"] || 1
  display_length = config["display_length"] || 30

  r = 3
  c = 4
  mform = RubyCurses::Form.new nil
  message_label = RubyCurses::Label.new mform, {'text' => message, "name"=>"message_label","row" => r, "col" => c, "display_length" => display_length,  "height" => height, "attr"=>"reverse"}

  r += 1
  input = RubyCurses::Field.new mform, input_config do
    name   "input" 
    row  r 
    col  c 
    display_length  display_length
    maxlen len
    set_buffer default
  end
  if !checks.nil?
    r += 2
    checks.each_with_index do |cbtext,ix|
      field = RubyCurses::CheckBox.new mform do
        text cbtext
        name cbtext
        value checkbox_defaults[ix]||false
        color 'black'
        bgcolor 'white'
        row r
        col c
      end
      r += 1
    end
  end
  radios = config["radiobuttons"] 
  if !radios.nil?
    radio_default = config["radio_default"] || radios[0]
    radio = RubyCurses::Variable.new radio_default
    r += 2
    radios.each_with_index do |cbtext,ix|
      field = RubyCurses::RadioButton.new mform do
        variable radio
        text cbtext
        value cbtext
        color 'black'
        bgcolor 'white'
        row r
        col c
      end
      r += 1
    end
  end
  mb = RubyCurses::MessageBox.new mform do
    title title
    button_type :ok_cancel
    default_button 0
  end
  hash = {}
  if !checks.nil?
  checks.each do |c|
    hash[c] = mform.by_name[c].getvalue
  end
  end
  hash["radio"] = radio.get_value unless radio.nil?
  # returns button index (0 = OK), value of field, hash containing values of checkboxes
  return mb.selected_index, mform.by_name['input'].getvalue, hash
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


