require File.dirname(__FILE__) + '/lib/predictor.rb'

@word_bank = WordBank.new

puts "Adding training data"

dir_name = File.dirname(__FILE__) + "/texts"

Dir.entries(dir_name).each do |file_name|
  if file_name =~ /.txt$/ then
    file_path = dir_name + "/" + file_name
    File.open(file_path) do |file|
      puts "now adding: #{file_name}"
      @word_bank.add_text file.read
    end
    FileUtils.mv(file_path, dir_name + "_done/" + file_name)
  end
end

puts "Added training data"

while true do
  print (@word_bank.what_comes_after? gets, 1) + " "
end
