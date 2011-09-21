#**************************************************************
# Author: rkumar (arunachalesha)
# Date: 2010-03-11 22:18 
# Provides the caller ability to do some edit operations
# on list widgets using either keys (vim largely)
# or a menu. made originally for textview and multitextview
#
#**************************************************************


require 'rbcurse/listeditable'
module ViEditable
  include ListEditable

  def vieditable_init
    $log.debug " inside vieditable_init "
    @editable = true
    bind_key( ?C, :edit_line)
    #bind_key( ?o, :insert_line)
    #bind_key( ?O) { insert_line(@current_index-1) } 
    bind_key( ?o) { insert_line(@current_index+1) } 
    bind_key( ?O) { insert_line(@current_index) } 
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
    bind_key(?\M-y, :yank_pop)
    bind_key(?\M-w, :kill_ring_save)
    @_events.push :CHANGE # thru vieditable

  end
  ##
  # Separate mappings for listboxes.
  # Some methods don;'t make sense for listboxes and are crashing
  # since not present for them. f was being overwritten, too.
  # Sorry for duplication, need to clean this somehow.
  def vieditable_init_listbox
    $log.debug " inside vieditable_init_listbox "
    @editable = true
    bind_key( ?C, :edit_line)
    bind_key( ?o) { insert_line(@current_index+1) } 
    bind_key( ?O) { insert_line(@current_index) } 
    bind_key( [?d, ?d] , :delete_line ) 
    bind_key( ?\C-_ ) { @undo_handler.undo if @undo_handler }
    bind_key( ?u ) { @undo_handler.undo if @undo_handler }
    bind_key( ?\C-r ) { @undo_handler.redo if @undo_handler }
    bind_key( [?y, ?y] , :kill_ring_save ) 
    bind_key( ?p, :yank ) # paste after this line
    bind_key( ?P ) { yank(@current_index - 1) } # should be before this line
    bind_key(?\w, :forward_word)
    bind_key(?\M-y, :yank_pop)
    bind_key(?\C-y, :yank)
    bind_key(?\M-w, :kill_ring_save)
    @_events.push :CHANGE # thru vieditable
    #bind_key( ?D, :delete_eol)
    #bind_key( [?d, ?$], :delete_eol)
    #bind_key(?f, :forward_char)
    #bind_key( ?x, :delete_curr_char )
    #bind_key( ?X, :delete_prev_char )
    #bind_key( [?d, ?w], :delete_word )
    #bind_key( [?d, ?t], :delete_till )
    #bind_key( [?d, ?f], :delete_forward )

  end

  ##
  # edit current or given line
  def edit_line lineno=@current_index
    line = self[lineno]
    prompt = "Edit: "
    maxlen = 80
    config={}; 
    oldline = line.dup
    config[:default] = line
    ret, str = rbgetstr(@form.window, $error_message_row, $error_message_col,  prompt, maxlen, config)
    $log.debug " rbgetstr returned #{ret} , #{str} "
    return if ret != 0
    self[lineno].replace(str)
    fire_handler :CHANGE, InputDataEvent.new(0,oldline.length, self, :DELETE_LINE, lineno, oldline)     #  2008-12-24 18:34 
    fire_handler :CHANGE, InputDataEvent.new(0,str.length, self, :INSERT_LINE, lineno, str)
    @repaint_required = true
  end
  ##
  # insert a line 
  # FIXME needs to fire handler 2010-05-23 11:40 
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
    ## added handler on 2010-05-23 11:46 - undo works - tested in testlistbox.rb
    fire_handler :CHANGE, InputDataEvent.new(0,str.length, self, :INSERT_LINE, lineno, str)
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
    #ret, str = rbgetstr(@form.window, $error_message_row, $error_message_col,  prompt, maxlen, config)
    ret, str = rbgetstr(@form.window, $error_message_row, $error_message_col,  prompt, maxlen, config)
    #return str if ret == 0
    #return ""
  end
  def edit_chars

  end
  def edit_word

  end
end # module
