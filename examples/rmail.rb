#!/usr/bin/env ruby -w
#
# this will only work in 1.8.7, since mailread.rb is not present after that
# supply the path of any mbox file such as ~/mbox or ~/mail/read-mail
# and see a listing of mails, then give a msg number and see body
# You may run this with -EASCII-8BIT if it crashes with a UTF8 error.
require 'mailread'
require 'date'

#BOLD       = "\e[1m"
#CLEAR      = "\e[0m"
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
    raise ArgumentError, "#{folder} not a valid file" if !File.exists? folder
    @folder  = folder
    @unread_count = 0
    @read_count = 0
    @mboxh = {}
    @mbox_counts = {}
    @mails = nil
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
#puts mails.size
if __FILE__ == $PROGRAM_NAME
  MAILBOX = ARGV[0] ||  "mbox"
  mx = Mbox.new "mbox"
  mx.formatted_each do |str|
    puts str
  end
  mails = mx.mails

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
