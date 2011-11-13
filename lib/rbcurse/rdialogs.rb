=begin
  * Name: dialogs so user can do basic stuff in one line.
  * Description: 
  * Author: rkumar
  
  --------
  * Date:  2008-12-30 12:22 
  * 2011-10-1 : moving print_error and print_status methods here as alternatives
                to alert and confirm. Anyone who has included those will get these.
                And this file is included in the base file.

               Shucks, this file has no module. It's bare !
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

TODO:
    Add one get_string(message, len, regex ...)
    Add select_one (message, values, default)
=end
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
#
def alert text, config={}, &block
  title = config['title'] || "Alert"
  #instance_eval &block if block_given?
  if text.is_a? RubyCurses::Variable # added 2011-09-20 incase variable passed
    text = text.get_value
  end
  mb = RubyCurses::MessageBox.new nil, config  do
    title title
    message text
    button_type :ok
  end
end
# confirms from user returning :YES or :NO
# Darn, should have returned boolean, now have to live with it.
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
def get_string(message, len=50, default="", config={})

  config["input_config"] = {}
  config["input_config"]["maxlen"] = len
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

# ------------------------ We've Moved here from window class ---------------- #
#                                                                              #
#  Moving some methods from window. They no longer require having a window.    #
#                                                                              #
# ---------------------------------------------------------------------------- #
#
#

# new version with a window created on 2011-10-1 12:37 AM 
# Now can be separate from window class, needing nothing, just a util class
# prints a status message and pauses for a char
def print_status_message text, aconfig={}, &block
  _print_message :status, text, aconfig, &block
end
# new version with a window created on 2011-10-1 12:30 AM 
# Now can be separate from window class, needing nothing, just a util class
# Why are we dealing with $error_message, that was due to old idea which failed
# scrap it and send the message.
def print_error_message text, aconfig={}, &block
  _print_message :error, text, aconfig, &block
end
def _create_footer_window h = 2 , w = Ncurses.COLS, t = Ncurses.LINES-2, l = 0
  ewin = VER::Window.new(h, w , t, l)
end
# @param [:symbol] :error or :status kind of message
# @private
def _print_message type, text, aconfig={}, &block
  case text
  when RubyCurses::Variable # added 2011-09-20 incase variable passed
    text = text.get_value
  when Exception
    text = text.to_s
  end
  # NOTE we are polluting global namespace
  aconfig.each_pair { |k,v| instance_variable_set("@#{k}",v) }
  ewin = _create_footer_window #*@layout
  r = 0; c = 1;
  case type 
  when :error
    @color ||= 'red'
    @bgcolor ||= 'black'
  else
    @color ||= :white
    @bgcolor ||= :black
  end
  color_pair = get_color($promptcolor, @color, @bgcolor)
  ewin.bkgd(Ncurses.COLOR_PAIR(color_pair));
  ewin.printstring r, c, text, color_pair
  ewin.printstring r+1, c, "Press a key", color_pair
  ewin.wrefresh
  ewin.getchar
  ewin.destroy
end
#
# Alternative to confirm dialog, if you want this look and feel, at last 2 lines of screen
# @param [String] text to prompt
# @return [true, false] 'y' is true, all else if false
def confirm_window text, aconfig={}, &block
  case text
  when RubyCurses::Variable # added 2011-09-20 incase variable passed
    text = text.get_value
  when Exception
    text = text.to_s
  end
  ewin = _create_footer_window
  r = 0; c = 1;
  aconfig.each_pair { |k,v| instance_variable_set("@#{k}",v) }
  @color ||= :white
  @bgcolor ||= :black
  color_pair = get_color($promptcolor, @color, @bgcolor)
  ewin.bkgd(Ncurses.COLOR_PAIR(color_pair));
  ewin.printstring r, c, text, color_pair
  ewin.printstring r+1, c, "[y/n]", color_pair
  ewin.wrefresh
  #retval = false
  retval = :NO # consistent with confirm
  begin
    ch =  ewin.getchar 
    retval = :YES if ch.chr == 'y' 
  ensure
    ewin.destroy
  end
  retval
end
# class created to display multiple messages without asking for user to hit a key
# returns a window to which one can keep calling printstring with 0 or 1 as row.
# destroy when finished.
# Also, one can pause if one wants, or linger.
# This is meant to be a replacement for the message_immediate and message_raw
# I was trying out in App.rb. 2011-10-1 1:27 AM 
# Testing from test2.rb
# TODO: add option of putting progress_bar
class StatusWindow
  attr_reader :h, :w, :top, :left # height, width, top row, left col of window
  attr_reader :win
  attr_accessor :color_pair
  def initialize config={}, &block
    @color_pair = config[:color_pair]
    @row_offset = config[:row_offset] || 0
    @col_offset = config[:col_offset] || 0
    create_window *config[:layout]
  end
  def create_window h = 2 , w = Ncurses.COLS-0, t = Ncurses.LINES-2, l = 0
    return @win if @win
    @win = VER::Window.new(h, w , t, l)
    @h = h ; @w = w; @top = t ; @left = l
    @color_pair ||= get_color($promptcolor, 'white','black')
    @win.bkgd(Ncurses.COLOR_PAIR(@color_pair));
    @win
  end
  # creates a color pair based on given bg and fg colors as strings
  #def set_colors bgcolor, fgcolor='white'
  #@color_pair = get_color($datacolor, 'white','black')
  #end
  # prints a string on given row (0 or 1)
  def printstring r, c, text, color_pair=@color_pair
    create_window unless @win
    show unless @visible
    r = @h-1 if r > @h-1
    #@win.printstring r, c, ' '*@w, @color_pair
    # FIXME this padding overwrites the border and the offset means next line wiped
    # However, now it may now totally clear a long line.
    @win.printstring r+@row_offset, c+@col_offset, "%-*s" % [@w-(@col_offset*2)-c, text], color_pair
    @win.wrefresh
  end
  # print given strings from first first column onwards
  def print *textarray
    create_window unless @win
    show unless @visible
    c = 1
    textarray.each_with_index { |s, i|  
      @win.printstring i+@row_offset, c+@col_offset, "%-*s" % [@w-(@col_offset*2)-c, s], @color_pair
    }
    @win.wrefresh
  end
  def pause; @win.getchar; end
  # pauses with the message, but doesn't ask the user to press a key.
  # If he does, the key should be used by underlying window.
  # Do not call destroy if you call linger, it does the destroy.
  def linger caller_window=nil
    begin
      if caller_window
        ch = @win.getchar
        caller_window.ungetch(ch) # will this be available to underlying window XXX i think not !!
      else
        sleep 1
      end
    ensure
      destroy
    end
  end
  # caller must destroy after he's finished printing messages, unless
  # user calls linger
  def destroy; @win.destroy if @win; @win = nil;  end
  def hide
    @win.hide
    @visible = false
  end
  def show
    @win.show unless @visible
    @visible = true
  end
end
# returns instance of a status_window for sending multiple
# statuses during some process
def status_window aconfig={}, &block
  return StatusWindow.new aconfig
end
# this is a popup dialog box on which statuses can be printed as a process is taking place.
# I am reusing StatusWindow and so there's an issue since I've put a box, so in clearing 
# the line, I might overwrite the box
def progress_dialog aconfig={}, &block
  aconfig[:layout] = [10,60,10,20]
  window = status_window aconfig
  height = 10; width = 60
  window.win.print_border_mb 1,2, height, width, $normalcolor, FFI::NCurses::A_REVERSE
  return window
end
# 
# Display a popup and return the seliected index from list
#  Config includes row and col and title of window
#  You may also pass bgcolor and color
#  @since 1.4.1  2011-11-1 
def popuplist list, config={}, &block
  require 'rbcurse/rbasiclistbox'

  max_visible_items = config[:max_visible_items]
  row = config[:row] || 5
  col = config[:col] || 5
  relative_to = config[:relative_to]
  if relative_to
    layout = relative_to.form.window.layout
    row += layout[:top]
    col += layout[:left]
  end
  config.delete :relative_to
  width = config[:width] || longest_in_list(list)+2 # borders take 2
  height = config[:height]
  height ||= [max_visible_items || 10+2, list.length+2].min 
  #layout(1+height, width+4, row, col) 
  layout = { :height => 0+height, :width => 0+width, :top => row, :left => col } 
  window = VER::Window.new(layout)
  form = RubyCurses::Form.new window

  listconfig = config[:listconfig] || {}
  listconfig[:list] = list
  listconfig[:width] = width
  listconfig[:height] = height
  listconfig[:selection_mode] = :single
  listconfig.merge!(config)
  listconfig.delete(:row); 
  listconfig.delete(:col); 
  # trying to pass populists block to listbox
  lb = RubyCurses::BasicListbox.new form, listconfig, &block
  #
  # added next line so caller can configure listbox with 
  # events such as ENTER_ROW, LEAVE_ROW or LIST_SELECTION_EVENT or PRESS
  # 2011-11-11 
  #yield lb if block_given? # No it won't work since this returns
  window.bkgd(Ncurses.COLOR_PAIR($reversecolor));
  window.wrefresh
  Ncurses::Panel.update_panels
  form.repaint
  window.wrefresh
  begin
    while((ch = window.getchar()) != 999 )
      case ch
      when -1
        next
      when ?\C-q.getbyte(0)
        break
      else
        lb.handle_key ch
        form.repaint
        if ch == 13 || ch == 10
          return lb.current_index
          # if multiple selection, then return list of selected_indices and don't catch 32
        elsif ch == 32      # if single selection
          return lb.current_index
        end
        #yield ch if block_given?
      end
    end
  ensure
    window.destroy  
  end
  return nil
end
# returns length of longest
def longest_in_list list  #:nodoc:
  longest = list.inject(0) do |memo,word|
    memo >= word.length ? memo : word.length
  end    
  longest
end    
#
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


