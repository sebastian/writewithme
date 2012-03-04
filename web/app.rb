require 'erubis'
Tilt.register :erb, Tilt[:erubis]

class Helpers
  def self.get_unique_id
    while true 
      id_to_try = rand(36**8).to_s(36)
      file_name = Helpers.get_path_name + id_to_try + ".json"
      return id_to_try unless File.exists?(file_name)
    end
  end
  def self.get_path_name
    File.dirname(__FILE__) + "/public/story/"
  end
end

get '/ping' do
  "pong"
end

get '/read/:story_id' do
  @id = params[:story_id]
  erb :read
end

get '/word_bank' do
  content = "my dear friends from the other side"
  word_bank = WordBank.new
  word_bank.what_comes_after? content, 1
end

post '/story_contribution' do
  content = params[:content]
  word_bank = WordBank.new
  word_bank.what_comes_after? content, 10 + rand(20)
end

post '/create_facebook_share' do
  story = params[:complete_story]
  file_name = Helpers.get_unique_id
  File.open(Helpers.get_path_name + file_name + ".json", "w") do |file|
    file.write story
  end
  return file_name
end

