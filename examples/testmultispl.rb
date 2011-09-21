$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/lib"
require 'rbcurse'
require 'rbcurse/rmultisplit'
require 'rbcurse/rlistbox'
require 'fileutils'

#
## this sample creates a multisplitpane with n objects
##+ and move divider around using - + and =.
# TODO:
# x Status bar below to reflect full path.
# - enter to gotonext component too, or at least make visible if not
#    but now cursor is showing around everywhere
#
$counter = 0

# when displaying a filename, if directory prepend a slash.
def format list, fullname=nil
  list.collect! {|e|
    if fullname
      f = File.join(fullname, e)
    else
      f = e
    end
    if File.directory? f
      "/" + e
    else
      e
    end
  }
  list
end
# @param [Listbox] new list to bind
# @param [Array] array of lists
# @param [MultiSplit] msp object to add a new list to
def bind_list(listb, lists, splitp)
  #listb.bind(:ENTER_ROW, mylist) {|lb,list| row_cmd.call(lb,list) }
  listb.bind(:PRESS) {     
    #@status_row.text = "Selected #{tablelist.get_content()[tablelist.current_index]}"
    item = "#{listb.get_content()[listb.current_index]}"
    fullname = File.join(listb.config[:path], item)
    mylist = nil
    if File.directory? fullname
      $log.debug " DIRector is a item #{item} "
      d = Dir.new(fullname)
      mylist = d.entries
      mylist.delete "."
      mylist.delete ".."
      format(mylist, fullname)
      # NOTE that we create component with nil form as container will manage it
      if lists.empty? || lists.last == listb
        $counter += 1
        listc = Listbox.new nil do
          name  "LIST#{$counter}" 
          list mylist
          title item
          title_attrib 'reverse'
        end
        listc.one_key_selection = false
        listc.bind(:ENTER) {|l| l.title_attrib 'reverse';  }
        listc.bind(:LEAVE) {|l| l.title_attrib 'normal';  }
        # FIXME crashes if file nil
        row_cmd = lambda {|lb, oldlist| list = lb.list(); file = list[lb.current_index]; file ||= "?";  $message.value = File.join(lb.config[:path], file); }
        listc.bind(:ENTER_ROW, mylist) {|lb,list| row_cmd.call(lb,list) }
        splitp.add listc
        lists << listc
        listb.config[:child] = listc
        listc.config[:path] = File.join(listb.config[:path], item)
        bind_list(listc, lists, splitp)
      else
        #l = lists.first
        l = listb.config[:child]
        l.list_data_model.remove_all
        # if empty maybe we should remove it, but its just a demo
        # what happens is, this comes up again when going through another
        # directory. First go down rbcurse/lib/rbcurse/extras
        # then go to examples which has a shallow structure.
        l.list_data_model.insert 0, *mylist unless mylist.empty?
        l.config[:path] = fullname
        l.title = item
        while true
          n = l.config[:child]
          break if n.nil?
          n.list_data_model.remove_all
          # TODO should be removed, so focus does not go to it
          n.title = ""
          l = n
        end
        $log.debug " MYLIST #{mylist} dir #{item} "
      end
      splitp.goto_next_component
    end
  } 
end
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new((File.join(ENV['LOGDIR'] || "./" ,"rbc13.log")))

    $log.level = Logger::DEBUG

    @window = VER::Window.root_window

    catch(:close) do
      @form = Form.new @window
      r = 3; c = 7; ht = 18
      #lastrow = ht+r+5 # 26
      lastrow = Ncurses.LINES-1


      help = "F1 to quit. #{$0}  Press Enter on directory, TAB/BTAB to navigate. C-w+-= "
      RubyCurses::Label.new @form, {:text => help, :row => lastrow, "col" => 2, "color" => "yellow" }
      title = "Demo of Multi-SplitPane (Column Browse pattern)"
      RubyCurses::Label.new @form, {:text => title, :row => 1, :col => c, :color => "white" }


      splitp = MultiSplit.new @form do
          name   "mypane" 
          row  r 
          col  c
          width 70
          height ht
          split_count 3
          unlimited true
          orientation :VERTICAL_SPLIT
          max_visible 3
        end
      splitp.bind(:PROPERTY_CHANGE){|e| $message.value = e.to_s }

      $message = Variable.new
      $message.value = "Message Comes Here"
      message_label = RubyCurses::Label.new @form, {'text_variable' => $message, "name"=>"message_label","row" => ht+r+2, "col" => 1, "display_length" => 80,  "height" => 2, 'color' => 'cyan'}
      $message.update_command() { message_label.repaint } # why ?
      #message_label.row = splitp.row + splitp.height 
      #message_label.col = splitp.col
      @form.place_below(message_label)


      lists = []
      FileUtils.cd("..")
      mylist = Dir.glob('*')
      mylist.delete_if {|x| x =~ /^\./ || x =~ /^_/ || x =~ /bak$/}
      format(mylist)
      # NOTE that we create component with nil form as container will manage it
      listb = Listbox.new nil do
        name   "mainlist" 
        list mylist
        title "A short list"
        title_attrib 'reverse'
      end
      listb.config[:path] = Dir.getwd
      listb.one_key_selection = false
      splitp.add listb
      row_cmd = lambda {|lb, list| file = list[lb.current_index]; $message.value = file; # File.stat("#{cur_dir()}/#{file}").inspect 
      }
      listb.bind(:ENTER_ROW, mylist) {|lb,list| row_cmd.call(lb,list) }
      listb.bind(:ENTER) {|l| l.title_attrib 'reverse';  }
      listb.bind(:LEAVE) {|l| l.title_attrib 'normal';  }
      bind_list(listb, lists, splitp)

      # Dummy field just to see navigation from and to container
      fname = "Search"
      r, c = @form.next_position
      c += fname.length + 1
        field = Field.new @form do
          name   fname
          row  r
          col  c
          display_length  30
          bgcolor 'cyan'
          #set_buffer "abcd " 
          set_label Label.new @form, {:text => fname, :color=>'white',:bgcolor=>'red', :mnemonic=> 's'}
        end

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      counter = 0
      while((ch = @window.getchar()) != KEY_F1 )
        str = keycode_tos ch
        @form.handle_key(ch)
        @window.wrefresh
      end
    end
  rescue => ex
  ensure
    @window.destroy if !@window.nil?
    VER::stop_ncurses
    p ex if ex
    puts(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end

