module YARD
  module CodeObjects
    class ExtendedMethodObject
      instance_methods.reject { |m| m =~ /^__/ }.each { |m| undef_method m }

      def initialize(method)
        @method = method
      end

      def scope; :class; end
      def member_type; :cmeth; end

      def inspect
        "#<yardoc extended_method #{path}>"
      end

      def [](key)
        case key
        when :scope; return scope
        when :member_type; return member_type
        else; super
        end
      end

      def method_missing(name, *args, &block)
        @method.send(name, *args, &block)
      end
    end
  end
end
