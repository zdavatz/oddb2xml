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
  RunAllTests = true

  context "should return correct dose for 'mg'" do
    dose = ParseDose.from_string('mg')
    specify { expect(dose.qty).to eq 1.0 }
    specify { expect(dose.unit).to eq 'mg' }
  end


  context "should return correct dose for 'ml'" do
    dose = ParseDose.from_string('ml')
    specify { expect(dose.qty).to eq 1.0 }
    specify { expect(dose.unit).to eq 'ml' }
  end

  context "should return correct dose for '123'" do
    dose = ParseDose.from_string("123")
    specify { expect(dose.qty).to eq 123 }
    specify { expect(dose.unit).to eq nil }
  end

  context "should return correct dose for '123.45'" do
    dose = ParseDose.from_string("123.45")
    specify { expect(dose.qty).to eq 123.45 }
    specify { expect(dose.unit).to eq nil }
  end

  context "should return correct dose for '2 mg'" do
    dose = ParseDose.from_string('2 mg')
    specify { expect(dose.qty).to eq 2.0 }
    specify { expect(dose.unit).to eq 'mg' }
  end

  context "should return correct dose for '0.3 ml'" do
    dose = ParseDose.from_string('0.3 ml')
    specify { expect(dose.qty).to eq 0.3 }
    specify { expect(dose.unit).to eq 'ml' }
  end

  context "should return correct dose for '0.01 mg/ml'" do
    dose = ParseDose.from_string('0.01 mg/ml')
    specify { expect(dose.qty).to eq 0.01 }
    specify { expect(dose.unit).to eq 'mg/ml' }
  end

  context "should return correct dose for '3 mg/ml'" do
    dose = ParseDose.from_string('3 mg/ml')
    specify { expect(dose.qty).to eq 3.0 }
    specify { expect(dose.unit).to eq 'mg/ml' }
  end

  context "should return correct dose for '80-120 g'" do
    string = "80-120 g"
    skip { dose = ParseDose.from_string(context)
    specify { expect(dose.to_s).to eq string }
    specify { expect(dose.qty).to eq 95.8 }
    specify { expect(dose.unit).to eq 'g' }
         }
  end
end
