require 'net/http'

# create a path to the file "C:\%HOME%\cacert.pem"
cacert_file = File.join(Dir.home, "cacert.pem")

Net::HTTP.start("curl.haxx.se") do |http|

  resp = http.get("/ca/cacert.pem")
  if resp.code == "200"
    open(cacert_file, "wb") { |file| file.write(resp.body) }
    puts "\n\nA bundle of certificate authorities has been installed to"
    puts "C:\\%HOME%\\cacert.pem\n"
    puts "* Please set SSL_CERT_FILE in your current command prompt session with:"
    puts " set SSL_CERT_FILE=C:\\Dir.home\\cacert.pem"
    puts "* To make this a permanent setting, add it to Environment Variables"
    puts " under Control Panel -> Advanced -> Environment Variables"
  else
    abort "\n\n>>>> A cacert.pem bundle could not be downloaded."
  end
end
system "cmd /k set.bat"
