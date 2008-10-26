#!/usr/bin/env ruby -w
require 'form'

Form.create :my_form  do

  outfile "gen1.rb"
  save_format 'txt'
  save_path 'out.txt'
  mystr=<<EOS
  states = {"MI" => "Michigan",
            "VA" => "Virginia",
            "VE" => "Vermont"}
  
  mycharcheck = proc { |ch|
    if (('A'..'Z').include?(ch))
      return true
    else
      return false
    end
  }
  myfieldcheck = proc { |afield|
      val = afield.field_buffer(0)
      val.strip!
      if (states[val] != nil) 
        afield.set_field_buffer(0,states[val])
        return true
      else
        return false
      end
    }
EOS
  myfuncs mystr

  init_pair 1, "COLOR_RED", "COLOR_BLACK"
  init_pair 2, "COLOR_WHITE", "COLOR_BLACK"
  init_pair 3, "COLOR_WHITE", "COLOR_BLUE"
  bkgd  2
  title "My Formy"
  title_color 3
  win_bkgd 3


  field :from do
    label 'From'
    field_back :UNDERLINE
    fieldtype :ALNUM
    width 10
    min_data_width 0
    # example of interpolation with run time hash, use only single quotes inside.
    help_text "Enter only #"+"{h['width']} letters"
  end
  field :rate do
    label 'rate'
    field_back :UNDERLINE
    fieldtype :NUMERIC
    width 10
    min_data_width 0
    padding 2
    range 0,1000
    default 'rand(1000)'
  end
  field :qty do
    label 'Qty'
    field_back :UNDERLINE
    fieldtype :INTEGER
    width 10
    min_data_width 0
    padding 2
    range 0,1000
    default 120
    help_text_eval %q{'Valid: ' + h["range"].join(" - ")}
    error_message 'Range is #{range}'
  end
  field :state_code do
    label 'State code'
    field_back :UNDERLINE
    fieldtype :CUSTOM, :myfieldcheck, :mycharcheck
    width 10
    min_data_width 0
    help_text_eval %q{ 'Valid: ' + states.keys.join(", ")}
    default 'states.keys.first'
  end

  field :numbers do
    label 'numbers'
    field_back :UNDERLINE
    fieldtype :REGEXP,  "^ *[0-9]* *$"
    width 10
    # foreground color is foreground of color pair 1
    fore 1
    min_data_width 0
    just :JUSTIFY_RIGHT
  end
  field :nickname do
   label 'nickname'
    field_back :UNDERLINE
    fieldtype :ALPHA
    valid "^[a-z]*$"
    width 10
    min_data_width 0
    help_text_eval '("a".."z").entries'
    #help_text 'You cannot see this!'
    # comma sep options to switch off
    #opts_off :O_PUBLIC
    # comma sep options to switch on
    #opts_on :O_EDIT,:O_VISIBLE
  end
  field :enumcheck do
    label 'enumcheck'
    field_back :UNDERLINE
    fieldtype :ENUM
    width 10
    min_data_width 0
    #values 'states.keys'
    values '["one","two","three"]'
    #values '("1".."9").entries'
    #values 'myarray.entries'
    checkcase false
    checkunique false
    help_text_eval %q{'Valid: ' + h["values"].join(", ")}
  end
end
