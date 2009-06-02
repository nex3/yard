module YARD
  module Tags
    class OverloadTag < Tag
      attr_reader :signature, :parameters, :docstring
      
      def initialize(tag_name, text, raw_text)
        super(tag_name, nil)
        parse_tag(raw_text)
        parse_signature
      end
      
      def tag(name) docstring.tag(name) end
      def tags(name = nil) docstring.tags(name) end
      def has_tag?(name) docstring.has_tag?(name) end
        
      def object=(value)
        super(value)
        docstring.object = value
      end

      def type
        object.type
      end

      def name(prefix = false)
        object.name(prefix)
      end

      def inspect
        "#<yardoc overload #{path}>"
      end
      
      def method_missing(sym, *args, &block)
        object ? object.send(sym, *args, &block) : super
      end
        
      private
      
      def parse_tag(raw_text)
        @signature, text = raw_text.split(/\r?\n/, 2)
        text ||= ""
        @signature.strip!
        numspaces = text[/\A(\s*)/, 1].length
        text.gsub!(/^[ \t]{#{numspaces}}/, '').strip!
        @docstring = Docstring.new(text, nil)
      end
      
      def parse_signature
        if signature =~ /^(?:def)?\s*(#{CodeObjects::METHODMATCH})(?:(?:\s+|\s*\()(.*)(?:\)\s*$)?)?/m
          meth, args = $1, $2
          meth.gsub!(/\s+/,'')
          # FIXME refactor this code to not make use of the Handlers::Base class (tokval_list should be moved)
          toks = YARD::Parser::Ruby::Legacy::TokenList.new(args)
          args = YARD::Handlers::Ruby::Legacy::Base.new(nil, nil).send(:tokval_list, toks, :all)
          args.map! {|a| k, v = *a.split('=', 2); [k.strip.to_sym, (v ? v.strip : nil)] } if args
          @name = meth.to_sym
          @parameters = args
        end
      end
    end
  end
end
