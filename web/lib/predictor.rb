require 'rubygems'
require 'sqlite3'

#--------------------
# Constants
#--------------------
DOT = "[[dot]]"
COMMA = "[[comma]]"
EXCLAMATIONMARK = "[[!]]"
MAX_NUM_WORDS = 10

#--------------------
# Da MEAT
#--------------------
class WordBank
  def initialize
    @db = SQLite3::Database.new(File.dirname(__FILE__) + "/bank.sqlite")
    @get_count_for_segment = 
        @db.prepare("select count from occurrences where word=? AND previous_words=?")
    @insert_count =
        @db.prepare("insert into occurrences (word, count, previous_words) values (?,?,?)")
    @update_count =
        @db.prepare("update occurrences set count=? where word=? and previous_words=?")
    @update_store = Hash.new
  end

  def add_text text
    puts "Preparing text"
    segments = prepare_text text
    segment_num = 0
    num_segments = segments.size
    segments.each do |segment|
      segment_num += 1
      puts "Segment #{segment_num} of #{segments.size}" if segment_num % 100 == 0
      unless segment_num > num_segments / 2 then
        add_segment segment
      end
    end
    end_text_import
  end

  def what_comes_after? text, number_of_words
    segments = (prepare_text text).flatten
    basis_for_prediction = segments.last(MAX_NUM_WORDS - 1)
    current_prediction = []
    number_of_words.times do
      next_word = word_after basis_for_prediction
      current_prediction << next_word
      basis_for_prediction << next_word
      basis_for_prediction = basis_for_prediction.last(MAX_NUM_WORDS - 1)
    end
    clean_up_and_make_prediction_into_string current_prediction
  end

  #----------------------
  # Private
  #----------------------

  def clean_up_and_make_prediction_into_string prediction
    cleaned = prediction.map do |word|
      case word
      when DOT
        "."
      when EXCLAMATIONMARK
        "!"
      when COMMA
        ","
      else
        word
      end
    end
    joined = cleaned.join(" ").
      gsub(" .", ".").
      gsub(" ,", ",").
      gsub(" !", "!")
  end
  
  def word_after sequence
    return nil if sequence.length == 0
    previous_words = sequence.join("_")
    result = @db.get_first_value("select word from occurrences \
        where previous_words=? order by count DESC", previous_words)
    return result if result
    word_after sequence.last(sequence.length - 1)
  end
  
  def add_segment segment
    index = 0
    while index < segment.length
      increment_subsegment segment[index...(index+MAX_NUM_WORDS)]
      index += 1
    end
  end

  def increment_subsegment segment 
    return if segment.length < 2
    last = segment.pop
    path = segment.join("_")
    # Do we have the element cached?
    key = last + "-" + path
    if @update_store[key] then
      @update_store[key][:count] = @update_store[key][:count] + 1
    else
      @update_store[key] = {:count => 1}
      @update_store[key][:word] = last
      @update_store[key][:previous_words] = path
      @update_store[key][:requires_update] = true
#       # Get the element from the Db if it exists
#       row = @get_count_for_segment.execute(last, path).next
#       if row then
#         current_count = row.first + 1
#         @update_store[key] = {:count => current_count, :new => false}
#       else
#         @update_store[key] = {:count => 1, :new => true}
#         initial_count = 1
#       end
#       @update_store[key][:word] = last
#       @update_store[key][:previous_words] = path
#       @update_store[key][:requires_update] = true
    end
    increment_subsegment segment
  end

  def end_text_import
    # Persist data to database
    puts "... persisting a total of #{@update_store.size}"
    items_done = 0
    @update_store.each_value do |item|
      items_done += 1
      puts ": #{items_done}" if items_done % 1000 == 0
      count = item[:count]
      word = item[:word]
      previous_words = item[:previous_words]
      @insert_count.execute(word, count, previous_words)
#       if item[:new] then
#         @insert_count.execute(word, count, previous_words)
#       else
#         @update_count.execute(count, word, previous_words)
#       end
    end
    @update_store = {}
  end

  def normalize_word word
    word.downcase
  end

  def prepare_text new_text
    new_text.split("\n\n").map { |segment|
      segment.downcase.
              chomp.
              gsub("\"", "").
              gsub("'", "").
              gsub("`", "").
              gsub("<", "").
              gsub(">", "").
              gsub("=", "").
              gsub("_", " ").
              gsub("--", "").
              gsub("$", "").
              gsub("%", "").
              gsub("&", "").
              gsub("*", "").
              gsub("(", "").
              gsub(")", "").
              gsub("#", "").
              gsub("@", "").
              gsub(".", padded(DOT)).
              gsub(".", padded(EXCLAMATIONMARK)).
              gsub(",", padded(COMMA)).
              gsub("  ", " ").
              split(" ")
    }
  end

  def padded string
    " #{string} "
  end
end
