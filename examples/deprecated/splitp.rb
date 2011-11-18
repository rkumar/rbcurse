require 'rbcurse/core/util/app'

App.new do 
  header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Splitpane Demo", :text_right =>""
  message_row(27)
  message "<TAB> between outer panes, Alt-W between inner tabs, Alt-TAb to exit Splitpane"

  stack :margin_top => 5, :margin => 15, :width => 79 do
    splp = splitpane "outer", :height => 15  do |s|
      fc = splitpane "top", :orientation => :VERTICAL_SPLIT, :border_color => $promptcolor, :divider_at => 0.3 do |fc1|
        lb = listbox "Shapes",:list => ["Square", "Oval", "Rectangle", "Somethinglarge"], :choose => ["Oval"]
        fc1.first_component lb

        lb2 = listbox "MyGems", :list => ["highline", "sqlite3-ruby", "thor", "ncurses"], :choose => ["thor"]
        fc1.second_component lb2
        
      end
      s.first_component fc

      sc = textarea "Edit"
      s.second_component sc

    end # splp
    blank
    flow do
      #toggle :onvalue => "Vertical", :offvalue => "Horizontal", :value => true do |e|
        #message "pressed #{e.state}"
        #case e.state
        #when :DESELECTED
          #$log.debug " about to call orientation with V"
          #splp.orientation :VERTICAL_SPLIT
          ##ret = splp.reset_to_preferred_sizes
        #else
          #$log.debug " about to call orientation with H"
          #splp.orientation :HORIZONTAL_SPLIT
          ##ret = splp.reset_to_preferred_sizes
        #end
      #end
      fc = splp
      # increase split size
      button "+" do
        #splp.set_divider_location(splp.divider_location+1)
        fc.set_divider_location(splp.divider_location+1)
      end
      # decrease split size
      button "-" do
        fc.set_divider_location(splp.divider_location-1)
      end
      # equalize  split size
      button "=" do
        splp.set_resize_weight(0.50)
      end
    end
       
  end # stack
end # app
