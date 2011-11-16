# ----------------------------------------------------------------------------- #
#         File: file.rb
#  Description: some common file related methods which can be used across
#              file manager demos, since we seems to have a lot of them :)
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 2011-11-15 - 19:54
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: use ,,L
# ----------------------------------------------------------------------------- #
#

require 'rbcurse/common/appmethods'
module RubyCurses
  def file_edit fp #=@current_list.filepath
    #$log.debug " edit #{fp}"
    editor = ENV['EDITOR'] || 'vi'
    vimp = %x[which #{editor}].chomp
    shell_out "#{vimp} #{fp}"
  end

  # TODO we need to move these to some common file so differnt programs and demos
  # can use them on pressing space or enter.
  def file_page fp #=@current_list.filepath
    ft=%x[file #{fp}]
    if ft.index("text")
      pager = ENV['PAGER'] || 'less'
      vimp = %x[which #{pager}].chomp
      shell_out "#{vimp} #{fp}"
    elsif ft.index(/zip/i)
      shell_out "tar tvf #{fp} | less"
    elsif ft.index(/directory/i)
      shell_out "ls -lh  #{fp} | less"
    else
      alert "#{fp} is not text, not paging "
      #use_on_file "als", fp # only zip or archive
    end
  end

end # module
include RubyCurses
