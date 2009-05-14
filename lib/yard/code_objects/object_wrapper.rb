module YARD
  module CodeObjects
    class ObjectWrapper
      alias_method :__class__, :class
      instance_methods.reject { |m| m =~ /^__/ }.each { |m| undef_method m }
      attr_accessor :wrapped

      def initialize(wrapped)
        @wrapped = wrapped
      end

      def inspect
        "#<yardoc #{wrapper_type} #{path}>"
      end

      def wrapper_type
        self.__class__.name.split(/#{NSEPQ}/).last.gsub(/Object$/, '').downcase.to_sym
      end

      def method_missing(name, *args, &block)
        wrapped.send(name, *args, &block)
      end
    end
  end
end
