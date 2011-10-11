require 'rbcurse/rvimsplit'
require 'forwardable'
# A convenience class that implements a 3 way Master Detail like form
# as in some email clients. See appemail.rb for usage.
# You may use this class or extend it. It takes care of expanding,
# increasing etc the 3 splits.
# This class is not fully tested beyond appemail.rb, and can change
# quite a bit. Users may want to copy this to prevent from major changes
# that could take place.
class MasterDetail < Widget
  dsl_property :weight
  attr_reader :vim # the vimsplit for any further configuration such as min_weight etc
  extend Forwardable
  def_delegators :@vim, :on_enter, :on_leave, :handle_key, :current_component
  def initialize form, config={}, &block
    @focusable = true
    @height = Ncurses.LINES-2
    @weight = 0.25
    super
    _create_vimsplit
    init_vars
  end
  def init_vars  #:nodoc:
    @first_time = true
    @repaint_required = true
  end
  def repaint
    if @first_time
      @first_time = nil
      [@vim, @left, @right1, @right2].each { |e|  
        e.set_buffering(:target_window => @target_window || @form.window, :form => @form) # removed on 2011-09-29 
      }
    end
    @vim.repaint
  end
  # set the single component on the left side/pane, typically a +Listbox+.
  # If an array is passed, the Listbox created is returned for further
  # manipulation.
  # @param [Widget] component to set on left
  # @return [Widget] component added
  def set_left_component comp, weight=nil
    @left = @vim.add comp, :FIRST, weight
    _add_component comp
    @left
  end
  # set the first component on the right side/pane, typically a +Listbox+.
  # @param [Widget] component to set on right
  # @return [Widget] component added
  def set_right_top_component comp, weight=0.5
    @added_top = true
    @right1 = @vim.add comp, :SECOND, weight
    _add_component comp
    @right1
  end
  # set the second component on the right side/pane, typically a
  # +TextView+
  # @param [Widget] component to set on right
  # @return [Widget] component added
  def set_right_bottom_component comp, weight=nil
    raise "Please add top component first!" unless @added_top
    # what if user gives in wrong order !!
    @gb = @vim.add :divider, :SECOND, 0
    @right2 = @vim.add comp, :SECOND, weight
    @gb.next_component(@right2)
    _add_component comp
    @right2
  end
  def focus comp
    case comp
    when :left
      @vim.goto_component @left
    when :top_right
      @vim.goto_component @right1
    when :bottom_right
      @vim.goto_component @right2
    else
      @vim.goto_component comp
    end
  end
  private
  # does nothing at present
  def _add_component comp  #:nodoc:
  end
  # creates a Vimplit containing 3 panes. Sets events in order to
  # increase and decrease panes/windows.
  def _create_vimsplit  #:nodoc:
    @vim = VimSplit.new nil, :row => @row, :col => @col, :width => @width, :height => @height, :weight => @weight, :orientation => :VERTICAL, :suppress_borders => true do |s|
      s.parent_component = self
      #s.target_window = @form.window
      #s.add @left, :FIRST
      #s.add @right1, :SECOND
      #s.add @right2, :SECOND
      s.bind :COMPONENT_RESIZE_EVENT do |e|
        alert "masterdetail got a resize event #{e.type}, #{e.source}  "
        case e.type
        when :INCREASE
          case e.source
          when @right2
            increase_body
          when @right1
            increase_headers
          when @left
            alert "masterdetail left increase - not handled"

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
            alert "masterdetail left decrease"
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
  # increase the top right pane and reduces lower one
  # TODO: to take into account multiplier
  def increase_headers  #:nodoc:
    @right2.row @right2.row()+1
    @right1.height +=1
    @right2.height -=1
    @right2.repaint_required  true
    @right1.repaint_required  true
  end
  # decrease the top right pane and increase lower one
  # TODO: to take into account multiplier
  def increase_body  #:nodoc:
    @right2.row @right2.row()-1
    @right1.height -=1
    @right2.height +=1
    @right2.repaint_required  true
    @right1.repaint_required  true
  end
end # class
