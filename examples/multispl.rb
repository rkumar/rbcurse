require 'rbcurse/app'

App.new do 
  header = app_header "rbcurse 1.2.0", :text_center => "MultiSplit Demo", :text_right =>""
  message_row(27)
  message "<TAB> and <BTAB> "

  stack :margin_top => 5, :margin => 15, :width => 79 do
    splp = multisplit "outer", :height => 15, :split_count => 2, :orientation => :VERTICAL_SPLIT  do |s|
        lb = list_box "Classes",:list => `ri -f bs`.split("\n")
        s.add lb

        lb2 = list_box "Methods", :list => ["highline", "sqlite3-ruby", "thor", "ncurses"], :choose => ["thor"]
        s.add lb2
      #sc = textarea "Edit"
      #s.add sc
    end # splp
    c1 = splp[0]
    c2 = splp[1]
    c1.bind_key(KEY_RETURN){ 
      #m = Object::const_get(c1.text).public_instance_methods
      lines = `ri -f bs #{c1.text} | tr -d ''`.split("\n")
      i = lines.index "= CCllaassss  mmeetthhooddss::"
       m = nil
      if i
        lines[i] = "Class Methods:" 
        m = lines.slice(i..-1)
        i = m.index "= IInnssttaannccee  mmeetthhooddss::"
        m[i] = "Instance Methods:" if i
      else
        i = lines.index "= IInnssttaannccee  mmeetthhooddss::"
        if i
          lines[i] = "Instance Methods:" 
          m = lines.slice(i..-1)
        end
      end
      if m
      c2.remove_all
      c2.insert 0, *m
      end
    }


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
