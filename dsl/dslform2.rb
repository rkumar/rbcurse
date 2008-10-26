#!/usr/bin/env ruby -w
require 'genform'

GenForm.create 'Emailer'  do

  outfile "email.rb"
  save_format 'txt'
  save_path 'out2.txt'
  form_post_proc 'method(:form_post_proc)'
  header_top_left "Demos"
  header_top_center "Rmailer"
  #set_handlers  :form_populate => 'method(:form_pop)', :form_save => 'method(:form_save)' 
  #  infile 'dump.yml'
  pipe_output_path '/usr/sbin/sendmail -t'
  save_template "From: {{from}}\r\nTo: {{to}}\r\nCc: {{cc}}\r\nSubject: {{subject}}\r\n\r\n{{body}}\r\n\r\n"
  mystr=<<EOS
  # add localhost if not given. Example of what can be done.
  def emailid_format(to, field)
      to = to + "@gmail.com" if to && to.strip != "" && to !~ /@/
      to
  end
  # @return datahash
  def form_post_proc(datahash, fields)
    body = datahash["body"]
    #body = multiline_format(body, 60)
    sig = "\n\n--\nThis is my sig!"
    datahash["body"] = body + sig
    datahash
  end
EOS
  myfuncs mystr

  edit_application 'eapp' do
    title "An email client in ncurses"

    field :from do
      position 1,1
      label 'From'
      fieldtype :REGEXP,  "^[a-z_0-9@.]+ *$"
      width 60
      min_data_width 0
      # example of interpolation with run time hash, use only single quotes inside.
      help_text "Enter your id"
      # this is because defaults can be executable commands like 'Time.now' or 'rand(200)'
      # or even '`date`' or '`ls -l`'
      default "oneness.univ"
      post_proc 'method(:emailid_format)'
    end
    field :to do
      position 2,1
      fieldtype :REGEXP,  "^[a-z_0-9@.]+ *$"
      label 'To'
      width 60
      default "rahulbeneg"
      post_proc 'method(:emailid_format)'
    end
    field :cc do
      position 3,1
      fieldtype :REGEXP,  "^[a-z0-9_@. ]+$"
      label 'Cc'
      width 60
      default "rahul"
      post_proc 'method(:emailid_format)'
    end
    field :date do
      position 4,1
      fieldtype :ALNUM
      label 'Date'
      opts_off :O_EDIT,:O_ACTIVE
      width 60
      default 'lambda {Time.now.rfc2822}'
    end
    field :subject do
      position 6,1
      label 'Subject'
      width 60
      help_text 'Enter a subject for your email'
    end

    field :body do
      position 8, -10
      label '----- Message Text -----'
      label_rowcol 7,1
      field_back :NORMAL
      width 60
      height 8
      opts_off [:O_STATIC]
      opts_on [:O_WRAP]
      help_text "Tab out before saving."
    end
    Datasource 'Messages' do
#      header_top_left "Demos"
#      header_top_center "Rmailer"
    end
  end
end
