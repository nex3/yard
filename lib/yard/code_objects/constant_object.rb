module YARD::CodeObjects
  class ConstantObject < Base
    attr_accessor :value

    def member_type; :const; end
  end
end
