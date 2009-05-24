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
          obj != Registry.root
        else
          obj != Registry.root &&
            types.any? do |type| 
              type.is_a?(Symbol) ? obj.type == type : obj.is_a?(type)
            end
        end
      end
    end
    
    def paths
      namespace.keys.map {|k| k.to_s }
    end
      
    def at(path, inherited = false)
      return root if path.to_sym == :root

      namespace = root
      scan = StringScanner.new(path.to_s)
      while scan.scan(/#{CodeObjects::CONSTANTMATCH}|(?:#{CodeObjects::METHODNAMEMATCH}|@@\w+)$/)
        name = scan.matched.to_sym
        unless new_namespace = namespace.child(:type => CodeObjects::NamespaceObject, :name => name)
          obj = namespace.child(:type => [CodeObjects::ConstantObject, CodeObjects::ClassVariableObject], :name => name)
          return obj if obj
          return unless scan.eos?
          return namespace.meths(:scope => :class, :included => inherited, :inherited => inherited).
            find {|m| m.name == name}
        end

        namespace = new_namespace
        scan.scan(/#{CodeObjects::NSEP}/)
      end
      return namespace if scan.eos?

      sep = scan.scan(/#{CodeObjects::NSEP}|#{CodeObjects::ISEP}/)
      return unless namespace.is_a?(CodeObjects::NamespaceObject) && scan.scan(CodeObjects::METHODNAMEMATCH) && scan.eos?

      name = scan.matched.to_sym
      opts = {:included => inherited, :inherited => inherited}
      opts[:scope] = sep == CodeObjects::NSEP ? :class : :instance if sep
      namespace.meths(opts).find {|m| m.name == name}
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

    def resolve(namespace, name, inherited = false, proxy_fallback = false)
      if namespace.is_a?(CodeObjects::Proxy)
        return proxy_fallback ? CodeObjects::Proxy.new(namespace, name) : nil
      end
      
      if namespace == :root || !namespace
        namespace = root
      else
        namespace = namespace.parent until namespace.is_a?(CodeObjects::NamespaceObject)
      end
      orignamespace = namespace

      newname = name.to_s.gsub(/^#{CodeObjects::ISEP}/, '')
      if name =~ /^#{CodeObjects::NSEP}/
        [name, newname[2..-1]].each do |n|
          if obj = at(n, inherited)
            return obj
          end
        end
      else
        while namespace
          [CodeObjects::NSEP, CodeObjects::ISEP].each do |s|
            path = newname
            if namespace != root
              path = [namespace.path, newname].join(s)
            end
            found = at(path, inherited)
            return found if found
          end
          namespace = namespace.parent
        end

        # Look for ::name or #name in the root space
        [CodeObjects::NSEP, CodeObjects::ISEP].each do |s|
          found = at(s + newname, inherited)
          return found if found
        end
      end
      proxy_fallback ? CodeObjects::Proxy.new(orignamespace, name) : nil
    end

    private
  
    attr_accessor :namespace

    def partial_resolve(namespace, name)
      [CodeObjects::NSEP, CodeObjects::CSEP, ''].each do |s|
        next if s.empty? && name =~ /^\w/
        path = name
        if namespace != root
          path = [namespace.path, name].join(s)
        end
        found = at(path)
        return found if found
      end
      nil
    end
  end
end
