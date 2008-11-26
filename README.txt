= rbcurse

* http://totalrecall.blogspot.com

* See latest changes on http://github.com/rkumar/rbcurse/tree/master/CHANGELOG

* For a working example, execute rform.rb and rwidget.rb (exit with F1).

* screenshots on blog mentioned above.
  Sample: http://www.benegal.org/files/nc_screen_textview.png

== DESCRIPTION:

A small widget library written in ruby for creating ncurses
applications.
See lib/rbcurse/rwidgets.rb and lib/rbcurse/rform.rb.

== FEATURES

* entry fields in ruby 
* scrollable list box
* multi-line editable area
* radio and check buttons
* message box
* menubar 

Above may be created using DSL like syntax, or hashes.

== PROBLEMS

* ncurses colors use color-pairs. Thus one has to select a color pair,
  although the description of the widgets does allow for selecting
  foreground and background color.

  Some other developers like that of "sup" have done a lot of work in
trying to work around this problem, but the code was very complex (for
me) and I was not confident in integrating all that. In order that
applications are light and fast, I hope to keep the behind-the-scenes
work minimal.


== SYNOPSIS:

See lib/rbcurse/rwidgets.rb and lib/rbcurse/rform.rb.

This depends only on "window" provided by ncurses. Does not use forms
and fields.

=== create a window and a form based on window

      @layout = { :height => 0, :width => 0, :top => 0, :left => 0 } 
      @win = VER::Window.new(@layout)

      @form = Form.new @win


=== create a bunch of fields with dependent labels

      r = 1; c = 22;
      %w[ name age company].each do |w|
        field = Field.new @form do
          name   w 
          row  r 
          col  c 
          display_length  30
          set_buffer "abcd #{w}" 
          set_label Label.new @form, {'text' => w}
        end
        r += 1
      end

=== create a variable (like TkVariable) and tie a label to it.

      $results = Variable.new
      $results.value = "A variable"
      var = RubyCurses::Label.new @form, {'text_variable' => $results, "row" => r, "col" => 22}
        r += 1

=== create a list and a list box based on the list.

        mylist = []
        0.upto(100) { |v| mylist << "#{v} scrollable data" }

        field = Listbox.new @form do
          name   "mylist" 
          row  r 
          col  1 
          width 40
          height 10
          list mylist
        end
        field.insert 5, "hello ruby", "so long python", "farewell java", "RIP .Net"

=== create a textarea for entry (this can be buggy at present)

        texta = TextArea.new @form do
          name   "mytext" 
          row  1 
          col  52 
          width 40
          height 20
        end
        texta << "hello there" << "we are testing deletes in this application"
        texta << "HELLO there" << "WE ARE testing deletes in this application"

=== create a check box, updates a Variable

      checkbutton = CheckBox.new @form do
        text_variable $results
        #value = true
        onvalue "selected cb"
        offvalue "UNselected cb"
        text "Please click me"
        row 17
        col 22
      end

=== change field properties at any time by referring to them by name

      @form.by_name["age"].display_length = 3
      @form.by_name["age"].maxlen = 3
      @form.by_name["age"].set_buffer  "24"
      @form.by_name["name"].set_buffer  "Not focusable"
      @form.by_name["age"].chars_allowed = /\d/
      @form.by_name["company"].type(:ALPHA)
      @form.by_name["name"].set_focusable(false)

=== bind events to forms, and fields

      @form.bind(:ENTER) { |f|   f.label.bgcolor = $promptcolor if f.instance_of? RubyCurses::Field}
      @form.bind(:LEAVE) { |f|  f.label.bgcolor = $datacolor  if f.instance_of? RubyCurses::Field}

=== create buttons

      ok_button = Button.new @form do
        text "OK"
        name "OK"
        row 18
        col 22
      end
      ok_button.command { |form| $results.value = "OK PRESS:";form.printstr(@window, 23,45, "OK CALLED") }
        #text "Cancel"
      cancel_button = Button.new @form do
        text_variable $results
        row 18
        col 28
      end
      cancel_button.command { |form| form.printstr(@window, 23,45, "Cancel CALLED"); throw(:close); }

=== create radio buttons

      Label.new @form, {'text' => "Select a language:", "row" => 20, "col" => 22}
      $radio = Variable.new
      radio1 = RadioButton.new @form do
        text_variable $radio
        text "ruby"
        value "ruby"
        row 21
        col 22
      end
      radio2 = RadioButton.new @form do
        text_variable $radio
        text  "java"
        value  "java"
        row 22
        col 22
      end

=== create a messagebox 

      @mb = RubyCurses::MessageBox.new do
        title "Enter your name"
        message "Enter your name"
        type :input
        default_value "rahul"
        default_button 0
      end
        #title "Color selector"
        #type :custom
        #buttons %w[red green blue yellow]
        #underlines [0,0,0,0]
      
     $log.debug "MBOX : #{@mb.selected_index} "
     $log.debug "MBOX : #{@mb.input_value} "

=== create a read-only scrollable view of data
 
        @textview = TextView.new @form do
          name   "myView" 
          row  16 
          col  52 
          width 40
          height 7
        end
        content = File.open("../../README.txt","r").readlines
        @textview.set_content content

        ## set it to point to row 21
        @textview.top_row 21


        # lets scroll the text view as we scroll the listbox

        listb.bind(:ENTER_ROW, @textview) { |arow, tview| tview.top_row arow }
        
        # lets scroll the text view to the line you enter in the numeric
        # field
        @form.by_name["line"].bind(:LEAVE, @textview) { |fld, tv| tv.top_row(fld.getvalue.to_i) }

        # lets scroll the text view to the first match of the regex you
        # enter
        @form.by_name["regex"].bind(:LEAVE, @textview) { |fld, tv| tv.top_row(tv.find_first_match(fld.getvalue)) }

== REQUIREMENTS:

* ruby 1.8.7    (not compatible with 1.9)

* ncurses-ruby

(following is provided with source)

* uses the window class created by "manveru" (michael) - this can be
  removed if not needed. (lib/ver/window)
  It is provided with this package, and has some alterations from the
  original.

* in the message box sample, i am catching keys using manveru's
  keyboard.rb. This allows me to get M-keys which i am not getting
  otherwise. However, his module returns string for all keys, whereas
  our applications may already expect ints. Thus, i modified it a bit
  yesterday to return ints. You can thus remove references to it, if you
  want to just catch the key in a loop and process. The original is
  lib/ver/keyboard.rb and the modified is lib/ver/keyboard2.rb.

== INSTALL:

* currently, just unzip/untar in a folder. Please change the path in
  the top line.

(Please advice me how i can improve installation procedure)

== LICENSE:

Copyright (c) 2008 rkumar

Same as ruby license.
