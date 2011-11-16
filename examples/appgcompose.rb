require 'rbcurse/core/util/app'
require 'gmail'

# requires gmail gem

def insert_file
  str = ask("File?  ", Pathname)  do |q| 
    q.completion_proc = Proc.new {|str| Dir.glob(str +"*").collect { |f| File.directory?(f) ? f+"/" : f  } }
    q.helptext = "Enter start of filename and tab to get completion"
  end
  message "we got #{str} "
end
################
# Allow a field to have gmail like completion
# As a user types, a window highlights matches. Up and down arrow key may be used to select with Enter.
# A user may type Multiple email ids in field (space or comma sep), and matches for last word will be 
# displayed.
# If you wish to use this in other ways:
#    - match entire field not last word, then set matching to false or single
#    - match_from_start will match your array values from start. If you want 
#        the pattern to match anywhere in array, set to false.
#    - set height, width, top and left in config hash
#    - block is intended to allow caller to override matching TODO
class GmailField
  def initialize field, list=nil, config={}, &block
    @field = field
    @list = list
    @config = config
    @matching = config.fetch(:matching, :multiple)
    @match_from_start = config.fetch(:match_from_start, true)
    setup
  end
  def setup # gmailfield
    @field.bind(:CHANGE) do |eve|
      c = eve.source
      text = c.getvalue
      if text[-1] == " "
        clear_list
      else
        pos = text.rindex(/, /)
        if pos
          text = text[pos+1..-1].strip if @matching == :multiple
        end
        @textsize = text.size
        # \W instead of ^, will match start of word, lastname, emailid
        patt = @match_from_start ?  %r{\W#{text}}i : %r{#{text}}i
        matches = @list.grep patt
        @matches = matches
        if @matches.size == 1 && @matches.first == text
          clear_list
        else
          #$log.debug "XXXX #{self.class}  matches #{matches} " if $log.debug? 
          #@caller = app.config[:caller]
          if !matches.empty? 
            say " matches:  #{matches.size}: #{matches} "
            @list_object = udisplay_list matches
          else 
            clear_list
            #@caller.clear_list
          end
        end
      end
    end
    @field.bind(:LEAVE) do |eve|
      clear_list
    end
    @field.bind_key(KEY_DOWN) do
      if @list_object
        @list_object.press(KEY_DOWN)
        #current_index = @list_object.current_index
        @list_object.display_content
      else
        :UNHANDLED
      end
    end
    @field.bind_key(KEY_UP) do
      if @list_object
        @list_object.press(KEY_UP)
        #current_index = @list_object.current_index
        @list_object.display_content
      else
        :UNHANDLED
      end
    end
    @field.bind_key(13) do
      #if @caller
      if @list_object
        @list_object.press(KEY_ENTER)
        current_index = @list_object.current_index
        if current_index > @matches.size-1
          current_index = 0
        end
        sel = @matches[current_index]
        if sel
          #$log.debug "XXXX sel #{sel},  #{@textsize}  " if $log.debug? 
          if @textsize
            t = @field.getvalue
            $log.debug "XXXX t #{t}:: matches:: #{@matches} " if $log.debug? 
            t.slice!(-@textsize..-1)
            t << sel

            #t << sel[@textsize..-1]
            @field.set_buffer(t)
          else
            @field.set_buffer(@matches[current_index])
          end
          @field.cursor_end
        end # sel , otherwise matches was nil
        # need to set cursor correctly.
        clear_list
      end
      #end
    end
  end

  def udisplay_list list1 # gmailfield
    unless @commandwin
      require 'rbcurse/core/util/rcommandwindow'
      if @style == :old
        h = @config.fetch(:height, 5)
        w = @config.fetch(:width, Ncurses.COLS-1)
        top = @config.fetch(:top, Ncurses.LINES-6)
        left = @config.fetch(:left, 0)
      else
        hj = list1.size+2
        hj = [hj, 10].min
        h = @config.fetch(:height, hj)
        w = @config.fetch(:width, list1[0].size+5)
        top = @config.fetch(:top, @field.row+1 )
        left = @config.fetch(:left, @field.col)
      end
      layout = { :height => h, :width => w, :top => top, :left => left }
      rc = CommandWindow.new nil, :layout => layout, :box => :border #, :title => config[:title]
      @commandwin = rc
    end
    begin
      @commandwin.clear
      @commandwin.udisplay_list list1
    ensure
      #rc.destroy
      #rc = nil
    end
  end
  def clear_list # gmailfield
    if @commandwin
      @commandwin.destroy
      @commandwin = nil
    end
    @list_object = nil
  end
end
module AppgCompose
  class GmailCompose
    def initialize gmail=nil, config={}
      @gmail = gmail
      @username = config[:username]
      @password = config[:password]
      @config = config
      #@to = config[:to]
      #@cc = config[:cc]
      #@bcc = config[:bcc]
      #@subject = config[:subject]
      yield self if block_given?
    end
    def __udisplay_list list1 # gmailcompose
      warn "is this used ?"
      unless @commandwin
        require 'rbcurse/core/util/rcommandwindow'
        layout = { :height => 5, :width => Ncurses.COLS-1, :top => Ncurses.LINES-6, :left => 0 }
        rc = CommandWindow.new nil, :layout => layout, :box => true #, :title => config[:title]
        @commandwin = rc
      end
      begin
        #w = rc.window
        # may need to clear first
        @commandwin.clear
        @commandwin.udisplay_list list1
      ensure
        #rc.destroy
        #rc = nil
      end
    end
    def __clear_list # gmailcompose
      warn "is this used"
      if @commandwin
        @commandwin.destroy
        @commandwin = nil
      end
      @list_object = nil
    end
    def run
      ss = self
      #$log.debug "XXX self #{ss.class}  " if $log.debug? 
      App.new(:caller => ss) do |app|
        #@caller = app.config[:caller]
        #$log.debug " inside XXX new app #{@caller} "
        $log.debug " inside XXX new app config #{app.config} "
        def get_commands
          %w{ insert_file}
        end
        header = app.app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Compose Mail", :text_right =>"27% Stronger", :color => :black, :bgcolor => :white, :attr => :bold 
        app.message "Press F10 to exit from here"
        app.stack :margin_top => 2, :margin => 5, :width => 15 do |xxx|
          fg = :white
          bg = :blue
          app.label :text => "To", :color => fg, :bgcolor => bg, :display_length => 10
          app.label :text => "Subject", :color => fg, :bgcolor => bg, :display_length => 10
          app.label :text => "Cc", :color => fg, :bgcolor => bg, :display_length => 10
          app.label :text => "Body", :color => fg, :bgcolor => bg, :display_length => 10
        end


        ww = 80
        app.stack :margin_top => 2, :margin => 25, :width => ww do |xxx|
          file="contacts.yml"
          to_list = []
          if File.exists? file
            require 'yaml'
            contacts = YAML::load( File.open(file))
            contacts.each { |e| to_list << "\"#{e[0]}\" <#{e[1]}>" }
          else
            to_list = ['"Matz " <matz@ruby.com>', '"James E Gray" <james@gmail.com>', '"Steve Jobs" <jobs@apple.com>', '"Bram Moolenar", <bmool@vim.com>', '"Mental Guy", <mentalguy@me.com>' ]
          end
          @to = app.field "to", :maxlen => 100, :bgcolor => :white, :color => :black
          GmailField.new @to, to_list
          @to.text = @config[:to]
          @subject = app.field "subject", :maxlen => 100, :display_length => nil , :bgcolor => :white, :color => :black
          @subject.text = @config[:subject]
          @cc = app.field "cc", :maxlen => 100, :display_length => nil , :bgcolor => :white, :color => :black
          GmailField.new @cc, to_list #, {:top => @cc.row+1, :left => @cc.col, :width => 40 }
          @cc.text = @config[:cc]
          @body = app.textarea :height => 10 do |e|
            #e.source.get_text
          end
          app.hline :width => ww
          app.flow do |xxx|
            app.button "&Post" do
              alert "To field is nil in button itself" if @to.nil?
              app.message "posting letter"
              #@caller = app.config[:caller]
              status = post_letter(self, :to => @to, :subject => @subject, :body => @body)
              app.message "posted email: status #{status} "
            end
            app.button "&Save" do
              app.message "saving to file"
            end
          end

        end # stack
      end # app

    end # run
    # now we can access to and subject and body directly
    # post an email
    def post_letter app, config={}
      #alert "i can access to directly. #{@to.getvalue} " if @to
      to = config[:to]
      subject = config[:subject]
      body = config[:body]
      if to.nil? 
        alert "To is nil. Some programming error"
        return false
      end
      unless @username
        ww = ENV['GMAIL_USER'] 
        #ww << "@gmail.com" if ww # suddnely giving frozen string error
        ww = ww + "@gmail.com" if ww
        @username = ask("Username: ") { |q| q.default = ww }
      end
      unless @password
        ww = ENV['GMAIL_PASS']
        @password = ask("Password: ") { |q| q.default = ww; q.echo ="*" }
      end
      if @username.nil? || @password.nil?
        say_with_pause "Cannot proceeed without user and pass" 
        return false
      end
      unless @gmail
        say "Connecting to gmail..."
        begin
          @gmail = Gmail.connect!(@username, @password)
        rescue => ex
          @password = @username = nil
          $log.debug( ex) if ex
          $log.debug(ex.backtrace.join("\n")) if ex
        end
      end
      unless @gmail
        say_with_pause "Cannot proceeed without connection" unless @gmail
        return false
      end

      body = body.get_text
      to = to.getvalue
      subject = subject.getvalue
      say "Posting #{subject} to #{to} "
      if body
        @gmail.deliver do
          to to
          subject subject
          body body
        end
      else
        alert "Got no body"
      end # body
      true
    end # post_letter

  end # class
end # module
if __FILE__ == $PROGRAM_NAME
  a = AppgCompose::GmailCompose.new
  a.run
end

