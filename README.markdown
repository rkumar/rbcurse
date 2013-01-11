# rbcurse (for ruby 1.9.x)

## Please install rbcurse-core. I have just released 0.0.3 on Jan 5, 2012.

    gem install rbcurse-core

Version 1.5.2 of rbcurse will install both core and rbcurse-extras.

## WARNING

  Currently this repo (rbcurse) is in flux. I've moved stuff off to other repos (rbcurse-core, rbcurse-extras
  and rbcurse-experimental.). This will be a wrapper repo. 
  
  Please go to branch [1.4.1](https://github.com/rkumar/rbcurse/tree/1.4.1) for the last version of all code in one repo. Gem 1.4.1 is the last gem that contains all the code in one gem/repo.

  *  [rbcurse-core](https://github.com/rkumar/rbcurse-core)

  *  [rbcurse-extras](https://github.com/rkumar/rbcurse-extras)

  *  [rbcurse-experimental](https://github.com/rkumar/rbcurse-experimental)


## DESCRIPTION:

A small but comprehensive widget library written in ruby for creating ncurses/curses
applications. (Tested on 1.9.1/2, compatible with 1.8.7.)

rbcurse is now a meta-gem. It depends on core, extras and experimental. You may install core in isolation, too, if you don't want all these. Extras and experimental depend on core. rbcurse-core depends only on ffi-ncurses.

> The essence of 'simple' is knowing "what to leave out"   - attributed to Steve Jobs

## News

*  2011-11-17 - I have spun off all the code into core, extras and experimental. 
       Oh, wait, i've done all this in the 1.5.0 branch, did not think of first
       merging with master, since if things went wrong, master would be fine.

      Merged with master. Now to update the gemspecs. Done that and created gems locally.
      Am testing them out, seems okay, will release shortly.

*  2011-11-16 - I am now working on 1.5.0, so please check that branch for latest work. I am separating
   the gem into core, extras and experimental. I am also moving to ruby 1.9.3.

    *  Changes expected in 1.5.0:

       * breakup into separate gems
       * core will be stable and backward compatible (in future)
       * may have directory structure changes such as a core directory, or core/widgets
         or widgets/core and widgets/experimental etc.
       * more standardization of methods across widgets in core
       * simplification of widget interfaces and code
       * more work on stacks and flows
       * inclusion of some experimental stuff into core such as color formatting of text
       * editable tables and lists will be moved to rbcurse/extras. Non-editable versions will
         be moved into core.


*  2011-11-16 - I have released a 1.4.1.pre2 gem, and will make it 1.4.1 in a few days if all remains fine.

* After releasing 1.4.1, I will be separating this gem into core, extras and experimental.
  Until now the basic widgets have often been volatile, with sudden changes coming in minor
  versions or patch versions. With 1.5.0, I hope to keep the core stable and back-compat.

  I've totally rewritten tabbedpane and messagebox. Much simpler now. Will substitute this with 
  existing one in 1.5.0 and push the existing ones into /deprecated. There is now support for
  printing colored text in ansi-escape format or a better format based on tmux's status-line 
  config, which allows for nesting of colors. I need to iron out the interface.


*  Migrated from ncurses-ruby to ffi-ncurses since 1.3.0. Thanks Sean.

## FEATURES

* Field : text/entry fields in pure ruby (not ncurses)
* scrollable list box (also editable lists with Field, checkbox and combos)
* Textarea : multi-line editable area 
* Textview - read-only textarea with vim keys for navigation 
* togglebutton, radio and check buttons (with mnemonics)
* message box
* menubar - with submenus
* popup list
* tabbedpane (multiple forms using tabbed metaphor)
* combobox
* labels with mnemonics
* Table: multi-column table - with cell selection and editing, horizontal and
  vertical scrolling
* MultiContainer = add any number of objects to it (such as tables or text objects) and cycle through them
  (saves screen estate)
* MultiTextView - have multiple files open for viewing in one component. Since these are readonly files, one can map a lot of single-keys as in vim for operating and cycling through buffers.
* PromptMenu - A simple interactive menu like the `most` application. Saves on allocating keybindings and memorizing them.
* multiple key bindings for Procs, block and symbols (as in vim and emacs: `C-x C-f` or `15dd`)
* Kill-ring concept of emacs for cut-paste operations
* Unlimited undo and redo in TextArea/Lists (needs to be switched on at present on instance basis)
* Numeric arguments. (vim: 25dd etc. Or in an editable box, emacs's C-u or Alt-1..9)
* ScrollForm (testscroller.rb) - a form that takes more fields/objects than can be viewed at a go. Meta keys scroll the form.
* Many more.

Above may be created using DSL like syntax, or hashes, and modified at
runtime. Very flexible unlike ncurses forms and fields.


## Download rbcurse

* <https://rubygems.org/gems/rbcurse>

* <http://github.com/rkumar/rbcurse>

## Screenshots

*  <http://totalrecall.wordpress.com>   
*  <http://github.com/rkumar/rbcurse/wikis/screenshots>

## Other links

* rbcurse tutorial (WIP - please review and give feedback)
 <http://rbcurse.rubyforge.org/tut0.html>

* <http://totalrecall.wordpress.com>  - blog, status, screenshots

* <http://rdoc.info/github/rkumar/rbcurse/master> - rdoc


* Many working demos in examples folder, such as:

   * test2.rb - original test program containing various widgets, menu bar and tabbed pane

   * rfe.rb is a ruby file explorer demo.

   * sqlt.rb is a ruby sql client _demo_ (using testd.db at
     <http://www.benegal.org/files/screen/testd.db>)
    (requires gem sqlite3)
    sqlm.rb: uses a multi-container - each query opens a new table in the multicontainer

   * alpmenu.rb - an alpine like menu screen that calls the following 2 programs

       * testtodo.rb is a test TODO application (M-h to see popup menus)

       * viewtodo.rb is a test TODO viewing application (now using sqlite3). The table is readonly, some vim keys are available.

   * app.rb  - demo of the app feature. Also has progress bars (type in the textarea to see progress bar)

   * appemail.rb - a larger demo of the app feature and Column Browse pattern. Uses mbox to display mails. M-x to show commands at bottom of screen. Vim and bash-like file selection and other goodies. You will need  to supply an mbox location.

   * appdirtree - demo of file browser using Tree on left and list on right.

   * dbdemo.rb - sqlite database query program

## Major changes

* 1.4.1: More cleanup, a lot of experimental stuff that is going to be standardized soon
         color formatting of documents in ANSI or tmux format. Rewrite of 
         tabbed pane and message box.
* 1.4.0: Cleanup, some small new features, deprecated stuff, added StatusLine. 
         Improvements to 'app'.
* 1.3.0: ffi-ification of rbcurses with some minor bug-fixes, deprecations
* 1.2.0: many additions (See CHANGELOG for details)
  - App class that wraps the environment and makes application development very easy
  - New controls such as:
    - vimsplit: allows multiple vertical and horizontal splits in one component
    - progress bar
    - Tree control
    - Divider (can grab and move, so as to visually resize components)
    - Scrollbar class that can be easily attached to lists, tables etc
    - Tabular data widgets and data converters

  Please see CHANGELOG for changes.


## PROBLEMS, ISSUES

## Splitpane
   Deprecated. Please use vimsplit instead. It's cleaner and hopefully easier to use.
   Splitpanes suffered from the problem of the system not knowing which pane the user was 
   issuing a command (resize) in (when there were embedded panes). 

## Scrollpane 
   Avoid this. Listboxes and textareas already implement scrolling. I was using
   pads to implement a viewport, this was slow esp with scrollpanes within
   splitpanes, but the copywin() and related methods often gave errors or
   seg-faults. 

## General terminal related issues.

The following are issues with terminals (or with ncurses-ruby in some cases) not with rbcurse.

* Some terminals may not show underlines (e.g screen). xterm-color is fine.

* Some terminals do not process Function keys, avoid declaring F1 etc if
  unsure of client terminals. I have put in fixes for xterm-color F1 and
  backtab.

* To use ALT/META keys on a Mac OS X, in Terminal preferences, under
  Keyboard, select
  "use Option as Meta key". All hotkeys are automatically, ALT combinations.
  In Iterm2 also, go to Preferences and select "Esc" for keys.

* Some screens do not display window background color under spaces.
  This is okay under "screen" and "xterm-color" but not under "xterm" and "xterm-256color". You will notice
  this in the message box samples. I am trying hard to work around this since some terminals do not seem to
  implement windows `bkgd` method.

I am developing and testing under "gnu screen" (compiled with 256 colors) under OSX Lion, using zsh). I have 
just shifted to iTerm2 - this gives me some additional keys such as PageUp, PageDown, Home and End but takes 
away some others that Terminal gaves me such as shifted-function keys and Control-left, Ctrl-Right.

Just for information, I am transitioning from macports to homebrew. I use rvm.


## REQUIREMENTS:

* ruby 1.9.1, 1.9.2, 1.9.3 (I believe it is working on 1.8.7, 1.8.6 as well).

* ffi-ncurses (>= 0.4.0) Thanks Sean !

## INSTALL:

(In following commands, use `sudo` if installing gems in readonly are such as /opt/local/).

   `gem install rbcurse`

 Now go to the the `examples` folder and execute some examples. Each sample writes to a log file named rbc13.log (earlier view.log). If the examples folder is readonly, you will have to set `LOGDIR` to a writable folder as below.

    cd examples 
    ruby test2.rb
    LOGDIR=~/tmp ruby test1.rb

To install only the core:

   `gem install rbcurse-core`

## LICENSE:

Copyright (c) 2008 -2011 rkumar

Same as ruby license.
