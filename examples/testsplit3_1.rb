#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
#*******************************************************#
#                     testsplit3.rb                     #
#                 written by Rahul Kumar                #
#                    January 14, 2010                   #
#                                                       #
#  test textview, split and textarea inside splitpane   #
#                                                       #
#
#  /---------|----------\
#  |         |          |
#  | 1       |  3       |
#  +---------|----------|
#  | 2       |  4       |
#  |         |          |
#  \---------|----------/
#
#
#            Released under ruby license. See           #
#         http://www.ruby-lang.org/en/LICENSE.txt       #
#               Copyright 2010, Rahul Kumar             #
#*******************************************************#
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rsplitpane'
require 'rbcurse/rtextarea'
require 'rbcurse/rtextview'
require 'rbcurse/rlistbox'
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new("vv#{$0}.log")
    $log.level = Logger::DEBUG
    show_caret_flag = true

    @window = VER::Window.root_window

    catch(:close) do
      colors = Ncurses.COLORS
      @form = Form.new @window
      @form.name = "Form::MAINFORM"
      r = 1; c = 3; ht = 18; w = 70
      r = 3; c = 7; ht = 24; w = 100


      @help = "F1 to quit. -/+/= to resize outer split, M-, M+, M= for inner split: #{$0}"
      RubyCurses::Label.new @form, {'text' => @help, "row" => ht+r, "col" => 2, "color" => "yellow"}

        outer = SplitPane.new @form do
          name   "mainpane" 
          row  r 
          col  c
          width w
          height ht
          #focusable false
          orientation :VERTICAL_SPLIT
          #orientation :HORIZONTAL_SPLIT
          #set_resize_weight 0.60
        end
        # note that splitleft has no form. so focus has to be managed XXX
        splitleft = SplitPane.new nil do
          name   "C1-left" 
          #row  r 
          #col  c

          ## earlier commented now bombing
          width w/2 # 30
          height ht #/2-1

          #focusable false
          orientation :HORIZONTAL_SPLIT
          #orientation :VERTICAL_SPLIT
          border_color $promptcolor
          border_attrib Ncurses::A_NORMAL
        end
        splitrt = SplitPane.new nil do
          name   "C1-rt" 
          #row  r 
          #col  c

          ## earlier commented now bombing
          width w/2 # 30
          height ht #/2-1

          #focusable false
          orientation :HORIZONTAL_SPLIT
          #orientation :VERTICAL_SPLIT
          border_color $promptcolor
          border_attrib Ncurses::A_NORMAL
        end
        ta1 = TextArea.new nil do
          name   "myTextArea1-left-bot" 
          #row 0
          #col  0 
          width w/2-2
          height (ht/2)-1
          #height ht
          title "README.mark"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
        end
        #ta1.show_caret=show_caret_flag
        ta2 = TextArea.new nil do
          name   "myTextArea2-right-bot" 
          #row 0
          #col  0 
          width w/2-2
          height (ht/2)-1
          #height ht
          title "Scratch Pad"
          title_attrib 'reverse'
          print_footer true
          footer_attrib 'bold'
        end
        #ta2.show_caret=show_caret_flag

        t1 = TextView.new nil do
          name   "myView-right-top" 
          #row 0
          #col  0 
          #width w-2
          height ht
          #height (ht/2)-1
          width w/2-1
          title "README.md"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
        end
        #t1.show_caret=show_caret_flag
        content = File.open("../README.markdown","r").readlines
        t1.set_content content #, :WRAP_WORD

        # to see lower border i need to set height to ht/2 -2 in both cases, but that
        # crashes ruby when i reduce height by 1.
        t2 = TextView.new nil do
          name   "myView2-left-top" 
          #row 0
          #col  0 
          width w/2-1
          height ht
          #height (ht/2)-1
          title "NOTES"
          title_attrib 'bold'
          print_footer true
          footer_attrib 'bold'
        end
        #t2.show_caret=show_caret_flag
        content = File.open("../NOTES","r").readlines
        t2.set_content content #, :WRAP_WORD

        # the outer compo needs child set first else cursor does not reach up from
        # lower levels. Is the connection broken ?
        outer.first_component(splitleft)
        outer.second_component(splitrt)
        splitleft.first_component(t2)
        splitleft.second_component(ta1)
        splitrt.first_component(t1)
        splitrt.second_component(ta2)
        t2.preferred_width w/2 #/2  ## should pertain more to horizontal orientation
        t2.preferred_height (ht/2)-1 ## this messes things up when we change orientation
        t1.preferred_width w/2 #/2  ## should pertain more to horizontal orientation
        t1.preferred_height (ht/2)-1 ## this messes things up when we change orientation
        #t1.set_resize_weight 0.50
        t2.min_width 15
        t2.min_height 5
        t1.min_width 12
        t1.min_height 5
        ta1.min_width 10
        ta1.min_height 5
        ta2.min_width 10
        ta2.min_height 5
        ret = splitleft.reset_to_preferred_sizes
        splitleft.set_resize_weight(0.50) if ret == :ERROR
        ret = splitrt.reset_to_preferred_sizes
        splitrt.set_resize_weight(0.50) if ret == :ERROR

        splitleft.preferred_width w/2
        splitleft.preferred_height ht/2-2
        splitleft.min_width 12
        splitleft.min_height 6
        splitrt.preferred_width w/2
        splitrt.preferred_height ht/2-2
        splitrt.min_width 12
        splitrt.min_height 6
        ret = outer.reset_to_preferred_sizes
        outer.set_resize_weight(0.50) if ret == :ERROR

        File.open("../README.markdown","r") do |file|
           while (line = file.gets)
              ta1 << line.chomp
           end
        end

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != KEY_F1 )
        str = keycode_tos ch
        #case ch
        #when ?v.getbyte(0)
          #$log.debug " ORIENTATION VERTICAL"
          #outer.orientation(:VERTICAL_SPLIT)
          #outer.reset_to_preferred_sizes
        #when ?h.getbyte(0)
          #$log.debug " ORIENTATION HORIZ"
          #outer.orientation(:HORIZONTAL_SPLIT)
          #outer.reset_to_preferred_sizes
        #when ?-.getbyte(0)
          #$log.debug " KEY PRESS -"
          #outer.set_divider_location(outer.divider_location-1)
        #when ?+.getbyte(0)
          #$log.debug " KEY PRESS +"
          #outer.set_divider_location(outer.divider_location+1)
        #when ?=.getbyte(0)
          #$log.debug " KEY PRESS ="
          #outer.set_resize_weight(0.50)
        #end
        #outer.get_buffer().wclear
        #outer << "#{ch} got (#{str})"
#        outer.repaint
#        outer.buffer_to_screen
        @form.repaint
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
