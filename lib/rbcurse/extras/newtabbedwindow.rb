=begin
  * Name: newtabbedwindow.rb
  * Description : This is a window that contains a tabbedpane (NewTabbedPane). This for situation
      when you want to pop up a setup/configuration type of tabbed pane.
      See examples/newtabbedwindow.rb for an example of usage, and test2.rb
      which calls it from the menu (Options2 item).
     In a short while, I will deprecate the existing complex TabbedPane and use this
     in the lib/rbcurse dir.
  * Author: rkumar (http://github.com/rkumar/rbcurse/)
  * Date: 22.10.11 - 20:35
  * License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
  * Last update:  Sat Oct 22 20:35:46 IST 2011

  == CHANGES
  == TODO 
=end
require 'rbcurse'
require 'rbcurse/extras/newtabbedpane'
require 'rbcurse/rcontainer'

include RubyCurses
class NewTabbedWindow
  attr_reader :tabbed_pane
  # The given block is passed to the TabbedPane
  # The given dimensions are used to create the window.
  # The TabbedPane is placed at 0,0 and fills the window.
  def initialize config={}, &block
    
    h = config.fetch(:height, 0)
    w = config.fetch(:width, 0)
    t = config.fetch(:row, 0)
    l = config.fetch(:col, 0)
    @window = VER::Window.new :height => h, :width => w, :top => t, :left => l
    @form = Form.new @window
    config[:row] = config[:col] = 0
    @tabbed_pane = NewTabbedPane.new @form, config , &block
  end
  # returns button index
  # Call this after instantiating the window
  def run
    @form.repaint
    @window.wrefresh
    return handle_keys
  end
  # returns button index
  private
  def handle_keys
    buttonindex = catch(:close) do 
      while((ch = @window.getchar()) != FFI::NCurses::KEY_F10 )
        break if ch == ?\C-q.getbyte(0) 
        begin
          @form.handle_key(ch)
          @window.wrefresh
        rescue => err
          $log.debug( err) if err
          $log.debug(err.backtrace.join("\n")) if err
          alert "Got an exception in NewTabbedWindow: #{err}. Check log"
          $error_message.value = ""
        ensure
        end

      end # while loop
    end # close
    $log.debug "XXX: CALLER GOT #{buttonindex} "
    @window.destroy
    return buttonindex 
  end
end
