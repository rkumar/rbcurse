require 'rbcurse/app'
require 'rbcurse/rvimsplit'
require 'fileutils'
require 'rbcurse/extras/tabularwidget'
require './common/rmail'
class ColumnBrowse < Widget
  require 'forwardable'
  extend Forwardable
  def_delegators :@vim, :on_enter, :on_leave, :handle_key
  def initialize form, config={}, &block
    @focusable = true
    @height = Ncurses.LINES-2
    @weight = 0.25
    super
    _create_vimsplit
    init_vars
  end
  def init_vars
    @first_time = true
    @repaint_required = true
  end
  def repaint
    if @first_time
      @first_time = nil
      [@vim, @left, @right1, @right2].each { |e|  
        e.set_buffering(:target_window => @target_window || @form.window, :form => @form)
      }
    end
    @vim.repaint
  end
  def set_left_component comp
    @left = @vim.add comp, :FIRST
    _add_component comp
    @left
  end
  def set_right_top_component comp
    @added_top = true
    @right1 = @vim.add comp, :SECOND, 0.5
    _add_component comp
    @right1
  end
  def set_right_bottom_component comp
    raise "Please add top component first!" unless @added_top
    # what if user gives in wrong order !!
    @gb = @vim.add :grabbar, :SECOND, 0
    @right2 = @vim.add comp, :SECOND, nil
    @gb.next_component(@right2)
    _add_component comp
    @right2
  end
  private
  def _add_component comp  #:nodoc:
    #comp.parent = self
    #comp.form = @form 
  end
  def _create_vimsplit  #:nodoc:
    @vim = VimSplit.new nil, :row => @row, :col => @col, :width => @width, :height => @height, :weight => @weight, :orientation => :VERTICAL, :suppress_borders => true do |s|
      s.parent_component = self
      #s.target_window = @form.window
      #s.add @left, :FIRST
      #s.add @right1, :SECOND
      #s.add @right2, :SECOND
      s.bind :COMPONENT_RESIZE_EVENT do |e|
        #alert "got a resize event #{e.type}  "
        case e.type
        when :INCREASE
          case e.source
          when @right2
            increase_body
          when @right1
            increase_headers
          when @left

          end
        when :DECREASE
          case e.source
          when @right2
            increase_headers
          when @right1
            increase_body
          when @left
            @left.width -= 1
            @right2.col -=1
            @right1.col -=1
            @right1.width +=1
            @right2.width +=1
            @right2.repaint_required  true
            @right1.repaint_required  true
            @left.repaint_required  true
          end
        when :EXPAND
          case e.source
          when @right2
            h = 3
            @right2.row(@right1.row + h)
            oldh = @right1.height
            @right1.height = h
            @right1.current_index = 0
            @right2.height += (oldh - h)
            @right2.repaint_required  true
            @right1.repaint_required  true
          when @right1
            h = 3
            @right2.row(@right2.row + (@right2.height - 3))
            oldh = @right2.height
            @right2.height = h
            #@right1.current_index = 0
            @right1.height += (oldh - h)
            @right2.repaint_required  true
            @right1.repaint_required  true
          end
        end
      end # bind
    end
  end # def
  def increase_headers
    @right2.row @right2.row()+1
    @right1.height +=1
    @right2.height -=1
    @right2.repaint_required  true
    @right1.repaint_required  true
  end
  def increase_body
    @right2.row @right2.row()-1
    @right1.height -=1
    @right2.height +=1
    @right2.repaint_required  true
    @right1.repaint_required  true
  end
end # class

  class MailCellRenderer #< ListCellRenderer
    include RubyCurses::ConfigSetup
    include RubyCurses::Utils
    dsl_accessor :justify     # :right, :left, :center  # added 2008-12-22 19:02 
    dsl_accessor :display_length     #  please give this to ensure the we only print this much
    dsl_accessor :height    # if you want a multiline label.
    dsl_accessor :text    # text of label
    dsl_accessor :color, :bgcolor
    dsl_accessor :row, :col
    dsl_accessor :parent    #usuall the table to get colors and other default info

    def initialize text="", config={}, &block
      @text = text
      @editable = false
      @focusable = false
      config_setup config # @config.each_pair { |k,v| variable_set(k,v) }
      instance_eval &block if block_given?
      init_vars
    end
    # NOTE: please call super() if you override this
    def init_vars  #:nodoc:
      # omg, some classes won't have justify !!
      #@justify ||= (@parent.justify || :left)
      unless @justify
        if @parent.respond_to? :justify
          @justify ||= (@parent.justify || :left)
        else
          @justify ||= :left
        end
      end
      @format = @justify.to_sym == :right ? "%*s" : "%-*s"  
      @display_length ||= 10
      # create color pairs once for this 2010-09-26 20:53 
    end
    # creates pairs of colors at start
    # since often classes are overriding init_vars, so not gettin created
    def create_color_pairs
      @color_pair = get_color $datacolor
      @pairs = Hash.new(@color_pair)
      @attrs = Hash.new(Ncurses::A_NORMAL)
      color_pair = get_color $selectedcolor, @parent.selected_color, @parent.selected_bgcolor
      @pairs[:normal] = @color_pair
      @pairs[:selected] = color_pair
      @pairs[:focussed] = @pairs[:normal]
      @attrs[:selected] = $row_selected_attr
      @attrs[:focussed] = $row_focussed_attr

    end
    #def getvalue
      #@text
    #end
    ##
    # sets @color_pair and @attr
    def select_colors focussed, selected
      create_color_pairs unless @pairs
      raise ArgumentError, "pairs hash is null. Changes have happened in listcellrenderer" unless @pairs
      @color_pair = @pairs[:normal]
      @attr = $row_attr
      # give precedence to a selected row
      if selected
        @color_pair = @pairs[:selected]
        @attr       = @attrs[:selected]
      elsif focussed
        @color_pair = @pairs[:focussed]
        @attr       = @attrs[:focussed]
      end
    end

    ##
    #  paint a list box cell
    #
    #  @param [Buffer] window or buffer object used for printing
    #  @param [Fixnum] row
    #  @param [Fixnum] column
    #  @param [Fixnum] actual index into data, some lists may have actual data elsewhere and
    #                  display data separate. e.g. rfe_renderer (directory listing)
    #  @param [String] text to print in cell
    #  @param [Boolean, cell focussed, not focussed
    #  @param [Boolean] cell selected or not
    def repaint graphic, r=@row,c=@col, row_index=-1,value=@text, focussed=false, selected=false

      select_colors focussed, selected 
      # if listboxes width is reduced, display_len remains the same
      # XXX FIXME parent may not be the list but a container like rfe !!
      # maybe caller should update at start of repain loop.
      #@display_length = @parent.width - 2 - @parent.left_margin

      value=value.to_s
      if !@display_length.nil?
        if value.length > @display_length
          value = value[0..@display_length-1]
        end
        # added 2010-09-27 11:05 TO UNCOMMENT AND TEST IT OUT
        if @justify == :center
          value = value.center(@display_length)
        end
      end
      len = @display_length || value.length
      graphic.printstring r, c, @format % [len, value], @color_pair, @attr
      if value =~ /^ *O/
        graphic.mvchgat(y=r, x=c,3, Ncurses::A_NORMAL, $promptcolor, nil) 
      else
        graphic.mvchgat(y=r, x=c,3, Ncurses::A_NORMAL, $datacolor, nil) 
      end

    end # repaiat

  end # class

App.new do 
  # this is for tree to get only directories
  ht = 24
  @messages = nil
  @tv = nil
  borderattrib = :reverse
  @header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Yet Another Email Client that sucks", :text_right =>"", :color => :black, :bgcolor => :white#, :attr =>  Ncurses::A_BLINK
  message "Press F10 to exit ...................................................."


     


  stack :margin_top => 1, :margin => 0, :width => :EXPAND do
    model = ["~/mbox"] 
    boxes = Dir.new(File.expand_path("~/mail/")).entries
    boxes.delete(".")
    boxes.delete("..")
    boxes = boxes.collect do |e| "~/mail/"+e; end
    model.push *boxes
    #@vim = vimsplit :height => Ncurses.LINES-2, :weight => 0.25, :orientation => :VERTICAL do |s|
      # try with new listbox
    @vim = ColumnBrowse.new @form, :row => 1, :col => 1, :width => :EXPAND
    @dirs = list_box :list => model, :height => ht, :border_attrib => borderattrib, :suppress_borders => true
    @dirs.one_key_selection = false
    def @dirs.convert_value_to_text(text, crow) ; File.basename(text); end
    @vim.set_left_component @dirs

    #@tw = TabularWidget.new nil
    @mails = []
    # FIXME why was list required in next, should have managed. length
    # error
    @lb2 = list_box :border_attrib => borderattrib, :suppress_borders => true #, :list => []
    @lb2.one_key_selection = false
    def @lb2.create_default_cell_renderer
      return MailCellRenderer.new "", {"color"=>@color, "bgcolor"=>@bgcolor, "parent" => self, "display_length"=> @width-@internal_width-@left_margin}
    end
    @vim.set_right_top_component @lb2
    @dirs.bind :PRESS do |e|
      @lines = []
      mx = Mbox.new File.expand_path(e.text)
      mx.formatted_each do |text|
        @lines << text
        #@tw.add text
      end
      message " #{e.text} has #{@lines.size} messages"
      @lb2.list @lines
      @messages = mx.mails()
    end
    @lb2.bind :PRESS do |e|
      #alert " line clicked #{e.source.current_index} "
      @tv.set_content(@messages[e.source.current_index].body, :WRAP_WORD)
    end
    @lb2.bind :ENTER_ROW do |e|
      @header.text_right "Row #{e.current_index+1} of #{@messages.size} "
    end
    
    #s.add @dirs, :FIRST
    #@tw.columns = [
    #s.add @lb2, :SECOND
    #@tv = textview
    #s.add "email body comes here. Press Enter on list above", :SECOND
    @tv = @vim.set_right_bottom_component "email body comes here. "
    #@tv = s.components_for(:SECOND).last
    @tv.suppress_borders true
    @tv.border_attrib = borderattrib
  end # stack
end # app
