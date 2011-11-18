require 'rbcurse/core/util/app'
require 'rbcurse/core/widgets/tabular'
require 'rbcurse/core/widgets/scrollbar'

App.new do 
  header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Tabular Demo", :text_right =>"New Improved!", :color => :black, :bgcolor => :white, :attr => :bold 
  message "Press F10 to escape from here"

  stack :margin_top => 2, :margin => 5, :width => 30 do
    t = Tabular.new(['a', 'b'], [1, 2], [3, 4])
    listbox :list => t.render
    t = Tabular.new ['a', 'b']
    t << [1, 2]
    t << [3, 4]
    t << [4, 6]
    #list_box :list => t.to_s.split("\n")
    listbox :list => t.render
  end # stack
  r = `/bin/df -gh`     # stock BSD df
  #r = `df -gh`   # I've installed brew, the df (maybe coreutils gives an error due to g option"
  
  raise "df -gh not returning anything. correct command here. Try removing g option" if r == ""
  # on my system there are extra spaces so i need to remove them, or else
  # there'll be a mismatch between headers and columns
  r.gsub!("Mounted on", "Mounted_on")
  r.gsub!("map ", "map_")
  res = r.split("\n")
  heads = res.shift.split
  t = Tabular.new do |t|
    t.headings = heads
    #t.headings = 'First Name', 'Last Name', 'Email'
    #t << %w( TJ Holowaychuk tj@vision-media.ca )
    #t << %w( TJ Holowaychuk tj@vision-media.ca 1 2 3  )
    #t << %w( Bob Someone bob@vision-media.ca )
    #t << %w( Joe Whatever bob@vision-media.ca )

    #res.each { |e| t <<   e.split.flatten   }
    res.each { |e| t.add_row e.split   }
  end

  t = t.render
  wid = t[0].length + 2
  stack :margin_top => 2, :margin => 35, :width => wid do
    listbox :list => t, :title => '[df -gh]'

    r = `ls -l`
    res = r.split("\n")

    t = Tabular.new do
#      self.headings = 'Perm', 'Gr', 'User', 'U',  'Size', 'Mon', 'Date', 'Time', 'File' # changed 2011 dts  
      self.headings = 'User',  'Size', 'Mon', 'Date', 'Time', 'File'
      res.each { |e| 
        cols = e.split
        next if cols.count < 6
        cols = cols[3..-1]
        cols = cols[0..5] if cols.count > 6
        #cols[1] = cols[1].to_i
        add_row cols
      }
      column_width 1, 6
      align_column 1, :right
      #self.headings = 'First Name', 'Last Name', 'Email'
      #add_row ['Roald',  'Amundsen', 'ra@explorers.org']
      #add_row ['Francis', 'Drake',    'joe@ducks.com']
      #add_row ['Hsuan', 'Tsang',    'tsang@asia.org']
      #add_separator
      #add_row ['Ernest', 'Shackleton',    'jack@radio-schakc.org']
      #add_row ['Fa', 'Hsien',    'fa@sheen.net']
      #add_row ['Vasco', 'Da Gama',     'bob@vasco.org']
      #add_row ['David', 'Livingstone',    'jack@trolls.com']
      ##add_row ['Total', { :value => '3', :colspan => 2, :alignment => :right }]
      #align_column 1, :center
      #self.numbering = true
    end
    #lb =  list_box :list => t.render2
    lb =  textview :set_content => t.render, :height => 15, :title => '[ls -l]'
    lb.bind(:PRESS){|tae|
      alert "Pressed list on line #{tae.current_index}  #{tae.word_under_cursor(nil, nil, "|")}  "
    }
    Scrollbar.new @form, :parent => lb
     #make a textview that is vienabled by default.
end

end # app
