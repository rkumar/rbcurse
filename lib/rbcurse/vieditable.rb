#**************************************************************
# Author: rkumar (arunachalesha)
# Date: 2010-03-11 22:18 
# Provides the caller ability to do some edit operations
# on list widgets using either keys (vim largely)
# or a menu. made originally for textview and multitextview
#
#**************************************************************
    #hscrollcols = $multiplier > 0 ? $multiplier : @width/2
  #def previous_row num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
require 'rbcurse/listeditable'
module ViEditable
  include ListEditable

  #def ViEditable.vieditable_init
  def vieditable_init
    $log.debug " inside vieditable_init "
    @editable = true
    bind_key( ?C, :edit_line)
    bind_key( ?o, :insert_line)
    bind_key( ?O) { insert_line(@current_index-1) } 
    bind_key( ?D, :delete_eol)
    bind_key( [?d, ?$], :delete_eol)
    bind_key( [?d, ?d] , :delete_line ) 
    bind_key( [?d, ?w], :delete_word )
    bind_key( [?d, ?t], :delete_till )
    bind_key( [?d, ?f], :delete_forward )
    bind_key( ?\C-_ ) { @undo_handler.undo if @undo_handler }
    bind_key( ?u ) { @undo_handler.undo if @undo_handler }
    bind_key( ?\C-r ) { @undo_handler.redo if @undo_handler }
    bind_key( ?x, :delete_curr_char )
    bind_key( ?X, :delete_prev_char )
    bind_key( [?y, ?y] , :kill_ring_save ) 
    bind_key( ?p, :yank ) # paste after this line
    bind_key( ?P ) { yank(@current_index - 1) } # should be before this line
    bind_key(?\w, :forward_word)
    bind_key(?f, :forward_char)

  end

  ##
  # edit current or given line
  def edit_line lineno=@current_index
    line = @list[lineno]
    prompt = "Edit: "
    maxlen = 80
    config={}; 
    config[:default] = line
    ret, str = rbgetstr(@form.window, $error_message_row, $error_message_col,  prompt, maxlen, config)
    $log.debug " rbgetstr returned #{ret} , #{str} "
    return if ret != 0
    @list[lineno].replace(str)
    @repaint_required = true
  end
  ##
  # insert a line 
  def insert_line lineno=@current_index
    prompt = "Insert: "
    maxlen = 80
    #config={}; 
    #config[:default] = line
    #ret, str = rbgetstr(@form.window, $error_message_row, $error_message_col,  prompt, maxlen, config)
    ret, str = input_string prompt
    #ret, str = rbgetstr(@form.window, @row+@height-1, @col+1, prompt, maxlen, config)
    $log.debug " rbgetstr returned #{ret} , #{str} "
    return if ret != 0
    @list.insert lineno, str
    @repaint_required = true
  end
  ##
  # common method to edit given string
  # @param [String] string to edit/modify
  # @param [String] prompt to display before string
  # @param [int] max length of input
  # @return [0, -1] return value 0 if okay, -1 if error
  #
  def edit_string string, prompt="Edit: ", maxlen=80
    config={}; 
    config[:default] = string
    ret, str = rbgetstr(@form.window, $error_message_row, $error_message_col,  prompt, maxlen, config)
    #return str if ret == 0
    #return ""
  end
  ##
  # common method to input a blank string
  # @param [String] prompt to display before string
  # @param [int] max length of input
  # @return [0, -1] return value 0 if okay, -1 if error
  def input_string prompt="Insert: ", maxlen=80
    ret, str = rbgetstr(@form.window, $error_message_row, $error_message_col,  prompt, maxlen, config)
    #return str if ret == 0
    #return ""
  end
  def edit_chars

  end
  def edit_word

  end
end # module
