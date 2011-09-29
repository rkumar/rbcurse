require 'rbcurse/app'
require 'fileutils'
require 'yaml'
require 'gmail'
# You need gmail gem. (one of them depends on i18n gem).
# # stopped working since gmail does not accept UIDS XXX FIXME
# TODO start putting commands in a popup or menu bar
# TODO what if i want to hide sidebar and bring it back on later
# TODO switch mailbox or label on command line, with prompt letter indexing
# TODO 
# TODO body does not show cc and date from reply_to etc
# TODO seems like gmail web preloads body so no delay, yet it remains unread XXX
# TODO: compose a message  - what of contacts ?  cc bcc
# TODO: reply.
# TODOx refresh, perhaps get unread and compare UIDS
# FIXME: reconnect gave allmain count as inbox count, clicking on lb2 gave nilclass
# TODOx : x  highlight / select if pressing enter, so we know which one is being shwon
#        _  should work with select also. Now we have a kind of mismatch between select
#           and press (spacebar and enter)
# TODOx : cache envelope and body so not read repeatedly
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

class OpenedMessage < Struct.new(:uid, :message, :index)
  def set uid, mess, index
    $log.debug "XXX opened got index #{index}  " if $log.debug? 
    @uid = uid
    @message = mess
    @index = index
    $log.debug "XXX opened got @index #{@index}  " if $log.debug? 
  end
end

#module RubyCurses
#class App
# putting some commands here so we can call from command_line
# ADD
def get_commands
  opts = %w{ test testend archive delete markread markunread spam star unstar open header savecontact connect connectas compose refresh }
  current_component = @vim.current_component
  case current_component
  when @lb2
    opts.push *%w{ select nextm prev nextunread prevunread savecontact header }
  when @tv
    opts.push *%w{ saveas reply replyall nextm prev nextunread prevunread munpack }
  end
  opts
end
# indices can be array or range
# can pass one row as array, @lb2.selected_indices or range 20..25
# . delete
# .,+20 delete
# 1,4 archive
# .,$ select mark etc
def nextm n=1
  ri = @lb2.real_index
  ri = @opened_message.index
  alert "ri in nil in nextm " unless ri
  return unless ri
  #@lb2.down
  #return if ri == @lb2.real_index
  if ri + n < @lb2.row_count
    #@lb2.current_index += 1
    open_mail(ri+n) #@lb2.real_index 
  else
    raw_message "No more messages"
  end
end
def prev
  ri = @lb2.real_index
  ri = @opened_message.index
  return unless ri
  #@lb2.up   # this moves cursor to lb2
  #return if ri == @lb2.real_index
  if ri > 0
    @lb2.current_index -= 1
    open_mail @lb2.real_index 
  else
    say "No previous messages", :color_pair => $prompt_color
  end
end

# fetch body of message and display in textview
def open_mail index
  @current_opened_index = index
  row = @lb2[index]
  unless row
    say "Invalid row.", :color_pair => $prompt_color
    return
  end
  if index >= 0
    uid = row[UID_OFFSET] # UID_OFFSET=5
    #uid = @message_uids[index]
    #body = @gmail.connection.uid_fetch(uid, "BODY[TEXT]")[0].attr['BODY[TEXT]']
    message_immediate "Fetching body from server ..."
    body = uid_to_message( uid ).body # this uses gmail gem's cache
    body = body.decoded.encode("ASCII-8BIT", :invalid => :replace, :undef => :replace, :replace => "?")
    #@tv.set_content(body.to_s, :WRAP_WORD)
    @current_uid = uid
    @current_message = uid_to_message(uid)
    env = @current_message.envelope
    f = env.from[0]
    t = env.to[0]
    from = "From: #{env.from[0].name.to_s} <#{env.from[0].mailbox.to_s}@#{f.host.to_s}>  "
    to = "To: #{env.to[0].name.to_s} <#{env.to[0].mailbox.to_s}@#{t.host.to_s}>  "
    str = to
    str << "\n" << from << "\n" << "Date: " << env.date << "\n" << "Subject: " << env.subject << "\n\n"
    str << body
    @tv.set_content(str, :WRAP_WORD)
    @opened_message.set(uid, uid_to_message(uid), index)
            @opened_message.uid = uid
            @opened_message.message = uid_to_message(uid)
            @opened_message.index = index
    @current_body = body
    row[0][0] = " " if row[0][0] == "N"

    message "Done.                "
    @lb2.repaint_required true
    @form.repaint
  end
end
# i partial command entered then returns matches
def _resolve_command opts, cmd
  return cmd if opts.include? cmd
  matches = opts.grep Regexp.new("^#{cmd}")
end

def select which=nil
  unless which
    opts = %w{ all none read unread starred unstarred from subject invert current n}
    which = ask("Select (TAB for options): ", opts) #{ |q| q.default = @previous_command }
  end
  which = which.to_sym
  case which
  when :all
    @lb2.select_all
  when :none
    @lb2.clear_selection
  when :invert
    @lb2.invert_selection
  when :unread
    list = @lb2.list
    list.each_with_index { |row, i| 
      if row[0][0]=="N" 
        @lb2.add_row_selection_interval(i,i) 
      end
    }
  when :read
    list = @lb2.list
    list.each_with_index { |row, i| 
      if row[0][0]=="N" 
      else
        @lb2.add_row_selection_interval(i,i) 
      end
    }
  when :from
    cv = @lb2.current_value
    from = cv[1]
    list = @lb2.list
    list.each_with_index { |row, i| 
      if row[1] == from
        @lb2.add_row_selection_interval(i,i) 
      end
    }
  when :n
    n = ask("How many? ", Integer) {|q| q.in = 1..100}
    ci = @lb2.current_index - 1 # header_adjustment
    @lb2.add_row_selection_interval ci, ci+n-1
  end
end

# just experimental, we load all mails on clicking a label anyway
# pick out all new mails in INBOX, compare to unread ids list
# and only add in those not in that list. Nothing great.

def refresh
  #@gmail.inbox.find(:unread) do |email|
  raw_message "Fetching ..."
  ctr = 0
  begin
    @gmail.label("INBOX") do |mailbox|
      unread = mailbox.emails(:unread) 
      total = unread.size
      unread.each_with_index do |email, index|  
        uid = email.uid
        if !@unreaduids.include? uid
          @unreaduids << uid
          ctr += 1
          env = email.envelope
          row = convert_message_to_row env, uid
          @lb2.insert 0, row
        end
        raw_progress([index, total])
      end
    end
    raw_message "#{ctr} new messages in inbox."
    #refresh_labels
  rescue => ex
    $log.debug( "EXC refresh  rescue reached.  ")
    print_error ex
  end

end
# one place to write and display exception
def print_error ex
  if ex
    $log.debug( ex)
    $log.debug(ex.backtrace.join("\n"))
    message "EXCEPTION : #{ex} "
    @message_label.repaint
    @window.refresh
  end
end
def convert_message_to_row envelope, uid
  e = envelope
  flag = @unreaduids.include?(uid) ? "N " : " "
  if @starred_uids.include?(uid)
    flag[1]="+"
  end
  date = e.date # .to_s #[5..10]
  date = Date.parse(date).strftime("%b %d")
  # name returns an Array, which crashes sort - therefore to_s, but says String
  from = e.from[0].name.to_s 
  from = e.from[0].mailbox.to_s if from == ""
  [ flag, from, e.subject ,date, uid]
end

def compose
  # TODO make a separate screen damn you !
  name = ask("To: ") # choices should be names from contacts
  subject = ask("Subject: ")
  # shell vim from here using temporary file
  body = edit_text nil
  message_immediate "sending message ... "
  if body
    @gmail.deliver do
      to name
      subject subject
      body body
    end
  end
  message "sent message to #{name} "
end

# needs to go into utils
def edit_text text
  # 2010-06-29 10:24 
  require 'fileutils'
  require 'tempfile'
  ed = ENV['EDITOR'] || "vim"
  temp = Tempfile.new "tmp"
  File.open(temp,"w"){ |f| f.write text } if text
  mtime =  File.mtime(temp.path)
  suspend() do
    system(ed, temp.path)
  end

  newmtime = File.mtime(temp.path)
  newstr = nil
  if mtime < newmtime
    # check timestamp, if updated ..
    newstr = File.read(temp)
  else
    #puts "user quit without saving"
    return nil
  end
  return newstr.chomp if newstr
  return nil
end
def header
  e = @lb2
  env = get_current_message e
  message_immediate "Fetching header ..."
  header = env.header.to_s
  case header
  when String
    header = header.split "\n"
  end
  view(header)
end
def savecontact
  e = @lb2
  env = get_current_message e
  $log.debug "XXX ENV #{env} " if $log.debug? 
  name = env.from[0].name
  id = "#{env.from[0].mailbox}@#{env.from[0].host}"

  obj = nil
  filename = "contacts.yml"
  if File.exists? filename
    obj = YAML::load_file( filename )
  end
  obj ||=[]
  obj << [name, id]
  File.open(filename, 'w' ) do |f|
    f << obj.to_yaml
   end
  message "Written #{name} #{id} to #{filename} "
end
def connectas
  user = ask "Emailid: "
  return unless user
  pass = ask("Password", String){ |q| q.echo = '*' }
  return unless pass
  gmail_connect(user, pass)
end
def connect
  gmail_connect
end
def test
  # creating a scratch window. should be put a textview in it ? or label ?
  require 'rbcurse/rcommandwindow'
  @layout = { :height => 5, :width => Ncurses.COLS-1, :top => Ncurses.LINES-5, :left => 0 }
  rc = CommandWindow.new nil, :layout => @layout
  w = rc.window
  w.box(0,0)
  w.printstring 1,1, "hello there!", $normalcolor, 'normal'
  #rc.handle_keys
  @rc = rc
end
def testend
  @rc.destroy if @rc
  @rc = nil
end
def archive
  if @vim.current_component == @tv
    archive_current
    return
  end
  inds, ms = do_selected_rows(@lb2)
  inds = inds.sort.reverse
  inds.each { |e| @lb2.delete_at e; @messages.delete_at e }
  @lb2.clear_selection
  say " #{inds.size} messages archived"
  Thread.new {
    ms.each { |m| 
    m.archive!
  }
  }
end
# delete current mail, should be called from tv for opened row
# FIXME what if delete repeatedly. what if no next should be check UID
# when we fetch row
def delete_current
  do_with_opened do |ri, message|
    @lb2.delete_at ri
    Thread.new { message.delete! }
  end
  # if we've delete then automatically next falls into place, no need to
  # add one to idnex
  nextm 0
end
def archive_current
  do_with_opened do |ri, message|
    @lb2.delete_at ri
    Thread.new { message.archive! }
  end
  nextm 0

end
def do_with_opened 
  if @vim.current_component != @tv
    say "not on tv. please open a mail and then delete"
    return
  end
  ri = @lb2.real_index
  ri = @opened_message.index
  return if ri.nil? || ri < 1 # header_adjust
  row = @lb2[ri]
  rowuid = row[UID_OFFSET]
  if @opened_message.uid != rowuid
    alert "something wrong, uid not matching"
  end
  message = get_current_message
  return unless message
  yield ri, message if block_given?
end
def delete
  if @vim.current_component == @tv
    delete_current
    return
  end
  e = @lb2
  aproc = lambda {|m| m.delete! }
  inds, ms = for_selected_rows(e, aproc) { |e| @lb2.delete_at e; @messages.delete_at e }
  @lb2.clear_selection
  say " #{inds.size} messages deleted" if inds
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
    uid = w[row][UID_OFFSET] # UID_OFFSET
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
  uid = row[UID_OFFSET] # UID_OFFSET
end
def get_current_message w=@lb2
  uid = get_current_uid w
  message = uid_to_message uid
end
def for_rows(indices, messageproc=nil)
  case indices
  when Integer
    indices = [indices]
  when Range
    indices = indices.to_a
  when :selected
    indices = w.selected_rows
  end
  w = @lb2
  messages = []
  indices = indices.sort.reverse
  indices.each { |row| 
    uid = w[row][UID_OFFSET] # UID_OFFSET
    message = uid_to_message uid
    next unless message
    messages << message
  }
  return false unless indices
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
  return indices, messages
end
# for each selected row, execute the yield row indices to block
# typically for deleting from table, or updating visual status.
# Also call messageproc in a thread for each message since imap
# operations take a little time.
# indices are given in reverse order, so delete of rows in table
# works correctly.
#@return [false] if no selected rows
#@return [Array<Fixnum>, Array<messages>] visual indices in listbox, and related messages (envelopes)
def for_selected_rows(w, messageproc=nil)
  indices = []
  messages = []
  w.selected_rows.each { |row| 
    uid = w[row][UID_OFFSET] # UID_OFFSET
    message = uid_to_message uid
    next unless message
    indices << row
    messages << message
  }
  return false unless indices
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
  return indices, messages
end
# fetch envelopes for a label name
# and populates the right table
def get_envelopes text
  @current_label = text
  $break_fetch = false
  #@message_uids = []
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
        @unreaduids = unreaduids
        dispstr << " getting UIDs .."
        message_immediate dispstr
        uids = []
        allmails.each do |email|
          uids << email.uid
          @uid_message[email.uid] = email
        end
        message_immediate "getting envelopes. unread: #{urc} total: #{total} "
        raw_progress 0.25

        envelopes = @gmail.connection.uid_fetch(uids, "(UID ENVELOPE)")
        # may need to reverse sort this !! TODO
        # reversing means we've lost the link to UID !!! so we redo the list
        return unless envelopes
        lines = []
        envelopes.reverse.each_with_index { |ee, index| 
          raw_progress([index+1, total])
          e = ee.attr["ENVELOPE"]
          uid = ee.attr["UID"]
          #@message_uids << uid UNUSED
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
          #lines << [ flag, ctr+1 , from, e.subject ,date, uid]
          lines << [ flag, from, e.subject ,date, uid]
          ctr+=1
          @messages << e
          break if ctr >= @max_to_read
          break if $break_fetch # can only happen in threaded mode
        }
        @lb2.estimate_column_widths=true # this sort of fails if we keep pushing a row at a time
        @lb2.set_content lines
        #message " #{text} showing #{ctr} of #{total} messages"
        #@message_label.repaint
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
  @vim.focus @dirs
  # place cursor on @dir since lb2 empty FIXME
end
# fetches labels and refreshes the unread counts
# I suspect there are issues here if this is in background, and someone presses enter
# on a label. he sees only unread -data inconsistency/race condition
def refresh_labels
  #message_immediate " inside refresh labels "
  raw_message "Getting label information..."
  @labels ||= @gmail.labels.all
  total = @labels.size
  @labels.each_with_index { |text, index| 
      next if text == "[GMAIL]"
      begin
        @gmail.label(text) do |mailbox|
          unread = mailbox.emails(:unread) # maybe this causes an issue internally
          urc = unread.size
          #message_immediate " mailbox #{text} has #{urc} unread "
          $unread_hash[text] = urc
          raw_progress([index+1, total])
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
UID_OFFSET = 4
App.new do 
  #begin
  @opened_message = OpenedMessage.new
  ht = 24
  @max_to_read = 100
  @messages = nil # hopefully unused
  @labels = nil
  @current_label = nil
  @message_uids = nil # uids of messages being displayed in @lb2 so as to get body
  @starred_uids = nil
  @uid_message = {} # map UID to a message
  @unreaduids = [] # current labels unread
  $unread_hash = {}
  $message_hash = {}
  @tv = nil
  @current_body = nil
  username = ENV['GMAIL_USER']+"@gmail.com"
  pass = ENV['GMAIL_PASS']
  @default_mailbox = "INBOX"
  @gmail = nil
  borderattrib = :reverse
  @header = app_header "rbcurse #{Rbcurse::VERSION}", :text_center => "Yet Another Gmail Client that sucks", :text_right =>"", :color => :black, :bgcolor => :white#, :attr =>  Ncurses::A_BLINK
  message "Press F1 to exit ...................................................."


  stack :margin_top => 1, :margin => 0, :width => :EXPAND do
  
    model = [" Fetching ..."]
    # todo, get unread too and update, do that at some interval

    @vim = master_detail :width => :EXPAND, :weight => 0.15 # TODO i want to change width of left container
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
    @vim.set_left_component @dirs #, 0.25 # FIXME not having impact

    
    #@mails = []
    headings = %w{ __ From Subject Date UID }
    @lb2 = tabular_widget :suppress_borders => true
    # TODO set column widths since we are pushing one at a time.
    @lb2.columns = headings
    #@lb2.column_align 1, :right # earlier numbering as in alpine
    #@lb2.column_align 0, :right
    @lb2.column_hidden UID_OFFSET, true
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
    @form.bind_key(?\M-y){
      # TODO previous command to be default
      opts = %w{ test testend archive delete markread markunread spam star unstar open header savecontact connect connectas compose refresh }
      current_component = @vim.current_component
      case current_component
      when @lb2
        opts.push *%w{ select nextm prev nextunread prevunread savecontact header }
      when @tv
        opts.push *%w{ saveas reply replyall nextm prev nextunread prevunread munpack }
      end
      cmd = ask("Command: ", opts){ |q| q.default = @previous_command }
      if cmd == ""
      else
        cmdline = cmd.split
        cmd = cmdline.shift
        # check if command is a substring of a larger command
        if !opts.include?(cmd)
          rcmd = _resolve_command(opts, cmd) if !opts.include?(cmd)
          if rcmd.size == 1
            cmd = rcmd.first
          else
            alert "Cannot resolve #{cmd}. Matches are: #{rcmd} "
          end
        end
        if respond_to?(cmd, true)
          @previous_command = cmd
          raw_message "calling #{cmd} "
          begin
          send cmd, *cmdline
          rescue => exc
            $log.debug "ERR EXC: send throwing an exception now. Duh. IMAP keeps crashing haha !! #{exc}  " if $log.debug? 
            print_error exc
          end
        else
          say("Command [#{cmd}] not supported by #{self.class} ")
        end
      end
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
      connectas
    }
    @lb2.bind :PRESS do |e|
      case @lb2
      when RubyCurses::TabularWidget
        if e.action_command == :header
          # now does sorting on multiple keys
        else
          ci = e.source.current_index  # this should check what first data index is
          index = ci - 1
          open_mail index
          #@current_opened_index = index
          #row = @lb2[index]
          #uid = row[UID_OFFSET] # UID_OFFSET=5
          #if index >= 0
            ##uid = @message_uids[index]
            ##body = @gmail.connection.uid_fetch(uid, "BODY[TEXT]")[0].attr['BODY[TEXT]']
            #message_immediate "Fetching body from server ..."
            #body = uid_to_message( uid ).body # this uses gmail gem's cache
            #body = body.decoded.encode("ASCII-8BIT", :invalid => :replace, :undef => :replace, :replace => "?")
            #@tv.set_content(body, :WRAP_WORD)
            ##@tv.set_content(body.to_s, :WRAP_WORD)
            #@current_uid = uid
            #@current_message = uid_to_message(uid)
            #@opened_message.set(uid, uid_to_message(uid), index)
            #@opened_message.uid = uid
            #@opened_message.message = uid_to_message(uid)
            #@opened_message.index = index
            #@current_body = body
            #row[0][0] = " " if row[0][0] == "N"
            #$log.debug "XXX opened_message:: #{@opened_message}  " if $log.debug? 
            #$log.debug "XXX opened_message index:: #{@opened_message.index}, #{index}  " if $log.debug? 

            #message "Done.                "
            #@lb2.repaint_required true
            #@form.repaint

            ##@tv.set_content(@messages[index].body.to_s, :WRAP_WORD)
          #end
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
      # looks like star and unstar don't work
      raw_message "called star"
      aproc = lambda {|m| m.star! }
      for_selected_rows(e, aproc) { |i| 
        row = @lb2[i]
        row[0][1] = "+" #if row[0][1] == " "
        raw_message "called star for #{i} #{row[2]} "
      }
    }
    @lb2.bind_key(?S){ |e| 
      aproc = lambda {|m| m.unstar! }
      for_selected_rows(e, aproc) { |i| 
        row = @lb2[i]
        row[0][1] = " " #if row[0][1] == "#"
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
