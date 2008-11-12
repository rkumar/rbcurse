## Insert order preserving hash
# Thanks to Bill Kelly, posted on http://www.ruby-forum.com/topic/166075
#
class OrderedHash
  include Enumerable

  def initialize(*args, &block)
    @h = Hash.new(*args, &block)
    @ordered_keys = []
  end

  def []=(key, val)
    @ordered_keys << key unless @h.has_key? key
    @h[key] = val
  end

  def each
    @ordered_keys.each {|k| yield(k, @h[k])}
  end
  alias :each_pair :each

  def each_value
    @ordered_keys.each {|k| yield(@h[k])}
  end

  def each_key
    @ordered_keys.each {|k| yield k}
  end

  def keys
    @ordered_keys
  end

  def values
    @ordered_keys.map {|k| @h[k]}
  end

  def clear
    @ordered_keys.clear
    @h.clear
  end

  def delete(k, &block)
    @ordered_keys.delete k
    @h.delete(k, &block)
  end

  def reject!
    del = []
    each_pair {|k,v| del << k if yield k,v}
    del.each {|k| delete k}
    del.empty? ? nil : self
  end

  def delete_if(&block)
    reject!(&block)
    self
  end
  ## added since the normal hash will give it in unordered. so debugging sucks
  def inspect
    out = []
    each do | k,v |
      out << " #{k} => #{v} "
    end
    res = %Q[  { #{out.join(",\n ")} } ]
  end

  %w(merge!).each do |name|
    define_method(name) do |*args|
      raise NotImplementedError, "#{name} not implemented"
    end
  end

  def method_missing(*args)
    @h.send(*args)
  end
end
