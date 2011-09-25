require 'rbcurse/app'

#if $0 == __FILE__
  App.new do 
    #title "Demo of Menu - rbcurse"
    #subtitle "Hit F1 to quit, F2 for menubar toggle"
    header = app_header "rbcurse 1.2.0", :text_center => "Menubar Demo", :text_right =>"enabled"
    form = @form
    mylabel = "a field"

    # TODO accelerators and 
    # getting a handle for later use
    mb = menubar do
      #@toggle_key=KEY_F2
      menu "File" do
        item "Open", "O" do
          accelerator "Ctrl-O"
          command do 
            alert "HA!! you wanted to open a file?"
          end
        end
        menu "QuickOpen" do
          item_list do
            Dir.glob("*.rb")
          end
          command do |menuitem, text|
            #alert " We gots #{text} "
            fld = form.by_name[mylabel]
            fld.text =text
          end
        end
        menu "Close" do
          item_list do
            Dir.glob("t*.rb")
          end
        end
        item "New", "N" 
        separator
        item "Exit", "x"  do 
          command do
            throw(:close)
          end
        end
        item "Cancel Menu" do
          accelerator "Ctrl-g"
        end
        
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
          menu "Size" do
            item "Zoom", "Z"
            item "Maximize", "X"
            item "Minimize", "N"
          end
        end
      end
    end # menubar
    mb.toggle_key = FFI::NCurses::KEY_F2
    mb.color = :white
    mb.bgcolor = :blue
    @form.set_menu_bar mb
    stack :margin_top => 10, :margin => 5 do
      field mylabel, :attr => 'reverse', :block_event => :CHANGE do |e|
        message e.to_s

        case e.text
        when "d"
          #alert("Me gots #{e.text} disabling menu item Window:Find: ")
          #$x.enabled = false
        when "e"
          # TODO this alert shows data wrapped but overlaps border
          #alert("Me gots #{e.text} enabling menu item Window:Find: Adding accel ")
          #$x.enabled = true
          $x.accelerator = "Ctrl-X"
        end
      end
      @adock = nil
    keyarray = [
      ["F10" , "Exit"], nil,
      ["F2", "Menu"], nil,
      ["M-e", "Disable"], ["M-x", "XXXX"],
      ["C-?", "Help"], nil
    ]
    @adock = dock keyarray
      lbltext = "Click this to enable or disable menu option Window:Find:Less"
      blank 1
      hline :width => lbltext.length
      label :text => lbltext
      toggle :offvalue => " Enable  ", :onvalue => " Disable ", :mnemonic => 'E', :value => true do |e|
        $x.enabled = e.item.value
        header.text_right = e.item.value ? "enabled" : "disabled"
        if e.item.value 
          @adock.update_application_key_label "M-e", "M-e", "Disable"
        else
          @adock.update_application_key_label "M-e", "M-e", "Enable"
        end
        #@form.handle_key mb.toggle_key
      end
      link "a linkie"
    end # stack
  end # app
#end
