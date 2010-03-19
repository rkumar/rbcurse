# rbcurse (for ruby 1.9.1)

* Version to work with ruby 1.9 (backward compatible with 1.8.7)

This branch - RFED19 - contains major rework on the buffering approach. It only affect
programs that have used buffers such as splitpanes, scrollpanes and tabbedpanes.
All are fixed.

Check downloads at <http://github.com/rkumar/rbcurse/downloads>

Some of the samples mentioned below may **not** work. test2.rb works - i always give it a quick run after making changes. All the testsplit* and testscroll* examples are working.

* <http://totalrecall.wordpress.com>  - always has some status posted.

* Notes on rbcurse - very frequent updates <http://rbcurse.tumblr.com/>

* rbcurse on rubyforge: <http://rbcurse.rubyforge.org/> - Not updated.

* See changes on (not updated often)
 <http://github.com/rkumar/rbcurse/tree/master/CHANGELOG>

* Many working demos in examples folder, such as:

  * test2.rb (exit with F1, Or Cancel button/Alt-C) contains various
    widgets. F2 for menubar toggling

  * rfe.rb is a ruby file explorer demo.

  * sqlc.rb is a ruby sql client _demo_ (using testd.db at
     <http://www.benegal.org/files/screen/testd.db>)
    (requires gem sqlite3-ruby)
    sqlc.rb: uses tabbedpanes - each query opens a new tab
    sqlm.rb: uses a multi-container - each query opens a new table in the multicontainer

  * testtodo.rb is a test TODO application (now using fastercsv)
    (needs retesting - may not work at all)

* Screenshots on 
  <http://www.benegal.org/files/screen/?M=D>   (new)
  and on blog, <http://totalrecall.wordpress.com>   
  and http://github.com/rkumar/rbcurse/wikis/screenshots (old)

* Todo (for 0.1.2):
 <http://rubyforge.org/pm/task.php?group_id=7775&group_project_id=13812&func=browse>

  See [TODO2.txt](http://github.com/rkumar/rbcurse/blob/rbcurse19/TODO2.txt) (created and maintained by [todoapp.sh](http://github.com/rkumar/todoapp), also hosted here)

* Next Major Release:
 <http://rubyforge.org/pm/task.php?group_project_id=13813&group_id=7775&func=browse>

## DESCRIPTION:

A small but comprehensive widget library written in ruby for creating ncurses
applications.

## FEATURES

* Field : text/entry fields in pure ruby (not ncurses)
* scrollable list box (also editable lists with Field, checkbox and combos)
* Textarea : multi-line editable area 
* togglebutton, radio and check buttons (with mnemonics)
* message box
* menubar - with submenu and CheckBoxMenuItem
* popup list
* tabbedpane (multiple forms using tabbed metaphor)
* combobox
* labels with mnemonics (hotkeys)
* Table: multi-column table - with cell selection and editing, horizontal and
  vertical scrolling
* Scrollpanes which can contain textviews, textareas, listboxes.
* Splitpanes which can contain scrollpanes, textviews/areas, listboxes *or splitpanes* ...
* MultiContainer = add any number of objects to it (such as tables or text objects) and cycle through them
  (saves screen estate)
* MultiTextView - have multiple files open for viewing in one component. Since these are readonly files, one can map a lot of single-keys as in vim for operating and cycling through buffers.
* Textview - editable option using vim like keys.
* PromptMenu - A simple interactive menu like the `most` application. Saves on allocating keybindings and memorizing them.
* multiple key bindings for Procs, block and symbols (as in vim and emacs: `C-x C-f` or `15dd`)
* Kill-ring concept of emacs for cut-paste operations
* Unlimited undo and redo in TextArea (needs to be switched on at present on instance basis)
* Numeric arguments. (vim: 25dd etc. Or in an editable box, emacs's C-u or Alt-1..9)
* Various others, too

Above may be created using DSL like syntax, or hashes, and modified at
runtime. Very flexible unlike ncurses forms and fields.

## Current work

I've just added vi and emacs key bindings to some classes, multiple object containers such as MultiContainer
and MultiTextView. Emacs like kill-ring in TextArea and TextView. Tabbedpane can have unlimited tabs, we can scroll the tabs. Bunch of other stuff. Multiple keys can be bound to a Proc or symbol as in emacs and vim (dd or C-x C-f).

I've made a demo using ScrollForm (testscroller.rb)- a form that takes more fields/objects than
can be viewed at a go. Meta keys scroll the form.
Then onto testing what's there, before making a stable
release.

## Sample programs:

*  test2.rb  most widgets (including menus)
*  sqlc.rb is a ruby sql client demo (using sqlite3-ruby)
*  rfe : file explorer or Finder like app
*  testcombo.rb  combos with various insert policies and vertical
   alignments
*  testtodo.rb  : a todo app based on a yaml file (now csv)
*  testmenu.rb  : popup menu with multiple levels
*  testtabp.rb  tabbed pane
*  test1.rb  various kinds of messageboxes (input, list, custom)
   pass 1,2,3,4, or 5 as argument on command line
   ruby test1.rb 1
   ruby test1.rb 2
*  test2.rb  most widgets (including menus)
   - partially tested, many widgets, needs thorough testing.

*  testscroll*.rb - various demos of scrollpanes with listboxes, text areas, tables etc

*  testsplit*.rb - various splitpanes with scrollpanes and other objects placed inside
   See screenshots on blog.

*  testtpane.rb  - tabbedpane sample with a scrollpane and a textobject. 

## PROBLEMS, ISSUES


## General terminal related issues.

The following are issues with terminals (or with ncurses-ruby in some cases) not with rbcurse.

* Some terminals may not show underlines (e.g screen).

* Some terminals (xterm-color) do not process Function keys, avoid declaring F1 etc if
  unsure of client terminals. I have put in fixes for xterm-color F1 and
  backtab.

* To use ALT/META keys on a Mac OS X, in Terminal preferences, under
  Keyboard, select
  "use Option as Meta key". All hotkeys are automatically, ALT combinations.

* Some screens do not display window background color under spaces.
  This is okay under "screen" and "xterm-color" but not under "xterm". You will notice
  this in the message box samples.

I am developing and testing under "screen" under OS X Leopard 10.5.8 PPC.

## SYNOPSIS:

See lib/rbcurse/rwidgets.rb.
For test programs, see test1, test2, testcombo etc in examples folder.

This depends only on "window" provided by ncurses. Does not use forms
and fields. Minor changes and improvements may have happened to sample
code below. **See test programs for latest, working code.**

THE following samples are only demonstrative of how widgets are built. See samples in examples folder for initialization of ncurses etc which is necessary before the following code can be run. The following samples may be slightly obsolete.

### create a window and a form based on window

      @layout = { :height => 0, :width => 0, :top => 0, :left => 0 } 
      @win = VER::Window.new(@layout)

      @form = Form.new @win


### create a bunch of fields with dependent labels

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

### create a variable (like TkVariable) and tie a label to it.

      $results = Variable.new
      $results.value = "A variable"
      var = RubyCurses::Label.new @form, {'text_variable' => $results, "row" => r, "col" => 22}
        r += 1

### create a list and a list box based on the list.

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

### create a textarea for entry 

        texta = TextArea.new @form do
          name   "mytext" 
          row  1 
          col  52 
          width 40
          height 20
        end
        texta << "hello there" << "Some text to go into textarea."
        texta << "HELLO ruby" << "Some text to go into textarea."

### create a check box, updates a Variable

      checkbutton = CheckBox.new @form do
        text_variable $results
        #value = true
        onvalue "selected cb"
        offvalue "UNselected cb"
        text "Please click me"
        row 17
        col 22
      end

### change field properties at any time by referring to them by name

      @form.by_name["age"].display_length = 3
      @form.by_name["age"].maxlen = 3
      @form.by_name["age"].set_buffer  "24"
      @form.by_name["name"].set_buffer  "Not focusable"
      @form.by_name["age"].chars_allowed = /\d/
      @form.by_name["company"].type(:ALPHA)
      @form.by_name["name"].set_focusable(false)

      @form.by_name["password"].color 'red'
      @form.by_name["password"].bgcolor 'blue'

      # restrict entry to some values
      password.values(%w[ scotty tiger secret qwerty])

      # validation using ruby's regular expressions

      field.valid_regex(/^[A-Z]\d+/)

### bind events to forms, and fields

      @form.bind(:ENTER) { |f|   f.label.bgcolor = $promptcolor if f.instance_of? RubyCurses::Field}
      @form.bind(:LEAVE) { |f|  f.label.bgcolor = $datacolor  if f.instance_of? RubyCurses::Field}

### create buttons

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

### create radio buttons

      colorlabel = Label.new @form, {'text' => "Select a color:", "row" => 20,
          "col" => 22, "color"=> "cyan"}
      $radio = Variable.new
      radio1 = RadioButton.new @form do
        text_variable $radio
        text "red"
        value "red"
        color "red"
        row 21
        col 22
      end
      radio2 = RadioButton.new @form do
        text_variable $radio
        text  "green"
        value  "green"
        color "green"
        row 22
        col 22
      end

### create a messagebox 

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

### create a read-only scrollable view of data
 
        @textview = TextView.new @form do
          name   "myView" 
          row  16 
          col  52 
          width 40
          height 7
        end
        content = File.open("../../README.markdown","r").readlines
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

        # change the value of colorlabel to the selected radiobutton
        # (red or green)

        $radio.update_command(colorlabel) {|tv, label|  label.color tv.value}

        # change the attribute of colorlabel to bold or normal

        $results.update_command(colorlabel,checkbutton) {|tv, label, cb| 
            attrs =  cb.value ? 'bold' : nil; label.attrs(attrs)}

      # during menu creation, create a checkboxmenuitem

      item = RubyCurses::CheckBoxMenuItem.new "CheckMe"

      # when selected, make colorlabel attribute reverse.

      item.command(colorlabel){|it, label| att = it.getvalue ? 'reverse' :
          nil; label.attrs(att); label.repaint}

## REQUIREMENTS:

* ruby 1.9.1 (I believe it is working on 1.8.7 as well).

* ncurses-ruby (1.2.4)

(Note: 1.8.6 users: pls report any issues and suggest a fix or alternative if you encounter a method_missing)


## INSTALL:

STEP 1.

   `sudo gem install ncurses-ruby`

If the above fails, then do as follows:

Somehow at the time of writing the above installs a version that does
not work with 1.9. So you have to download ncurses-ruby (1.2.4) tgz from
<http://ncurses-ruby.berlios.de/> as follows:

1. Download <http://prdownload.berlios.de/ncurses-ruby/ncurses-ruby-1.2.4.tar.bz2>
2. unzip the file, cd into dir
2. run install commands as per README (`ruby extconf.rb && make`)
3. Create a gemspec ... use this file <http://gist.github.com/201877>
   Save it as ncurses.gemspec 
4. `sudo gem build ncurses.gemspec`
5. `sudo gem install --local ncurses-1.2.4.gem`
6. **uninstall** any previous ncurses or ncurses-ruby version otherwise
errors will persist at runtime.
7. check with `gem list --local` and you should see ncurses (1.2.4). The
 examples in the ncurses-ruby/examples folder should work. (Check the
first line regarding interpreter first).
8. As a last resort, I've put up a copy of the gem [here](http://www.benegal.org/files/ncurses-1.2.4.gem).

(edit: I am told that step 2 installs ncurses-ruby locally, so you don't need to create a gem)

STEP 2.

   `sudo gem install rbcurse`

 Now go to the the `examples` folder and execute some examples.

    cd examples 
    ruby test2.rb


Note: if you are downloading the git repo, you may find that the Manifest.txt does not contain some files, or README.txt has changed to README.markdown. I have not been creating a 1.9 gem while testing changes, so the Manifest can be outdated. I'll try to keep it updated.

## LICENSE:

Copyright (c) 2008 -2010 rkumar

Same as ruby license.
