##
# give the ability to a list, to allow for selection of rows.
#
module Selectable
  # @param index of row in list, offset 0
  # This puts an X character on the first col of the selected row
  def do_select arow=@prow
    @implements_selectable = true
    win = get_window
    visual_index = row_visual_index arow
    sel = " "; r = arow+1; 
    @selected ||= []
    if @selected.include? arow
      @selected.delete arow
      @list_attribs[arow] = {:status=> nil, :bgcolor => nil}
     sel = " "; color = $datacolor
    else
      $log.debug("Adding #{arow}")
      @selected << arow
      # 2008-11-25 21:00 added this just to see if it make things better
      @list_attribs[arow] = {:status=> 'X', :bgcolor => $selectedcolor}
     sel = "X"; color = $selectedcolor
    end
    # remember to erase these skidmarks when the user scrolls
    printstr win, @row+1+visual_index, @col+@left_margin-1, sel, color unless visual_index.nil?
  end
  ## is the row in view, if so, return index, else nil
  def row_visual_index arow
    if arow >= @toprow and arow <= @toprow+@scrollatrow
      $log.debug "return visual #{arow-@toprow} "
      return arow-@toprow
    end
    nil
  end
  def do_next_selection
    return if @selected.length == 0 
    row = @selected.sort.find { |i| i > @prow }
    row ||= @prow
    @prow = row
  end
  def do_prev_selection
    return if @selected.length == 0 
    row = @selected.sort{|a,b| b <=> a}.find { |i| i < @prow }
    row ||= @prow
    @prow = row
  end
# FIXME not clearing properly
  def do_clear_selection
    @selected.each {|sel| 
      do_select(sel)}
  end
  def get_selected_data
    ret = []
    list = get_content
    @selected.each { |sel| ret << list[sel] }
    return ret
  end
  def selectable_handle_key ch
    case ch
    when ?x
      do_select
    when ?'
$log.debug "insdie next selection"
      do_next_selection
    when ?"
$log.debug "insdie prev selection"
      do_prev_selection
    when ?\C-e
      do_clear_selection
    end
    post_key
  end
end
