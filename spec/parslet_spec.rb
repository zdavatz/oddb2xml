# encoding: utf-8

begin
require 'pry'
rescue LoadError
end
require 'pp'
require 'spec_helper'
require "#{Dir.pwd}/lib/oddb2xml/parslet_compositions"
require 'parslet/rig/rspec'

describe ParseDose do
  RunAllTests = false
  context 'should return correct dose for 123' do
    # dose = ParseDose.from_string("123")
    skip { expect(dose.qty).to eq 123 }
    skip { expect(dose.unit).to eq nil }
  end
  context 'should return correct dose for mg' do
    # dose = ParseDose.from_string('mg')
    skip { expect(dose.qty).to eq 1.0 }
    skip { expect(dose.unit).to eq 'mg' }
  end

  context 'should return correct dose for 2 mg' do
    dose = ParseDose.from_string('2 mg')
    specify { expect(dose.qty).to eq 2.0 }
    specify { expect(dose.unit).to eq 'mg' }
  end
end
