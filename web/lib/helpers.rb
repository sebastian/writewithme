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
