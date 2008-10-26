#!/usr/bin/env ruby -w
require 'form'

Form.create :my_form  do

  outfile "gen3.rb"
  mystr=<<EOS
  states = {"MI" => "Michigan",
            "VA" => "Virginia",
            "VE" => "Vermont"}
EOS
  myfuncs mystr

#  init_pair 1, "COLOR_RED", "COLOR_BLACK"
#  init_pair 2, "COLOR_BLACK", "COLOR_WHITE"
#  init_pair 3, "COLOR_BLACK", "COLOR_GREEN"
#  bkgd  2
  title "My Quick Form"
# title_color 1
#  win_bkgd 3


  field :from do
#    label 'From'
#    fieldtype :ALNUM
    width 10
  end
  field :rate do
    label 'rate'
    fieldtype :NUMERIC
    range 0,1000
  end
  field :qty do
    label 'Qty'
    fieldtype :INTEGER
  end
  field :state_code do
    label 'State code'
    default 'states.keys.first'
  end
  field :numbers do
    label 'Regexp'
   fieldtype :REGEXP,  "^ *[0-9]* *$"
  end
end
