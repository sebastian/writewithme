require 'socket'      # Sockets are in standard library


puts "Adding training data"

dir_name = File.dirname(__FILE__) + "/texts"

def send text 
  s = TCPSocket.open("localhost", 5678)
  s.puts text
  l = s.gets
  s.close 
  puts "Server says '#{l}'" if l and l.chomp != ""
end

Dir.entries(dir_name).each do |file_name|
  if file_name =~ /.txt$/ then
    file_path = dir_name + "/" + file_name
    File.open(file_path) do |file|
      puts "now adding: #{file_name}"
      file.each_line do |line|
        send line
      end
    end
    send "done"
    # FileUtils.mv(file_path, dir_name + "_done/" + file_name)
  end
end

puts "Added training data"
