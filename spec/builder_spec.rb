# encoding: utf-8

require 'spec_helper'

module Kernel
  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval "$#{stream} = #{stream.upcase}"
    end
    result
  end
end

describe Oddb2xml::Builder do
  include ServerMockHelper
  before(:all) do
    files = (Dir.glob('oddb_*.tar.gz')+ Dir.glob('oddb_*.zip')+ Dir.glob('oddb_*.xml'))# +Dir.glob('data/download/*'))
    files.each{ |file| FileUtils.rm(file) }
  end

  before(:each) do
    setup_server_mocks
    setup_swiss_index_server_mock(types =  ['NonPharma', 'Pharma'])
  end
  context 'should handle BAG-articles with and without pharmacode' do
    subject do
      dat = File.read(File.expand_path('../data/Preparation.xml', __FILE__))
      @items = Oddb2xml::BagXmlExtractor.new(dat).to_hash
    end
    it {
      saved =  @items.clone
      @items = subject.to_hash
      expect(@items.size).to eq(2)
      expect(saved).to eq(@items)
    }
  end if false
  
  context 'when no option is given' do
    let(:cli) do
      opts = {}
      Oddb2xml::Cli.new(opts)
    end    
    it 'should generate a valid oddb_product.xml' do
      res = capture(:stdout){ cli.run }
      res.should match(/products/)
      article_filename = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb_article.xml'))
      File.exists?(article_filename).should be_true   
      article_xml = IO.read(article_filename)
      product_filename = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb_product.xml'))
      File.exists?(product_filename).should be_true         
      product_xml = IO.read(product_filename)
      article_xml.should match(/3TC/) 
      article_xml.should match(/<PHAR>1699947</)
      article_xml.should match(/<SMNO>53662013</) 
      article_xml.should match(/<DSCRD>3TC Filmtabl 150 mg</) 
      article_xml.should match(/<COMPNO>7601001392175</) 
      article_xml.should match(/<BC>7680536620137</)
      article_xml.should match(/<VDAT>01.10.2011</)
      article_xml.should match(/<PTYP>PEXF</)
      article_xml.should match(/<PRICE>164.55</)
      article_xml.should match(/<PTYP>PPUB</)
      article_xml.should match(/<PRICE>205.3</)
      
      article_xml.should match(/Levetiracetam DESITIN/i) # 
      article_xml.should match(/7680536620137/) # Pharmacode
      article_xml.should match(/<PRICE>13.49</) 
      article_xml.should match(/<PRICE>27.8</) 

      product_xml.should match(/3TC/)
      product_xml.should match(/7680620690084/) # Levetiracetam DESITIN
      article_xml.scan(/<ART DT=/).size.should eq(2) # we should find two articles
      article_xml.should match(/<PHAR>5819012</)
      article_xml.should match(/<DSCRD>LEVETIRACETAM DESITIN Filmtabl 250 mg/)
      article_xml.should match(/<COMPNO>7601001320451</)
    end
  end
  
  context 'when -a nonpharma -f dat is given' do
    let(:cli) do
      opts = {
        :nonpharma    => 'true',
        :format       => :dat,
      }
      Oddb2xml::Cli.new(opts)
    end    
    it 'should generate a valid oddb_with_migel.dat' do
      res = capture(:stdout){ cli.run }
      res.should match(/products/)
      dat_filename = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb_with_migel.dat'))
      File.exists?(dat_filename).should be_true
      oddb_dat = IO.read(dat_filename)
#      $stdout.puts oddb_dat
#      return
      oddb_dat.should match(/1115819012LEVETIRACETAM DESITIN Filmtabl 250 mg 30 Stk      001349002780100B010710076806206900842/) 
    end
  end
end

