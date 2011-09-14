require 'rbcurse/app'

####
#  If you want to create an application which can run standaalong from terminal, or be passed
#  values from a previous form then this is one way you can do it.
#
# this was a test to see how i could have a class and an app inside
# and i could call methods in the class and have variables available
# inside App.
#
# instance_eval inside stack and others was causing the issue putting everything in
# App. However, i have to change the app, to use yield in order not to lose context

class Testy
  attr_accessor :value
  def initialize val
    @value = val
    @my = "oldval"
    run
  end
  # i will call this method from within the App block
  def amethod
    $log.debug "XXXX amethod called... " if $log.debug? 
    #alert " self #{self.class} amethod "
    # we will access @my from insdie the block, we also access @f from here
    @my = "hellothere #{@f.getvalue} "
  end
  def run

    App.new do |app|
      $log.debug " APP : value #{value}" if $log.debug? 
      header = app.app_header "rbcurse 1.2.0", :text_center => " #{@value} Demo", :text_right =>"New Improved!", :color => :black, :bgcolor => :white, :attr => :bold 
      app.message "Press F1 to exit from here #{@value} "

      app.stack :margin_top => 2, :margin => 5, :width => 30 do |s|
        app.label "Hello: ", :attr => :reverse
        @f=app.field "abc"
        #amethod() 
        @f.bind(:CHANGE) { 
          amethod() 
          app.message "now #{@my} "
        }

      end # stack
      #app.safe_loop
    end
  end
end
if __FILE__ == $PROGRAM_NAME
  Testy.new "SomeData"
end
