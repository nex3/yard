require "set"

module YARD::CodeObjects
  class NamespaceObject < Base
    attr_reader :attributes, :aliases
    
    def initialize(namespace, name, *args, &block)
      @children = CodeObjectList.new(self)
      @class_mixins = CodeObjectList.new(self)
      @instance_mixins = CodeObjectList.new(self)
      @attributes = SymbolHash[:class => SymbolHash.new, :instance => SymbolHash.new]
      @aliases = {}
      super
    end
    
    def class_attributes
      attributes[:class]
    end
    
    def instance_attributes 
      attributes[:instance]
    end
    
    def child(opts = {})
      opts = SymbolHash[:inherited => false, :name => opts] if !opts.is_a?(Hash)
      children(opts.delete(:inherited)).find {|o| check_opts(o, opts) }
    end
    
    def meths(opts = {})
      opts = meth_opts(opts)
      children(opts.delete(:inherited)).select {|o| check_opts(o, opts) }
    end

    def included_meths(opts = {})
      opts = meth_opts(opts)
      opts.delete(:inherited)
      included_children.select {|o| check_opts(o, opts) }
    end

    def constants(inherited = true)
      children(inherited).select {|o| o.is_a? ConstantObject }
    end

    def included_constants
      included_children.select {|o| o.is_a? ConstantObject }
    end

    def cvars 
      children.select {|o| o.is_a? ClassVariableObject }
    end

    def children(inherited = false)
      return @children unless inherited
      flatten_mtype_hash children_hash
    end

    def included_children
      flatten_mtype_hash reject_children_hash(included_children_hash, local_children_hash)
    end

    def mixins(*scopes)
      raise ArgumentError, "Scopes must be :instance, :class, or both" if scopes.empty?
      return @class_mixins if scopes == [:class]
      return @instance_mixins if scopes == [:instance]

      unless (scopes - [:instance, :class]).empty?
        raise ArgumentError, "Scopes must be :instance, :class, or both"
      end

      return @class_mixins | @instance_mixins
    end

    def member_type; :const; end

    protected

    def children_hash(no_class_mixins = false)
      merge_children_hash(included_children_hash(no_class_mixins), local_children_hash)
    end

    def local_children_hash
      @children.inject(mtype_hash) do |h, c|
        h[c.member_type][c.name] = c
        h
      end
    end

    def included_children_hash(no_class_mixins = false)
      hash = mixins(:instance).inject(mtype_hash) do |h, mixin|
        next h unless mixin.is_a?(NamespaceObject)
        merge_children_hash(h, mixin.children_hash.reject {|k, v| k == :cmeth})
      end
      return hash if no_class_mixins
      mixins(:class).each do |mixin|
        next unless mixin.is_a?(NamespaceObject)
        hash[:cmeth].merge!(mixin.children_hash(true)[:imeth].inject({}) do |h, (k, v)|
            h[k] = ExtendedMethodObject.new(v)
            h
          end)
      end
      hash
    end

    def merge_children_hash(old, new)
      new.merge(old.inject(mtype_hash) do |h, (key, value)|
          h[key] = value.merge(new[key])
          h
        end)
    end

    def reject_children_hash(old, new)
      old.inject(mtype_hash) do |h, (key, value)|
        h[key] = value.reject {|k, v| new[key].include?(k) }
        h
      end
    end

    def mtype_hash; Hash.new {|h, k| h[k] = {}}; end

    def flatten_mtype_hash(h)
      h.values.map {|v| v.values}.flatten
    end

    def meth_opts(opts)
      SymbolHash[
        :type => :method,
        :visibility => [:public, :private, :protected],
        :scope => [:class, :instance],
        :inherited => true
      ].update(opts)
    end

    def check_opts(obj, opts)
      opts.all? do |name, value|
        value = [value] unless value.is_a?(Array)
        value.any? do |v|
          case name
          when :name; obj.name == v.to_sym
          when :type
            next obj.type == v if v.is_a?(Symbol)
            obj.is_a?(v)
          else; obj[name] == v
          end
        end
      end
    end
  end
end
