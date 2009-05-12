module YARD
  module CodeObjects
    class MethodOverloadObject
      attr_accessor :docstring, :method, :name, :parameters

      def initialize(method, name)
        self.method = method
        self.name = name.to_sym
        self.parameters = []
        self.docstring = YARD::Docstring.new('', self)
        yield(self) if block_given?
      end

      ##
      # Attaches a docstring to a code oject by parsing the comments attached to the statement
      # and filling the {#tags} and {#docstring} methods with the parsed information.
      #
      # @param [String, Array<String>, Docstring] comments 
      #   the comments attached to the code object to be parsed 
      #   into a docstring and meta tags.
      def docstring=(comments)
        @docstring = Docstring === comments ? comments : Docstring.new(comments, method)
      end

      def tag(name); @docstring.tag(name) end
      def tags(name = nil); @docstring.tags(name) end
      def has_tag?(name); @docstring.has_tag?(name) end

      def name(prefix = false)
        ((prefix ? method.sep : "") + @name.to_s).to_sym
      end
    end
  end
end
