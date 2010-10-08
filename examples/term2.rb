require 'rbcurse/app'
require 'rbcurse/extras/tabular'
require 'rbcurse/extras/scrollbar'

App.new do 
  header = app_header "rbcurse 1.2.0", :text_center => "**** Demo", :text_right =>"New Improved!", :color => :black, :bgcolor => :white, :attr => :bold 
  message "Press F1 to escape from here"

  stack :margin_top => 2, :margin => 5, :width => 30 do
    t = Tabular.new(['a', 'b'], [1, 2], [3, 4])
    $log.debug "YYY table #{t.class} "
    list_box :list => t.render
    t = Tabular.new ['a', 'b']
    t << [1, 2]
    t << [3, 4]
    t << [4, 6]
    #list_box :list => t.to_s.split("\n")
    list_box :list => t.render
  end # stack
  t = Tabular.new do |t|
    t.headings = 'First Name', 'Last Name', 'Email'
    t << %w( TJ Holowaychuk tj@vision-media.ca )
    t << %w( Bob Someone bob@vision-media.ca )
    t << %w( Joe Whatever bob@vision-media.ca )
  end

  t = t.render
  wid = t[0].length + 2
  stack :margin_top => 2, :margin => 35, :width => wid do
    list_box :list => t
    t = Tabular.new do
      self.headings = 'First Name', 'Last Name', 'Email'
      add_row ['Roald',  'Amundsen', 'ra@explorers.org']
      add_row ['Francis', 'Drake',    'joe@ducks.com']
      add_row ['Hsuan', 'Tsang',    'tsang@asia.org']
      add_separator
      add_row ['Ernest', 'Shackleton',    'jack@radio-schakc.org']
      add_row ['Fa', 'Hsien',    'fa@sheen.net']
      add_row ['Vasco', 'Da Gama',     'bob@vasco.org']
      add_row ['David', 'Livingstone',    'jack@trolls.com']
      #add_row ['Total', { :value => '3', :colspan => 2, :alignment => :right }]
      align_column 1, :center
      self.numbering = true
    end
    #lb =  list_box :list => t.render2
    lb =  textview :set_content => t.render, :height => 10
    lb.bind(:PRESS){|tae|
      alert "Pressed list on line #{tae.current_index}  #{tae.word_under_cursor(nil, nil, "|")}  "
    }
    Scrollbar.new @form, :parent => lb
     #make a textview that is vienabled by default.
end

end # app
