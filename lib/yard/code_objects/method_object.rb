module YARD::CodeObjects
  class MethodObject < Base
    attr_accessor :visibility, :scope, :explicit, :parameters, :overloads
    
    def initialize(namespace, name, scope = :instance) 
      self.visibility = :public
      self.scope = scope
      self.overloads = []
      self.parameters = []

      super
    end

    def overloads
      return @overloads unless @overloads.empty?
      [self]
    end
    
    def scope=(v) @scope = v.to_sym end
    def visibility=(v) @visibility = v.to_sym end
      
    def is_attribute?
      namespace.attributes[scope].has_key? name.to_s.gsub(/=$/, '')
    end
      
    def is_alias?
      namespace.aliases.has_key? self
    end
    
    def is_explicit?
      explicit ? true : false
    end
    
    def aliases
      list = []
      namespace.aliases.each do |o, aname| 
        list << o if aname == name && o.scope == scope 
      end
      list
    end
    
    def path
      if !namespace || namespace.path == "" 
        sep + super
      else
        super
      end
    end
    
    def name(prefix = false)
      ((prefix ? sep : "") + super().to_s).to_sym
    end

    def member_type; scope == :class ? :cmeth : :imeth; end

    def sep; scope == :class ? CSEP : ISEP end
  end
end
