#!/usr/bin/env ruby -w
require 'genquery'

GenQuery.create 'TransactionViewer'  do

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
    field :product_name do
      label 'Product'
      width 30
      help_text "Enter a portion of a product"
    end
    field :price do
      label 'Price'
      width 10
      help_text "Enter a portion of a URL to filter on"
    end
  end

  table_application 'tapp' do
    rows_to_show 12
    field_length 80
    xdatasource 'FFHistory'
    Datasource 'Transactions' do
      db      'testdb.db'
      entity  'transaction'
      apptype 'sqlite3'
      sqlstring "select product_name,transaction_quantity,price,units,total_transmission_charge from transactions"
      header_top_left "Demos"
      header_top_center "Transactions"
    end
  end

end
