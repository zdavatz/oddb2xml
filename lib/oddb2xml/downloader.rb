# encoding: utf-8

require 'savon'

module Oddb2xml
  class Downloader

    def initialize(url=nil)
      @url = url || 'https://index.ws.e-mediat.net/Swissindex/Pharma/ws_Pharma_V101.asmx?WSDL'
      HTTPI.log = false # disable httpi warning
      Savon.configure do |config|
        config.log_level    = :info
        config.log          = false # $stdout
        config.raise_errors = true
      end
    end

    def download_by(lang = 'DE')
      client = Savon::Client.new do |wsdl, http|
        http.auth.ssl.verify_mode = :none
        wsdl.document             = @url
      end
      retry_times = 3
      begin
        response = client.request :download_all do
          soap.xml = <<XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Body>
  <lang xmlns="http://swissindex.e-mediat.net/SwissindexPharma_out_V101">#{lang}</lang>
</soap:Body>
</soap:Envelope>
XML
        end
        if response.success?
          if xml = response.to_xml
            return response.to_hash[:pharma][:item]
          else
            # received broken data or internal error
            raise StandardError
          end
        else
          # occured timeout or network error
          raise Timeout::Error
        end
      rescue Timeout::Error
        if retry_times > 0
          sleep 5
          retry_times -= 1
          retry
        else
          raise
        end
      rescue StandaredError, Savon::HTTP::Error => error
        puts error
      end
    end

  end
end
