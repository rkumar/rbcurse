#!/usr/bin/env ruby -w
# WARNING. This file is required by appemail.rb.
#
# Supply the path of any mbox file such as ~/mbox or ~/mail/read-mail
# and see a listing of mails, then give a msg number and see body
# You may run this with -EASCII-8BIT if it crashes with a UTF8 error.
#require 'mailread' # i've copied it in here 2011-09-18 
require 'date'

# a sample mail formatter class
# Does formatting just like alpine
# Each message is passed in the format method, thus this is reused
class MailFormatter 
  attr_reader :message
  attr_reader :header
  def initialize #message
    #@message  = message
    #@header   = message.header
  end

  def date
    raise StandardError, "pass message first using format()" unless @header
    m = @header
    date = Date.parse(m['Date'])
    date = date.strftime("%b %d")
  end

  def from
    raise StandardError, "pass message first using format()" unless @header
    m = @header
    match = m['From'].to_s.match(/\((.*)\)/)
    from  = m['From']
    if match
      from = match[1]
    else
      match = m['From'].to_s.match(/(.*)</)
      from = match[1] if match
    end
    from
  end
  def body
    raise StandardError, "pass message first using format()" unless @message
    @message.body
  end

  def subject
    raise StandardError, "pass message first using format()" unless @header
    m = @header
    m['Subject']
  end
  def status
    raise StandardError, "pass message first using format()" unless @header
    m = @header
    m['Status']
  end

  def format message, count
    @header = message.header
    #@message  = message
    m = message.header
    "%2s %2d %s %-25s %-s\n" % [ status, count, date, from, subject ]
  end

  def create_array message, count
    @header = message.header
    #@message  = message
    m = message.header
    #printf("#{attr}%2s %2d  %s |%-25s| %-s#{attre}\n", m['Status'], count, date, from, msg.header['Subject'])
    row = [ status, count, date, from, m['Subject'] ]
  end
end # class
# opens and maintains an mbox mailbox
class Mbox
  include Enumerable
  attr_reader :folder
  attr_reader :mails
  attr_reader :unread_count
  attr_reader :read_count

  # takes a mailbox name, e,g., mbox
  # Does not update, since this is just a demo
  def initialize folder
    raise ArgumentError, "#{folder} not a valid file. Pls supply correct path." if !File.exists? folder
    @folder  = folder
    @unread_count = 0
    @read_count = 0
    @mboxh = {}
    @mbox_counts = {}
    @mails = nil
    @formatter = nil
    parse
  end
  def parse &block # :yields: Mail
    mbox = File.open(@folder)
    count = lines = 0
    unread_count = 0
    read_count = 0
    # array of mails
    mails = []

    # read up the warning message, we don't want it in our array
    msg = Mail.new(mbox)

    while !mbox.eof?
      msg = Mail.new(mbox)
      count += 1
      s = msg.header['Status']
      if s == "O"
        unread_count += 1
      else
        read_count += 1
      end
      mails << msg
      yield msg if block_given?
    end
    @mails = mails
    #@mbox_counts[@folder] = [unread_count, read_count]
    @unread_count, @read_count = unread_count, read_count
    mbox.close
  end
  def each # :yields: message
    parse unless @mails
    @mails.each { |e| yield e }
  end
  def formatted_each &block
    fmt = @formatter || MailFormatter.new
    each_with_index do |msg, index|
      yield fmt.format msg, index + 1
    end
  end
  # returns an array for each entry which can be used with tabularwidget
  def array_each &block
    fmt = @formatter || MailFormatter.new
    each_with_index do |msg, index|
      yield fmt.create_array msg, index + 1
    end
  end
  # set a formatter object, if you wish to override default one
  def formatter fmt
    @formatter = fmt
  end
end
# opens and maintains a hash of mboxes
# does not see to add any value other than being just a hash !
class MboxManager
  def initialize
    @boxes = {}
    @current_name = nil
  end
  def use folder
    if !@boxes.has_key? folder
      @mails = Mbox.new folder
      @boxes[folder] = @mails
    else
      @mails = @boxes[folder]
    end
    @current_name = folder
    @mails
  end
  def mails folder=@current_name
    use folder
    @mails
  end
end

# The Mail class represents an internet mail message (as per RFC822, RFC2822)
# with headers and a body. 
class Mail

  # Create a new Mail where +f+ is either a stream which responds to gets(),
  # or a path to a file.  If +f+ is a path it will be opened.
  #
  # The whole message is read so it can be made available through the #header,
  # #[] and #body methods.
  #
  # The "From " line is ignored if the mail is in mbox format.
  def initialize(f)
    unless defined? f.gets
      f = open(f, "r")
      opened = true
    end

    @header = {}
    @body = []
    begin
      while line = f.gets()
        line.chop!
        # Added encode by RK since crashing with UTF-8 error
        line = line.encode("ASCII-8BIT", :invalid => :replace, :undef => :replace, :replace => "?")
        next if /^From /=~line	# skip From-line
        break if /^$/=~line	# end of header

        if /^(\S+?):\s*(.*)/=~line
          (attr = $1).capitalize!
          @header[attr] = $2
        elsif attr
          line.sub!(/^\s*/, '')
          @header[attr] += "\n" + line
        end
      end

      return unless line

      while line = f.gets()
        # Added encode by RK since crashing with UTF-8 error
        line = line.encode("ASCII-8BIT", :invalid => :replace, :undef => :replace, :replace => "?")
        #line = line.encode('ASCII-8BIT') # added RK
        break if /^From /=~line
        @body.push(line)
      end
    ensure
      f.close if opened
    end
  end

  # Return the headers as a Hash.
  def header
    return @header
  end

  # Return the message body as an Array of lines
  def body
    return @body
  end

  # Return the header corresponding to +field+. 
  #
  # Matching is case-insensitive.
  def [](field)
    @header[field.capitalize]
  end
end
#puts mails.size
if __FILE__ == $PROGRAM_NAME
  MAILBOX = ARGV[0] ||  "mbox"
  mx = Mbox.new MAILBOX
  mx.formatted_each do |str|
    puts str
  end
  mails = mx.mails
BOLD       = "\e[1m"
CLEAR      = "\e[0m"

  # ask user for a number and print body for that
  while true
    print "Enter a mail number [1 to #{mails.size}]:"
    n = STDIN.gets.chomp
    break if n.nil? || n.empty? 
    msg = mails[n.to_i-1]
    body = msg.body
    puts
    string= "#{msg.header['Subject']}"
    puts "#{BOLD}#{string}#{CLEAR}"
    puts "-" * string.length
    puts body
  end
end
