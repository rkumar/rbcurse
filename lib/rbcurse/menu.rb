# == Synopsis 
#   This program parses the meu DSL and generates the actual ncurses
#   menu program source code.
#
#   **difference between this and menu.rb**
#   This differs from menu.rb in that menu.rb currently has the annoying
#   feature of giving all params as arrays. So one has to always
#   remember to take [0] or else strange errors happen. Since most
#   situations do not ask for an array, it is simlper this way:
#   * if only one arg, then give it as scalar
#   * if more give it as array. This does pose one issue, why i have not
#   made the change in menu.rb: if a keyword has optional params then
#   one would not know if to expect array or scalar!
#   This is a simple program, so i don't expect anything to go wrong.
# == Examples
#
# == Usage 
#   ruby_cl_skeleton [options] source_file
#
#
# == Options
#
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

module Menu
  extend self

  @@debug = true
  @@form={}        # form has to be passed
  @@menuarr = []   # array of menuitem hashes to be passed to actual code
  @@labelarr = [] # array of label hashes to be passed to actual code
  @@curfield = '' # to distinguish where we are in menuitem or outside
  @@index = 0
  @@labelindex = 0
  @type = :form     # tells me which array to fill: form, menuitem or label
  @@initcode = []   # text of user-def procs to be added to source
  @@outfile = ""

  def create(name, &block)
    puts name.to_s if @@debug
    @@classname = name.to_s
   
    #params= %w[label field_back fieldtype min_data_width values checkcase checkunique help_text default valid]
    #params.each { |param| @@hashes["#{param}"] = {} }
    instance_eval(&block) if block_given?
    if !check_sanity?
      print "CRASHING OUT. PLS CORRECT INPUT FILE!\n"
      exit(-1)
    end
    if @@debug
      print "printing @@menuarr"
      pp @@menuarr
    end

    @@initcode << "@menuarr = " + @@menuarr.inspect
    myfuncs = @@form.delete('myfuncs')
    @@initcode << "@labelarr = " + @@labelarr.inspect
    @@initcode << "@form_headers = " + @@form.inspect

    
    template=File::read("menu.skel");
    message = ERB.new(template, nil, '%<>')
    output=message.result(binding)
    output.gsub!(/^(\#\#\#PROCS_COME_HERE\#\#\#)$/,'\1'+"\n"+myfuncs)
    
    if @@outfile == nil
      puts output
    else
      @@outfile = @@classname.downcase() + ".rb"
      File.open( @@outfile, 'w' ) do |f|
        f << output
      end
      puts "see #{@@outfile}"
    end


  end

  def menuitem(fld, attribs={}, &block)
    puts "item: ", fld.to_s
    @type = :menuitem
    #@@fields << fld.to_s
    @@curfield = fld.to_s
    @@menuarr[@@index] = {}
    #@@hashes["#{fld.to_s}"] = {}
    ## 2008-09-21 16:47 this should save me a lot of derefencing later
    #@@hashes["#{fld.to_s}"]["index"] = @@index
    instance_eval(&block) if block_given?
    @@index += 1
  end
  def label(fld, attribs={}, &block)
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
    puts "method missing: #{id.to_s} "
      pp args
    if @@curfield == ''
      puts "101 Added to form #{id}"
        argx = args
        if args.length == 1
          argx = args[0]
        end
      @@form[id.to_s]=argx
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
    return true
  end

end
