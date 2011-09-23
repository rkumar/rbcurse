# encoding: utf-8
require 'rbcurse/app'
require 'rbcurse/extras/tabular'
require 'rbcurse/extras/scrollbar'

App.new do 
  # putting japanese chars makes the title line flow a bit into next
  header = app_header "rbcurse 1.2.0", :text_center => "日本語 Demo", :text_right =>"New Improved!", :color => :black, :bgcolor => :white, :attr => :bold 
  message "Press F10 to escape from here"

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
    t.headings = 'の名前', 'Last の名前', 'メール'
    t << %w( TJ Holowaychuk tj@vision-media.ca )
    t << %w( Bob Someone bob@vision-media.ca )
    t << %w( Joe Whatever bob@vision-media.ca )
  end

  # added some japanese characters for fun, however they are wider
  # so aligning them fails, they can go out of boxes bounds
  t = t.render
  wid = t[0].length + 2
  stack :margin_top => 2, :margin => 35, :width => wid do
    lb1 = list_box :list => t
    t = Tabular.new do
      self.headings = 'First Name', 'Last Name', 'Email'
      add_row ['Roald',  'Amundsen', 'の名前']
      add_row ['Francis', 'Drake',    '松本行弘']
      add_row ['Hsuan', 'Tsang',    '主に漢字に対']
      add_separator
      add_row ['Ernest', 'Shackleton',    'とは']
      add_row ['Fa', 'Hsien',    '読み仮名']
      add_row ['Vasco', 'Da Gama',     'また']
      add_row ['David', 'Livingstone',    "振り仮名 "]
      #add_row ['Total', { :value => '3', :colspan => 2, :alignment => :right }]
      align_column 1, :center
      self.numbering = true
    end
    # added 2011-09-22 to show deleting a row
    lb1.one_key_selection = false
    lb1.bind_key('d') {|e| e.delete_at(e.current_index)  }
    #lb =  list_box :list => t.render2
    lb =  textview :set_content => t.render, :height => 10
    lb.bind(:PRESS){|tae|
      alert "Pressed list on line #{tae.current_index}  #{tae.word_under_cursor(nil, nil, "|")}  "
    }
    Scrollbar.new @form, :parent => lb
     #make a textview that is vienabled by default.
end

end # app
