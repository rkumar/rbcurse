$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/lib"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rmultisplit'
require 'rbcurse/rlistbox'
#
## this sample creates a multisplitpane with n objects
##+ and move divider around using - + and =.
# ON_LEAVE make title normal
# if possible selection should also become dimmer
# Stuatus bar below to reflect full path.
#
KEY_ENTER = 13
# @param [Listbox] new list to bind
# @param [Array] array of lists
# @param [MultiSplit] msp object to add a new list to
def bind_list(listb, lists, splitp)
  #listb.bind(:ENTER_ROW, mylist) {|lb,list| row_cmd.call(lb,list) }
  listb.bind_key(KEY_ENTER) {     
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
      $log.debug "1 MYLIST #{mylist} dir #{item} "
      if lists.empty? || lists.last == listb
        listc = Listbox.new @form do
          name  "LIST" 
          list mylist
          title item
          title_attrib 'reverse'
        end
        listc.one_key_selection = false
        listc.bind(:ENTER) {|l| l.title_attrib 'reverse';  }
        listc.bind(:LEAVE) {|l| l.title_attrib 'normal';  }
        splitp.add listc
        lists << listc
        listb.config[:child] = listc
        listc.config[:path] = File.join(listb.config[:path], item)
        bind_list(listc, lists, splitp)
      else
        #l = lists.first
        l = listb.config[:child]
        l.list_data_model.remove_all
        l.list_data_model.insert 0, *mylist
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
    end
  } 
end
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new((File.join(ENV['LOGDIR'] || "./" ,"view.log")))

    $log.level = Logger::DEBUG

    @window = VER::Window.root_window

    catch(:close) do
      colors = Ncurses.COLORS
      @form = Form.new @window
      r = 3; c = 7; ht = 18
      # filler just to see that we are covering correct space and not wasting lines or cols
      filler = "*" * 88
      (ht+2).times(){|i| @form.window.printstring(i,r, filler, $datacolor) }


      @help = "q to quit. v h - + =        : #{$0}                              . Check logger too"
      RubyCurses::Label.new @form, {'text' => @help, "row" => ht+r, "col" => 2, "color" => "yellow"}

      $message = Variable.new
      $message.value = "Message Comes Here"
      message_label = RubyCurses::Label.new @form, {'text_variable' => $message, "name"=>"message_label","row" => ht+r+2, "col" => 1, "display_length" => 60,  "height" => 2, 'color' => 'cyan'}
      $message.update_command() { message_label.repaint } # why ?

      splitp = MultiSplit.new @form do
          name   "mypane" 
          row  r 
          col  c
          width 70
          height ht
          split_count 3
          unlimited true
  #        focusable false
          orientation :VERTICAL_SPLIT
        end
      splitp.bind(:PROPERTY_CHANGE){|e| $message.value = e.to_s }

      lists = []
      mylist = Dir.glob('*')
      listb = Listbox.new @form do
        name   "mylist" 
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

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      counter = 0
      while((ch = @window.getchar()) != ?q.getbyte(0) )
        str = keycode_tos ch
        case ch
        when ?A.getbyte(0)
          next
          r = 0
        mylist = []
        counter.upto(counter+100) { |v| mylist << "#{v} scrollable data" }
        counter+=100;
        $listdata = Variable.new mylist
        listb = Listbox.new @form do
          name   "mylist" 
#         list mylist
          list_variable $listdata
          selection_mode :SINGLE
          #show_selector true
          #row_selected_symbol "[X] "
          #row_unselected_symbol "[ ] "
          title "A short list"
          title_attrib 'reverse'
          #cell_editing_allowed true
        end
        #listb.insert 55, "hello ruby", "so long python", "farewell java", "RIP .Net"
        #$listdata.value.insert 55, "hello ruby", "so long python", "farewell java", "RIP .Net"
        #listb.list_data_model.insert 55, "hello ruby", "so long python", "farewell java", "RIP .Net", "hi lisp", "hi clojure"
        splitp.add listb
        when ?V.getbyte(0)
          splitp.orientation(:VERTICAL_SPLIT)
          #splitp.reset_to_preferred_sizes
        when ?H.getbyte(0)
          splitp.orientation(:HORIZONTAL_SPLIT)
          #splitp.reset_to_preferred_sizes
        when ?-.getbyte(0)
          #splitp.set_divider_location(splitp.divider_location-1)
        when ?+.getbyte(0)
          #splitp.set_divider_location(splitp.divider_location+1)
        when ?=.getbyte(0)
          #splitp.set_resize_weight(0.50)
        end
        #splitp.get_buffer().wclear
        #splitp << "#{ch} got (#{str})"
        splitp.repaint # since the above keys are not being handled inside
        @form.handle_key(ch)
        @window.wrefresh
      end
    end
  rescue => ex
  ensure
    @window.destroy if !@window.nil?
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end

