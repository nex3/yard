module YARD
  module CodeObjects
    class ExtendedMethodObject < ObjectWrapper
      def scope; :class; end
      def member_type; :cmeth; end

      def [](key)
        case key
        when :scope; return scope
        when :member_type; return member_type
        else; super
        end
      end
    end
  end
end
