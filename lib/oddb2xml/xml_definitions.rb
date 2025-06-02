# Definitions for the sax-machine parse to parse
# Preparations.xml

require "sax-machine"

STRIP_FOR_SAX_MACHINE = '<?xml version="1.0" encoding="utf-8"?>' + "\n"

class PriceElement
  include SAXMachine
  element :Price
  element :ValidFromDate
  element :DivisionDescription
  element :PriceTypeCode
  element :PriceTypeDescriptionDe
  element :PriceTypeDescriptionFr
  element :PriceTypeDescriptionIt
  element :PriceChangeTypeDescriptionDe
  element :PriceChangeTypeDescriptionFr
  element :PriceChangeTypeDescriptionIt
end

class StatusElement
  include SAXMachine
  element :IntegrationDate
  element :ValidFromDate
  element :ValidThruDate
  element :StatusTypeCodeSl
  element :StatusTypeDescriptionSl
  element :FlagApd
end

class PricesElement
  include SAXMachine
  element :ExFactoryPrice, class: PriceElement
  element :PublicPrice, class: PriceElement
end

class LimitationElement
  include SAXMachine
  element :LimitationCode
  element :LimitationType
  element :LimitationValue
  element :LimitationNiveau
  element :DescriptionDe
  element :DescriptionFr
  element :DescriptionIt
  element :ValidFromDate
  element :ValidThruDate
end

class LimitationsElement
  include SAXMachine
  elements :Limitation, class: LimitationElement
end

class PointLimitationElement
  include SAXMachine
  element :Points
  element :Packs
  element :ValidFromDate
  element :ValidThruDate
end

class PointLimitationsElement
  include SAXMachine
  elements :PointLimitation, class: PointLimitationElement
end

class PackContent
  include SAXMachine
  attribute :ProductKey
  attribute :PackId
  element :DescriptionDe
  element :DescriptionFr
  element :DescriptionIt
  element :SwissmedicCategory
  element :SwissmedicNo8
  element :FlagNarcosis
  element :FlagModal
  element :BagDossierNo
  element :GTIN
  element :Limitations, class: LimitationsElement
  element :PointLimitations, class: PointLimitationsElement
  element :Prices, class: PricesElement
end

class PacksElement
  include SAXMachine
  elements :Pack, class: PackContent
end

class ItCodeContent
  include SAXMachine
  attribute :Code
  element :DescriptionDe
  element :DescriptionFr
  element :DescriptionIt
  element :Limitations, class: LimitationsElement
end

class ItCodeEntry
  include SAXMachine
  element :ItCode, class: ItCodeContent
end

# handling attributes as suggested by https://github.com/pauldix/sax-machine/issues/30
class ItCodesElement
  include SAXMachine
  elements :ItCode, class: ItCodeContent
end

class SubstanceElement
  include SAXMachine
  element :DescriptionLa
  element :Quantity
  element :QuantityUnit
end

class SubstancesElement
  include SAXMachine
  elements :Substance, class: SubstanceElement
end

class PreparationContent
  include SAXMachine
  attribute :ProductCommercial
  element :NameFr
  element :NameDe
  element :NameIt
  element :Status, class: StatusElement
  element :Dummy
  element :DescriptionDe
  element :DescriptionFr
  element :DescriptionIt
  element :AtcCode
  element :SwissmedicNo5
  element :FlagItLimitation
  element :OrgGenCode
  element :FlagSB
  element :FlagSB20
  element :CommentDe
  element :CommentFr
  element :CommentIt
  element :VatInEXF
  element :Limitations, class: LimitationsElement
  element :Substances, class: SubstancesElement
  element :Packs, class: PacksElement
  element :ItCodes, class: ItCodesElement
end

class PreparationEntry
  include SAXMachine
  element :Preparation, class: PreparationContent
end

class PreparationsContent
  include SAXMachine
  attribute :ReleaseDate
  elements :Preparation, class: PreparationContent
end

class PreparationsEntry
  include SAXMachine
  element :Preparations, class: PreparationsContent
end

class CompElement
  include SAXMachine
  element :NAME
  element :GLN
end

class ItemContent
  include SAXMachine
  attribute :DT
  element :GTIN
  element :PHAR
  element :STATUS
  element :SDATE
  element :LANG
  element :DSCR
  element :ADDSCR
  element :ATC
  element :COMP, class: CompElement
end

class PharmaContent
  include SAXMachine
  attribute :CREATION_DATETIME
  elements :ITEM, class: ItemContent
end

class PharmaEntry
  include SAXMachine
  element :CREATION_DATETIME
  element :NONPHARMA, as: :PHARMA, class: PharmaContent
  element :PHARMA, class: PharmaContent
end

class ItemContent
  include SAXMachine
  attribute :DT
  element :GTIN
  element :PHAR
  element :STATUS
  element :STDATE
  element :LANG
  element :DSCR
  element :ADDSCR
  element :ATC
  element :COMP, class: CompElement
end

class MedicalInformationContent
  include SAXMachine
  attribute :type
  attribute :version
  attribute :lang
  element :title
  element :authHolder
  element :authNrs
  element :style
  element :content
end

class MedicalInformationEntry
  include SAXMachine
  element :medicalInformation, class: MedicalInformationContent
end

class MedicalInformationsContent
  include SAXMachine
  elements :medicalInformation, class: MedicalInformationContent
end

class MedicalInformationsEntry
  include SAXMachine
  element :medicalInformations, class: MedicalInformationsContent
end

class SwissRegProductClassification
  include SAXMachine
  element :ProductClass
  element :Atc
end

class SwissRegMedicinalProduct
  include SAXMachine
  element :Identifier
  element :Domain
  element :LegalStatusOfSupply
  element :RegulatedAuthorisationIdentifier
  element :ProductClassification, class: SwissRegProductClassification
end

class SwissRegHolder
  include SAXMachine
  element :Identifier
  element :Name
end

class SwissRegName
  include SAXMachine
  element :Language
  element :FullName
end

class SwissRegMarketingStatus
  include SAXMachine
  element :DateStart
end

class SwissRegPackagedProduct
  include SAXMachine
  element :Identifier
  element :RegulatedAuthorisationIdentifier
  element :DataCarrierIdentifier
  element :Holder, class: SwissRegHolder
  elements :Name, class: SwissRegName
  element :MarketingStatus, class: SwissRegMarketingStatus
end

class SwissRegArticle
  include SAXMachine
  element :MedicinalProduct, class: SwissRegMedicinalProduct
  element :PackagedProduct, class: SwissRegPackagedProduct
end

class SwissRegDocumentReference
  include SAXMachine
  element :Language
  element :Url
end

class SwissRegProductPrice
  include SAXMachine
  element :RetailPrice
end

class SwissRegArticles
  include SAXMachine
  elements :Article, class: SwissRegArticle
  elements :DocumentReference, class: SwissRegDocumentReference
  element :Hpc
  element :ProductPrice, class: SwissRegProductPrice
end
