=begin
  * Name: rmessagebox: creates messageboxes
  * Description   
  * Author: rkumar (arunachalesha)
  * Date: 2008-11-19 12:49 
  * License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
  * file separated on 2009-01-13 22:39 

=end
require 'rbcurse/rwidget'
require 'rbcurse/rlistbox'

module RubyCurses
  ##
  # dimensions of window should be derived on content
  #
  class MessageBox
    include DSL
    include RubyCurses::Utils
    dsl_accessor :title
    dsl_accessor :message
    dsl_accessor :type               # :ok, :ok_cancel :yes_no :yes_no_cancel :custom
    dsl_accessor :default_button     # TODO - currently first
    dsl_accessor :layout
    dsl_accessor :buttons           # used if type :custom
    dsl_accessor :underlines           # offsets of each button to underline
    attr_reader :config
    attr_reader :selected_index     # button index selected by user
    attr_reader :window     # required for keyboard
    dsl_accessor :list_selection_mode  # true or false allow multiple selection
    dsl_accessor :list  # 2009-01-05 23:59 
    dsl_accessor :button_type      # ok, ok_cancel, yes_no
    dsl_accessor :default_value     # 
    dsl_accessor :default_values     # #  2009-01-06 00:05 after removing meth missing 
    dsl_accessor :height, :width, :top, :left  #  2009-01-06 00:05 after removing meth missing

    dsl_accessor :message_height


    def initialize form=nil, aconfig={}, &block
      @form = form
      @config = aconfig
      @buttons = []
      #@keys = {}
      @bcol = 5
      @selected_index = -1
      @config.each_pair { |k,v| instance_variable_set("@#{k}",v) }
      instance_eval &block if block_given?
      if @layout.nil? 
        case @type.to_s
        when "input"
          layout(10,60, 10, 20) 
        when "list"
          height = [5, @list.length].min 
          layout(10+height, 60, 5, 20)
        when "field_list"
          height = @field_list.length
          layout(10+height, 60, 5, 20)
        when "override"
          $log.debug " override: #{@height},#{@width}, #{@top}, #{@left} "
          layout(@height,@width, @top, @left) 
          $log.debug " override: #{@layout.inspect}"
        else
          height = @form && @form.widgets.length ## quick fix. FIXME
          height ||= 0
          layout(10+height,60, 10, 20) 
        end
      end
      @window = VER::Window.new(@layout)
      if @form.nil?
        @form = RubyCurses::Form.new @window
      else
        @form.window = @window
      end
      acolor = get_color $reversecolor
      $log.debug " MESSAGE BOX #{@bgcolor} , #{@color} , #{acolor}"
      @window.bkgd(Ncurses.COLOR_PAIR(acolor));
      @window.wrefresh
      @panel = @window.panel
      Ncurses::Panel.update_panels
      process_field_list
      print_borders
      print_title
      print_message unless @message.nil?
      print_input
      create_buttons
      @form.repaint
      @window.wrefresh
      handle_keys
    end
    ##
    # takes care of a field list sent in
    def process_field_list
      return if @field_list.nil? or @field_list.length == 0
      @field_list.each do |f|
        f.set_form @form
      end
    end
    def default_button offset0
      @selected_index = offset0
    end
    ##
    # value entered by user if type = input
    def input_value
      return @input.buffer if !@input.nil?
      return @listbox.getvalue if !@listbox.nil?
    end
    def create_buttons
      case @button_type.to_s.downcase
      when "ok"
        make_buttons ["&OK"]
      when "ok_cancel" #, "input", "list", "field_list"
        make_buttons %w[&OK &Cancel]
        # experience 2009-02-22 12:52 trapping y and n - hopefully wont cause an edit problem
        @form.bind_key(?o){ press(?\M-o) }   # called method takes care of getbyte 1.9
        @form.bind_key(?c){ press(?\M-c) }   # called method takes care of getbyte 1.9
      when "yes_no"
        make_buttons %w[&Yes &No]
        # experience 2009-02-22 12:52 trapping y and n - hopefully wont cause an edit problem
        @form.bind_key(?y){ press(?\M-y) }   # called method takes care of getbyte 1.9
        @form.bind_key(?n){ press(?\M-n) }   # called method takes care of getbyte 1.9
      when "yes_no_cancel"
        make_buttons ["&Yes", "&No", "&Cancel"]
      when "custom"
        raise "Blank list of buttons passed to custom" if @buttons.nil? or @buttons.size == 0
        make_buttons @buttons
      else
        $log.debug "No type passed for creating messagebox. Using default (OK)"
        make_buttons ["&OK"]
      end
    end
    def make_buttons names
      total = names.inject(0) {|total, item| total + item.length + 4}
      bcol = center_column total

      brow = @layout[:height]-3
      button_ct=0
      names.each_with_index do |bname, ix|
        text = bname
        #underline = @underlines[ix] if !@underlines.nil?

        button = Button.new @form do
          text text
          name bname
          row brow
          col bcol
          #underline underline
          highlight_background $datacolor 
          color $reversecolor
          bgcolor $reversecolor
        end
        index = button_ct
        button.command { |form| @selected_index = index; @stop = true; $log.debug "Pressed Button #{bname}";}
        button_ct += 1
        bcol += text.length+6
      end
    end
    ## message box
    def stopping?
      @stop
    end
    def handle_keys
      begin
        while((ch = @window.getchar()) != 999 )
          case ch
          when -1
            next
          else
            press ch
            break if @stop
          end
        end
      ensure
        destroy  
      end
      return @selected_index
    end
    def press ch
      ch = ch.getbyte(0) if ch.class==String ## 1.9
        case ch
        when -1
          return
        when KEY_F1, 27, ?\C-q.getbyte(0)   
          @selected_index = -1
          @stop = true
          return
        when KEY_ENTER, 10, 13
          field =  @form.get_current_field
          if field.respond_to? :fire
            field.fire
          end
          #$log.debug "popup ENTER : #{@selected_index} "
          #$log.debug "popup ENTER :  #{field.name}" if !field.nil?
          @stop = true
          return
        when 9
          @form.select_next_field
        when 353
          @form.select_prev_field
        else
          # fields must return unhandled else we will miss hotkeys. 
          # On messageboxes, often if no edit field, then O and C are hot.
          field =  @form.get_current_field
          handled = field.handle_key ch

          if handled == :UNHANDLED
            ret = @form.process_key ch, self ## trying out trigger button
          end
        end
        @form.repaint
        Ncurses::Panel.update_panels();
        Ncurses.doupdate();
        @window.wrefresh
    end
    def print_borders
      width = @layout[:width]
      height = @layout[:height]
      @window.print_border_mb 1,2, height, width, $normalcolor, A_REVERSE
=begin
      start = 2
      hline = "+%s+" % [ "-"*(width-((start+1)*2)) ]
      hline2 = "|%s|" % [ " "*(width-((start+1)*2)) ]
      @window.printstring(row=1, col=start, hline, color=$reversecolor)
      (start).upto(height-2) do |row|
        @window.printstring row, col=start, hline2, color=$normalcolor, A_REVERSE
      end
      @window.printstring(height-2, col=start, hline, color=$reversecolor)
=end
    end
    def print_title title=@title
      width = @layout[:width]
      title = " "+title+" "
      @window.printstring(row=1,col=(width-title.length)/2,title, color=$normalcolor)
    end
    def center_column textlen
      width = @layout[:width]
      return (width-textlen)/2
    end
    def print_message message=@message, row=nil
      @message_row = @message_col = 2
      display_length = @layout[:width]-8
        $log.debug " print_message: dl:#{display_length} "
      # XXX this needs to go up and decide height of window
      if @message_height.nil?
        @message_height = (message.length/display_length)+1
        $log.debug " print_message: mh:#{@message_height}, ml: #{message.length}"
      end
      @message_height ||= 1
      width = @layout[:width]
      return if message.nil?
      case @type.to_s
      when "input" 
        row=(@layout[:height]/3) if row.nil?
        @message_col = 4
      when "list" 
        row=3
        @message_col = 4 
      else
        row=(@layout[:height]/3) if row.nil?
        @message_col = (width-message.length)/2
      end
      @message_row = row
      # added 2009-11-05 14:53 to fix erasure of border
      display_length -= @message_col
      # FIXME : wont print if newline at end of message !!!
      #@window.printstring( row, @message_col , message, color=$reversecolor)
      # 2008-12-30 19:45 experimenting with label so we can get justify and wrapping.
      #@window.printstring( row, @message_col , message, color=$reversecolor)
        $log.debug " print_message: row #{row}, col #{@message_col} "
      message_label = RubyCurses::Label.new @form, {'text' => message, "name"=>"message_label","row" => row, "col" => @message_col, "display_length" => display_length,  "height" => @message_height, "attr"=>"reverse"}

    end
    def print_input
      #return if @type.to_s != "input"
      @message_height ||= 0
      @message_row ||= 2
      @message_col ||= 2
      r = @message_row + @message_height + 1
      c = @message_col
      disp_len = @layout[:width]-8
      defaultvalue = @default_value || ""
      input_config = @config["input_config"] || {}
      case @type.to_s 
      when "input"
        @input = RubyCurses::Field.new @form, input_config do
          name   "input" 
          row  r 
          col  c 
          display_length disp_len
          set_buffer defaultvalue
        end
      when "list"
        list = @list
        selection_mode = @list_selection_mode 
        default_values = @default_values
        $log.debug " value of select_mode #{selection_mode}"
        @listbox = RubyCurses::Listbox.new @form do
          name   "input" 
          row  r 
          col  c 
#         attr 'reverse'
          color 'black'
          bgcolor 'white'
          width 30
          height 6
          list  list
          # ?? display_length  30
          #set_buffer defaultvalue
          selection_mode selection_mode
          default_values default_values
          is_popup false
        end
      end
    end
    def configure(*val , &block)
      case val.size
      when 1
        return @config[val[0]]
      when 2
        @config[val[0]] = val[1]
        instance_variable_set("@#{val[0]}", val[1]) 
      end
      instance_eval &block if block_given?
    end
    def cget param
      @config[param]
    end

    def layout(height=0, width=0, top=0, left=0)
      @layout = { :height => height, :width => width, :top => top, :left => left } 
    end
    def destroy
      $log.debug "DESTROY : widget"
      panel = @window.panel
      Ncurses::Panel.del_panel(panel) if !panel.nil?   
      @window.delwin if !@window.nil?
    end
  end
end
