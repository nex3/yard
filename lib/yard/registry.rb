require 'singleton'
require 'find'
require 'strscan'

module YARD
  class Registry 
    DEFAULT_YARDOC_FILE = ".yardoc"
    
    include Singleton
  
    @objects = {}

    class << self
      attr_reader :objects

      def method_missing(meth, *args, &block)
        if instance.respond_to? meth
          instance.send(meth, *args, &block)
        else
          super
        end
      end
      
      def clear
        instance.clear 
        objects.clear
      end
    end

    attr_accessor :yardoc_file
    attr_reader :proxy_types
    
    def load(files = [], reload = false)
      if files.is_a?(Array)
        if File.exists?(yardoc_file) && !reload
          load_yardoc
        else
          size = namespace.size
          YARD.parse(files)
          save if namespace.size > size
        end
        true
      elsif files.is_a?(String)
        load_yardoc(files)
        true
      else
        raise ArgumentError, "Must take a list of files to parse or the .yardoc file to load."
      end
    end
    
    def load_yardoc(file = yardoc_file)
      return false unless File.exists?(file)
      ns, pt = *Marshal.load(IO.read(file))
      namespace.update(ns)
      proxy_types.update(pt)
    end
    
    def save(file = yardoc_file)
      File.open(file, "w") {|f| Marshal.dump([@namespace, @proxy_types], f) }
      true
    end

    def all(*types)
      namespace.values.select do |obj| 
        if types.empty?
          obj != root
        else
          obj != root &&
            types.any? do |type| 
              type.is_a?(Symbol) ? obj.type == type : obj.is_a?(type)
            end
        end
      end + (types.include?(:root) ? [root] : [])
    end
    
    def paths
      namespace.keys.map {|k| k.to_s }
    end
      
    def at(path, inherited = false)
      resolve(:root, path, inherited)
    end
    alias_method :[], :at
    
    def root; namespace[:root] end
    
    def delete(object) 
      namespace.delete(object.path)
      self.class.objects.delete(object.path)
    end

    def clear
      @namespace = SymbolHash.new
      @namespace[:root] = CodeObjects::RootObject.new(nil, :root)
      @proxy_types = {}
    end

    def initialize
      @yardoc_file = DEFAULT_YARDOC_FILE
      clear
    end
  
    def register(object)
      self.class.objects[object.path] = object
      return if object.is_a?(CodeObjects::Proxy)
      namespace[object.path] = object
    end

    def resolve(namespace, path, inherited = false)
      return root if path.to_sym == :root
      namespace = root if !namespace || namespace == :root

      scan = StringScanner.new(path.to_s)
      return namespace if scan.eos?
      namespace = root if scan.scan(/#{CodeObjects::NSEPQ}/)
      return @namespace[path.to_s] if namespace == root && @namespace[path.to_s]

      while namespace
        return if namespace.is_a?(CodeObjects::Proxy)
        obj = resolve_under(namespace, scan.dup, inherited)
        return obj if obj
        namespace = namespace.namespace
      end

      nil
    end

    private
  
    attr_accessor :namespace

    def resolve_under(namespace, scan, inherited)
      cmeth = false
      while scan.scan(/#{CodeObjects::CONSTANTMATCH}|(?:#{CodeObjects::METHODNAMEMATCH}|@@\w+)$/)
        name = scan.matched.to_sym
        unless new_namespace = namespace.child(:inherited => inherited, :name => name,
            :type => CodeObjects::NamespaceObject)
          obj = namespace.child(:type => [CodeObjects::ConstantObject, CodeObjects::ClassVariableObject], :name => name)
          return obj if obj
          return unless scan.eos?
          return namespace.meths(:scope => cmeth ? :class : [:class, :instance], :inherited => inherited).
            find {|m| m.name == name}
        end

        namespace = new_namespace
        cmeth = scan.scan(/#{CodeObjects::NSEPQ}/)
      end
      return namespace if scan.eos?

      sep = scan.scan(/#{CodeObjects::NSEPQ}|#{CodeObjects::ISEPQ}|#{CodeObjects::CSEPQ}/)
      return unless namespace.is_a?(CodeObjects::NamespaceObject) && scan.scan(CodeObjects::METHODNAMEMATCH) && scan.eos?

      name = scan.matched.to_sym
      opts = {:inherited => inherited}
      opts[:scope] = sep == CodeObjects::ISEP ? :instance : :class if sep
      namespace.meths(opts).find {|m| m.name == name}
    end
  end
end
