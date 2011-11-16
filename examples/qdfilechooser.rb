# this is a test program, tests out messageboxes. type F1 to exit
# a quick dirty file chooser in 2 lines of code.
require 'logger'
require 'rbcurse/core/system/ncurses'
require 'rbcurse/core/system/window'
require 'rbcurse/core/widgets/rwidget'

##
# a quick dirty file chooser - only temporary till we make something better.
class QDFileChooser
  attr_accessor :show_folders   # bool
  attr_accessor :traverse_folders   # bool
  attr_accessor :default_pattern  # e.g. "*.*"
  attr_accessor :dialog_title    # File Chooser
  def initialize

  end
  def show_open_dialog
        @form = RubyCurses::Form.new nil
        label = RubyCurses::Label.new @form, {'text' => 'File', 'row'=>3, 'col'=>4, 'color'=>'black', 'bgcolor'=>'white', 'mnemonic'=>'F'}
        field = RubyCurses::Field.new @form do
          name   "file" 
          row  3 
          col  10
          display_length  40
          set_label label
        end
        default_pattern ||= "*.*"
        flist = Dir.glob(default_pattern)
        @listb = RubyCurses::Listbox.new @form do
          name   "mylist" 
          row  5 
          col  10 
          width 40
          height 10
          list flist
          title "File list"
          title_attrib 'bold'
        end
        #@listb.list.bind(:ENTER_ROW) { field.set_buffer @listb.selected_item }
        listb = @listb
        field.bind(:CHANGE) do |f|   
          flist = Dir.glob(f.getvalue+"*")
          l = listb.list
          l.remove_all
          l.insert 0, *flist
        end
        atitle = @dialog_title || "Quick Dirty(TM) File Chooser"
        @mb = RubyCurses::MessageBox.new @form do
          title atitle
          type :override
          height 20
          width 60
          top 5
          left 20
          default_button 0
          button_type :ok_cancel
        end
        #$log.debug "MBOX :selected #{@listb.selected_item}, #{@listb[@listb.getvalue[0]]} "
        return @mb.selected_index == 0 ? :OK : :CANCEL
  end 
  def get_selected_file
    #return @mb.selected_index == 0 ? @listb.selected_item : nil
    #return @mb.selected_index == 0 ? @listb[@listb.getvalue[0]]  : nil
    # return either the selected_value or if user pressed okay, then focussed item
    return @mb.selected_index == 0 ? @listb.selected_value || @listb.selected_item  : nil
  end
end
