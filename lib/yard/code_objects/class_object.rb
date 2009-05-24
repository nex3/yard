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
      list = (include_mods ? mixins(:instance) : [])
      if superclass.is_a?(Proxy) || superclass.respond_to?(:inheritance_tree)
        list << superclass unless superclass == P(:Object)
      end
      [self] + list.map do |m|
        next m unless m.respond_to?(:inheritance_tree)
        m.inheritance_tree(include_mods)
      end.flatten
    end

    def inherited_children
      flatten_mtype_hash reject_children_hash(inherited_children_hash, local_children_hash)
    end

    def inherited_meths(opts = {})
      opts = meth_opts(opts)
      opts.delete(:inherited)
      inherited_children.select {|o| check_opts(o, opts) }
    end

    def inherited_constants
      inherited_children.select {|o| o.is_a? ConstantObject }
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

    protected

    def children_hash(no_class_mixins = false)
      merge_children_hash(inherited_children_hash, super)
    end

    def inherited_children_hash
      inheritance_tree[1..-1].reverse.inject(mtype_hash) do |h, superclass|
        next h unless superclass.is_a?(NamespaceObject)
        merge_children_hash(h, superclass.children_hash)
      end
    end
  end
end
