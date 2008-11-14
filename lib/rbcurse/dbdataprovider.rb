=begin
  * Name: dbdataprovider
  * $Id$
  * Description   provides data from db in datasource format
  * Author: rkumar
  * Date:  2008-11-14 12:30 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
module DBDataProvider
  def get_data(command)
    @columns, *@datarows = $db.execute2(command)
    @datatypes = @datarows[0].types
    @content = @datarows
    # used for padding the row number printed on the left side
    @numpadding = @content.length.to_s.length  # how many digits the max row is: 10 is 2, 100 is 3 etc
    $log.debug("sql: #{command}")
    $log.debug("content len: #{@content.length}")
  end
end
