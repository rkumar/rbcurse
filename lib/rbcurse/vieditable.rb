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
module ViEditable

  #def ViEditable.vieditable_init
  def vieditable_init
    $log.debug " inside vieditable_init "
    @editable = true
    bind_key( ?C, :edit_line)
    bind_key( ?o, :insert_line)
    bind_key( ?O) { insert_line(@current_index-1) } 
  end

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
  def insert_line lineno=@current_index
    prompt = "Insert: "
    maxlen = 80
    config={}; 
    #config[:default] = line
    ret, str = rbgetstr(@form.window, $error_message_row, $error_message_col,  prompt, maxlen, config)
    #ret, str = rbgetstr(@form.window, @row+@height-1, @col+1, prompt, maxlen, config)
    $log.debug " rbgetstr returned #{ret} , #{str} "
    return if ret != 0
    @list.insert lineno, str
    @repaint_required = true
  end
  def edit_chars

  end
  def edit_word

  end
end # module
