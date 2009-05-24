require 'erb'

module YARD
  module Generators
    class Base
      include Helpers::BaseHelper
      include Helpers::FilterHelper

      class << self
        def template_paths
          @@template_paths ||= [TEMPLATE_ROOT]
        end

        ##
        # Convenience method to registering a template path.
        # Equivalent to calling:
        #   GeneratorName.template_paths.unshift(path)
        # 
        # @param [String] path 
        #   the pathname to look for the template
        # 
        # @see template_paths
        def register_template_path(path)
          template_paths.unshift(path)
        end

        # Calls the +Proc+ object or method name before generating all or a specific
        # section. The callback should return +false+ if the section is to be
        # skipped.
        # 
        # @overload before_section(method_name)
        #   @param [Symbol] method_name the name of the method to call before
        #     running the generator.
        # 
        # @overload before_section(proc)
        #   @param [Proc] proc should return +false+ if section should be skipped.
        # 
        # @overload before_section(section, condition)
        #   Only calls the +Proc+ or method if it matches the passed +section+
        #   
        #   @param [Object] section one of the section items in {#sections_for}
        #   @param [Symbol, Proc] condition see the first two overloads
        def before_section(*args)
          if args.size == 1
            before_section_filters.push [nil, args.first]
          elsif args.size == 2
            before_section_filters.push(args)
          else
            raise ArgumentError, "before_section takes a generator followed by a Proc/lambda or Symbol referencing the method name"
          end
        end
        
        def before_section_filters
          @before_section_filters ||= []
        end
        
        def before_generate(meth)
          before_generate_filters.push(meth)
        end
        
        def before_generate_filters
          @before_generate_filters ||= []
        end
        
        def before_list(meth)
          before_list_filters.push(meth)
        end
        
        def before_list_filters
          @before_list_filters ||= []
        end
      end
      
      # Creates a generator by adding extra options
      # to the options hash. 
      # 
      # @example [Creates a new MethodSummaryGenerator for public class methods]
      #   G(MethodSummaryGenerator, :scope => :class, :visibility => :public)
      # 
      # @param [Class] generator 
      #   the generator class to use.
      # 
      # @option opts :ignore_serializer [Boolean] (true) whether or not the serializer is ignored.
      # 
      def G(generator, opts = {})
        opts = SymbolHash[:ignore_serializer => true].update(opts)
        generator.new(options, opts)
      end

      attr_reader :format, :template, :verifier
      attr_reader :serializer, :ignore_serializer
      attr_reader :options
      attr_reader :current_object
      
      def initialize(opts = {}, extra_opts = {})
        opts = SymbolHash[
          :format => :html,
          :template => :default,
          :markup => :rdoc,
          :serializer => nil,
          :verifier => nil
        ].update(opts).update(extra_opts)
        
        @options = opts
        @format = options[:format]
        @template = options[:template] 
        @serializer = options[:serializer] 
        @ignore_serializer = options[:ignore_serializer]
        @verifier = options[:verifier]
        
        extend Helpers::HtmlHelper if format == :html
      end
      
      def generator_name
        self.class.to_s.split("::").last.gsub(/Generator$/, '').downcase
      end
      
      def generate(*list, &block)
        output = ""

        list = list.flatten
        @current_object = Registry.root
        return output if FalseClass === run_before_list(list)

        serializer.before_serialize if serializer && !ignore_serializer
        
        list.each do |object|
          next unless object && object.is_a?(CodeObjects::Base)
          
          objout = ""
          @current_object = object

          next if call_verifier(object).is_a?(FalseClass)
          next if run_before_generate(object).is_a?(FalseClass)
          
          objout << render_sections(object, &block) 

          if serializer && !ignore_serializer && !objout.empty?
            serializer.serialize(object, objout) 
          end
          output << objout
        end
        
        if serializer && !ignore_serializer
          serializer.after_serialize(output) 
        end
        output
      end
      
      protected
      
      def call_verifier(object)
        if verifier.is_a?(Symbol)
          send(verifier, object)
        elsif verifier.respond_to?(:call)
          verifier.call(self, object)
        end
      end
      
      def run_before_list(list)
        self.class.before_list_filters.each do |meth|
          meth = method(meth) if meth.is_a?(Symbol)
          result = meth.call *(meth.arity == 0 ? [] : [list])
          return result if result.is_a?(FalseClass)
        end
      end
      
      def run_before_generate(object)
        self.class.before_generate_filters.each do |meth|
          meth = method(meth) if meth.is_a?(Symbol)
          result = meth.call *(meth.arity == 0 ? [] : [object])
          return result if result.is_a?(FalseClass)
        end
      end

      def run_before_sections(section, object)
        result = before_section(section, object)
        return result if result.is_a?(FalseClass)
        
        self.class.before_section_filters.each do |info|
          result, sec, meth = nil, *info
          if sec.nil? || sec == section
            meth = method(meth) if meth.is_a?(Symbol)
            args = [section, object]
            if meth.arity == 1 
              args = [object]
            elsif meth.arity == 0
              args = []
            end

            result = meth.call(*args)
            log.debug("Calling before section filter for %s%s with `%s`, result = %s" % [
              self.class.class_name, section.inspect, object, 
              result.is_a?(FalseClass) ? 'fail' : 'pass'
            ])
          end

          return result if result.is_a?(FalseClass)
        end
      end
      
      def sections_for(object); [] end
      
      def before_section(section, object); end
      
      def render_sections(object, sections = nil)
        sections ||= sections_for(object) || []

        data = ""
        sections.each_with_index do |section, index|
          next if section.is_a?(Array)
          
          data << if sections[index+1].is_a?(Array)
            render_section(section, object) do |obj|
              tmp, @current_object = @current_object, obj
              out = render_sections(obj, sections[index+1])
              @current_object = tmp
              out
            end
          else
            render_section(section, object)
          end
        end
        data
      end

      def render_section(section, object, &block)
        begin
          if section.is_a?(Class) && section <= Generators::Base
            opts = options.dup
            opts.update(:ignore_serializer => true)
            sobj = section.new(opts)
            sobj.generate(object, &block)
          elsif section.is_a?(Generators::Base)
            section.generate(object, &block)
          elsif section.is_a?(Symbol) || section.is_a?(String)
            return "" if run_before_sections(section, object).is_a?(FalseClass)

            if section.is_a?(Symbol)
              if respond_to?(section)
                if method(section).arity != 1
                  send(section, &block)
                else
                  send(section, object, &block) 
                end || ""
              else # treat it as a String
                render(object, section, &block)
              end
            else
              render(object, section, &block)
            end
          else
            type = section.is_a?(String) || section.is_a?(Symbol) ? 'section' : 'generator'
            log.warn "Ignoring invalid #{type} '#{section}' in #{self.class}"
            ""
          end
        end
      end
      
      def render(object, file = nil, locals = {}, &block)
        if object.is_a?(Symbol)
          object, file, locals = current_object, object, (file||{})
        end
        
        path = template_path(file.to_s + '.erb', generator_name)
        filename = find_template(path)
        if filename
          begin
            render_method(object, filename, locals, &block)           
          rescue => e
            log.error "#{e.class.class_name}: #{e.message}"
            log.error "in generator #{self.class}: #{filename}"
            log.error e.backtrace[0..10].join("\n")
            exit
          end
        else
          log.warn "Cannot find template `#{path}`"
          ""
        end
      end
      
      def render_method(object, filename, locals = {}, &block)
        l = locals.map {|k,v| "#{k} = locals[#{k.inspect}]" }.join(";")
        src = erb("<% #{l} %>" + File.read(filename)).src
        instance_eval(src, filename, 1)
      end
      
      def erb(str)
        ERB.new(str, nil, '<>')
      end
      
      def template_path(file, generator = generator_name)
        File.join(template.to_s, generator, format.to_s, file.to_s)
      end
      
      def find_template(path)
        self.class.template_paths.each do |basepath| 
          f = File.join(basepath, path)
          return f if File.file?(f)
        end
        nil
      end
    end
  end
end