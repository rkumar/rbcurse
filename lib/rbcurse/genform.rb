# == Synopsis 
# == Usage 
# == Author
#   rkumar
#
# == Copyright
#   Copyright (c) 2008 rkumar. Licensed under the MIT License:
#   http://www.opensource.org/licenses/mit-license.php

require 'rubygems'
require 'ncurses'
require 'erb'
require 'yaml'
require 'pp'

module GenForm
  extend self

  @@fields = []
  @@hashes = {}
  @@debug = false
#  @@form={}        # form has to be passed
  @@menuarr = []   # array of menuitem hashes to be passed to actual code
  @@labelarr = [] # array of label hashes to be passed to actual code
  @@curfield = '' # to distinguish where we are in menuitem or outside
  @@table_app = {}
  @@query_app = {}
  @@edit_app = {}
  @@datasource = {}
  @@wrap_after = 3  # wrap after 3 fields sicne query form has little space
  @@app = {}
  @@currhash = @@app
  @@index = 0
  @@labelindex = 0
  @type = :form     # tells me which array to fill: form, menuitem or label
  @@initcode = []   # text of user-def procs to be added to source
  @@outfile = "app.txt"

  def create(name, &block)
    puts name.to_s if @@debug
    @@app["classname"] = name.to_s
    
   
    #params= %w[label field_back fieldtype min_data_width values checkcase checkunique help_text default valid]
    #params.each { |param| @@hashes["#{param}"] = {} }
    instance_eval(&block) if block_given?
    if !check_sanity?
      print "CRASHING OUT. PLS CORRECT INPUT FILE!\n"
      exit(-1)
    end
    if @@debug
      puts "printing fields"
      pp @@fields
      puts "printing table_app"
      pp @@table_app if !@@table_app.empty?
      puts "printing query_app"
      pp @@query_app if !@@query_app.empty?
      puts "printing datasource"
      pp @@datasource if !@@datasource.nil?
      puts "printing hashes"
      pp @@hashes
      puts "printing app"
      pp @@app

      puts "printing edit_app"
      pp @@edit_app if !@@edit_app.nil?
    end

    @@str = ""
    if !@@query_app.empty?
      @@str << "@query_app=" + @@query_app.inspect
      @@str << "\n"
    end
    myfuncs = @@app.delete('myfuncs')
    myprocs = @@app.delete('my.funcs')
    @@initcode << "@rt_fields=" + @@fields.inspect
    @@initcode << "@rt_form=" + @@app.inspect
    if !@@table_app.empty?
      @@str << "@table_app=" + @@table_app.inspect
      @@str << "\n"
    end
    if !@@edit_app.empty?
      @@str << "@edit_app=" + @@edit_app.inspect
      @@str << "\n"
    end
    @@str << "@app=" + @@app.inspect
      puts @@str

   #template=File::read("_skelform.rb");
   template=File::read("_skelform2.rb");
   message = ERB.new(template, nil, '%<>')
   output=message.result(binding)
    output.gsub!(/(\#\#\#DEFS_COME_HERE\#\#\#)$/,'\1'+"\n"+myfuncs) if !myfuncs.nil?
    output.gsub!(/(\#\#\#PROCS_COME_HERE\#\#\#)$/,'\1'+"\n"+myprocs) if !myprocs.nil?
   output.gsub!(/^\s*$/,'')
    if !@@query_app.empty?
      qfields =  create_field_string(@@query_app)
      output.gsub!(/(\#\#\#QFIELDS\#\#\#)$/,'\1'+"\n"+qfields)
    end
    if !@@edit_app.empty?
      qfields =  create_field_string(@@edit_app)
      output.gsub!(/(\#\#\#FIELDS\#\#\#)$/,'\1'+"\n"+qfields)
    end
    
    if @@outfile == nil
      puts output
    else
      @@outfile = @@app["classname"].downcase + ".rb"
      File.open( @@outfile, 'w' ) do |f|
        #f << @@str
        f << output
      end
      puts "see #{@@outfile}"
    end


  end
  # in order to have multiple edit apps need to use name provided in hash
  def edit_application(fld, attribs={}, &block)
    puts "EA: ", fld.to_s
    @@curfield = fld.to_s
    # should be user definable
    @@wrap_after = 10  # wrap after edit has whole screen usually
    @type = :app
    @app = :edit_application
    @@edit_app["fieldlist"] = []
    @@edit_app["fields"] = {}
    @@currhash = @@edit_app 
    @@currhash["classname"] = fld.to_s
    instance_eval(&block) if block_given?
  end
  def query_application(fld, attribs={}, &block)
    puts "QA: ", fld.to_s
    @@curfield = fld.to_s
    @type = :app
    @app = :query_application
    @@query_app["fieldlist"] = []
    @@query_app["fields"] = {}
    @@currhash = @@query_app 
    @@currhash["classname"] = fld.to_s
    instance_eval(&block) if block_given?
  end
  def table_application(fld, attribs={}, &block)
    puts "TA: ", fld.to_s
    @type = :app
    @@curfield = fld.to_s
    
    @app = :table_application
    @@table_app["fieldlist"] = []
    @@table_app["fields"] = {}
    @@currhash = @@table_app 
    @@currhash["classname"] = fld.to_s
    instance_eval(&block) if block_given?
  end
  def Datasource(fld, attribs={}, &block)
    puts "DS: ", fld.to_s
    @@curfield = fld.to_s
    @type = :app
    @app = :datasource
    #@@currhash = @@datasource
    @@currhash["datasource"] = {}
    @@currhash["datasource"]["classname"] = fld.to_s
    #@@currhash = @@currhash["datasource"]  # how will we step back out ?
    instance_eval(&block) if block_given?
  end
  def field(fld, attribs={}, &block)
    puts "FIELD: ", fld.to_s
    @type = :field
    @@fields << fld.to_s
    @@currhash["fieldlist"] << fld.to_s
    @@curfield = fld.to_s
    @@hashes["#{fld.to_s}"] = {}
    @@currhash["fields"]["#{fld.to_s}"] = {}
    @@currhash["fields"]["#{fld.to_s}"]["name"] = fld.to_s
    @@currhash["fields"]["#{fld.to_s}"]["index"] = @@index
    @@hashes["#{fld.to_s}"]["index"] = @@index
    @@index += 1
    instance_eval(&block) if block_given?
  end

  def method(arg)
    "Method(:#{arg})"
  end

  def menuitem(fld, attribs={}, &block)
    puts "item: ", fld.to_s
    @type = :menuitem
    @@curfield = fld.to_s
    @@menuarr[@@index] = {}
    instance_eval(&block) if block_given?
    @@index += 1
  end
  def flabel(fld, attribs={}, &block)
    puts "label: ", fld.to_s
    @type = :label
    @@curfield = fld.to_s
    @@labelarr[@@labelindex] = {}
    #@@hashes["#{fld.to_s}"] = {}
    ## 2008-09-21 16:47 this should save me a lot of derefencing later
    #@@hashes["#{fld.to_s}"]["index"] = @@index
    instance_eval(&block) if block_given?
    @@labelindex += 1
  end

  def method_missing(id, *args, &block)
    puts "method missing: #{id.to_s}, #{@type} "
    pp args
    if @@curfield == ''
      puts "101 Added to app #{id}"
      argx = args
      if args.length == 1
        argx = args[0]
      end
      @@app[id.to_s]=argx
      pp argx
    else
      arr = []
      ix = 0
      case @type 
      when :menuitem
        arr = @@menuarr
        ix = @@index
      when :label
        arr = @@labelarr
        ix = @@labelindex
      when :field
        if block
          @@hashes["#{@@curfield}"]["#{args[0]}"]=block
        else
          argx = args
          if args.length == 1
            argx = args[0]
          end
          @@hashes["#{@@curfield}"]["#{id.to_s}"]=argx
          @@currhash["fields"]["#{@@curfield}"]["#{id.to_s}"]=argx
        end
        return
      when :app
        argx = args
        if args.length == 1
          argx = args[0]
        end
        if @app == :datasource
          @@currhash["datasource"][id.to_s]=argx
        else
          @@currhash[id.to_s]=argx
        end
        pp argx
        return
      end 
      puts "113 Added to #{@type.to_s} #{@@curfield}"
      if block
        arr[ix]["#{args[0]}"]=block
      else
        argx = args
        if args.length == 1
          argx = args[0]
        end
        arr[ix]["#{id.to_s}"]=argx
      end
      pp argx
    end
  end
  def check_sanity?
    @@fields.each { |fld|
      next if fld == "Help"
      h=@@hashes[fld]
      ft = h["fieldtype"]
      #puts fld+" FT:"
      if ft == nil
        printf "%s: No fieldtype specified. All data will be allowed.\n", fld
        #h["fieldtype"] = 'ALNUM'
      end
      if !h.include?"label"
        printf "%s: no label specified. Using %s\nPut blank label if you wan't none.\n", fld, fld
        h["label"] = fld.to_s
      end
      case ft
      when 'INTEGER', 'NUMERIC'
        if h["range"] == nil
          printf "%s: no range specified for numeric. Using 0, 10000\n", fld
          h["range"] = [0,10000]
        end
      when 'REGEXP'
        if h["fieldtype"].size < 2
          printf "%s: Regexp field must have regexp as 2nd param in fieldtype\n", fld
          print "ERROR! CANNOT PROCEED!\n"
          return false
        end
      end
    }
    return true
  end
  def create_field_string(fhash)
   @@fields_hash = fhash
   template=File::read("_skelfld.rb");
   message = ERB.new(template, nil, '%<>')
   output=message.result(binding)
   output.gsub!(/^\s*$/,'')
   return output
  end

end
