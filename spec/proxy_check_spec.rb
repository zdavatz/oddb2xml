# frozen_string_literal: true

require "spec_helper"
require "oddb2xml/proxy_check"

RSpec.describe Oddb2xml::ProxyCheck do
  describe ".check_host" do
    it "returns :ok with no :via for a plain 200" do
      stub_request(:head, "https://files.refdata.ch/x").to_return(status: 200)
      expect(described_class.check_host("files.refdata.ch", nil, "/x")).to eq(result: :ok, via: nil)
    end

    it "flags a proxy 407 as :blocked" do
      stub_request(:head, "https://files.refdata.ch/x").to_return(status: 407)
      expect(described_class.check_host("files.refdata.ch", nil, "/x")[:result]).to eq :blocked
    end

    it "follows the cross-host redirect chain and names the final host in :via" do
      stub_request(:head, "https://id.gs1.ch/01/07612345000961")
        .to_return(status: 301, headers: {"Location" => "https://id.gs1.org/01/07612345000961"})
      stub_request(:head, "https://id.gs1.org/01/07612345000961")
        .to_return(status: 307, headers: {"Location" => "https://apitools.gs1.ch/api/v2/x?format=csv"})
      stub_request(:head, "https://apitools.gs1.ch/api/v2/x?format=csv").to_return(status: 405)

      expect(described_class.check_host("id.gs1.ch", nil, "/01/07612345000961"))
        .to eq(result: :ok, via: "apitools.gs1.ch")
    end

    it "reports a blocked redirect target as :blocked, naming it in :via" do
      stub_request(:head, "https://id.gs1.ch/01/x")
        .to_return(status: 301, headers: {"Location" => "https://id.gs1.org/01/x"})
      stub_request(:head, "https://id.gs1.org/01/x").to_return(status: 407)

      expect(described_class.check_host("id.gs1.ch", nil, "/01/x"))
        .to eq(result: :blocked, via: "id.gs1.org")
    end

    it "does not set :via for a same-host redirect" do
      stub_request(:head, "https://files.refdata.ch/a")
        .to_return(status: 301, headers: {"Location" => "https://files.refdata.ch/b"})
      # same-host redirect is not followed; the host is already reachable
      expect(described_class.check_host("files.refdata.ch", nil, "/a")).to eq(result: :ok, via: nil)
    end
  end

  describe ".all_hosts" do
    it "includes the GS1 forwarder target id.gs1.org" do
      expect(described_class.all_hosts).to have_key("id.gs1.org")
    end
  end

  describe ".hosts_for" do
    it "probes id.gs1.org alongside id.gs1.ch when firstbase is requested" do
      hosts = described_class.hosts_for(firstbase: true)
      expect(hosts).to include("id.gs1.ch", "id.gs1.org")
    end

    it "omits the GS1 hosts without firstbase" do
      hosts = described_class.hosts_for({})
      expect(hosts).not_to have_key("id.gs1.ch")
      expect(hosts).not_to have_key("id.gs1.org")
    end
  end

  describe ".probe_path" do
    it "maps a known host to its real download resource" do
      expect(described_class.probe_path("id.gs1.ch")).to eq "/01/07612345000961"
    end

    it "falls back to / for an unknown host" do
      expect(described_class.probe_path("example.com")).to eq "/"
    end
  end
end
