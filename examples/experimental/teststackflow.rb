# #!/usr/bin/env ruby -w
=begin
  * Name          : teststackflow.rb
  * Description   : to test Container2.rb (to be renamed)
  *               :
  * Author        : rkumar http://github.com/rkumar/rbcurse/
  * Date          : 25.10.11 - 12:57
  * License       :
  * Last update   : Use ,,L to update
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end


if __FILE__ == $PROGRAM_NAME
  require 'rbcurse/core/util/app'
  require 'rbcurse/extras/widgets/rlistbox'
  require 'rbcurse/experimental/stackflow'
  App.new do

    lb = Listbox.new nil, :list => ["borodin","berlioz","bernstein","balakirev", "elgar"] , :name => "mylist"
    lb1 = Listbox.new nil, :list => ["bach","beethoven","mozart","gorecki", "chopin","wagner","grieg","holst"] , :name => "mylist1"

    lb2 = Listbox.new nil, :list => `gem list --local`.split("\n") , :name => "mylist2"

    alist = %w[ ruby perl python java jruby macruby rubinius rails rack sinatra pylons django cakephp grails] 
    str = "Hello, people of Earth.\nI am HAL, a textbox.\nUse arrow keys, j/k/h/l/gg/G/C-a/C-e/C-n/C-p\n"
    str << alist.join("\n")
    require 'rbcurse/core/widgets/rtextview'
    tv = TextView.new nil, :name => "text"
    tv.set_content str
=begin
    f1 = field "name", :maxlen => 20, :display_length => 20, :bgcolor => :white, 
      :color => :black, :text => "abc", :label => " Name: ", :label_color_pair => @datacolor
    f2 = field "email", :display_length => 20, :bgcolor => :white, 
      :color => :blue, :text => "me@google.com", :label => "Email: ", :label_color_pair => @datacolor
    f3 = radio :group => :grp, :text => "red", :value => "RED", :color => :red
    f4 = radio :group => :grp, :text => "blue", :value => "BLUE", :color => :blue
    f5 = radio :group => :grp, :text => "green", :value => "GREEN", :color => :green
=end

    f1 = Field.new nil, :maxlen => 20, :display_length => 20, :bgcolor => :white, 
      :color => :black, :text => "abc", :label => " Name: ", :label_color_pair => @datacolor,
      :valid_regex => /[A-Z][a-z]*/
    f2 = Field.new nil, :display_length => 20, :bgcolor => :white, 
      :color => :blue, :text => "me@google.com", :label => "Email: ", :label_color_pair => @datacolor
    f3 = Field.new nil, :display_length => 20, :bgcolor => :white, 
      :color => :blue, :text => "24", :label => "Age: ", :label_color_pair => @datacolor,
      :valid_range => (20..100)
    r = StackFlow.new @form, :row => 1, :col => 2, :width => 80, :height => 25, :title => "Stack n Flow with margins" do
      #stack :margin_top => 2, :margin_left => 1 do
        flow :margin_top => 0, :margin_left => 2, :margin_right => 0, :orientation => :right do #:weight => 49 do 
          add tv, :weight => 40
          add lb2 , :weight => 50
        end
        stack :margin_top => 0, :orientation => :bottom do #stack :height => 12, :width => 78 do
          add lb, :weight => 40, :margin_left => 1
          add lb1 , :weight => 40
          #add f1
        #stack :weight => 30 do
        #add f1
        #add f2
        #add f3
        end
      #end # stack
    end # r
    def increase_height
      @r.height += 1
      @r.repaint_all(true)
    end
    def increase_width
      @r.width += 1
      @r.repaint_all(true)
    end
    @r = r
    @r.bind_key(?\M-w) {increase_width}
    @r.bind_key(?\M-h) {increase_height}
    @r.bind_key(0) {
      f = @r.item_for tv
      f1 = @r.item_for lb2
      p = @r.parent_of tv
      p1 = @r.parent_of lb2
      $log.debug "XXX: ITEM_FOR tv is #{f}, #{f1}  #{p} , #{p1} "
      @ctr ||= 0
      case @ctr
      when 0
        @r.components[0].orientation = :left
      when 1
        @r.components[0].orientation = :right
      when 2
        @r.components[1].orientation = :top
      when 3
        @r.components[1].orientation = :bottom
      else
        @ctr = -1
      end
      $status_message.value =" Flow: #{@r.components[0].orientation} | Stack #{@r.components[1].orientation}. Use C-Space to change "
      @r.repaint_all(true)
      @ctr += 1

    }
    $status_message.value =" Flow: #{@r.components[0].orientation} | Stack #{@r.components[1].orientation}. Use Ctrl-Space to change "

    #r.add(f1)
    #r.add(f2)
    #r.add(f3,f4,f5)
    #sl = status_line

    st = status_line
  end # app
end # if 
