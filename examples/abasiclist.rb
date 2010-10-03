require 'rbcurse/app'
require 'rbcurse/rbasiclistbox'

# just a simple test to ensure that rbasiclistbox is running inside a container.
App.new do 
  header = app_header "rbcurse 1.2.0", :text_center => "Basic List Demo", :text_right =>"New Improved!", :color => :black, :bgcolor => :white, :attr => :bold 
  message "Press F1 to escape from here"

  list = %W{ bhikshu boddisattva avalokiteswara mu mun kwan paramita prajna samadhi sutra shakyamuni }
  vimsplit :row => 1, :col => 0, :suppress_borders => false, :width => 60, :height => Ncurses.LINES-2, :weight => 0.4, :orientation => :VERTICAL do |s|
    lb = RubyCurses::BasicListbox.new nil, :list => list, :suppress_borders => false
    #lb = RubyCurses::BasicListbox.new nil, :list => list, :show_selector => true, :row_selected_symbol => "*", :suppress_borders => false
    #lb = RubyCurses::BasicListbox.new nil, :list => list
    #lb = list_box "A list", :list => list
    lb.show_selector = false
    #lb.row_selected_symbol = "*"
    #lb = list_box "A list", :list => list
    
    s.add lb, :FIRST
    #lb2= RubyCurses::BasicListbox.new nil, :list => list.shuffle, :justify => :center
    lb2 = basiclist :list => list.shuffle, :justify => :left, :suppress_borders => false
    s.add lb2, :SECOND
  end

end # app
