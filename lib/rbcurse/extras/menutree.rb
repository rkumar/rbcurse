module RubyCurses
  # Create a simple tree-ish structure.
  # Each node is not a tree, only submenus are trees
  # Others contain a hash with menu character and code
  # Typically the code is not a method symbol, it is to be 
  # used to decode a description or method symbol from anoterh hash
  # @usage
  #    menu = MenuTree.new "Main", { c: :goprev, d: :gonext, e: :gonext, s: :submenu }
  #    menu.submenu :s, "submenu", {a: :next1, b: :next2, f: :next3 }
  #    puts menu.hash
  #    puts "each ..."
  #    menu.each { |e|  puts e }
  #    menu.each_pair { |e, v|  puts "#{e} #{v}" }
  #    puts " -- :c -- "
  #    puts menu[:c]
  #    puts " -- :s -- "
  #    puts menu[:s].children
  class MenuTree
    attr_reader :value
    def initialize value, hash = {}
      @value = [value, hash]
    end
    def << kv
      @value[1][kv[0]] = kv[1]
    end
    def hash
      @value[1]
    end
    alias :children :hash
    def push hsh
      hash().merge hsh
    end
    def [](x)
      hash()[x]
    end
    def []=(x,y)
      hash()[x] = y
    end
    def submenu key, value, hash = {}
      m = MenuTree.new value, hash
      #hash()[key] = [value, hash]
      hash()[key] = m
    end
    def each
      hash().keys.each { |e| yield e }
    end
    def each_pair
      hash().each_pair { |name, val| yield name, val  }
    end
  end
end
if __FILE__ == $PROGRAM_NAME
  menu = RubyCurses::MenuTree.new "Main", { c: :goprev, d: :gonext, e: :gonext, s: :submenu }
  menu.submenu :s, "submenu", {a: :next1, b: :next2, f: :next3 }
  puts menu.hash
  puts "each ..."
  menu.each { |e|  puts e }
  menu.each_pair { |e, v|  puts "#{e} #{v}" }
  puts " -- :c -- "
  puts menu[:c]
  puts " -- :s -- "
  puts menu[:s].children
end
