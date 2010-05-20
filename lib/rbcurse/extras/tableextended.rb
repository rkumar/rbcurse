# Provides extended abilities to a table
# so user does not need to code it into his app.
# At the same time, i don't want to weigh down Table with too much functionality/
# I am putting in some stuff, so that table columns can be resized, using multipliers.
# That allows us to redistribute the space taken or released across rows.
# Other options: dd, C, . (repeat) and how about range operations
#
module TableExtended

  ##
  # increase the focused column
  # If no size passed, then use numeric multiplier, else 1
  # Typically, one would bind a key such as + to this method
  # e.g. atable.bind_key(?+) { atable.increase_column ; }
  # See examples/viewtodo.rb for usage
  def increase_column num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)

    acolumn = column focussed_col()
    #num = $multiplier || 1
    $multiplier = 0
    w = acolumn.width + num
    acolumn.width w
    #atable.table_structure_changed
  end
  # decrease the focused column
  # If no size passed, then use numeric multiplier, else 1
  # Typically, one would bind a key such as - to this method
  def decrease_column num=(($multiplier.nil? or $multiplier == 0) ? 1 : $multiplier)
    acolumn = column focussed_col()
    w = acolumn.width - num
    $multiplier = 0
    if w > 3
      acolumn.width w
      #atable.table_structure_changed
    end
  end



end
