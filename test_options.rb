#!/usr/bin/env ruby
# Helper script to test all common usageas of oddb2xml
# - runs rake install to install the gem
# - Creates an output directory ausgabe/time_stamp
# - runs all commands (and add ---skip-download)
# - saveds output and downloads to ausgabe/time_stamp


require 'fileutils'
require 'socket'
require 'oddb2xml/version'

def test_one_call(cmd)
  dest = File.join(Ausgabe, cmd.gsub(/[ -]/, '_'))
  all_downloads = File.join(dest, 'downloads')
  FileUtils.makedirs(all_downloads) unless File.exists?(all_downloads)
  cmd.sub!('oddb2xml',  'oddb2xml --skip-download --log')
  files = (Dir.glob('%.xls*') + Dir.glob('*.dat*') + Dir.glob('*.xml'))
  FileUtils.rm(files, :verbose => true)
  puts "#{Time.now}: Running cmd #{cmd}"
  startTime = Time.now
  res = system(cmd)
  endTime = Time.now
  diffSeconds = (endTime - startTime).to_i
  duration = "#{Time.now}: Took #{sprintf('%3d', diffSeconds)} seconds for"
  puts "#{duration} success #{res} for #{cmd}"
  exit 2 unless res
  FileUtils.makedirs(dest)
  return unless File.directory?('downloads')
  FileUtils.cp_r('downloads', dest, :preserve => true, :verbose => true) if Dir.glob(Ausgabe).size > 0
  FileUtils.cp(Dir.glob('*.dat'), dest, :preserve => true, :verbose => true) if Dir.glob('*.dat').size > 0
  FileUtils.cp(Dir.glob('*.xml'), dest, :preserve => true, :verbose => true) if Dir.glob('*.xml').size > 0
  FileUtils.cp(Dir.glob('*.gz'),  dest, :preserve => true, :verbose => true) if Dir.glob('*.gz').size > 0
  downloaded_files = Dir.glob("#{dest}/*/downloads/*")
  FileUtils.mv(downloaded_files,  all_downloads, :verbose => true) if downloaded_files.size > 0
  FileUtils.rm(Dir.glob("#{dest}/*#{Time.now.year}*.xml"), :verbose => true)
end

def prepare_for_gem_test
  [ "rake clean gem install"      , # build  and install our gem first
#    "gem uninstall --all --ignore-dependencies --executables",
    "gem install --no-ri --no-rdoc pkg/*.gem"
  ].each {
    |cmd|
      puts "Running #{cmd}"
      exit 1 unless system(cmd)
  }
end

Ausgabe = File.join(Dir.pwd, 'ausgabe', "#{Oddb2xml::VERSION}-#{Time.now.strftime('%Y.%m.%d')}") 
puts "FQDN hostname #{Socket.gethostbyname(Socket.gethostname).inspect}"
FileUtils.makedirs(Ausgabe)
prepare_for_gem_test
# we will skip some long running tests as travis jobs must finish in less than 50 minutes
# unfortunately it returns a very common name
unless 'localhost.localdomain'.eql?(Socket.gethostbyname(Socket.gethostname).first)
  test_one_call('oddb2xml -e')
  test_one_call('oddb2xml --artikelstamm')
  test_one_call('oddb2xml -e -I80')
  test_one_call('oddb2xml -f dat --append -I 80')
  test_one_call('oddb2xml -f dat --append')
  test_one_call('oddb2xml --append')
end
test_one_call('oddb2xml --calc')
test_one_call('oddb2xml -t md -c tar.gz')
test_one_call('oddb2xml -o')
test_one_call('oddb2xml -f xml')
test_one_call('oddb2xml -f dat')
test_one_call('oddb2xml -t md')
# test_one_call('oddb2xml -x address')
