# ----------------------------------------------------------------------------- #
#         File: colorparser.rb
#  Description: Default parse for our tmux format
#               The aim is to be able to specify parsers so different kinds
#               of formatting or documents can be used, such as ANSI formatted
#               manpages.
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 07.11.11 - 13:17
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: use ,,L
# ----------------------------------------------------------------------------- #
# == TODO
#    - perhaps we can compile the regexp once and reuse
# 

class AnsiParser

  # NOTE: Experimental and minimal
  # parses the formatted string and yields either an array of color, bgcolor and attrib
  # or the text. This will be called by convert_to_chunk.
  #
  # Currently, assumes colors and attributes are correct. No error checking or fancy stuff.
  #  s="#[fg=green]hello there#[fg=yellow, bg=black, dim]"
  # @since 1.4.1  2011-11-3 experimental, can change
  # @return [nil] knows nothign about output format. 

  def parse_format s  # yields attribs or text
    ## set default colors
    color   = :white
    bgcolor = :black
    attrib  = FFI::NCurses::A_NORMAL
    text    = ""

    ## split #[...]
    #a       = s.split /(#\[[^\]]*\])/
    a       = s.split /(\x1b\[\d*(?:;\d+)*?[a-zA-Z])/
    a.each { |e| 
      ## process color or attrib portion
      #[ "", "\e[1m", "", "\e[34m", "", "\e[47m", "Showing all items...", "\e[0m", "", "\e[0m", "\n"]
      if e[0] == "\x1b" && e[-1] == "m"

        #e.each { |f|  x=/^.\[(.*).$/.match(f) 
          $log.debug "XXX: ANSI e #{e} "
          x=/^.\[(.*).$/.match(e) 
          color, bgcolor, attrib = nil, nil, nil
          $log.debug "XXX: ANSI #{x} ..... #{x[1]}  "
          args = x[1].split ';'
          ## first split on commas to separate fg, bg and attr
          # http://ascii-table.com/ansi-escape-sequences.php
          args.each { |att|  
            $log.debug "XXX: ANSI att: #{att}   "
            case att.to_i
            when 0
              color, bgcolor, attrib = nil, nil, nil
              yield :reset # actually this resets all so we need an endall or clearall reset

            when 1
              attrib = 'bold'
            when 2
              attrib = 'dim'
            when 4
              attrib = 'underline'
            when 5
              attrib = 'blink'
            when 7
              attrib = 'reverse'
            when 8
              attrib = 'hidden' # XXX
            when 30 
              color = 'black'
            when 31  
              color = 'red'
            when 32  
              color = 'green'
            when 33  
              color = 'yellow'
            when 34  
              color = 'blue'
            when 35  
              color = 'magenta'
            when 36  
              color = 'cyan'
            when 37  
              color = 'white'

              #Background colors
            when 40  
              bgcolor = 'black'
            when 41  
              bgcolor = 'red'
            when 42  
              bgcolor = 'green'
            when 43  
              bgcolor = 'yellow'
            when 44  
              bgcolor = 'blue'
            when 45  
              bgcolor = 'magenta'
            when 46  
              bgcolor = 'cyan'
            when 47  
              bgcolor = 'white'
            else
              $log.warn "XXX: WARN ANSI not used #{att} "
            end
          } # args.ea
        #} # e.each
          $log.debug "XXX:  ANSI YIELDING #{color} , #{bgcolor} , #{attrib} "
        yield [color,bgcolor,attrib] if block_given?
      else
        text = e
        yield text if block_given?
      end
    } # a.each
  end

end
