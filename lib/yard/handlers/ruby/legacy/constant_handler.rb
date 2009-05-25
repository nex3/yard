class YARD::Handlers::Ruby::Legacy::ConstantHandler < YARD::Handlers::Ruby::Legacy::Base
  HANDLER_MATCH = /\A[A-Z]\w*\s*=[^=]\s*/m
  handles HANDLER_MATCH
  
  def process
    # Don't document CONSTANTS if they're set in second class objects (methods) because
    # they're not "static" when executed from a method
    return unless owner.is_a? NamespaceObject
    
    name, value = *statement.tokens.to_s.gsub(/\r?\n/, '').split(/\s*=\s*/, 2)
    register ConstantObject.new(namespace, name) {|o| o.source = statement; o.value = value.strip }
  end
end