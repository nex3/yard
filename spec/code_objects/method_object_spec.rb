require File.dirname(__FILE__) + '/spec_helper'

describe YARD::CodeObjects::MethodObject do
  before do 
    Registry.clear 
    @yard = ModuleObject.new(:root, :YARD)
  end
  
  it "should have a path of testing for an instance method in the root" do
    meth = MethodObject.new(:root, :testing)
    meth.path.should == "#testing"
  end
  
  it "should have a path of YARD#testing for an instance method in YARD" do
    meth = MethodObject.new(@yard, :testing)
    meth.path.should == "YARD#testing"
  end
  
  it "should have a path of YARD.testing for a class method in YARD" do
    meth = MethodObject.new(@yard, :testing, :class)
    meth.path.should == "YARD.testing"
  end
  
  it "should exist in the registry after successful creation" do
    obj = MethodObject.new(@yard, :something, :class)
    Registry.at("YARD::something").should_not == nil
    obj = MethodObject.new(@yard, :somethingelse)
    Registry.at("YARD#somethingelse").should_not == nil
  end
end
