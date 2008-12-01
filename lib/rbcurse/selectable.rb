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
      @list_attribs[arow] = {:status=> " ", :bgcolor => nil}
     sel = " "; color = $datacolor
    else
      $log.debug("Adding #{arow} #{@select_mode}")
      do_clear_selection if @select_mode != 'multiple'
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
      $log.debug "return visual NIL #{arow-@toprow} "
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
    $log.debug " CALLED clear_sel "
    @selected.each {|sel| 
      $log.debug " CLAER for #{sel}"
      do_select(sel)}
  end
  def get_selected_data
    return nil if @selected.nil?
    ret = []
    list = get_content
    @selected.each { |sel| ret << list[sel] }
    return ret
  end
  def selectable_handle_key ch
    begin
      case ch
      when ?x, 32
        do_select
      when ?'
        $log.debug "insdie next selection"
        do_next_selection
      when ?"
        $log.debug "insdie prev selection"
        do_prev_selection
      when ?\C-e
        do_clear_selection
      else
        return :UNHANDLED
      end
    ensure
      post_key
    end
    0
  end
end
