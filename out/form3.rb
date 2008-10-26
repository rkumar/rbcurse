#!/usr/bin/env ruby -w
require 'form'

Form.create :my_form  do

  outfile "gen3.rb"
  save_format 'txt'
  save_path 'out3.txt'
  mystr=<<EOS
  @@states = {"MI" => "Michigan",
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
      if (@@states[val] != nil) 
        afield.set_field_buffer(0,@@states[val])
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
  title "Dependent Fields"
  title_color 3
  win_bkgd 3


  field :item do
    label 'Item'
    field_back :UNDERLINE
    fieldtype :ALNUM
    width 10
    # example of interpolation with run time hash, use only single quotes inside.
    help_text "Enter item code"
  end
  field :rate do
    label 'rate'
    field_back :UNDERLINE
    fieldtype :NUMERIC
    width 10
    min_data_width 0
    padding 2
    range 0,1000
  end
  field :qty do
    label 'Qty'
    field_back :UNDERLINE
    fieldtype :INTEGER
    width 10
    min_data_width 0
    padding 2
    range 0,1000
    default '120'
    help_text_eval %q{'Valid: ' + h["range"].join(" - ")}
    error_message 'Range is #{range}'
  end
  field :state_code do
    label 'State code'
    field_back :UNDERLINE
    fieldtype :CUSTOM, :myfieldcheck, :mycharcheck
    width 10
    min_data_width 0
    help_text_eval %q{ 'Valid: ' + @@states.keys.join(", ")}
    default '@@states.keys.first'
  end

  field :total do
    label 'Total'
    field_back :UNDERLINE
    width 10
    # foreground color is foreground of color pair 1
    fore 1
    just :JUSTIFY_RIGHT
    opts_off :O_ACTIVE, :O_EDIT
    observes :qty, :rate
    update_func 'getv("qty").to_i * getv("rate").to_f'
  end
  field :date do
    label 'Date'
    width 20
    default 'Time.now'
    opts_off :O_ACTIVE, :O_EDIT
  end
end
