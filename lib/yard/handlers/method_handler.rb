class YARD::Handlers::MethodHandler < YARD::Handlers::Base
  handles TkDEF
    
  def process
    nobj = namespace
    mscope = scope

    # Ignore the first 'def' token
    meth, args = parse_signature(statement.tokens[1..-1].to_s)

    # Class method if prefixed by self(::|.) or Module(::|.)
    if meth =~ /(?:#{NSEPQ}|#{CSEPQ})([^#{NSEP}#{CSEPQ}]+)$/
      mscope, meth = :class, $1
      nobj = P(namespace, $`) unless $` == "self"
    end
    
    obj = register MethodObject.new(nobj, meth, mscope) do |o| 
      o.visibility = visibility 
      o.source = statement
      o.explicit = true
      o.parameters = args
    end

    if obj.has_tag?(:overload)
      obj.overloads = obj.tags(:overload).map do |overload|
        meth, args = parse_signature(overload.name)
        MethodOverloadObject.new(obj, meth) do |sig|
          sig.parameters = args
          overload.text =~ /^(\s+)/
          sig.docstring = overload.text.gsub(/^#{$1}/, '')
        end
      end
    end

    parse_block(:owner => obj) # mainly for yield/exceptions
  end

  private

  def parse_signature(str)
    if str =~ /^\s*(#{METHODMATCH})(?:(?:\s+|\s*\()(.*)(?:\)\s*$)?)?/m
      meth, args = $1, $2
      meth.gsub!(/\s+/,'')
      args = tokval_list(YARD::Parser::TokenList.new(args), :all)
      args.map! {|a| k, v = *a.split('=', 2); [k.strip.to_sym, (v ? v.strip : nil)] } if args
      return meth, args
    else
      raise YARD::Handlers::UndocumentableError, "method: invalid name"
    end
  end
end
