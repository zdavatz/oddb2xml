# frozen_string_literal: true

require "net/http"
require "uri"
require "openssl"

module Oddb2xml
  # Preflight connectivity check. Run once at the very start of a CLI run, it
  # probes every outbound host oddb2xml needs (honouring the http(s)_proxy
  # environment) and prints a loud warning if any host is blocked by the proxy
  # (HTTP 407 on an allow-list proxy such as Aspectra's Skyhigh gateway) or is
  # otherwise unreachable. It never aborts the run -- downloads still proceed and
  # fail individually as before; this just surfaces the cause up front instead of
  # leaving the user to decode a later Errno/empty-output symptom. See issue #121.
  module ProxyCheck
    module_function

    # host => human-readable description of what breaks when it is unreachable.
    # Hosts only needed for certain options are added conditionally (see #hosts_for).
    BASE_HOSTS = {
      "files.refdata.ch" => "Refdata articles",
      "www.swissmedic.ch" => "Swissmedic registrations",
      "raw.githubusercontent.com" => "ATC codes (cpp2sqlite)"
    }.freeze

    TIMEOUT = 6 # seconds, per host (open + read); checks run concurrently

    def proxy_uri
      env = ENV["https_proxy"] || ENV["HTTPS_PROXY"] || ENV["http_proxy"] || ENV["HTTP_PROXY"]
      return nil if env.nil? || env.empty?
      env = "http://#{env}" unless env.start_with?("http")
      URI.parse(env)
    rescue URI::InvalidURIError
      nil
    end

    def hosts_for(options = {})
      hosts = BASE_HOSTS.dup
      hosts["epl.bag.admin.ch"] = "BAG FHIR data (--fhir)" if options[:fhir]
      hosts["id.gs1.ch"] = "GS1 NONPHARMA (--firstbase / -b)" if options[:firstbase]
      hosts["www.spezialitaetenliste.ch"] = "BAG Spezialitätenliste" unless options[:fhir]
      hosts["www.medregbm.admin.ch"] = "Medizinalberuferegister (-x address)" if options[:address]
      hosts
    end

    # Full union of every host any run could need, regardless of options.
    # Used by --proxy-check so the report covers everything in one go.
    def all_hosts
      BASE_HOSTS.merge(
        "epl.bag.admin.ch" => "BAG FHIR data (--fhir)",
        "id.gs1.ch" => "GS1 NONPHARMA (--firstbase / -b)",
        "www.spezialitaetenliste.ch" => "BAG Spezialitätenliste",
        "www.medregbm.admin.ch" => "Medizinalberuferegister (-x address)"
      )
    end

    # Probe every host and print a full OK/BLOCKED/UNREACHABLE table.
    # Returns true when all hosts are reachable. Used by `oddb2xml --proxy-check`.
    def report(_options = {})
      proxy = proxy_uri
      results = all_hosts.map do |host, desc|
        Thread.new { [host, desc, check_host(host, proxy)] }
      end.map(&:value).sort_by { |(host, _desc, _status)| host }

      header = "oddb2xml connectivity check"
      header += proxy ? " (via proxy #{proxy.host}:#{proxy.port})" : " (no proxy configured)"
      puts header
      results.each do |(host, desc, status)|
        tag = case status
        when :ok then "OK     "
        when :blocked then "BLOCKED" # proxy returned 407
        else "UNREACH"
        end
        puts format("  [%s] %-28s %s", tag, host, desc)
      end
      unreachable = results.reject { |(_host, _desc, status)| status == :ok }
      if unreachable.empty?
        puts "All #{results.size} hosts reachable."
        true
      else
        puts "#{unreachable.size} of #{results.size} host(s) NOT reachable -- downloads using them will fail."
        false
      end
    end

    # Returns :ok, :blocked (proxy 407) or :unreachable for a single host.
    def check_host(host, proxy)
      http =
        if proxy
          Net::HTTP.new(host, 443, proxy.host, proxy.port, proxy.user, proxy.password)
        else
          Net::HTTP.new(host, 443)
        end
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT
      http.start do |h|
        res = h.head("/")
        return :blocked if res.code.to_s == "407"
        return :ok # any HTTP answer (200/301/403/404/...) means the host is reachable
      end
    rescue => error
      msg = error.message.to_s.downcase
      return :blocked if msg.include?("407") || msg.include?("authenticationrequired") || msg.include?("proxy")
      :unreachable
    end

    # Probe all relevant hosts concurrently and warn about any that fail.
    def run(options = {})
      return if defined?(RSpec) || defined?(VCR) # never touch the network in tests
      return if ENV["ODDB2XML_SKIP_PROXY_CHECK"]

      proxy = proxy_uri
      hosts = hosts_for(options)
      results = hosts.map do |host, desc|
        Thread.new { [host, desc, check_host(host, proxy)] }
      end.map(&:value)

      problems = results.reject { |(_host, _desc, status)| status == :ok }
      return if problems.empty?

      warn_about(problems, proxy)
    end

    def warn_about(problems, proxy)
      line = "=" * 72
      warn line
      warn " oddb2xml CONNECTIVITY WARNING"
      warn " The following hosts could not be reached -- the corresponding"
      warn " downloads will FAIL or produce incomplete data:"
      problems.each do |(host, desc, status)|
        tag = (status == :blocked) ? "BLOCKED by proxy (407)" : "UNREACHABLE          "
        warn format("   [%s] %-26s %s", tag, host, desc)
      end
      if proxy
        warn ""
        warn " Proxy in use: #{proxy.host}:#{proxy.port}"
        if problems.any? { |(_h, _d, s)| s == :blocked }
          warn " This looks like an allow-list proxy. Ask your admin to allow the"
          warn " hosts above (HTTPS/443), or set credentials in http(s)_proxy."
        end
      end
      warn " (Set ODDB2XML_SKIP_PROXY_CHECK=1 to silence this check.)"
      warn line
    end
  end
end
