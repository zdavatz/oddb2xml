# encoding: utf-8

require 'spec_helper'

describe "Oddb2xml::Cli" do
  context "when -c tar.gz option is given" do
    subject { Oddb2xml::Cli.new({:compress => 'tar.gz'}) }
    it { subject.instance_variable_get(:@options).should == {:compress => 'tar.gz'} }
    it { should respond_to(:run)  }
  end
  context "when no option is given" do
    subject { Oddb2xml::Cli.new({:compress => nil}) }
    it { should respond_to(:run)  }
    it { should respond_to(:help)  }
    it 'should call help successfully' do
      $stdout.should_receive(:puts).with(/Usage/).once
      subject.help
    end
  end
end
