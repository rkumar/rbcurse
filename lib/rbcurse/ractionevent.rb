=begin
  * Name: ActionEvent
  * Description: Event used to notify interested parties that an action has happened on component
                 Usually a button press. Nothing more.
  * Author: rkumar (arunachalesha)
  
  --------
  * Date: 2010-09-12 18:53 
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end

# Event created when state changed (as in ViewPort)
module RubyCurses
  # source - as always is the object whose event has been fired
  # id     - event identifier (seems redundant since we bind events often separately.
  # action_command - command string associated with event (such as title of button that changed
  ActionEvent = Struct.new(:source, :event, :action_command) do
    # This should always return the most relevant text associated with this object
    # so the user does not have to go through the source object's documentation.
    # It should be a user-friendly string 
    # @return text associated with source (label of button)
    def text
      source.text
    end

    # This is similar to text and can often be just an alias.
    # However, i am putting this for backward compatibility with programs
    # that received the object and called it's getvalue. It is better to use text.
    # @return text associated with source (label of button)
    def getvalue
      source.getvalue
    end
  end
end
