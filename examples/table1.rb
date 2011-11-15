require 'rbcurse/app'

if $0 == __FILE__
  # NOTE try using the readonly tabular or tabular widget instead, see term2.rb
  App.new do 
    @window.printstring 1, 30, "Demo of Table - rbcurse", $normalcolor, 'reverse'
    @window.printstring 2, 30, "Hit F1 to quit", $datacolor, 'normal'
      data = [["Roger Federer",16,"SWI"],
        ["Pete Sampras",14, "USA"],
        ["Roy Emerson", 12, "AUS"],
        ["Bjorn Borg",  11, "SWE"],
        ["Rod Laver",   11, "AUS"],
        ["Bill Tilden", 10, "USA"]]
      colnames = %w[ Player Wins Nation ]
    stack :margin_top => 3, :margin => 10 do
      # we leave out :width so it gets calculated by column_widths
      t = table :height => 10, :columns => colnames, :data => data, :column_widths => [15,5,10], :extended_keys => true
      # :estimate_widths => true
      # other options are :column_widths => [12,4,12]
      # :size_to_fit => true

    end
  end
end
