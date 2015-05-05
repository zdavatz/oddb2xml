# encoding: utf-8

require 'spec_helper'
require "#{Dir.pwd}/lib/oddb2xml/parslet_compositions"
require 'parslet/rig/rspec'
require 'parslet/convenience'
require 'csv'

RunAllParsingExamples = false # Takes over 3 minutes to run, all the other ones just a few seconds
GoIntoPry = true
NGoIntoPry = false

galenic_tests = {
  'Acetocaustin, Lösung'                      => { :prepation_name=>"Acetocaustin", :galenic_form=>"Lösung" },
  '3TC 150 mg, Filmtabletten'                 => { :prepation_name=>"3TC 150 mg", :galenic_form=>"Filmtabletten" },
  'Sandostatin 0,2 mg/mL, Injektionslösung'   => { :prepation_name=>"Sandostatin 0,2 mg/mL", :galenic_form=>"Injektionslösung" },
  'Atorvastax-Drossapharm 20 mg'              => { :prepation_name=>"Atorvastax-Drossapharm 20 mg", :galenic_form=> nil },
#  'Atorvastatin Helvepharm, 10 mg Filmtabletten' => {:prepation_name=>"Atorvastatin Helvepharm", :galenic_form=> 'Filmtabletten'  },
#  'Ondansetron Labatec, 8mg/4ml concentré pour perfusion' =>    {:prepation_name=>"Ondansetron Labatec", :galenic_form=> 'concentré pour perfusion'  },
#  'Ondansetron Labatec, 8mg/4ml, concentré pour perfusion' =>   {:prepation_name=>"Ondansetron Labatec", :galenic_form=> 'concentré pour perfusion'  },
#  'Alustal Bäume, Injektionssuspension' =>    {:prepation_name=>"Alustal Bäume", :galenic_form=> 'Injektionssuspension'  },
#  'Alustal 3-Bäume, Injektionssuspension' =>    {:prepation_name=>"Alustal 3-Bäume", :galenic_form=> 'Injektionssuspension'  },
  }

if GoIntoPry

describe CompositionParser do
  let(:parser) { CompositionParser.new }
  context "identifier parsing" do
    let(:galenic_parser) { parser.galenic }
    it "parses identifier" do
      galenic_tests.each{
        |string, expected|
        puts string
        res1 = galenic_parser.parse_with_debug(string)
        res1.delete(:qty)   if res1
        res1.delete(:unit)  if res1
        if res1 == nil or ! res1.to_s.gsub(/@\d+/, '').eql? expected.to_s
          pp res1
          binding.pry
        end
        res1.should eq expected
                        }
    end
  end
end
else
  describe CompositionParser do
    context "should parse all lines in #{File.basename(AllColumn_C_Lines)}" do
      let(:galenic_parser) { CompositionParser.new.galenic }
      ausgabe = {}
      count = 0
      galenic_parser = CompositionParser.new.galenic
      IO.readlines(AllColumn_C_Lines).each {
        |string|
          count += 1
          # break if count > 100
          puts string
          res1 = galenic_parser.parse_with_debug(string)
          ausgabe[res1[:prepation_name].to_s] = res1[:galenic_form] if res1
          it "parses galenic #{string}" do
            res1 = galenic_parser.parse_with_debug(string)
            unless res1
              pp res1
              binding.pry
            end
          end
      }
      csv_name = File.join(Oddb2xml::WorkDir, 'galenic.csv')
      CSV.open(csv_name, "w+", :col_sep => ';') do |csv|
        ausgabe.each do |key, value|
          csv <<  [key, value]
        end
      end
    end
  end
end