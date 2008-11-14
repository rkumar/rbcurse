=begin
  * Name: processdataprovider
  * $Id$
  * Description   provides data from a process in datasource format
  * Author: rkumar
  * Date:  2008-11-14 12:30 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
module ProcessDataProvider
  def get_data(command)
    res = %x{#{command}}
    res = res.split("\n")
    #$log.debug "#{command} RES: #{res}"
    @content = []
    res.each { |row|
      if block_given?
        yield row, @content
      else
        @content << row.split
      end
    }
   # $log.debug "RES: #{@content}"
  end
end
