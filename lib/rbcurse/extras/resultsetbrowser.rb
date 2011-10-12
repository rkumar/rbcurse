require 'rbcurse/rscrollform'
require 'fileutils'

# See tabbed pane, and add_cols nad add_rows, on_entr and set_form_row to see cursor issue
# remove main form 
# don't make a widget just an object
# let it create own form.

# NOTE: experimental, not yet firmed up
# If you use in application, please copy to some application folder in case i change this.
# Can be used for print_help_page
# SUGGESTIONS WELCOME.
# @since 1.4.1
module RubyCurses

  class ResultsetBrowser #< Widget
    #include EventHandler
    include ConfigSetup
    include RubyCurses::Utils
    #dsl_property :xxx
    # I don't think width is actually used, windows width matters. What of height ?
    # THATS WRONG , i cannot eat up window. I should use object dimentsion for pad,
    #  not window dimensions
    dsl_accessor :row, :col, :height, :width
    dsl_accessor :should_print_border

    def initialize win, config={}, &block
      @should_print_border = true
      @v_window = win #form.window
      @window = @v_window
      @focusable = true
      @editable  = true
      @old_index = @current_index = 0
      @fields = nil
      config_setup config 
      instance_eval &block if block_given?
      init_vars
    end
    def map_keys
      @v_form.bind_key(?\C-n) { @current_index += 1 if @current_index < @rows.count-1 }
      @v_form.bind_key(?\C-p) {  @current_index -= 1  if @current_index > 0 }
      @mapped = true
    end
    def init_vars
      @row ||= 0
      @col ||= 0
      @height ||= 15
      @width ||= 50
      @field_offset = 14   # where actual Field should start (leaving space for label)
      @row_offset ||= 0
      @col_offset ||= 1
      @border_offset = 0
      if @should_print_border
        @border_offset = 1
      end
      @v_form = RubyCurses::ScrollForm.new @v_window
      @v_form.display_h(@height-1-@border_offset*2) if @height
      @v_form.display_w(@width-1-@border_offset*2)  if @width
    end
    def data=(rows)
      @rows = rows
    end
    def columns=(columns)
      @columns = columns
      h = @columns.count + 2
      w = 150 
      #row = 1
      #col = 1
      row = @row + @border_offset
      col = @col + @border_offset
      @v_form.set_pad_dimensions(row, col, h, w)
      @v_form.should_print_border(false) # this should use dimensions of object not window. # 2011-10-12 15:48:14
      # currently I don't have space for any buttons or anything.  The form takes all space of the window
      # not of the object defined.
      # I should be able to tell Scrollform to use only thismuch of window.
    end
    def set_form_row
      f = @v_form.get_current_field
      f.set_form_row
    end
    def handle_key ch
      map_keys unless @mapped
      $log.debug "XXX: RB HK got ch "
      ret =  @v_form.handle_key ch
      #set_form_row
      if ret == :UNHANDLED
        @v_form.process_key ch, self
      end
      repaint
      @v_window.wrefresh
    end
    def repaint
      @fields ||= _create_fields
      #alert "old #{@old_index} , #{@current_index} "
      if @old_index != @current_index
        #alert "index change"
        row = @rows[@current_index]
        @columns.each_with_index { |e, i|  
          value = row[i]
          len = value.to_s.length
          type=@rows[0].types[i]
          if type == "TEXT"
            value = value.gsub(/\n/," ") if value
          end
          f = @fields[i]
          @fields[i].set_buffer(value)
          if f.display_length < len && len < (@width - @field_offset)
            @fields[i].display_length len
          end
        }
        @v_form.repaint
        @window.wrefresh
        Ncurses::Panel.update_panels
        @old_index = @current_index
      end
    end
    # maybe not required since we don't have 2 forms now
    def unused_on_enter
      if $current_key == KEY_BTAB
        c = @v_form.widgets.count-1
        @v_form.select_field c
      else
        @v_form.select_field 0
      end
    end
    private
    def _create_fields
      color = $datacolor
      if @should_print_border
        @v_window.print_border @row, @col, @height-1, @width, color #, Ncurses::A_REVERSE
        @row_offset += 1
        @col_offset += 1
      end
      $log.debug "XXX: ROWS#{@rows}"
      $log.debug "XXX: COLS#{@columns}"
      $log.debug "XXX: row#{@rows[@current_index]}"
      fields = []
      r = @row + @row_offset   # row was for where to print the total object, not this
      c = @col + @col_offset + @field_offset # 14 is to leave space for labels
      v_form = @v_form
      @columns.each_with_index { |e, index| 
        #break if index >= @height-1 # create only as much space we have, SUCKS but just trying till be scroll
        #$log.debug "XXX: #{r} #{c} EACH #{e}, #{index}, #{@rows[@current_index][index]}"
        value=@rows[@current_index][index]
        type=@rows[0].types[index]
        if type == "TEXT"
          value = value.gsub(/\n/," ") if value
        end
        len = [value.to_s.length, (@width - @field_offset)].min
        f = Field.new v_form do 
          name  e
          row  r
          col c 
          bgcolor 'blue'
          highlight_background 'cyan'
          set_buffer value
          display_length len
          set_label Label.new v_form, {'text' => e, 'color'=>'cyan'}
        end
        fields << f
        r += 1
      }
      @v_form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      #$log.debug "XXX: created fields "
      return fields
    end
    
    # ADD HERE
    
  end # class
end # module
module RubyCurses
  # a data viewer for viewing some text or filecontents
  # view filename, :close_key => KEY_RETURN
  # send data in an array
  # view Array, :close_key => KEY_RETURN, :layout => [0,0,23,80]
  # when passing layout reserve 4 rows for window and border. So for 2 lines of text
  # give 6 rows.
  class Browser
    def self.browse_sql dbname, tablename, sql, config={} #:yield: ???
      raise "file not found" unless File.exist? dbname
      require 'sqlite3'
      db = SQLite3::Database.new(dbname)
      columns, *rows = db.execute2(sql)
      #$log.debug "XXX COLUMNS #{sql}  "
      content = rows
      return nil if content.nil? or content[0].nil?
      datatypes = content[0].types 
      self.browse db, tablename, columns, rows, config
    end
    # @param filename as string or content as array
    # @yield textview object for further configuration before display
    # NOTE: i am experimentally yielding textview object so i could supress borders
    # just for kicks, but on can also bind_keys or events if one wanted.
    #def self.view what, config={} #:yield: textview
    def self.browse dbconn, tablename, columns, rows, config={} #:yield: ???
      wt = 0 # top margin
      wl = 0 # left margin
      wh = Ncurses.LINES-wt-3 # height, goes to bottom of screen
      ww = Ncurses.COLS-wl-3  # width, goes to right end
      wt, wl, wh, ww = config[:layout] if config.has_key? :layout

      fp = config[:title] || ""
      pf = config.fetch(:print_footer, true)
      ta = config.fetch(:title_attrib, 'bold')
      fa = config.fetch(:footer_attrib, 'bold')

      wh = 20
      ww = 100 # Ncurses.COLS-4
      layout = { :height => wh, :width => ww, :top => wt, :left => wl } 
      v_window = VER::Window.new(layout) # copywin gives -1 and prints nothing
      #v_window = VER::Window.root_window
      #v_form = RubyCurses::Form.new v_window
      #rb = ResultsetBrowser.new v_form, :row => 2, :col => 2
      rb = ResultsetBrowser.new v_window, :row => 2, :col => 2, :height => 15, :width => 75
      rb.columns = columns
      rb.data = rows
      rb.repaint


      # yielding textview so you may further configure or bind keys or events
      begin
      #v_form.repaint
      v_window.wrefresh
      Ncurses::Panel.update_panels
      # allow closing using q and Ctrl-q in addition to any key specified
      #  user should not need to specify key, since that becomes inconsistent across usages
        while((ch = v_window.getchar()) != ?\C-q.getbyte(0) )
          break if ch == config[:close_key] 
          rb.handle_key ch
          #v_form.handle_key ch
        end
      rescue => err
        $log.error err.to_s
        $log.error err.backtrace.join("\n")
        alert err.to_s

      ensure
        v_window.destroy if !v_window.nil?
      end
    end
  end  # class
end # module
if __FILE__ == $PROGRAM_NAME
require 'rbcurse/app'

App.new do 
  header = app_header "rbcurse ", :text_center => "ResultsetBrowser Demo", :text_right =>"New Improved!", :color => :black, :bgcolor => :white, :attr => :bold 
  message "Press F1 to exit from here"
  columns = ["Name","Age","City", "Country"]
  data    = [
             [ "Rahul",31, "Delhi","India"], 
             [ "Dev",35, "Mumbai","India"], 
             [ "Jobs",56, "L.A","U.S.A"], 
             [ "Matz",40, "Tokyo","Nippon"] 
  ]

    #RubyCurses::Browser.browse("dummy", "atable", columns, data,  :close_key => FFI::NCurses::KEY_F10, :title => "Enter to close") do |t|
  sql = "select id, type, priority, title from bugs"
  sql = "select * from bugs"
    RubyCurses::Browser.browse_sql("../../../bugzy.sqlite", "bugs", sql, :close_key => FFI::NCurses::KEY_F10, :title => "Enter to close") do |t|
      # you may configure textview further here.
      #t.suppress_borders true
      #t.color = :black
      #t.bgcolor = :white
      # or
      #t.attr = :reverse
    end

end # app
end
