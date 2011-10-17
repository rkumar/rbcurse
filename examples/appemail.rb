require 'rbcurse/app'
require 'fileutils'
require './rmail'
# You need mailread.rb which is present in 1.8, but missing in 1.9
# I've loaded it here ... http://gist.github.com/634166 with line encoding
# You need to fix paths of local mbox files

# this will go into top namespace so will conflict with other apps!
def testchoose
  # list filters as you type
  $log.debug "called CHOOSE " if $log.debug? 
  filter = "*"
  filter = ENV['PWD']+"/*"
  str = choose filter, :title => "Files", :prompt => "Choose a file: "
end
def testnumberedmenu
  list1 =  %w{ ruby perl python erlang rake java lisp scheme chicken }
  list1[0] = %w{ ruby ruby1.9 ruby1.8.x jruby rubinius ROR }
  str = numbered_menu list1, { :title => "Languages: ", :prompt => "Select :" }
  $log.debug "17 We got #{str.class} "
  say "We got #{str} " # will get overwritten by message() as soon as repaint happens
end
def testdisplay_list
  # scrollable list
  str = display_list Dir.glob("t*.rb"), :title => "Select a file"
  $log.debug "23 We got #{str} :  #{str.class} , #{str.list[str.current_index]}  "
  message "We got #{str.list[str.current_index]} "
end
def testdisplay_text
  str = display_text_interactive File.read($0), :title => "#{$0}"
end
def testdir
  # this behaves like vim's file selector, it fills in values
  str = ask("File?  ", Pathname)  do |q| 
    q.completion_proc = Proc.new {|str| Dir.glob(str +"*").collect { |f| File.directory?(f) ? f+"/" : f  } }
    q.helptext = "Enter start of filename and tab to get completion"
  end
  message "We got #{str} "
end
def test
  #require 'rbcurse/rcommandwindow'
  #rc = CommandWindow.new
  scr = Ncurses.stdscr
  #scr.color_set $promptcolor, nil
  Ncurses.attron(Ncurses.COLOR_PAIR($promptcolor))
  Ncurses.mvprintw 27,0,"helllllo theeeerE                  "
  Ncurses.attroff(Ncurses.COLOR_PAIR($promptcolor))
  #scr.refresh() # refresh FFI NW
end
def saveas1
  @tv.saveas 
end

# experimental. 
# if components have some commands, can we find a way of passing the command to them
# method_missing gave a stack overflow.
def execute_this(meth, *args)
  $log.debug "app email got #{meth}  " if $log.debug? 
  cc = @vim.current_component
  [cc, @lb2, @tv].each do |c|  
    if c.respond_to?(meth, true)
      c.send(meth, *args)
      return true
    end
  end
  false
end

App.new do 
  ht = 24
  @messages = nil
  $unread_hash = {}
  @tv = nil
  borderattrib = :reverse
  @header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Yet Another Email Client that sucks", :text_right =>"", :color => :black, :bgcolor => :white
  message "Press F10 to exit ...................................................."


  stack :margin_top => 1, :margin => 0, :width => :EXPAND do
    # NOTE: please fix the next 2 lines based on where your mbox files reside
    model = ["~/mbox"] 
    others = "~/mail/"
    boxes = Dir.new(File.expand_path(others)).entries
    boxes.delete(".")
    boxes.delete("..")
    boxes = boxes.collect do |e| others+e; end
    model.push *boxes

    #@vim = MasterDetail.new @form, :row => 1, :col => 1, :width => :EXPAND
    @vim = master_detail :width => :EXPAND
    @dirs = list_box :list => model, :height => ht, :border_attrib => borderattrib, :suppress_borders => true
    @dirs.one_key_selection = false
    
    # commands that can be mapped to or executed using M-x
    # however, commands of components aren't yet accessible.
    def get_commands
      %w{ testchoose testnumberedmenu testdisplay_list testdisplay_text testdir saveas1 }
    end
    # we override so as to only print basename. Also, print unread count 
    def @dirs.convert_value_to_text(text, crow)
      str = File.basename(text)
      if $unread_hash.has_key?(str)
        str << " (#{$unread_hash[str]})"
      else
        str 
      end
    end
    def test1XX
      $log.debug "called test1 " if $log.debug? 
      str = choose "*.rb", :title => "Files", :prompt => "Choose a file: "
    end
    def help_text
      <<-eos
               APPEMAIL HELP 

      This is some help text for appemail.
      We are testing out this feature.

      Alt-x    -   Command mode (<tab> to see commands and select)
      :        -   Command mode
      <Enter>  -   Display mail headers for mailbox
                   Display body for selected header
      F3       -   Enable sidebars in order to change size of windows (toggle)
      F10      -   Quit application

      Some commands for using bottom of screen as vim and emacs do.

      testchoose       - filter directory list as you type
      testdir          - vim style, tabbing completes matching files
      testnumberedmenu - use menu indexes to select options
      testdisplaylist  - display a list at bottom of screen
      testdisplaytext  - display text at bottom

      -----------------------------------------------------------------------
      Hope you enjoyed this help.
      eos
    end
    @vim.set_left_component @dirs

    
    @mails = []
    headings = %w{ Stat #  Date From Subject }
    @lb2 = tabular_widget :suppress_borders => true
    @lb2.columns = headings
    @lb2.column_align 1, :right
    @lb2.column_align 0, :right
    @lb2.header_fgcolor :white
    @lb2.header_bgcolor :cyan
    @vim.set_right_top_component @lb2
    @dirs.bind :PRESS do |e|
      @lines = []
      mx = Mbox.new File.expand_path(e.text)
      mx.array_each do |text|
        @lines << text
      end
      message_immediate " #{e.text} has #{@lines.size} messages"
      $unread_hash[File.basename(e.text)] = mx.unread_count
      @lb2.set_content @lines
      @lb2.estimate_column_widths=true
      @messages = mx.mails()
    end
    @lb2.bind :PRESS do |e|
      case @lb2
      when RubyCurses::TabularWidget
        if e.action_command == :header
          # now does sorting on multiple keys
        else
          index = e.source.current_index - 1 # this should check what first data index is
          if index >= 0
            @tv.set_content(@messages[index].body, :WRAP_WORD)
          end
        end
      else
        @tv.set_content(@messages[e.source.current_index].body, :WRAP_WORD)
      end
    end
    @lb2.bind :ENTER_ROW do |e|
      @header.text_right "Row #{e.current_index} of #{@messages.size} "
      message "Row #{e.current_index} of #{@messages.size} "
      raw_message "Row #{e.current_index} of #{@messages.size} " # 2011-10-17 14:08:27
      x = e.current_index
      y = @messages.size
      #raw_progress((x*1.0)/y)
      #raw_progress([x,y])
    end

    @tv = @vim.set_right_bottom_component "Email body comes here. "
    @tv.suppress_borders true
    @tv.border_attrib = borderattrib
  end # stack
  @statusline = status_line :row => Ncurses.LINES-1
  #@statusline.command { }
  @form.bind_key(?\M-v) { test11() }
  @form.bind_key(?\M-V) { testme() }
  @form.bind_key(?\M-c) { test1() }
  @form.bind_key(?\M-C) { test2() }
end # app
