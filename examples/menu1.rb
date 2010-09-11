require './app'

if $0 == __FILE__
  App.new do 
    title "Demo of Menu - rbcurse"
    subtitle "Hit F1 to quit, F2 for menubar toggle"

    # TODO accelerators and 
    # getting a handle for later use
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
        menu "Find" do
          item "More", "M"
          $x = item "Less", "L" do
            #accelerator "Ctrl-X"
            command do
              alert "You clickses on Less"
            end
          end
        end
      end
    end # menubar
    mb.toggle_key = KEY_F2
    @form.set_menu_bar mb
    stack :margin_top => 10, :margin => 5 do
      field "a field", :attr => 'reverse', :block_event => :CHANGE do |fld|
        case fld.getvalue
        when "d"
          alert("Me gots #{fld.getvalue} disabling menu item Window:Find: #{$x} ")
          $x.enabled = false
        when "e"
          alert("Me gots #{fld.getvalue} enabling menubar:Window:Less and setting Accelerator to C-x")
          $x.enabled = true
          $x.accelerator = "Ctrl-X"
        end
      end
    end
  end # app
end
