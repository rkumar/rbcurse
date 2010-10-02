require 'rbcurse/app'
require 'rbcurse/rvimsplit'
require 'fileutils'
require 'rbcurse/extras/tabularwidget'
require './rmail'
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
        e.set_buffering(:target_window => @target_window || @form.window)
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
    @right1 = @vim.add comp, :SECOND
    _add_component comp
    @right1
  end
  def set_right_bottom_component comp
    @right2 = @vim.add comp, :SECOND
    _add_component comp
    @right2
  end
  private
  def _add_component comp  #:nodoc:
    #comp.parent = self
    #comp.form = @form 
  end
  def _create_vimsplit  #:nodoc:
    @vim = VimSplit.new nil, :row => @row, :col => @col, :width => @width, :height => @height, :weight => @weight, :orientation => :VERTICAL do |s|
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

App.new do 
  # this is for tree to get only directories
  ht = 24
  @messages = nil
  @tv = nil
  borderattrib = :reverse
  @header = app_header "rbcurse 1.2.0", :text_center => "Yet Another Email Client that sucks", :text_right =>"", :color => :black, :bgcolor => :white#, :attr =>  Ncurses::A_BLINK
  message "Press F1 to exit"


     


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
    @dirs = list_box :list => model, :height => ht, :border_attrib => borderattrib
    @dirs.one_key_selection = false
    def @dirs.convert_value_to_text(text, crow) ; File.basename(text); end
    @vim.set_left_component @dirs

    #@tw = TabularWidget.new nil
    @mails = []
    # FIXME why was list required in next, should have managed. length
    # error
    @lb2 = list_box :border_attrib => borderattrib #, :list => []
    @lb2.one_key_selection = false
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
    @tv.border_attrib = borderattrib
  end # stack
end # app
