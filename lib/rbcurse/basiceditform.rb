=begin
  * Name: basiceditform
  * $Id$
  * Description   Edit form object extends rbeditform with some handlers
  * Author: rkumar
  * Date: 2008-11-02 10:55 
  * License: (http://www.ruby-lang.org/LICENSE.txt)
=end

require 'rbcurse/rbeditform'


class BasicEditForm < RBEditForm 

  def initialize(fields)
    super
  end

  def field_init_hook()
    helpproc()
    highlight_label true
    super
  end
  # all these atributes have to be handled properly and not in this fashion, XXX
  def field_term_hook()
    highlight_label  false
    super
  end # field_term

  def form_save 
    default_form_save_proc
    form_driver(REQ_FIRST_FIELD);
  end

  ##
  # If user does not specify any proc for saving we use this one.
  # It has some pre-baked (half-baked) features:
  #   - save_path
  #   - save_format
  #   - save_template
  #   - pipe_output_path
  #
  # currently the sql forms are mapping their own delete/update/insert keys

  def default_form_save_proc
    outdata = get_current_values_as_hash
    #if defined? @main.form_post_proc   # XXX ban this, its ugly coupling, let them set it
    #  outdata = @main.send(:form_post_proc, outdata, @fields)
    #end
    ret = fire_handler(:form_post_proc, outdata,  self)
    outdata = ret if ret # cludgy, but outdata is not in the form
    filename = user_object["save_path"] || 'out.txt'
    @main.print_status("Saving data to #{filename}");
    ### XXX FIXME put this into methods and call them with default being
    # save_as_text
    # create a format at generation time and use that, if none given
    # if save_proc specified, use that.
    if user_object["save_format"]=='yml'
      File.open(filename || "out.yml", "w") { | f | YAML.dump( outdata, f )} 
    else
      File.open("dump.yml", "w") { | f | YAML.dump( outdata, f )}  # debugging REMOVE

      str=''
      templateStr = user_object["save_template"]
      if templateStr!=nil
        str = template(templateStr, outdata)
      else
        str = default_format_text(outdata)
      end
      save_as_text(filename, str)
      pipeto = user_object["pipe_output_path"]
      pipe_output(str) if pipeto != nil
    end
    @main.print_status("Saved data to #{filename}  ");
    set_current_field(@fields[0]);  
    form_driver(REQ_FIRST_FIELD);
  end # save

  def form_populate
    set_defaults(@values_hash)
  end #  form_populate

  # default save as text format, if user has not specified a format

  def default_format_text(outdata)
    str = ''
    @fields.each{ |f| 
      fn = f.user_object["name"]
      value = outdata[fn]
      str << "#{fn}: #{value}\n"
    }
    str << "\n"
  end
  def save_as_text(filename, str)
    $log.info(str)
    File.open(filename, "a") {|f| f.puts(str) }
  end
  def pipe_output (str)
    pipeto = user_object["pipe_output_path"]
    if pipeto != nil
      proc = IO.popen(pipeto, "w+")
      proc.puts str
      proc.close_write
      #@main.log.info(proc.gets)
    end
  end
  # default save as yaml, can be overridden by user
  def save_as_yaml (filename, outdata)
    File.open(filename || "out.yml", "w") { | f | YAML.dump( outdata, f )} 
  end
  ## prints help text for fields, or actions/events.
  def highlight_label tf
    x = current_field
    uo = x.user_object
    r,c = uo["label_rowcol"]
    #len = uo["label"].length
    len = x["label"].length   # possible since we've now overloaded [] to give us user_object
    color=Ncurses.COLOR_PAIR(4); # selection
    if !tf
      color=Ncurses.COLOR_PAIR(5); # selection
    end
    win = form_win # 2008-10-15 14:58 
    win.attron(color);
    win.mvprintw(r, c, "%s" % uo["label"]);
    win.attroff(color);
    win.refresh
  end

  ### ADD HERE ###
end # class
