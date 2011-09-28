require 'rbcurse/app'
require 'terminal-table/import'

App.new do 
  header = app_header "rbcurse 1.2.0", :text_center => "**** Demo", :text_right =>"New Improved!", :color => :black, :bgcolor => :white, :attr => :bold 
  message "Press F1 to escape from here"

  stack :margin_top => 2, :margin => 5, :width => 30 do
    t = Terminal::Table.table(['a', 'b'], [1, 2], [3, 4])
    $log.debug "YYY table #{t.class} "
    list_box :list => t.render2
    t = Terminal::Table.table ['a', 'b']
    t << [1, 2]
    t << [3, 4]
    t << :separator
    t << [4, 6]
    #list_box :list => t.to_s.split("\n")
    list_box :list => t.render2
  end # stack
  t = Terminal::Table.table do |t|
    t.headings = 'First Name', 'Last Name', 'Email'
    t << %w( TJ Holowaychuk tj@vision-media.ca )
    t << %w( Bob Someone bob@vision-media.ca )
    t << %w( Joe Whatever bob@vision-media.ca )
  end
  #t = t.to_s.split(/[|+]\n/)
  t = t.render2
  wid = t[0].length + 2
  stack :margin_top => 2, :margin => 35, :width => wid do
    list_box :list => t
    t = Terminal::Table.table do
      self.headings = 'First Name', 'Last Name', 'Email'
      add_row ['TJ',  'Holowaychuk', 'tj@vision-media.ca']
      add_row ['Bob', 'Someone',     'bob@vision-media.ca']
      add_row ['Joe', 'Whatever',    'joe@vision-media.ca']
      add_separator
      add_row ['Total', { :value => '3', :colspan => 2, :alignment => :right }]
      align_column 1, :center
    end
    #lb =  list_box :list => t.render2
    lb =  textview :set_content => t.render2, :height => 10
    lb.bind(:PRESS){|tae|
      alert "Pressed list on #{tae.word_under_cursor(nil, nil, "|")}  "
    }
    # make a textview that is vienabled by default.
end

end # app
