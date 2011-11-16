#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
# this program tests out various widgets.
require 'rubygems'
#require 'ncurses' # FFI
require 'logger'
require 'rbcurse'
require 'rbcurse/core/widgets/rwidget'
require 'rbcurse/experimental/widgets/rscrollform'
#require 'rbcurse/core/widgets/rtextarea'
#require 'rbcurse/core/widgets/rtextview'
#require 'rbcurse/core/widgets/rmenu'
#require 'rbcurse/core/widgets/rcombo'
#require 'rbcurse/listcellrenderer'
#require 'rbcurse/checkboxcellrenderer'
#require 'rbcurse/comboboxcellrenderer'
#require 'rbcurse/celleditor'
#require 'qdfilechooser'
#require 'rbcurse/rlistbox'
#require 'rbcurse/rmessagebox'
if $0 == __FILE__
  include RubyCurses

  begin
  # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new((File.join(ENV["LOGDIR"] || "./" ,"rbc13.log")))
    $log.level = Logger::DEBUG

    #@window = VER::Window.root_window
    # Initialize few color pairs 
    # Create the window to be associated with the form 
    # Un post form and free the memory

    catch(:close) do
      colors = Ncurses.COLORS
      $log.debug "START #{colors} colors testscroller.rb --------- #{@window} "
      @form = ScrollForm.new @window
      # pad coordinates - the virtual area larger than screen
      h = 50
      w = 150 
      row = 1
      col = 1
      @form.set_pad_dimensions(row, col, h, w)
      # dimensions of screen area onto which pad will paint
      @form.should_print_border(true)

      #@window.print_border_only 0, 0, 20+2, 100+2, $datacolor
      @window.printstring 0, 30, "Demo of ScrollForm ", $normalcolor, 'reverse'
      r = row + 0; fc = 12;
      #mnemonics = %w[ n l r p]
      %w[ name detail descr password street city country zip hobbies homepage facebook twitter buzz gmail ].each_with_index do |w,i|
        field = Field.new @form do
          name   w 
          row  r 
          col  fc 
          display_length  30
          maxlen  30
          #set_buffer "abcd " 
          #set_label Label.new @form, {'text' => w, 'color'=>'cyan','mnemonic'=> mnemonics[i]}
          set_label Label.new @form, {'text' => w, 'color'=>'cyan'}
        end
        r += 3
      end
        r = row
        fc = 120
        # XXX while typing in a field, cursor goes off in this case
      %w[ operating_system version application build release shell band instrument guitarist drummer ].each_with_index do |w,i|
        field = Field.new @form do
          name   w 
          row  r 
          col  fc 
          display_length  30
          maxlen  30
          bgcolor 'white'
          color 'black'
          #set_buffer "abcd " 
          #set_label Label.new @form, {'text' => w, 'color'=>'cyan','mnemonic'=> mnemonics[i]}
          set_label Label.new @form, {'text' => w, 'color'=>'cyan'}
        end
        field.overwrite_mode = true
        r += 3
      end

      $message = Variable.new
      $message.value = "Message Comes Here"
      message_label = RubyCurses::Label.new @form, {'text_variable' => $message, "name"=>"message_label","row" => 27, "col" => 1, "display_length" => 60,  "height" => 2, 'color' => 'cyan'}

      # a special case required since another form (combo popup also modifies)
      $message.update_command() { message_label.repaint }

      @form.by_name["detail"].set_buffer  "This form has more components"
      @form.by_name["descr"].set_buffer  "Use M-l/h and M-n/p for scrolling"

      # a form level event, whenever any widget is focussed
      @form.bind(:ENTER) { |f|   f.label && f.label.bgcolor = 'red' if f.respond_to? :label}
      @form.bind(:LEAVE) { |f|  f.label && f.label.bgcolor = 'black'   if f.respond_to? :label}

      @form.repaint
      @window.wrefresh
      Ncurses::Panel.update_panels
      while((ch = @window.getchar()) != KEY_F1 )
        @form.handle_key(ch)
        @form.repaint
        @window.wrefresh
        Ncurses::Panel.update_panels
      end
    end
  rescue => ex
  ensure
      @window.destroy if !@window.nil?
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
