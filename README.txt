= rbcurse

* http://totalrecall.blogspot.com

== DESCRIPTION:

A small widget library written in ruby for creating ncurses
applications.
See lib/rbcurse/rwidgets.rb and lib/rbcurse/rform.rb.

== FEATURES/PROBLEMS:

* entry fields in ruby 
* scrollable list box
* multi-line editable area
* radio and check buttons
* message box
* menubar 

Above may be created using DSL like syntax, or hashes.

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

== REQUIREMENTS:

* ncurses-ruby
* uses the window class created by "manveru" (michael) - this can be
  removed if not needed. (lib/ver/window)

== INSTALL:

* currently, just unzip/untar in a folder.

== LICENSE:

Copyright (c) 2008 rkumar

Same as ruby license.
