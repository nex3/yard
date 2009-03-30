module YARD::CodeObjects
  class ClassObject < NamespaceObject
    attr_accessor :superclass
    
    def initialize(namespace, name, *args, &block)
      super

      if is_exception?
        self.superclass ||= :Exception unless P(namespace, name) == P(:Exception)
      else
        self.superclass ||= :Object unless P(namespace, name) == P(:Object)
      end
    end
    
    def is_exception?
      inheritance_tree.reverse.any? {|o| BUILTIN_EXCEPTIONS_HASH.has_key? o.path }
    end
    
    def inheritance_tree(include_mods = false)
      list = [self] + (include_mods ? mixins(:instance) : [])
      if superclass.is_a? Proxy
        list << superclass unless superclass == P(:Object)
      elsif superclass.respond_to? :inheritance_tree
        list += superclass.inheritance_tree
      end
      list
    end
    
    def meths(opts = {})
      opts = SymbolHash[:inherited => true].update(opts)
      super(opts) + (opts[:inherited] ? inherited_meths(opts) : [])
    end
    
    def inherited_meths(opts = {})
      inheritance_tree[1..-1].inject([]) do |list, superclass|
        if superclass.is_a?(Proxy)
          list
        else
          list += superclass.meths(opts).reject do |o|
            child(:name => o.name, :scope => o.scope) ||
              list.find {|o2| o2.name == o.name && o2.scope == o.scope }
          end
        end
      end
    end
    
    def constants(opts = {})
      opts = SymbolHash[:inherited => true].update(opts)
      super(opts) + (opts[:inherited] ? inherited_constants : [])
    end
    
    def inherited_constants
      inheritance_tree[1..-1].inject([]) do |list, superclass|
        if superclass.is_a?(Proxy)
          list
        else
          list += superclass.constants.reject do |o|
            child(:name => o.name) || list.find {|o2| o2.name == o.name }
          end
        end
      end
    end
    
    ##
    # Sets the superclass of the object
    # 
    # @param [Base, Proxy, String, Symbol, nil] object the superclass value
    def superclass=(object)
      case object
      when Base, Proxy, NilClass
        @superclass = object
      when String, Symbol
        @superclass = Proxy.new(namespace, object)
      else
        raise ArgumentError, "superclass must be CodeObject, Proxy, String or Symbol" 
      end

      if name == @superclass.name && namespace != YARD::Registry.root
        @superclass = Proxy.new(namespace.namespace, object)
      end
      
      if @superclass == self
        msg = "superclass #{@superclass.inspect} cannot be the same as the declared class #{self.inspect}"
        @superclass = P(:Object)
        raise ArgumentError, msg
      end
    end
  end
end
