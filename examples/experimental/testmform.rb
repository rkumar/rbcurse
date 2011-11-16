require 'rbcurse/core/util/app'
require 'rbcurse/experimental/widgets/multiform'

App.new do 
  header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "My Demo", :text_right =>"New Improved!", :color => :black, :bgcolor => :white, :attr => :bold 
  message "Press F10 to exit from here, F1 for help, F2 for menu"

  stack :margin_top => 2, :margin => 5, :width => 30 do

    mf = MultiForm.new @form do
      row 2
      col 2
      height 15
      width  50

      add_form "first" do |f|
        f1 = Field.new f, :name => "f1", :row => 1, :col => 10, :display_length => 15, :color => :red, :bgcolor => :white
        f2 = Field.new f, :name => "f2", :row => 2, :col => 10, :display_length => 15, :color => :cyan, :bgcolor => :red
        f1.set_buffer "ABCD"
        f2.set_buffer "1234a"
      #add_to(0, f1)
      #add_to(0, f2)
    end
      add_form "second" do |f|
        f1 = Field.new f, :name => "f1", :row => 2, :col => 10, :display_length => 15, :color => :white, :bgcolor => :blue
        f2 = Field.new f, :name => "F2", :row => 4, :col => 10, :display_length => 15, :color => :yellow, :bgcolor => :blue
        f1.set_buffer "alpha"
        f2.set_buffer "roger"
      #add_to(0, f1)
      #add_to(0, f2)
      end
    end

  end # stack
end # app
