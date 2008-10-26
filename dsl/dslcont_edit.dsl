#!/usr/bin/env ruby -w
require 'genform'

# string will be used as a class name and file name
GenForm.create 'ContractEdit'  do

  mystr=<<EOS
  myfieldcheck = proc { |afield|
    }
EOS
  myprocs mystr
  mystr1=<<EOS
  def someproc

  end
EOS
  mydefs mystr1

  query_application 'qapp' do
    # field names map to actual table fields
    field :contract_id do   
      label 'contract_id'
      width 10
      field_back 'REVERSE'
      help_text "Enter a rate to search on"
    end
  end

  edit_application 'tapp' do
    # string will be used as a class name 
    field :contract_id do   
      label 'contract_id'
      width 10
      field_back 'REVERSE'
      help_text "Enter a rate to search on"
    end
    field :product_name do   
      label 'product_name'
      width 10
      field_back 'REVERSE'
      help_text "Enter a rate to search on"
    end
    field :rate do   
      label 'rate'
      width 5
      field_back 'REVERSE'
      help_text "Enter a rate to search on"
    end
    Datasource 'Contracts' do
      db      'testd.db'
      entity  'contracts'   # printed on top right, e.g., 1 of 5 contracts
      apptype 'sqlite3'
      sqlstring "select contract_id, contract_execution_date, rate, quantity, product_name from contracts"
      column_widths 8, 10, 5, 8, 15  # optional, but makes neater.
      #optional but make things neater
      #column_titles "Contract", "Exec Date", "Rate", "Quantity", "Product Name"
      header_top_left "Demos"
      header_top_center "Contracts"
      #column_separator " | "
      keys_handled [{ :keycode=>"X"[0], :display_code => "X", :text => "eXlcude" },
       { :keycode=>"V"[0], :display_code => "V", :text => "View   " },
       { :keycode=>999, :display_code => " ", :text => "       " },
       { :keycode=>"$"[0], :display_code => "$", :text => "Sort   ", :action => "sort" }]
 
    end
  end

end
