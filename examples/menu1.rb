require './app'

if $0 == __FILE__
  App.new do 
    title "Demo of Menu - rbcurse"
    subtitle "Hit F1 to quit, F2 for menubar toggle"

    mb = menubar do
      #@toggle_key=KEY_F2
      menu "File" do
        item "Open", "O" do
          command do
            alert "HA!! you wanted to open a file?"
          end
        end
        item "New", "N" 
        separator
        item "Close", "C" 
        
      end # menu
      menu "Window" do
        item "Tile", "T"
      end
    end # menubar
    mb.toggle_key = KEY_F2
    @form.set_menu_bar mb
    stack :margin_top => 10, :margin => 5 do
      field "a field", :attr => 'reverse'
    end
  end # app
end
