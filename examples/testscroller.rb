#$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
# this program tests out various widgets.
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rwidget'
require 'rbcurse/rscrollform'
#require 'rbcurse/rtextarea'
#require 'rbcurse/rtextview'
#require 'rbcurse/rmenu'
#require 'rbcurse/rcombo'
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
    #$log = Logger.new("v#{$0}.log")
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG

    @window = VER::Window.root_window
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
      #@buttonpad = @form.create_pad

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

      #@form.by_name["line"].display_length = 3
      #@form.by_name["line"].maxlen = 3
      #@form.by_name["line"].set_buffer  "24"
      @form.by_name["detail"].set_buffer  "This form has more components"
      @form.by_name["descr"].set_buffer  "Use M-l/h and M-n/p for scrolling"
      #@form.by_name["name"].set_focusable(false)
      #@form.by_name["line"].chars_allowed = /\d/
      ##@form.by_name["regex"].type(:ALPHA)
      #@form.by_name["regex"].valid_regex(/^[A-Z][a-z]*/)
      #@form.by_name["regex"].set_buffer  "SYNOP"
      #@form.by_name["regex"].display_length = 10
      #@form.by_name["regex"].maxlen = 20
      ##@form.by_name["regex"].bgcolor 'cyan'
      #@form.by_name["password"].set_buffer ""
      #@form.by_name["password"].show '*'
      #@form.by_name["password"].color 'red'
      ##@form.by_name["password"].bgcolor 'blue'
      #@form.by_name["password"].values(%w[scotty tiger secret pass qwerty])
      #@form.by_name["password"].null_allowed true

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
