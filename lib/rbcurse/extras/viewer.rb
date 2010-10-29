require 'rbcurse/rtextview'
require 'fileutils'

# NOTE: experimental, not yet firmed up
# If you use in application, please copy to some application folder in case i change this.
# TODO: add vi_keys here
# SUGGESTIONS WELCOME.
# @since 1.2.0
module RubyCurses
  # a data viewer for viewing some text or filecontents
  # view filename, :close_key => KEY_RETURN
  # send data in an array
  # view Array, :close_key => KEY_RETURN, :layout => [0,0,23,80]
  class Viewer
    # @param filename as string or content as array
    # @yield textview object for further configuration before display
    # NOTE: i am experimentally yielding textview object so i could supress borders
    # just for kicks, but on can also bind_keys or events if one wanted.
    def self.view what, config={} #:yield: textview
      case what
      when String # we have a path
        content = _get_contents(what)
      when Array
        content = what
      else
        raise ArgumentError, "Expecting Filename or Contents (array), but got #{what.class} "
      end
      wt = 0 # top margin
      wl = 0 # left margin
      wh = Ncurses.LINES-wt # height, goes to bottom of screen
      ww = Ncurses.COLS-wl  # width, goes to right end
      wt, wl, wh, ww = config[:layout] if config.has_key? :layout

      fp = config[:title] || ""
      pf = config.fetch(:print_footer, true)
      ta = config.fetch(:title_attrib, 'bold')
      fa = config.fetch(:footer_attrib, 'bold')

      layout = { :height => wh, :width => ww, :top => wt, :left => wl } 
      v_window = VER::Window.new(layout)
      v_form = RubyCurses::Form.new v_window
      textview = TextView.new v_form do
        name   "Viewer" 
        row  0
        col  0
        width ww
        height wh-2
        title fp
        title_attrib ta
        print_footer pf
        footer_attrib fa
      end
      textview.set_content content #, :WRAP_WORD
      
      # yielding textview so you may further configure or bind keys or events
      yield textview if block_given? # tentative
      v_form.repaint
      v_window.wrefresh
      Ncurses::Panel.update_panels
      begin
        while((ch = v_window.getchar()) != ?\C-q.getbyte(0) )
          break if ch == config[:close_key]
          # if you've asked for RETURN then i also check for 10 and 13
          break if (ch == 10 || ch == 13) && config[:close_key] == KEY_RETURN
          v_form.handle_key ch
          v_form.repaint
        end
      ensure
        v_window.destroy if !v_window.nil?
      end
    end
    private
    def self._get_contents fp
      return nil unless File.readable? fp 
      return Dir.new(fp).entries if File.directory? fp
      case File.extname(fp)
      when '.tgz','.gz'
        cmd = "tar -ztvf #{fp}"
        content = %x[#{cmd}]
      when '.zip'
        cmd = "unzip -l #{fp}"
        content = %x[#{cmd}]
      else
        content = File.open(fp,"r").readlines
      end
    end
  end  # class
end # module
if __FILE__ == $PROGRAM_NAME
require 'rbcurse/app'

App.new do 
  header = app_header "rbcurse 1.2.0", :text_center => "Viewer Demo", :text_right =>"New Improved!", :color => :black, :bgcolor => :white, :attr => :bold 
  message "Press F1 to exit from here"

    RubyCurses::Viewer.view(ARGV[0] || $0, :close_key => KEY_RETURN, :title => "Enter to close") do |t|
      # you may configure textview further here.
      #t.suppress_borders true
      #t.color = :black
      #t.bgcolor = :white
      # or
      #t.attr = :reverse
    end

end # app
end
