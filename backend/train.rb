require 'socket'      # Sockets are in standard library

hostname = 'localhost'
port = 5678

puts "Adding training data"

dir_name = File.dirname(__FILE__) + "/texts"

Dir.entries(dir_name).each do |file_name|
  if file_name =~ /.txt$/ then
    file_path = dir_name + "/" + file_name
    File.open(file_path) do |file|
      puts "now adding: #{file_name}"
      file.each_line do |line|
        s = TCPSocket.open(hostname, port)
        s.puts line
        s.close 
      end
    end
    # FileUtils.mv(file_path, dir_name + "_done/" + file_name)
  end
end

puts "Added training data"
