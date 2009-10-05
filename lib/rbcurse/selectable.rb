##
# give the ability to a list, to allow for selection of rows.
#
module Selectable
  SELECT_CHAR = '>'
  # @param index of row in list, offset 0
  # This puts an > character on the first col of the selected row
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
      @list_attribs[arow] = {:status=> SELECT_CHAR, :bgcolor => $selectedcolor}
     sel = SELECT_CHAR; color = $selectedcolor
    end
    # remember to erase these skidmarks when the user scrolls
    win.printstring @row+1+visual_index, @col+@left_margin-1, sel, color unless visual_index.nil?
    # fire ListComboSelect event, added TODO to test out.
    fire_handler :LIST_COMBO_SELECT, arow
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
  alias :get_selected_items :get_selected_data  # data should be deprecated
  ##
  # XXX in case of single selection popup, only ENTER selects and it closes too firing PRESS.
  # in case of multiple selection and popup, space selects and fires COMBO_SELECT, but enter closes and fires 
  # a different event, PRESS. This needs to be regularized.
  def selectable_handle_key ch
    begin
      case ch
      when ?;.getbyte(0), 32  # x no more selecting since we now jump to row matching char 2008-12-18 13:13 
        return if is_popup and @select_mode == 'single' # not allowing select this way since there will be a difference 
        # between pressing ENTER and space. Enter is trapped by Listbox!
        do_select
      when ?'.getbyte(0)
        $log.debug "insdie next selection"
        do_next_selection if @select_mode == 'multiple'
      when ?".getbyte(0)
        $log.debug "insdie prev selection"
        do_prev_selection if @select_mode == 'multiple'
      when ?\C-e.getbyte(0)
        do_clear_selection if @select_mode == 'multiple'
      else
        return :UNHANDLED
      end
    ensure
      #### post_key  2009-01-07 13:43 
    end
    0
  end
end
