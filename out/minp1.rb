#!/usr/bin/env ruby -w
require 'menu'

Menu.create 'MyMenu'  do

  mystr=<<EOS
#  some text
EOS
  myfuncs mystr

  header 0,0, "KillerCurses, V 0.0    MAIN MENU "
  label 'copy' do
    position(-4,28) 
    text "Copyright 2008, University of Antartica"
    color_pair 5
  end

  # simplified one line way
  #        1.key 2.short  3. long desc   4.procedure to call 5.Associate
  #        message to show below in bottom bar when cursor on item
  menuitem :c do 
    key 'C'
    short "Compose" 
    long "Compose a message" 
    action "Gen2" 
    message "Compose"
  end
  menuitem :k do
    key 'I'
    short "TransactionViewer"
    long "View Index of messages"
    action "TransactionViewer"
    message "Index"
  end
  menuitem :l do
    key 'L'
    short "Folder List"
    long "Select a folder to view"
    action ":folder"
    message "Folder"
  end
  menuitem :h do
    key '?'
    short "Help"
    long "Get help on using KillerCurses"
    action ":help"
    message "Help"
  end
  menuitem :q do
    key 'Q'
    short "Quit"
    long "Leave the KillerCurses program"
    action "quit"
    message "Quit"
  end
end
