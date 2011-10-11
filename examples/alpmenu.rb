require 'rbcurse/app'

  App.new do 
    #title "Demo of Menu - rbcurse"
    #subtitle "Hit F1 to quit, F2 for menubar toggle"
    header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Alpine Menu Demo", :text_right =>""
    message_row(27)

    stack :margin_top => 10, :margin => 15 do
      #w = "Messages".length + 1
      w = 60
      menulink "&View Todo", :width => w, :description => "View TODO in sqlite"  do |s|
        message "Pressed #{s.text} "
        require './viewtodo'; todo = ViewTodo::TodoApp.new; todo.run
      end
      blank
      menulink "&Edit Todo", :width => w, :description => "Edit TODO in CSV"  do |s|
        message "Pressed #{s.text} "
        require './testtodo'; todo = TestTodo::TodoApp.new; todo.run
      end
      blank
      menulink "&Messages", :width => w, :description => "View messages in current folder"  do |s|
        message "Pressed #{s.text} "
        load './menu1.rb'
      end
      blank
      menulink "&Compose", :width => w, :description => "Compose a mail"  do |s|
        message "Pressed #{s.getvalue} "
      end
      blank
      menulink "Setup", :mnemonic => "?", :width => w, :description => "Configure Alpine options"  do |s|
        message "Pressed #{s.text} "
      end
      blank
      menulink "&Quit", :width => w, :description => "Quit this application"  do |s|
        quit
      end
      @form.bind(:ENTER) do |w|
        header.text_right = w.text
      end
    end # stack
  end # app
