#*******************************************************#
#                                                       #
#                                                       #
# Arunachalesha                                         #
# $Id$  #
#*******************************************************#
require 'rubygems'
require 'ncurses'
require 'rbcurse/rbform'
require 'logger'

include Ncurses
include Ncurses::Form
class Application
#  HEADER_WIN_WIDTH=1 # giving already defined error when called from menu
#  BOTTOM_WIN_WIDTH=4

  attr_accessor :header_win, :header_panel
  attr_accessor :footer_win, :footer_panel
  attr_reader :window, :panel
  # the caller application
  attr_accessor :main  #  needed to call the print methods - DANG
  attr_reader :datakeys  #  rbeditform acccesses
  attr_reader :helpfile  #  rbeditform acccesses
  attr_accessor :form_headers
  # constructor

  def initialize
    @bww = 4
    @hww = 1
    initial_setup
    @header_win = nil
    @footer_win = nil
    #@key_labels=["?~Help      ","O~Other CMDS"]
    # removed since edit screens cannot take a ? and O. They use ^G
    @key_labels=[]
    @form_headers={"header"=>[0, 0, "NcursesOnRails, V0.1 "]}
    @table_width=Ncurses.LINES-(@bww+ @hww)
    #set_color_pairs
    @action_posy = Ncurses.LINES-1
    @action_posx = 12
    @datakeys = {}
    @helpfilepath = "."
    @helpfile = "help.txt"

  end
  # 2008-09-30 14:56 create it here so we don't keep mucking around in each program
  def create_header_win
    @header_win = WINDOW.new(@hww,0,0,0)
    @header_panel = @header_win.new_panel
    Ncurses.refresh();
    print_headers(@form_headers) # moved, so move this too.
    #return header_win, header_panel
  end
  def create_footer_win
    @footer_win = WINDOW.new(@bww,0,Ncurses.LINES-@bww,0)
    @footer_panel = @footer_win.new_panel
    #return footer_win, footer_panel
  end
  #def self.create_default_form(fields)  # no one calling this ?
  def create_default_form(fields)
    #my_form = FORM.new(fields);
    my_form = create_form_with(RBForm.new(fields));
    return my_form;
  end

  # creates a form with a specialized 
  def create_form_with(my_form)
    # Calculate the area required for the form
    #raise "get_fields is null : " if my_form.myfields().nil?
    #raise "error null 4: "+my_form.get_fields.count.to_s
    rows = Array.new()
    cols = Array.new()
    my_form.scale_form(rows, cols);
    #raise "error null 3: "+my_form.get_fields().count.to_s if !my_form.get_fields.nil?

    my_form.user_object = { :row_col_array => [ rows[0], cols[0] ], :fields => my_form.get_fields }
    #@form_field_hash[my_form] = fields 
    #my_form.set_application(self) # XXX this prevented us from making a bunch of methods
    # into class methods. however, need to call this
    return my_form
  end

  # Create the window to be associated with the form
  #@table_width=Ncurses.LINES-(@bww + @hww)
  #def self.create_default_window(my_form)
  def create_default_window(my_form)
    my_form_win = WINDOW.new(@table_width,0,@hww+1,0)
    my_panel = my_form_win.new_panel
    Ncurses::Panel.update_panels

    my_form_win.bkgd(Ncurses.COLOR_PAIR(5));
    my_form_win.keypad(TRUE);

    # Set main window and sub window
    my_form.set_form_win(my_form_win);
    rows, cols = my_form.user_object[:row_col_array]
    col_offset = 14
    row_offset = 2
    my_form.set_form_sub(my_form_win.derwin(rows, cols, row_offset, col_offset));

    Ncurses.refresh();
    my_form.post_form();
    my_form_win.wrefresh();
    #my_form.window = my_form_win # 2008-10-15 09:58  HAHA, set_form_win does that 02:55
    return my_form_win, my_panel
  end


  # we need to make this structure the standard one and not the quick hack above with the tilde
  # this contains ALL The keys to be shown below for all forms. :-(
  # Each form needs to know keyarr[] for what is to be handled.
  # Or shouldst we keep this at app level --- ????
  def add_to_application_labels(key_hash_array)
    raise "k_h_a nil " if key_hash_array.nil?
    return if key_hash_array.nil?
    keyarr=[]
    #raise "kha empty" if key_hash_array.count = 0
    key_hash_array.each{ |khash|
      keyarr << khash[:display_code]+"~"+khash[:text]
    }
    #raise "#{keyarr}"
    @key_labels = @key_labels + keyarr
    # this structure will be in the mem of the app that sets the labels but not necessarily in the one that uses this !!!
    create_datakeys(key_hash_array)
  end

    #create a hash of keys for quick lookup on keypress, 
    # keys will be ascii values 
    # 2008-10-01 00:42 you  can specify multiple keys like < and , which both bind to
    # same action. Case is taken care of for alphas.
  def create_datakeys(key_hash_array)
    #@datakeys = {} # 2008-10-14 10:28 may wanna append 
    return if key_hash_array.nil?
    key_hash_array.each { |khash|
      kc = khash[:keycode]
      # added on 2008-10-23 22:57, pls give proc, we are not linking to datasources from rbform
      raise "Action #{kc} #{kc.chr} can no longer be nil. Please give Proc" if khash[:action].nil?
      if kc.is_a?Array
        kc.each{ |arr| @datakeys[arr]=khash[:action] }
      else
        @datakeys[kc]=khash[:action]
      end
    }
    #raise "datakeys has #{@datakeys.count}"
  end
  def restore_application_key_labels
    win = @main.footer_win
    @main.print_key_labels(0, 0, @key_labels)  # XXX 2008-10-10 13:02 
    win.wrefresh   # needed else secod row not shown on startup XXX
  end
  def create_header_footer keys_handled
    create_header_win  # super takes care of this
    create_footer_win  # super takes care of this
    Ncurses::Panel.update_panels
    add_to_application_labels(keys_handled)
    restore_application_key_labels
  end
                                                     
  # one time
  def initial_setup
    if $setup_done
      return
    end
    $setup_done = true
#    stdscr = Ncurses.initscr();
    Ncurses.start_color();
    #    Ncurses.cbreak();
    Ncurses.raw();
    #   Ncurses.keypad(stdscr, true);
    Ncurses.meta(nil, true) # i think this is already the default
    Ncurses.noecho();

    #initialize few color pairs
    Ncurses.init_pair(1, COLOR_RED, COLOR_BLACK);
    Ncurses.init_pair(2, COLOR_BLACK, COLOR_WHITE);
    Ncurses.init_pair(3, COLOR_BLACK, COLOR_BLUE);
    Ncurses.init_pair(4, COLOR_YELLOW, COLOR_RED); # for selected item
    Ncurses.init_pair(5, COLOR_WHITE, COLOR_BLACK); # for unselected menu items
    Ncurses.init_pair(6, COLOR_WHITE, COLOR_BLUE); # for bottom/top bar
    Ncurses.init_pair(7, COLOR_WHITE, COLOR_RED); # for error messages
    $log = Logger.new("app.log")  
    $log.level = Logger::DEBUG
  end
  # a simple linear display
  def create_query_fields(how_many, qform_fwidth, qform_row1, qform_col)
    qfields = Array.new
    (1..how_many).each {| i |
      frow = qform_row1+(i-1) 
    fcol = qform_col
    field = FIELD.new(1, qform_fwidth, frow, fcol, 0, 0)
    field.user_object = { :row => frow, :col => fcol }
    field.set_field_back(A_REVERSE)
    qfields << field
    }
    qfields
  end

  # Unlike default window which takes up entire screen
  # this on allows user to specify location, width, while defaulting
  # to sane values (a single window taking up all area other than header and footer.)

  def create_custom_window(qform, 
                           qform_win_rows = 0, 
                           qform_win_cols = Ncurses.COLS, 
                           qform_win_starty = @hww,
                           qform_win_startx = 0)

    qfields = qform.user_object[:fields]
    if qform_win_rows == 0
      qform_win_rows = qfields.length+2 
    end
    qform_win = WINDOW.new(qform_win_rows,Ncurses.COLS, qform_win_starty, qform_win_starty) 
    qpanel = qform_win.new_panel
    Ncurses::Panel.update_panels
    qform_win.keypad(TRUE);
    qform.set_form_win(qform_win);

    # header_win
    Ncurses.refresh();

    qform.post_form();
    qfields.each_index { |i| 
      fldhash = qfields[i].user_object
      if fldhash.include?:label and fldhash[:label].length>0
        if fldhash.include?"label_rowcol"
          lrow, lcol = fldhash["label_rowcol"]
        else
          lcol = fldhash[:col] - (fldhash[:label].length+3)
          lrow = fldhash[:row]
           fldhash["label_rowcol"] = [lrow, lcol ]
           qfields[i].user_object = fldhash
        end
        qform_win.mvaddstr(lrow, lcol, fldhash[:label]+" :")
      end
    }
    #@qform_win.mvaddstr(qform_row1+1, qform_label_offset , "URL")
    #qform.window = qform_win # 2008-10-15 09:59  set_form_win does this !
    qform_win.wrefresh();
    return qform_win, qpanel; 
  end
  # for the moment, att_hash can contain :just => :right/:left
  # if its not right then :offset
  def set_field_label_info(fields, field_labels, att_hash={})
    fields.each_index { |i|
      att_hash[:label]=field_labels[i]
      if fields[i].user_object.nil?
        fields[i].user_object = att_hash
      else
        fields[i].user_object.merge!(att_hash)
      end
    }
  end

  # convenience cleanup 2008-10-04 23:38 
  def wrefresh
    @window.wrefresh if !@window.nil?
  end
  # easier cleanup 2008-10-04 23:37 
  def free_all
    fields = @form.fields if !@form.nil?  # nil in menu, app does not have this!
    if !@form.nil?
      @form.unpost_form();
      @form.free_form();
    end
    fields.each {|f| f.free_field()} if !fields.nil?
    Ncurses::Panel.del_panel(@panel)  if !@panel.nil?
    @window.delwin if !@window.nil?
    Ncurses::Panel.del_panel(@header_panel) 
    Ncurses::Panel.del_panel(@footer_panel) 
    @header_win.delwin if !@header_win.nil?
    @footer_win.delwin if !@footer_win.nil?
  end
  def application_key_handler(ch)
    case ch
    when ??,?\C-g
      help(@main.helpfile)
    else
        @main.print_error( sprintf("[Command %c (%d) is not defined for this screen]   ", ch,ch))
        Ncurses.beep() # 2008-10-24 23:57 
    end
  end
  def help(file)
    ofilename = File.expand_path(@helpfilepath+"/"+file)
    ofilename.gsub!(/\.rb$/,'.txt') if File.extname(ofilename)=='.rb'
    if File.exists?(ofilename)
      print_help_page(ofilename)   # TODO XXX get actual page
    else
      @log.error("No help file found: #{ofilename}")
      filename = File.expand_path(@helpfilepath+"/"+self.class.to_s().downcase()+".txt")
      if File.exists?(filename)
        print_help_page(filename)   # TODO XXX get actual page
      else
        @log.error("No help file found: #{filename}")
        @main.print_error("No help file found: #{ofilename}")
      end
    end
    @window.wrefresh
    Ncurses::Panel.update_panels
  end

  ##
  # Silently binds a key to an action. Does not display in key labels
  # 2008-10-14 10:55 
  #
  # @param [int] the key code
  # @param [String] the name of the method

  def bind_key keycode, action
    @datakeys[keycode]=action
  end

  ##
  # Unbinds a key. Does not touch key labels
  # 2008-10-14 10:55 
  #
  # @param [int] the key code

  def unbind_key keycode
    @datakeys.delete keycode
  end
  ## ADD HERE ##
end # class
