require 'rubygems'
require 'ncurses'
require 'erb'
require 'yaml'
require 'pp'

module Form
  extend self

  @@debug = true
  @@fields = []
  @@hashes = {}
  @@curfield = ''
  @@form = {}
  @@form_text = []
  @@outfile = nil
  @@initcode = []
  @@yamlname = ''
  @@index = 0

  def create(name, &block)
    puts name.to_s if @@debug
    #@@fields << "Help" # help no longer polluting fields array
    #@@hashes["Help"] = {}
    @@currhash["fieldlist"] = []
    @@currhash["fields"] = {}
    params= %w[label field_back fieldtype min_data_width values checkcase checkunique help_text default valid]
    #params.each { |param| @@hashes["#{param}"] = {} }
    instance_eval(&block) if block_given?
    if !check_sanity?
      print "CRASHING OUT. PLS CORRECT INPUT FILE!\n"
      exit(-1)
    end
    if @@debug
    print "printing @@fields"
    pp @@fields
    print "printing @@form"
    pp @@form
    print "printing @@hashes"
    pp @@hashes
    end

    @@initcode << "@rt_fields=" + @@fields.inspect
    myfuncs = @@form.delete('myfuncs')
    @@initcode << "@rt_form=" + @@form.inspect

    #File.open( 'fields.yml', 'w' ) do |f|
    #  f << @@fields.to_yaml
    #end
    if @@outfile != nil
      @@yamlname = @@outfile.sub(/\.rb$/, '.yml') 
      @@classname= @@outfile.sub(/\.rb$/,'')
      @@classname.capitalize!

      File.open( @@yamlname, 'w' ) do |f|
        f << @@hashes.to_yaml
      end
    end
    #File.open( 'form.yml', 'w' ) do |f|
    #  f << @@form.to_yaml
    #end
    
    template=File::read("form.skel");
    message = ERB.new(template, nil, '%<>')
    output=message.result(binding)
    output.gsub!(/(\#\#\#PROCS_COME_HERE\#\#\#)$/,'\1'+"\n"+myfuncs[0])
    
    if @@outfile == nil
      puts output
    else
      File.open( @@outfile, 'w' ) do |f|
        f << output
      end
      puts "see #{@@outfile}"
    end


  end
  # this should no longer be allowed
  def init_pair (i, c1, c2)
    if i<4
      print "WARN: Please define init_pairs higher than 3 to avoid duplication. This may be ignored.\n"
    end
    @@form_text << %{Ncurses.init_pair(#{i}, #{c1}, #{c2})}
  end
  # this should no longer be allowed
  def bkgd(col)
    #@@form_text << %{stdscr.bkgd(Ncurses.COLOR_PAIR(#{col})) }
  end


  def field(fld, attribs={}, &block)
    puts "FIELD: ", fld.to_s
    @@fields << fld.to_s
    @@curfield = fld.to_s
    @@hashes["#{fld.to_s}"] = {}
    ## 2008-09-21 16:47 this should save me a lot of derefencing later
    @@hashes["#{fld.to_s}"]["index"] = @@index
    @@currhash["fieldlist"] << fld.to_s
    @@currhash["fields"]["#{fld.to_s}"] = {}
    @@currhash["fields"]["#{fld.to_s}"]["name"] = fld.to_s
    @@index += 1
    instance_eval(&block) if block_given?
  end

  # All are just getters/setters
  # of class variables.
  %w[outfile].each do |method|
    define_method(method) do |string|
      variable = "@@#{method}"
      return class_variable_get(variable) if string.nil?
      val = class_variable_get(variable) || ''
      class_variable_set(variable, val << string)
    end
  end
  def method_missing(id, *args, &block)
    #puts "method missing: #{id.to_s} "
    if @@curfield == ''
      #puts "Added to form #{id}"
        argx = args
        if args.length == 1
          argx = args[0]
        end
      @@form[id.to_s]=argx
      #pp args
    else
      #puts "Added to hashes #{@@curfield}"
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
      #pp args
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

end
