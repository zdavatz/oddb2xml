# encoding: utf-8

require 'spec_helper'
require "rexml/document"
require 'webmock/rspec'
include REXML
RUN_ALL = true

describe Oddb2xml::Builder do
  raise "Cannot rspec in directroy containing a spac" if / /.match(Oddb2xml::SpecData)
  NrExtendedArticles = 34
  NrSubstances = 14
  NrLimitations = 5
  NrInteractions = 5
  NrCodes = 5
  NrProdno = 23
  NrPackages = 24
  NrProducts = 19
  RegExpDesitin = /1125819012LEVETIRACETAM DESITIN Mini Filmtab 250 mg 30 Stk/
  include ServerMockHelper
  def check_artikelstamm_xml(key, expected_value)
    expect(@artikelstamm_name).not_to be nil
    expect(@inhalt).not_to be nil
    unless @inhalt.index(expected_value)
      puts expected_value
    end
    binding.pry unless @inhalt.index(expected_value)
    expect(@inhalt.index(expected_value)).not_to be nil
  end
  def common_run_init(options = {})
    @savedDir = Dir.pwd
    @oddb2xml_xsd = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb2xml.xsd'))
    @oddb_calc_xsd = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb_calc.xsd'))
    @elexis_v3_xsd = File.expand_path(File.join(__FILE__, '..', '..', 'Elexis_Artikelstamm_v003.xsd'))
    @elexis_v5_xsd = File.expand_path(File.join(__FILE__, '..', '..', 'Elexis_Artikelstamm_v5.xsd'))
    @elexis_v5_csv = File.join(Oddb2xml::WorkDir, 'Elexis_Artikelstamm_v5.csv')
    expect(File.exist?(@oddb2xml_xsd)).to eq true
    expect(File.exist?(@oddb_calc_xsd)).to eq true
    expect(File.exist?(@elexis_v3_xsd)).to eq true
    expect(File.exist?(@elexis_v5_xsd)).to eq true
    cleanup_directories_before_run
    FileUtils.makedirs(Oddb2xml::WorkDir)
    Dir.chdir(Oddb2xml::WorkDir)
    mock_downloads
  end

  after(:all) do
    Dir.chdir @savedDir if @savedDir and File.directory?(@savedDir)
  end
  context 'when artikelstamm option is given' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.parse(['--artikelstamm']) # , '--log'])
      # @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options).run }
      Oddb2xml::Cli.new(options).run # to debug
      @artikelstamm_name = File.join(Oddb2xml::WorkDir, "artikelstamm_#{Date.today.strftime('%d%m%Y')}_v5.xml")
      @doc = Nokogiri::XML(File.open(@artikelstamm_name))
      # @rexml = REXML::Document.new File.read(@artikelstamm_name)
      @inhalt = IO.read(@artikelstamm_name)
    end

    it 'should exist' do
      expect(File.exists?(@artikelstamm_name)).to eq true
    end

    it 'should have a comment' do
      expect(@inhalt).to match /<!--Produced by/
    end

    it 'should produce a Elexis_Artikelstamm_v5.csv' do
      expect(File.exists?(@elexis_v5_csv)).to eq true
      inhalt = File.open(@elexis_v5_csv, 'r+').read
      expect(inhalt.size).to be > 0
      expect(inhalt).to match /7680284860144/
    end

    it 'should generate a valid v3 nonpharma xml' do
      v3_name = @artikelstamm_name.sub('_v5.xml', '_v3.xml').sub('artikelstamm_', 'artikelstamm_N_')
      expect(File.exist?(v3_name)).to eq true
      validate_via_xsd(@elexis_v3_xsd, v3_name)
      expect(IO.read(v3_name)).not_to match(/<LIMITATION/)
      expect(IO.read(v3_name)).not_to match(/GTIN>7680161050583/)
      expect(IO.read(v3_name)).to match(/GTIN>4042809018288/)
      expect(IO.read(v3_name)).not_to match(/<LPPV>true</)
    end

    it 'should generate a valid v3 pharma xml' do
      v3_name = @artikelstamm_name.sub('_v5.xml', '_v3.xml').sub('artikelstamm_', 'artikelstamm_P_')
      expect(File.exist?(v3_name)).to eq true
      validate_via_xsd(@elexis_v3_xsd, v3_name)
      expect(IO.read(v3_name)).to match(/<LIMITATION/)
      expect(IO.read(v3_name)).to match(/GTIN>7680161050583/)
      expect(IO.read(v3_name)).not_to match(/GTIN>4042809018288/)
      expect(IO.read(v3_name)).to match(/<LPPV>true</)
    end

    it 'should contain a LIMITATION_PTS' do
      expect(@inhalt.index('<LIMITATION_PTS>40</LIMITATION_PTS>')).not_to be nil
    end

    it 'should contain a PRODUCT which was not in refdata' do
      expected = %(<PRODUCT>
            <PRODNO>6118601</PRODNO>
            <SALECD>A</SALECD>
            <DSCR>Nutriflex Omega special, Infusionsemulsion 625 ml</DSCR>
            <DSCRF/>
            <ATC>B05BA10</ATC>
        </PRODUCT>)
      expect(@inhalt.index(expected)).not_to be nil
    end

    it 'should not contain a GTIN=0' do
      expect(@inhalt.index('GTIN>0</GTIN')).to be nil
    end

    it 'should contain a GTIN starting 0' do
      expect(@inhalt.index('GTIN>0')).to be > 0
    end

    it 'should a DSCRF for 4042809018288 TENSOPLAST Kompressionsbinde 5cmx4.5m' do
      skip("Where does the DSCR for 4042809018288 come from. It should be TENSOPLAST bande compression 5cmx4.5m")
    end

    it 'should ignore GTIN 7680172330414' do
      # Took to much time to construct an example. Should change VCR
      skip("No time to check that data/gtin2ignore.yaml has an effect")
      @inhalt = IO.read(@artikelstamm_name)
      expect(@inhalt.index('7680172330414')).to be nil
    end

    it 'should a company EAN for 4042809018288 TENSOPLAST Kompressionsbinde 5cmx4.5m' do
      skip("Where does the COMP GLN for 4042809018288 come from. It should be 7601003468441")
    end

    it 'shoud contain Lamivudinum as 3TC substance' do
      expect(@inhalt.index('<SUBSTANCE>Lamivudinum</SUBSTANCE>')).not_to be nil
    end

    it 'shoud contain GENERIC_TYPE' do
      expect(@inhalt.index('<GENERIC_TYPE')).not_to be nil
    end
    
    it 'should contain DIBASE with phar' do
      info = %(DIBASE 10'000 - 7199565
DIBASE 25'000 - 7210539
  )
      expected = %(
                      <GTIN>7680658560014</GTIN>
            <SALECD>A</SALECD>
            <DSCR>DIBASE 10'000, orale Tropflösung</DSCR>
    )
      expect(@inhalt.index('<GTIN>7680658560014</GTIN>')).not_to be nil
    end
            
    it 'should contain a public price if the item was only in the SL liste (Preparations.xml)' do
      # same as 7680403330459 CARBADERM
      expect(@inhalt.index('<PPUB>27.70</PPUB>')).not_to be nil
    end
    it 'should contain PEVISONE Creme 30 g' do
      expect(@inhalt.index('PEVISONE Creme 15 g')).not_to be nil # 7680406620144
      expect(@inhalt.index('PEVISONE Creme 30 g')).not_to be nil # 7680406620229
      # Should also check for price!
    end
    it 'should validate against artikelstamm.xsd' do
      validate_via_xsd(@elexis_v5_xsd, @artikelstamm_name)
    end
      tests = { 'item 7680403330459 CARBADERM only in Preparations(SL)' =>
        %(<ITEM PHARMATYPE="P">
            <GTIN>7680403330459</GTIN>
            <PHAR>3603779</PHAR>
            <SALECD>I</SALECD>
            <DSCR>CARBADERM Creme Tb 300 ml</DSCR>
            <DSCRF>--missing--</DSCRF>
            <PEXF>16.22</PEXF>
            <PPUB>27.70</PPUB>
        </ITEM>),
        'item 4042809018288 TENSOPLAST' =>
      %(<ITEM PHARMATYPE="N">
            <GTIN>4042809018288</GTIN>
            <PHAR>55805</PHAR>
            <SALECD>A</SALECD>
            <DSCR>TENSOPLAST Kompressionsbinde 5cmx4.5m</DSCR>
            <DSCRF>--missing--</DSCRF>
            <PEXF>0.00</PEXF>
            <PPUB>22.95</PPUB>
        </ITEM>),
         'product 3247501 LANSOYL' => '<ITEM PHARMATYPE="P">
            <GTIN>7680324750190</GTIN>
            <PHAR>23722</PHAR>
            <SALECD>A</SALECD>
            <DSCR>LANSOYL Gel 225 g</DSCR>
            <DSCRF>LANSOYL gel 225 g</DSCRF>
            <COMP>
                <NAME>Actipharm SA</NAME>
                <GLN>7601001002012</GLN>
            </COMP>
            <PKG_SIZE>225</PKG_SIZE>
            <MEASURE>g</MEASURE>
            <MEASUREF>g</MEASUREF>
            <DOSAGE_FORM>Gelée</DOSAGE_FORM>
            <IKSCAT>D</IKSCAT>
            <LPPV>true</LPPV>
            <PRODNO>3247501</PRODNO>
        </ITEM>',
        'product 5366201 3TC' =>
      '<ITEM PHARMATYPE="P">
            <GTIN>7680353660163</GTIN>
            <PHAR>20273</PHAR>
            <SALECD>A</SALECD>
            <DSCR>KENDURAL Depottabl 30 Stk</DSCR>
            <DSCRF>KENDURAL cpr dépôt 30 pce</DSCRF>
            <COMP>
                <NAME>Farmaceutica Teofarma Suisse SA</NAME>
                <GLN>7601001374539</GLN>
            </COMP>
            <PEXF>4.4606</PEXF>
            <PPUB>8.25</PPUB>
            <PKG_SIZE>30</PKG_SIZE>
            <MEASURE>Tablette(n)</MEASURE>
            <MEASUREF>Tablette(n)</MEASUREF>
            <DOSAGE_FORM>Tupfer</DOSAGE_FORM>
            <DOSAGE_FORMF>Compresse</DOSAGE_FORMF>
            <SL_ENTRY>true</SL_ENTRY>
            <IKSCAT>C</IKSCAT>
            <DEDUCTIBLE>10</DEDUCTIBLE>
            <PRODNO>3536601</PRODNO>
        </ITEM>',
        'item 7680161050583 HIRUDOID' =>
         %(<ITEM PHARMATYPE="P">
            <GTIN>7680161050583</GTIN>
            <PHAR>2731179</PHAR>
            <SALECD>A</SALECD>
            <DSCR>HIRUDOID Creme 3 mg/g 40 g</DSCR>
            <DSCRF>HIRUDOID crème 3 mg/g 40 g</DSCRF>
            <COMP>
                <NAME>Medinova AG</NAME>
                <GLN>7601001002258</GLN>
            </COMP>
            <PEXF>4.768575</PEXF>
            <PPUB>8.8</PPUB>
            <PKG_SIZE>40</PKG_SIZE>
            <MEASURE>g</MEASURE>
            <MEASUREF>g</MEASUREF>
            <DOSAGE_FORM>Creme</DOSAGE_FORM>
            <SL_ENTRY>true</SL_ENTRY>
            <IKSCAT>D</IKSCAT>
            <DEDUCTIBLE>10</DEDUCTIBLE>
            <PRODNO>1610501</PRODNO>
        </ITEM>),
        'item 7680284860144 ANCOPIR' =>'<ITEM PHARMATYPE="P">
            <GTIN>7680284860144</GTIN>
            <PHAR>177804</PHAR>
            <SALECD>A</SALECD>
            <DSCR>Ancopir, Injektionslösung</DSCR>
            <DSCRF>--missing--</DSCRF>
            <COMP>
                <NAME>Dr. Grossmann AG, Pharmaca</NAME>
                <GLN/>
            </COMP>
            <PKG_SIZE>5</PKG_SIZE>
            <MEASURE>Ampulle(n)</MEASURE>
            <MEASUREF>Ampulle(n)</MEASUREF>
            <DOSAGE_FORM>Injektionslösung</DOSAGE_FORM>
            <DOSAGE_FORMF>Solution injectable</DOSAGE_FORMF>
            <SL_ENTRY>true</SL_ENTRY>
            <IKSCAT>B</IKSCAT>
            <DEDUCTIBLE>10</DEDUCTIBLE>
            <PRODNO>2848601</PRODNO>
        </ITEM>',
      'product 3TC Filmtabl' => %(<PRODUCT>
            <PRODNO>5366201</PRODNO>
            <SALECD>A</SALECD>
            <DSCR>3TC Filmtabl 150 mg</DSCR>
            <DSCRF>3TC cpr pell 150 mg</DSCRF>
            <ATC>J05AF05</ATC>
            <SUBSTANCE>Lamivudinum</SUBSTANCE>
        </PRODUCT>),
        'nur aus Packungen Coeur-Vaisseaux Sérocytol,' => %(<ITEM PHARMATYPE="P">
            <GTIN>7680002770014</GTIN>
            <PHAR>361815</PHAR>
            <SALECD>A</SALECD>
            <DSCR>SEROCYTOL Herz-Gefässe Supp 3 Stk</DSCR>
            <DSCRF>SEROCYTOL Coeur-Vaisseaux supp 3 pce</DSCRF>
            <COMP>
                <NAME>Serolab SA (succursale de Remaufens)</NAME>
                <GLN>7640128710004</GLN>
            </COMP>
            <PKG_SIZE>3</PKG_SIZE>
            <MEASURE>Suppositorien</MEASURE>
            <MEASUREF>Suppositorien</MEASUREF>
            <DOSAGE_FORM>suppositoire</DOSAGE_FORM>
            <IKSCAT>B</IKSCAT>
            <PRODNO>0027701</PRODNO>
        </ITEM>),
        'HUMALOG (Richter)' => %(<ITEM PHARMATYPE="P">
            <GTIN>7680532900196</GTIN>
            <PHAR>1699999</PHAR>
            <SALECD>A</SALECD>
            <DSCR>HUMALOG Inj Lös 100 IE/ml Durchstf 10 ml</DSCR>
            <DSCRF>HUMALOG sol inj 100 UI/ml flac 10 ml</DSCRF>
            <COMP>
                <NAME>Eli Lilly (Suisse) SA</NAME>
                <GLN>7601001261853</GLN>
            </COMP>
            <PEXF>30.4</PEXF>
            <PPUB>51.3</PPUB>
            <PKG_SIZE>1</PKG_SIZE>
            <MEASURE>Flasche(n)</MEASURE>
            <MEASUREF>Flasche(n)</MEASUREF>
            <DOSAGE_FORM>Injektionslösung</DOSAGE_FORM>
            <DOSAGE_FORMF>Solution injectable</DOSAGE_FORMF>
            <SL_ENTRY>true</SL_ENTRY>
            <IKSCAT>B</IKSCAT>
            <DEDUCTIBLE>20</DEDUCTIBLE>
            <PRODNO>5329001</PRODNO>
        </ITEM>)
              }

      tests.each do |key, expected|
        it "should a valid entry for #{key}" do
          check_artikelstamm_xml(key, expected)
        end
      end
  end
end
