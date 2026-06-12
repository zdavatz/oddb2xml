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

    # Representative resource path per host -- the actual file the downloader
    # fetches, NOT "/". Probing "/" gives misleading host redirects (e.g.
    # raw.githubusercontent.com/ -> github.com, while the real raw file path
    # returns 200), whereas the genuine download paths reveal the real
    # forwarder chain the proxy must allow (id.gs1.ch -> id.gs1.org ->
    # apitools.gs1.ch; www.spezialitaetenliste.ch/File.axd -> sl.bag.admin.ch).
    PROBE_PATHS = {
      "files.refdata.ch" => "/simis-public-prod/Articles/1.0/Refdata.Articles.zip",
      "raw.githubusercontent.com" => "/zdavatz/oddb2xml_files/master/LPPV.txt",
      "id.gs1.ch" => "/01/07612345000961",
      "id.gs1.org" => "/01/07612345000961",
      "www.spezialitaetenliste.ch" => "/File.axd?file=XMLPublications.zip",
      "www.medregbm.admin.ch" => "/Publikation/"
    }.freeze

    def probe_path(host)
      PROBE_PATHS[host] || "/"
    end

    def proxy_uri
      env = ENV["https_proxy"] || ENV["HTTPS_PROXY"] || ENV["http_proxy"] || ENV["HTTP_PROXY"]
      return nil if env.nil? || env.empty?
      env = "http://#{env}" unless env.start_with?("http")
      URI.parse(env)
    rescue URI::InvalidURIError
      nil
    end

    # Redirect targets ("forwarders") that an allow-list proxy must permit in
    # addition to the host we actually request. id.gs1.ch 301-redirects every
    # path to the global resolver id.gs1.org, so allowing only id.gs1.ch is not
    # enough -- the firstbase download follows the redirect and dies on the
    # blocked target. The real firstbase chain is id.gs1.ch -> id.gs1.org ->
    # apitools.gs1.ch, so the redirect is followed dynamically too (see
    # check_host); this list just guarantees the known target is probed even
    # when the redirect probe is short-circuited.
    FORWARDERS = {
      "id.gs1.org" => "GS1 global resolver (id.gs1.ch redirect target, --firstbase / -b)"
    }.freeze

    def hosts_for(options = {})
      hosts = BASE_HOSTS.dup
      hosts["epl.bag.admin.ch"] = "BAG FHIR data (--fhir)" if options[:fhir]
      if options[:firstbase]
        hosts["id.gs1.ch"] = "GS1 NONPHARMA (--firstbase / -b)"
        hosts["id.gs1.org"] = FORWARDERS["id.gs1.org"]
      end
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
      ).merge(FORWARDERS)
    end

    # Probe every host and print a full OK/BLOCKED/UNREACHABLE table.
    # Returns true when all hosts are reachable. Used by `oddb2xml --proxy-check`.
    def report(_options = {})
      proxy = proxy_uri
      results = all_hosts.map do |host, desc|
        Thread.new { [host, desc, check_host(host, proxy, probe_path(host))] }
      end.map(&:value).sort_by { |(host, _desc, _status)| host }

      header = "oddb2xml connectivity check"
      header += proxy ? " (via proxy #{proxy.host}:#{proxy.port})" : " (no proxy configured)"
      puts header
      results.each do |(host, desc, status)|
        tag = case status[:result]
        when :ok then "OK     "
        when :blocked then "BLOCKED" # proxy returned 407
        else "UNREACH"
        end
        label = status[:via] ? "#{host} -> #{status[:via]}" : host
        puts format("  [%s] %-36s %s", tag, label, desc)
      end
      unreachable = results.reject { |(_host, _desc, status)| status[:result] == :ok }
      if unreachable.empty?
        puts "All #{results.size} hosts reachable."
        true
      else
        puts "#{unreachable.size} of #{results.size} host(s) NOT reachable -- downloads using them will fail."
        results.select { |(_host, _desc, status)| status[:via] }.each do |(host, _desc, status)|
          puts "  note: #{host} redirects to #{status[:via]} -- that host must be on the proxy allow-list too."
        end
        false
      end
    end

    # Probe a host (following HTTP redirects to other hosts) and return a Hash:
    #   { result: :ok | :blocked | :unreachable, via: "final.host" | nil }
    # `:via` is set only when the host redirected to a *different* host, so the
    # caller can surface that the redirect target (e.g. id.gs1.ch -> id.gs1.org)
    # must be reachable too -- a 301 to a blocked host used to be reported as OK.
    def check_host(host, proxy, path = "/", hops = 4, origin = nil)
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
        res = h.head(path)
        return {result: :blocked, via: via_for(origin, host)} if res.code.to_s == "407"
        if res.code.to_s.start_with?("3") && res["location"] && hops > 0
          loc = URI.parse(res["location"])
          if loc.host && loc.host != host
            next_path = (loc.respond_to?(:request_uri) && loc.request_uri) ? loc.request_uri : "/"
            return check_host(loc.host, proxy, next_path, hops - 1, origin || host)
          end
        end
        # any other HTTP answer (200/403/404/...) means this host is reachable
        return {result: :ok, via: via_for(origin, host)}
      end
    rescue => error
      msg = error.message.to_s.downcase
      blocked = msg.include?("407") || msg.include?("authenticationrequired") || msg.include?("proxy")
      {result: blocked ? :blocked : :unreachable, via: via_for(origin, host)}
    end

    # The final host reached, but only when it differs from where we started.
    def via_for(origin, host)
      (origin && origin != host) ? host : nil
    end

    # Probe all relevant hosts concurrently and warn about any that fail.
    def run(options = {})
      return if defined?(RSpec) || defined?(VCR) # never touch the network in tests
      return if ENV["ODDB2XML_SKIP_PROXY_CHECK"]

      proxy = proxy_uri
      hosts = hosts_for(options)
      results = hosts.map do |host, desc|
        Thread.new { [host, desc, check_host(host, proxy, probe_path(host))] }
      end.map(&:value)

      problems = results.reject { |(_host, _desc, status)| status[:result] == :ok }
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
        tag = (status[:result] == :blocked) ? "BLOCKED by proxy (407)" : "UNREACHABLE          "
        label = status[:via] ? "#{host} -> #{status[:via]}" : host
        warn format("   [%s] %-34s %s", tag, label, desc)
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
