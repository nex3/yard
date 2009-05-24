module YARD::CodeObjects
  class NamespaceObject < Base
    attr_reader :children, :cvars, :meths, :constants, :attributes, :aliases
    attr_reader :class_mixins, :instance_mixins
    
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
      if !opts.is_a?(Hash)
        children.find {|o| o.name == opts.to_sym }
      else
        opts = SymbolHash[opts]
        children.find do |obj| 
          opts.all? do |meth, value|
            value = [value] unless value.is_a?(Array)
            value.any? do |v|
              case meth
              when :name; obj.name == v.to_sym
              when :type
                return obj.type == v if v.is_a?(Symbol)
                obj.is_a?(v)
              else; obj[meth] == v
              end
            end
          end
        end
      end
    end
    
    def meths(opts = {})
      opts = SymbolHash[
        :visibility => [:public, :private, :protected],
        :scope => [:class, :instance],
        :included => true
      ].update(opts)
      
      opts[:visibility] = [opts[:visibility]].flatten
      opts[:scope] = [opts[:scope]].flatten

      ourmeths = children.select do |o| 
        o.is_a?(MethodObject) && 
          opts[:visibility].include?(o.visibility) &&
          opts[:scope].include?(o.scope)
      end
      
      ourmeths + (opts[:included] ? included_meths(opts) : [])
    end
    
    def included_meths(opts = {})
      opts = SymbolHash[:scope => [:instance, :class]].update(opts)
      [opts[:scope]].flatten.map do |scope|
        mixins(scope).reverse.inject([]) do |list, mixin|
          next list if mixin.is_a?(Proxy)
          arr = mixin.meths(opts.merge(:scope => :instance)).reject do |o|
            child(:name => o.name, :scope => scope) || list.find {|o2| o2.name == o.name }
          end
          arr.map! {|o| ExtendedMethodObject.new(o) } if scope == :class
          list + arr
        end
      end.flatten
    end
    
    def constants(opts = {})
      opts = SymbolHash[:included => true].update(opts)
      consts = children.select {|o| o.is_a? ConstantObject }
      consts + (opts[:included] ? included_constants : [])
    end
    
    def included_constants
      instance_mixins.reverse.inject([]) do |list, mixin|
        if mixin.respond_to? :constants
          list += mixin.constants.reject do |o| 
            child(:name => o.name) || list.find {|o2| o2.name == o.name }
          end
        else
          list
        end
      end
    end
    
    def cvars 
      children.select {|o| o.is_a? ClassVariableObject }
    end

    def mixins(*scopes)
      return class_mixins if scopes == [:class]
      return instance_mixins if scopes == [:instance]
      class_mixins | instance_mixins
    end
  end
end
