require './app'

if $0 == __FILE__
  App.new do 
    #title "Demo of Menu - rbcurse"
    #subtitle "Hit F1 to quit, F2 for menubar toggle"
    header = app_header "rbcurse 1.2.0", :text_center => "Alpine Menu Demo", :text_right =>""

    # TODO accelerators and 
    # getting a handle for later use
    stack :margin_top => 10, :margin => 15 do
      #w = "Messages".length + 1
      w = 60
      menulink "&Messages", :width => w, :description => "View messages in current folder"  do |s|
        message "Pressed #{s.text} "
      end
      blank
      menulink "&Compose", :width => w, :description => "Compose a mail"  do |s|
        message "Pressed #{s.getvalue} "
      end
      blank
      menulink "Setup", :mnemonic => "?", :width => w, :description => "Configure Alpine options"  do |s|
        message "Pressed #{s.text} "
      end
      @form.bind(:ENTER) do |w|
        header.text_right = w.text
      end
    end # stack
  end # app
end
