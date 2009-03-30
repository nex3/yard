module YARD::CodeObjects
  class NamespaceObject < Base
    attr_reader :children, :cvars, :meths, :constants, :mixins, :attributes, :aliases
    
    def initialize(namespace, name, *args, &block)
      @children = CodeObjectList.new(self)
      @mixins = CodeObjectList.new(self)
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
          opts.each do |meth, value|
            break false if obj[meth] != value
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
      # At the moment, we don't record class-scoped includes as anything special,
      # so we assume no included methods are class-scoped.
      return [] if opts[:scope] == [:class]
      mixins.reverse.inject([]) do |list, mixin|
        if mixin.is_a?(Proxy)
          list
        else
          list += mixin.meths(opts.merge(:scope => :instance)).reject do |o| 
            child(:name => o.name, :scope => o.scope) || 
              list.find {|o2| o2.name == o.name && o2.scope == o.scope }
          end
        end
      end
    end
    
    def constants(opts = {})
      opts = SymbolHash[:included => true].update(opts)
      consts = children.select {|o| o.is_a? ConstantObject }
      consts + (opts[:included] ? included_constants : [])
    end
    
    def included_constants
      mixins.reverse.inject([]) do |list, mixin|
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
  end
end
