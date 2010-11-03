require 'rbcurse/app'
require 'fileutils'
require 'gmail'
# You need gmail gem. (one of them depends on i18n gem).
# TODO start putting commands in a popup or menu bar
# TODO: compose a message  - what of contacts ? check sup, how to call vim fomr inside ncurses
# TODO: reply.
# FIXME: reconnect gave allmain count as inbox count, clicking on lb2 gave nilclass
# TODO : x  highlight / select if pressing enter, so we know which one is being shwon
#        _  should work with select also. Now we have a kind of mismatch between select
#           and press (spacebar and enter)
# TODO : cache envelope and body so not read repeatedly
# TODOD: C-w C-w should go between current and last. it does left and right
# TODO: option for only unseen mails
# FIX column widths so date also showm TODO
# # reduce width of left
# TODO: upper right should say NEW if N, also deleted can be D and not removed ??
#       but there's no way to undelete.
# TODO: handling of packed (munpack) - temporary fix in place
# TODO : catch connectionreset and relogin : Connection reset by peer (Errno::ECONNRESET)
# TODO: unread on top, or only unread
# TODO: offline, download all mails (body too)
# TODO: select read, unread, by same author, starred, unstarred


#module RubyCurses
#class App
# putting some commands here so we can call from command_line
def archive
  inds, ms = do_selected_rows(@lb2)
  inds = inds.sort.reverse
  inds.each { |e| @lb2.delete_at e; @messages.delete_at e }
  @lb2.clear_selection
  Thread.new {
    ms.each { |m| 
    m.archive!
  }
  }
end
def delete
  e = @lb2
  aproc = lambda {|m| m.delete! }
  inds, ms = for_selected_rows(e, aproc) { |e| @lb2.delete_at e; @messages.delete_at e }
  @lb2.clear_selection
end
  def saveas *args
    @tv.saveas *args
  end
def remove_current_label m
  label = @current_label
  m.remove_label! label
end
# return message object for a UID
# m.envelope
# m.header   # < take a little time
def uid_to_message uid
  m = @uid_message[uid]
end
# calls block for selected rows
def do_selected_rows(w) # :yield: row, msg
  indices = []
  messages = []
  w.selected_rows.each { |row| 
    uid = w[row][5] # UID_OFFSET
    message = uid_to_message uid
    next unless message
    yield row, message if block_given?
    indices << row
    messages << message
  }
  return indices, messages
end
def get_current_uid w=@lb2
  row = w.current_value
  uid = row[5] # UID_OFFSET
end
def get_current_message w=@lb2
  uid = get_current_uid w
  message = uid_to_message uid
end
# for each selected row, execute the yield row indices to block
# typically for deleting from table, or updating visual status.
# Also call messageproc in a thread for each message since imap
# operations take a little time.
# indices are given in reverse order, so delete of rows in table
# works correctly.
def for_selected_rows(w, messageproc=nil)
  indices = []
  messages = []
  w.selected_rows.each { |row| 
    uid = w[row][5] # UID_OFFSET
    message = uid_to_message uid
    next unless message
    indices << row
    messages << message
  }
  return unless indices
  indices = indices.sort.reverse
  indices.each { |i| yield i if block_given? }
  if messageproc
    thr = Thread.new{
      begin
      messages.each { |m| messageproc.call(m) }
      rescue => ex
        $log.debug( "EXC for_selected_row rescue reached.  ")
        if ex
          $log.debug( ex)
          $log.debug(ex.backtrace.join("\n"))
          message "EXCEPTION IN THREAD: #{ex} "
          @message_label.repaint
          @window.refresh
        end
      end
    }
    thr.abort_on_exception = true
  end
end
# fetch envelopes for a label name
# and populates the right table
def get_envelopes text
  @current_label = text
  $break_fetch = false
  @message_uids = []
  @messages = [] # hopefully unused
  #Thread.new {
    begin
      ctr = 0
      @gmail.label(text) do |mailbox|
        # TODO. praps a progress bar also.
        unreaduids = []
        unread = mailbox.emails(:unread)
        urc = unread.size
        dispstr = " #{text} : unread #{urc} "
        message_immediate dispstr
        $unread_hash[text] = urc
        allmails = mailbox.emails(:read)
        allmails.insert 0, *unread
        total = allmails.size
        dispstr << " total: #{total} "
        unread.each do |email|
          unreaduids << email.uid
        end
        dispstr << " getting UIDs .."
        message_immediate dispstr
        uids = []
        allmails.each do |email|
          uids << email.uid
          @uid_message[email.uid] = email
        end
        message_immediate "getting envelopes. unread: #{urc} total: #{total} "

        envelopes = @gmail.connection.uid_fetch(uids, "(UID ENVELOPE)")
        # may need to reverse sort this !! TODO
        # reversing means we've lost the link to UID !!! so we redo the list
        return unless envelopes
        lines = []
        envelopes.reverse.each_with_index { |ee, index| 
          e = ee.attr["ENVELOPE"]
          uid = ee.attr["UID"]
          @message_uids << uid
          flag = unreaduids.include?(uid) ? "N " : " "
          if @starred_uids.include?(uid)
            flag[1]="+"
          end
          date = e.date # .to_s #[5..10]
          date = Date.parse(date).strftime("%b %d")
          #$log.debug "name: XXX  #{e.from[0].name} "
          #$log.debug "name: XXX  #{e.from[0].class} " unless e.from[0].nil?
          # name returns an Array, which crashes sort - therefore to_s, but says String
          from = e.from[0].name.to_s # why blank some times FIXME
          from = e.from[0].mailbox.to_s if from == ""
          #@lb2.append([ flag, ctr+1 , from, e.subject ,date])
          lines << [ flag, ctr+1 , from, e.subject ,date, uid]
          ctr+=1
          @messages << e
          break if ctr >= @max_to_read
          break if $break_fetch # can only happen in threaded mode
        }
        @lb2.estimate_column_widths=true # this sort of fails if we keep pushing a row at a time
        @lb2.set_content lines
        message " #{text} showing #{ctr} of #{total} messages"
        @message_label.repaint
        @form.repaint
      end
    rescue => ex
      $log.debug( "EXC thread.rb rescue reached.  ")
      if ex
        $log.debug( ex)
        $log.debug(ex.backtrace.join("\n"))
        message "EXCEPTION IN THREAD: #{ex} Reconnect using M-c"
        @message_label.repaint
        @window.refresh
        gmail_connect # this should only happen in imap error not just any
      end
    end
  #}
end
def get_starred gmail
  @starred_uids = []
  starred = @gmail.mailbox("[Gmail]/Starred")
  starred.mails.each do |email|
    @starred_uids << email.uid
  end
  $log.debug "XXX got starred #{@starred_uids.size} " if $log.debug? 
end
# connect to gmail,
# but what if i want to change user - then we need to clear hashes.
def gmail_connect username=ENV['GMAIL_USER']+"@gmail.com", pass=ENV['GMAIL_PASS']
  @gmail = Gmail.connect!(username, pass)
  message_immediate "Connected to gmail, fetching labels ... "
  @labels = @gmail.labels.all
  message_immediate "Fetched labels. Click on a label. "
  get_starred @gmail
  @dirs.list @labels
  @lb2.remove_all
  @tv.remove_all
  @form.repaint
  # pull in inbox contents
  # pull in unread for each label
  #Thread.new { refresh_labels }
  refresh_labels
end
# fetches labels and refreshes the unread counts
# I suspect there are issues here if this is in background, and someone presses enter
# on a label. he sees only unread -data inconsistency/race condition
def refresh_labels
  #message_immediate " inside refresh labels "
  @labels ||= @gmail.labels.all
  @labels.each { |text| 
      next if text == "[GMAIL]"
      begin
        @gmail.label(text) do |mailbox|
          unread = mailbox.emails(:unread) # maybe this causes an issue internally
          urc = unread.size
          #message_immediate " mailbox #{text} has #{urc} unread "
          $unread_hash[text] = urc
        end
      rescue => ex
        $log.debug  " refresh_labels :: ERROR in mailbox #{text} ...  #{ex}" if $log.debug? 
        next
      end
  }
  @dirs.repaint_required(true)
  message_immediate " Ready"
end
#end
#end

# START start
@app = App.new do 
  #begin
  ht = 24
  @max_to_read = 100
  @messages = nil # hopefully unused
  @labels = nil
  @current_label = nil
  @message_uids = nil # uids of messages being displayed in @lb2 so as to get body
  @starred_uids = nil
  @uid_message = {} # map UID to a message
  $unread_hash = {}
  $message_hash = {}
  @tv = nil
  @current_body = nil
  username = ENV['GMAIL_USER']+"@gmail.com"
  pass = ENV['GMAIL_PASS']
  @default_mailbox = "INBOX"
  @gmail = nil
  borderattrib = :reverse
  @header = app_header "rbcurse 1.2.0", :text_center => "Yet Another Gmail Client that sucks", :text_right =>"", :color => :black, :bgcolor => :white#, :attr =>  Ncurses::A_BLINK
  message "Press F1 to exit ...................................................."


  stack :margin_top => 1, :margin => 0, :width => :EXPAND do
  
    model = [" Fetching ..."]
    # todo, get unread too and update, do that at some interval

    @vim = master_detail :width => :EXPAND # TODO i want to change width of left container
    # labels list on left
    @dirs = list_box :list => model, :height => ht, :border_attrib => borderattrib, :suppress_borders => true
    @dirs.one_key_selection = false
    
    # we override so as to only print basename. Also, print unread count 
    def @dirs.convert_value_to_text(text, crow)
      str = text.dup
      if $unread_hash.has_key?(str)
        str << " (#{$unread_hash[str]})"
      else
        str 
      end
    end
    @vim.set_left_component @dirs

    
    #@mails = []
    headings = %w{ __ #  From Subject Date UID }
    @lb2 = tabular_widget :suppress_borders => true
    # TODO set column widths since we are pushing one at a time.
    @lb2.columns = headings
    @lb2.column_align 1, :right
    @lb2.column_align 0, :right
    @lb2.column_hidden 5, false
    @lb2.header_fgcolor :white
    @lb2.header_bgcolor :cyan
    @vim.set_right_top_component @lb2
    Thread.new {
      begin
      @gmail = Gmail.connect!(username, pass)
      message_immediate "Connected to gmail, fetching labels ... "
      @labels = @gmail.labels.all
      message_immediate "Fetched #{@labels.count} labels. Click on a label. "
      @dirs.list @labels
      @form.repaint
      get_starred @gmail
      message_immediate "Fetching #{@default_mailbox} " if @default_mailbox
      get_envelopes @default_mailbox if @default_mailbox
      #Thread.new { refresh_labels } 
      rescue => ex
        if ex
          $log.debug( ex)
          $log.debug(ex.backtrace.join("\n"))
          message "EXCEPTION IN THREAD: #{ex} "
          @message_label.repaint
          @window.refresh
        end
      end
    }
    @dirs.bind :PRESS do |e|
      # TODO = methodize this so i can call it on startup
      text = e.text # can this change if user goes down in dir2 YES
      ci = e.source.current_index
      @dirs.add_row_selection_interval ci, ci # show selected, this should happen on fire auto
      message_immediate "Wait a few seconds ..."
      # don't allow if alreadt inside this, since thread - or only allow one thread FIXME
      # # TODO NOW WE NEED TO CACHE SINC we are not using gmail gem cache
      @lines = []
      @messages = [] # hopefully unused
      #@lb2.remove_all
      @lb2.estimate_column_widths=true # this sort of fails if we keep pushing a row at a time
      # and repainting
      get_envelopes text
    end
    # will only work in Thread mode
    @dirs.bind_key(?q) { $break_fetch = true }
    @dirs.bind_key(27) { $break_fetch = true }
    @form.bind_key(?\M-p){
      require 'live_console'

      lc = LiveConsole.new :socket, :port => 4000, :bind => self.get_binding
      lc.start            # Starts the LiveConsole thread
      alert "started console on 4000 #{self} "
      # you would connect using "nc localhost 4000"
      # if you use pp then it shows here too and mucks the screen.
      # i think it writes on STDSCR - do not use pp and puts, just enter the variable
    }

    @form.bind_key(?\M-m){
      @max_to_read = ask("How many mails to retrieve? ", Integer) { |q| q.in = 1..1000 }
    }
    # write file to disk so as to munpack it
    @form.bind_key(?\M-s){
      if @current_body
        File.open("message.txt", 'w') {|f| f.write(@current_body) }
        message_immediate "Written body as message.txt. You may use munpack on file"
      end
    }
    @form.bind_key(?\M-c){
      gmail_connect
    }
    @form.bind_key(?\M-C){
      user = ask "Emailid: "
      pass = ask("Password", String){ |q| q.echo = '*' }
      gmail_connect(user, pass)
    }
    @lb2.bind :PRESS do |e|
      message_immediate "Fetching body from server ..."
      case @lb2
      when RubyCurses::TabularWidget
        if e.action_command == :header
          # now does sorting on multiple keys
        else
          ci = e.source.current_index  # this should check what first data index is
          index = ci - 1
          row = @lb2[index]
          uid = row[5] # UID_OFFSET=5
          if index >= 0
            #uid = @message_uids[index]
            #body = @gmail.connection.uid_fetch(uid, "BODY[TEXT]")[0].attr['BODY[TEXT]']
            body = uid_to_message( uid ).body # this uses gmail gem's cache
            body = body.decoded.encode("ASCII-8BIT", :invalid => :replace, :undef => :replace, :replace => "?")
            @tv.set_content(body, :WRAP_WORD)
            #@tv.set_content(body.to_s, :WRAP_WORD)
            @current_body = body
            row[0] = "" if row[0] == "N"

            # TODO need to repaint lb2
            @lb2.repaint_required true
            @form.repaint

            #@tv.set_content(@messages[index].body.to_s, :WRAP_WORD)
          end
        end
      else
        @tv.set_content(@messages[e.source.current_index].body, :WRAP_WORD)
      end
    end
    @lb2.bind :ENTER_ROW do |e|
      @header.text_right "Row #{e.current_index} of #{@messages.size} "
    end
    @lb2.bind_key(?\M-a) do |e| 
      env = get_current_message e
      $log.debug "XXX ENV #{env} " if $log.debug? 
      alert " #{env.from[0].name} :: #{env.from[0].mailbox}@#{env.from[0].host} "
      $log.debug "XXX ENV HEADER #{env.header} " if $log.debug? 
    end
    @lb2.bind_key(?U){ |e| 
      aproc = lambda {|m| m.mark(:unread) }
      for_selected_rows(e, aproc) { |i| 
        row = @lb2[i]
        row[0][0] = "N" if row[0][0] == " "
      }
    }
    @lb2.bind_key(?I){ |e| 
      aproc = lambda {|m| m.mark(:read) }
      for_selected_rows(e, aproc) { |i| 
        row = @lb2[i]
        row[0][0] = " " if row[0][0] == "N"
      }
    }
    # we have no way of knowing which ones are starred or unstarred, so can't show.
    @lb2.bind_key(?s){ |e| 
      aproc = lambda {|m| m.star! }
      for_selected_rows(e, aproc) { |i| 
        row = @lb2[i]
        row[0][1] = "*" if row[0][1] == " "
      }
    }
    @lb2.bind_key(?S){ |e| 
      aproc = lambda {|m| m.unstar! }
      for_selected_rows(e, aproc) { |i| 
        row = @lb2[i]
        row[0][1] = " " if row[0][1] == "*"
      }
    }
    # remove current label
    @lb2.bind_key(?X){ |e| 
      label = @current_label
      return unless label
      aproc = lambda {|m| remove_current_label(m) }
      inds, ms = for_selected_rows(e, aproc) { |e| @lb2.delete_at e; @messages.delete_at e }
      @lb2.clear_selection
    }
    @lb2.bind_key(?#){ |e| 
      aproc = lambda {|m| m.delete! }
      inds, ms = for_selected_rows(e, aproc) { |e| @lb2.delete_at e; @messages.delete_at e }
      @lb2.clear_selection
    }
    @lb2.bind_key(?!){ |e| 
      aproc = lambda {|m| m.spam! }
      inds, ms = for_selected_rows(e, aproc) { |e| @lb2.delete_at e; @messages.delete_at e }
      @lb2.clear_selection
    }
    # archive
    # this way of defining does not allow user to reassign this method to a key.
    # we should put into a method in a class, so user can reassign
    @lb2.bind_key(?\e){ |e| 
      inds, ms = do_selected_rows(e)
      inds = inds.sort.reverse
      inds.each { |e| @lb2.delete_at e; @messages.delete_at e }
      @lb2.clear_selection
      Thread.new {
        ms.each { |m| 
           m.archive!
        }
      }

    }
    @lb2.bind_key(?\M-u){ @lb2.clear_selection }

    @tv = @vim.set_right_bottom_component "Email body comes here. "
    @tv.bind_key(?\M-m){ o = @tv.pipe_output('munpack', @current_body)
      $log.debug "munpack returned #{o.size}  " if $log.debug? 
      newfile = o.last.split(" ").first
      $log.debug "munpack file #{newfile}   " if $log.debug? 
      o = File.read(newfile) if File.exists?(newfile)
      @tv.set_content o
      # this leaves a file in current directory
    }
    @tv.bind_key(?\M-A) { |s| @tv.saveas }
    @tv.suppress_borders true
    @tv.border_attrib = borderattrib
  end # stack
  #ensure
    #$log.debug "XX ENSURE !!! " if $log.debug? 
    #gmail.logout
  #end
end # app
