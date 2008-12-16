=begin
  * Name: combo box
  * Description: 
  * Author: rkumar
  
  --------
  * Date:  2008-12-16 22:03 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'rubygems'
require 'ncurses'
require 'logger'
require 'lib/ver/ncurses'
require 'lib/ver/window'
require 'lib/rbcurse/rwidget'

include Ncurses
include RubyCurses
module RubyCurses
  META_KEY = 128
  extend self

  # TODO : 
  # must have a values list
  class ComboBox < Field


  def handle_key(ch)
    @current_index ||= 0
    case ch
    #when KEY_UP+ RubyCurses::META_KEY # alt up
    when KEY_UP
      set_buffer @values[@current_index].dup
      @current_index -= 1 if @current_index > 0
    when KEY_DOWN
      set_buffer @values[@current_index].dup
      @current_index += 1 if @current_index < @values.length()-1
    when KEY_DOWN+ RubyCurses::META_KEY # alt down
      popup
    else
      super
    end
  end
  def popup
    listconfig = {'bgcolor' => 'blue', 'color' => 'white'}
    url_list= @values
    poprow = row+1
    popcol = col
    dlength = @display_length
    f = self
    $log.debug " passing f: #{f}"
    pl = RubyCurses::PopupList.new do
      row  poprow
      col  popcol
      width dlength
      list url_list
      list_select_mode 'single'
      relative_to f
      list_config listconfig
      #default_values %w[ lee _why ]
      bind(:PRESS) do |index|
        f.set_buffer url_list[index]
      end
    end
  end
 
  # field advances cursor when it gives a char so we override this
  def putc c
    if c >= 0 and c <= 127
      ret = putch c.chr
      if ret == 0
  #     addcol 1
        set_modified 
      end
    end
    return -1 # always ??? XXX 
  end
  ##
  # field does not give char to non-editable fields so we override
  def putch char
    @current_index ||= 0
    if @editable 
    else
      match = next_match(char)
      set_buffer match unless match.nil?
    end
    @modified = true
    fire_handler :CHANGE, self    # 2008-12-09 14:51 
    0
  end
  def next_match char
    start = @current_index
    start.upto(@values.length-1) do |ix|
      if @values[ix][0,1] == char
        return @values[ix] unless @values[ix] == @buffer
      end
      @current_index += 1
    end
    ## could not find, start from zero
    @current_index = 0
    start = [@values.length()-1, start].min
    0.upto(start) do |ix|
      if @values[ix][0,1] == char
        return @values[ix] unless @values[ix] == @buffer
      end
      @current_index += 1
    end
    @current_index = [@values.length()-1, @current_index].min
    return nil
  end

  end # class ComboBox

end # module
