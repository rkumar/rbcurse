=begin
  * Name: rkumar
  * $Id$
  * Description   Basic form object with a basic key listener
  * Author:
  * Date:
  * License:
    This is free software; you can copy and distribute and modify
    this program under the term of Ruby's License
    (http://www.ruby-lang.org/LINCENSE.txt)

=end

# An extension of the FORM class.
# Needed so i can attach key_handlers for various forms. 
# Got tired of mucking around with the user_object class.
#
# Arunachalesha 
# @version 
#
require 'ncurses'

include Ncurses
include Ncurses::Form

##
# Added a little sugar to FIELD
# treating it like a hash invokes the underlying user_object
#
module Form
  class FieldValidationException < RuntimeError
  end
  class FIELD
    attr_reader :height, :width

    # retrieve key value from underlying user_object
    def [](key)
      return @user_object[key]
    end

    # set value into underlying user_object
    def []=(key,value)
      return @user_object[key]=value
    end

    # check key in underlying user_object
    def include?(key)
      return @user_object.include? key
    end
    # getter for name 2008-10-18 11:56 
    def name 
      @user_object["name"]
    end
    # getter for value 2008-10-18 11:56 
    def value
      get_value(0)
    end

    # sets value in default buffer 2008-10-15 11:02 
    def set_value(val, buf = 0)
      h, w = get_height_width
      if h == 1
        set_field_buffer(buf, val)
        check = field_buffer(buf)
        if check == nil || check.strip ==''
          # string could have a newline at end send by unix command
          set_field_buffer(buf, val.chomp!.to_s)
        end
      else
        # multiline string, take out tabs, newlines and pad it to width
        val = RBForm.text_to_multiline(val, w) 
        set_field_buffer(buf, val.to_s)
      end
    end

    # retrieves value in default buffer 2008-10-15 11:02 
    def get_value(buf = 0)
      h, w = get_height_width
      if h == 1
        value = field_buffer(buf)
        value =  handle_default value
        value = handle_post_proc value
        if valid? value
          return value
        else
          raise FieldValidationException, "Field #{self["name"]} fails valid check"
        end
      else
        return RBForm.multiline_format(field_buffer(buf), w)
      end
    end
    ## sets default if exists
    # @param value
    # @return value after subtituting default
    def handle_default value
      value.strip!
      if value == ''  # user blanked out value
        if user_object.include?"default"
          value = user_object["default"]
          if value != nil
            if value.respond_to? :call # 2008-10-24 12:05 allow user to pass a proc
              value = value.call
            else
              value = eval(value) rescue value 
            end
          end
        end
      end
      value
    end

    def handle_post_proc value
      if user_object.include?"post_proc"
        pproc = user_object["post_proc"];
        #value=@main.send(pproc, value, self )
        #value=send(pproc, value, self ) # 2008-10-24 10:28 
        value = pproc.call(value,self)
      end
      value
    end

    def valid? value=nil
      value = field_buffer(0) if value == nil
      if include?"valid"
        return value.match(user_object["valid"])
      end
      return true
    end

    @height = nil
    @width = nil
    def get_height_width
      if @height.nil?
        rows=[]; cols=[]; frow=[]; fcol=[]; noffscrows=[]; nbuf = []
        field_info(rows, cols, frow, fcol, noffscrows, nbuf)
        @height = rows[0]
        @width = cols[0]
      end
      return @height, @width
    end
    def set_handler handler_code, aproc
      raise "#{handler_code} arg2 should be a proc" if aproc.class != Proc
      user_object[handler_code] = aproc
    end
    ##
    # will typically return value, at least if its on_exit or on_enter handler
    # others are default handler
    def fire_handler handler_code, aform
      user_object[handler_code].call(aform) if user_object.include? handler_code
    end
    def set_read_only(flag=true)
      if flag
        field_opts_off(O_EDIT)
        field_opts_off(O_ACTIVE)
      else
        field_opts_on(O_EDIT)
        field_opts_on(O_ACTIVE)
      end
    end
    def set_reverse flag=true
      if flag
        set_field_back(A_REVERSE)
      else
        set_field_back(A_NORMAL)
      end
    end
    def justify(align=:right)
      case align.downcase
      when :right
        field.set_field_just(JUSTIFY_RIGHT)
      when :left
        field.set_field_just(JUSTIFY_LEFT)
      when :center
        field.set_field_just(JUSTIFY_CENTER)
      end
    end
    def set_real(min=0, max=10000, pad=2)
      set_field_type(TYPE_NUMERIC, pad, min, max)
      set_field_just(JUSTIFY_RIGHT)
      user_object["type"]="real"
    end
    def set_date
      set_field_type(TYPE_REGEXP, "^[12][0-9]\{3}[\-/][0-9]\{2}[\-/][0-9]\{2}")
      user_object["type"]="date"
    end
    def set_integer(min=0, max=10000, pad=2)
      set_field_type(TYPE_INTEGER, pad, min, max)
      set_field_just(JUSTIFY_RIGHT)
      user_object["type"]="integer"
    end
    def self.create_integer_field
    end
    def self.create_real_field
    end
    def self.create_date_field
    end
    def self.create_field(fieldwidth, row, col, name, type=nil,label=nil, height=1, nrows=0, nbufs=0, config={})
      field = FIELD.new(height, fieldwidth, row, col, nrows, nbufs)
      help_text = config.fetch("help_text", "Enter a #{name}")
      label ||= config.fetch("label", name)
      type ||= config.fetch("type", "")

      read_only = config.fetch("read_only", false)
      field.set_read_only(true) if read_only


      field.user_object = config
      field.user_object.merge!({"label"=>label, "name"=>"#{name}", "help_text"=>help_text, 
        :row=>row, :col => col, :label=>label, "type"=>type,"width"=>fieldwidth})

      type = config.fetch("type", "")
      case type.downcase
      when "date":
        field.set_date
      when "integer"
        field.set_integer
      when "smallint"
        field.set_integer(0,127,1)
      when "real", "float", "numeric"
        field.set_real
      end

      yield field if block_given?
      return field
    end
  end                        # class FIELD
end                          # module Form

class RBForm 

  attr_accessor :fields
  attr_reader   :newform
  attr_reader   :application
  #  attr_accessor :window   # the window associated with this 2008-10-15 09:57 
  # the original caller application, all print_ funcs are called on this
  # since it maintains context of the header_win and footer_win
  attr_accessor   :main
  def initialize(fields)
    @newform = FORM.new(fields);
    @fields = fields
    @key_handlers = nil # should be in apps but here due to unhandled
    $interrupted = false # needed now ??? XXX
  end
  def set_fields(fields)
    @fields = fields
  end
  def get_fields()
    @fields
  end
  # returns window associated with this form. 2008-10-15 15:03 
  def window
    return form_win()
  end
  def method_missing(name, *args)
    name = name.to_s
    if (@newform.respond_to?(name))
      #return @newform.send(name, self, *args)
      return @newform.send(name,*args)
    else
      # 2008-10-13 14:39 daring check for application
      # this could put us in an endless loop if app calls form and form is not implementing
      if (@application.respond_to?(name))
        return @application.send(name,*args)
      else
        $log.error("RBFORM method_missing (#{name}): #{@application.class.to_s} ")
        raise "#{name}"
      end
    end
  end
  def set_application(app)
    @application = app
  end

  # receives an int key to processes
  # returns :BREAK, :QUIT, :UNHANDLED, :OK
  def handle_keys(ch, application)
  end
  def populate_form
  end
  def refresh
    @application.wrefresh
  end
  alias :wrefresh :refresh

  ## a multi-line field rejects text containing newlines.
  #  So we split incoming text on newline, then pad it to the width of the
  # field so it looks just as expected.
  # lines longer than width are split and then padded.
  # 2008-09-22 19:28 
  def self.text_to_multiline(text, width)
    text.gsub!(/\t/, '  ') # 2008-10-10 22:59 tabs and other chars are still a problem
    lines = text.split("\n")
    lines.map!{ |line|  
      if line.length <= width
        line.gsub!(/[^[:print:]]/, '') # 2008-10-10 22:59 other chars are still a problem
        sprintf("%-#{width}s", line) 
      else
        sublines = line.scan(/.{1,#{width}}/)
        sublines.map!{ |sline| sline.gsub!(/[^[:print:]]/, ''); sprintf("%-#{width}s", sline)  }
        sublines.join
      end
    }
    #  @content_rows = lines.count
    text = lines.join
    text
  end
  # in order to save as file, or post out
  def self.multiline_format(text, width)
    # ncurses pads each row with spaces rather than put a newline. Very annoying.
    lines = text.scan(/.{1,#{width}}/)
    lines.map{|l| l.strip!}
    lines = lines.join("\n")
    lines
  end
  ##
  # typical inbuilt ones are :form_populate, :form_save, :field_init, :field_term, :form_init
  #  and :form_term
  #  WHAT ABOUT KEYPRESSES ? XXX
  def set_handler handler_code, aproc
    #raise "#{handler_code} arg2 should be a proc or method" if aproc.class != Proc
    # check to see if it is callable
    #raise "#{handler_code} arg2 should be a proc or method" if !aproc.respond_to? :call
    user_object[handler_code] = aproc
  end
  ##
  # will typically return value, at least if its on_exit or on_enter handler
  # others are default handler
  def fire_handler handler_code, *args
    return false if !user_object.include? handler_code
    aproc = user_object[handler_code]
    if aproc.respond_to? :call
      user_object[handler_code].call(*args) #if user_object.include? handler_code
    else
      send(aproc, *args)
    end
  end
  def handle_unhandled_keys(ch)
    @key_handlers = @application.datakeys
    ## TODO these should be directly set into the form and not into this hash
    raise "unhandled called : #{ch}: #{@key_handlers.count}" if @key_handlers.count == 0
    return false if @key_handlers.nil?
    begin # chr fails with left and rt arrow what if someones wants to trap ?
      suffix=ch.chr.upcase
    rescue
      $log.debug "rbform got #{ch}"
      return false
    end
    chup=suffix[0] # will break in 1.9
    if @key_handlers.include?chup
      if @key_handlers[chup] == nil # no action mentioned, use default
        # 2008-10-08 16:29 , commented off on 2008-10-23 22:59 
        #if @datasource.respond_to?"handle_#{suffix}"
        #  @datasource.send("handle_#{suffix}", self)
        #else
        #@main.print_error("Datasource does not handle #{suffix}")
        return false
        #        end
      else
        action = @key_handlers[chup]
        if action.respond_to? :call # 2008-10-27 19:57 
          action.call(self)
        else  # string
          if respond_to?action
            send(action)
          elsif action =~ /^REQ_/  # 2008-10-14 11:07 
            # if key def starts with REQ_ call form driver
            send(action.downcase)
            #          elsif @datasource.respond_to?action
            #            @datasource.send(action, self)
          else
            #@main.print_error("Datasource does not handle this key #{chup.chr}")
            return false
          end
        end
        return true
      end
    end
    return false
  end

  ### ADD HERE ###
  def req_next_page
    form_driver(REQ_NEXT_PAGE);
  end
  def req_prev_page
    form_driver(REQ_PREV_PAGE);
  end
  def req_first_page
    form_driver(REQ_FIRST_PAGE);
  end
  def req_last_page
    form_driver(REQ_LAST_PAGE);
  end
  def req_next_field
    form_driver(REQ_NEXT_FIELD);
  end
  def req_prev_field
    form_driver(REQ_PREV_FIELD);
  end
  def req_first_field
    form_driver(REQ_FIRST_FIELD);
  end
  def req_last_field
    form_driver(REQ_LAST_FIELD);
  end
  def req_snext_field
    form_driver(REQ_SNEXT_FIELD);
  end
  def req_sprev_field
    form_driver(REQ_SPREV_FIELD);
  end
  def req_sfirst_field
    form_driver(REQ_SFIRST_FIELD);
  end
  def req_slast_field
    form_driver(REQ_SLAST_FIELD);
  end
  def req_left_field
    form_driver(REQ_LEFT_FIELD);
  end
  def req_right_field
    form_driver(REQ_RIGHT_FIELD);
  end
  def req_up_field
    form_driver(REQ_UP_FIELD);
  end
  def req_down_field
    form_driver(REQ_DOWN_FIELD);
  end
  def req_next_char
    form_driver(REQ_NEXT_CHAR);
  end
  def req_prev_char
    form_driver(REQ_PREV_CHAR);
  end
  def req_next_line
    form_driver(REQ_NEXT_LINE);
  end
  def req_prev_line
    form_driver(REQ_PREV_LINE);
  end
  def req_next_word
    form_driver(REQ_NEXT_WORD);
  end
  def req_prev_word
    form_driver(REQ_PREV_WORD);
  end
  def req_beg_field
    form_driver(REQ_BEG_FIELD);
  end
  def req_end_field
    form_driver(REQ_END_FIELD);
  end
  def req_beg_line
    form_driver(REQ_BEG_LINE);
  end
  def req_end_line
    form_driver(REQ_END_LINE);
  end
  def req_left_char
    form_driver(REQ_LEFT_CHAR);
  end
  def req_right_char
    form_driver(REQ_RIGHT_CHAR);
  end
  def req_up_char
    form_driver(REQ_UP_CHAR);
  end
  def req_down_char
    form_driver(REQ_DOWN_CHAR);
  end
  def req_new_line
    form_driver(REQ_NEW_LINE);
  end
  def req_ins_char
    form_driver(REQ_INS_CHAR);
  end
  def req_ins_line
    form_driver(REQ_INS_LINE);
  end
  def req_del_char
    form_driver(REQ_DEL_CHAR);
  end
  def req_del_prev
    form_driver(REQ_DEL_PREV);
  end
  def req_del_line
    form_driver(REQ_DEL_LINE);
  end
  def req_del_word
    form_driver(REQ_DEL_WORD);
  end
  def req_clr_eol
    form_driver(REQ_CLR_EOL);
  end
  def req_clr_eof
    form_driver(REQ_CLR_EOF);
  end
  def req_clr_field
    form_driver(REQ_CLR_FIELD);
  end
  def req_ovl_mode
    form_driver(REQ_OVL_MODE);
  end
  def req_ins_mode
    form_driver(REQ_INS_MODE);
  end
  def req_scr_fline
    form_driver(REQ_SCR_FLINE);
  end
  def req_scr_bline
    form_driver(REQ_SCR_BLINE);
  end
  def req_scr_fpage
    form_driver(REQ_SCR_FPAGE);
  end
  def req_scr_bpage
    form_driver(REQ_SCR_BPAGE);
  end
  def req_scr_fhpage
    form_driver(REQ_SCR_FHPAGE);
  end
  def req_scr_bhpage
    form_driver(REQ_SCR_BHPAGE);
  end
  def req_scr_fchar
    form_driver(REQ_SCR_FCHAR);
  end
  def req_scr_bchar
    form_driver(REQ_SCR_BCHAR);
  end
  def req_scr_hfline
    form_driver(REQ_SCR_HFLINE);
  end
  def req_scr_hbline
    form_driver(REQ_SCR_HBLINE);
  end
  def req_scr_hfhalf
    form_driver(REQ_SCR_HFHALF);
  end
  def req_scr_hbhalf
    form_driver(REQ_SCR_HBHALF);
  end
  def req_validation
    form_driver(REQ_VALIDATION);
  end
  def req_next_choice
    form_driver(REQ_NEXT_CHOICE);
  end
  def req_prev_choice
    form_driver(REQ_PREV_CHOICE);
  end
  ### ADD HERE ###
end # class
