require 'rbcurse/core/util/app'

App.new do 
  header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "MultiSplit Demo", :text_right =>"ColumnBrowse pattern"
  #message_row(27)
  message "<TAB> and <BTAB> "
  oo = :HORIZONTAL_SPLIT
  oo = :VERTICAL_SPLIT

  stack :margin_top => 2, :margin => 1, :width => FFI::NCurses.COLS-2 do
    splp = multisplit "outer", :height => FFI::NCurses.LINES - 3 , :split_count => 2, :orientation => oo  do |s|
      #s.suppress_borders = false
        lb = list_box "Classes",:list => `ri -f bs`.split("\n")
        s.add lb

        lb2 = list_box "Methods", :list => ["highline", "sqlite3-ruby", "thor", "ncurses"], :choose => ["thor"]
        #lb2.suppress_borders true
        s.add lb2
      #sc = textarea "Edit"
      #s.add sc
    end # splp
    c1 = splp[0]
    c2 = splp[1]
    #c1.bind_key(KEY_RETURN){ 
    # listbox now traps key ENTER and fires PRESS event
    c1.bind(:PRESS){ 
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
        c2.clear_selection # since we had put default value using choose
      end
    }


    #blank
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
        #fc.set_divider_location(splp.divider_location+1)
        fc.increase
      end
      # decrease split size
      button "-" do
        #fc.set_divider_location(splp.divider_location-1)
        fc.decrease
      end
      # equalize  split size
      button "=" do
        #splp.set_resize_weight(0.50)
        fc.same
      end
    end
       
  end # stack
end # app
