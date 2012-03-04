class Word
  attr_reader :frequency
  attr_reader :total_next_count

  def initialize
    @next_words = {}

    # The frequency with which this word occurs in this context
    @frequency = 1

    # The total number of times a next word has been added
    @total_next_count = 0

    # The currently most popular next word
    @most_popular_next_word = nil
    @most_popular_next_word_count = 0
  end

  ###
  # For training
  def add_next_word next_word
    increase_number_of_next_words_received
    normalized_word = normalize_word next_word
    word = @next_words[normalized_word]
    unless word
      new_word = Word.new
      @next_words[normalized_word] = new_word
      word = new_word
    else
      word.increase_frequency
    end
    is_the_word_now_the_most_popular? normalized_word, word.frequency
    return word
  end

  ###
  # For predicting
  def predict_next
    @most_popular_next_word
  end

  ###
  # For introspection
  def frequency_of lookup_word
    word = @next_words[normalize_word lookup_word]
    return word.frequency if word
    0
  end

  def increase_frequency
    @frequency += 1
  end

  def object_for_word word
    @next_words[normalize_word word]
  end

  def to_s
    to_s_depth 0
  end
  def to_s_depth depth
    @next_words.each_pair do |word, word_object|
      depth.times {print "--"}
      puts word
      word_object.to_s_depth depth + 1
    end
  end
  
private
  def normalize_word word
    word.downcase
  end

  def increase_number_of_next_words_received
    @total_next_count += 1
  end

  def is_the_word_now_the_most_popular? word, frequency
    if frequency > @most_popular_next_word_count then
      @most_popular_next_word = word
      @most_popular_next_word_count = frequency
    end
  end
end

DOT = "[[dot]]"
COMMA = "[[comma]]"
MAX_NUM_WORDS = 3

class Predictor
  def initialize
    @words = Word.new
  end

  # Each text string is first split into paragraphs (double \n).
  # Then each paragraph is cleaned up a little bit and then fed
  # into the learning machinery
  #
  #    This is a great test.
  #
  #    What is next?
  #
  # becomes two separate texts:
  #   a) This is a great test.
  #   b) What is next?
  # which are separately fed into the training system
  def add_text new_text
    prepare_text(new_text).each do |word_array|
      0.upto word_array.length do |index|
        add_sequence word_array[index...(index+MAX_NUM_WORDS)]
      end
    end
  end

  def prepare_text new_text
    new_text.split("\n\n").map { |segment|
      segment.downcase.
              chomp.
              gsub("\"", "").
              gsub(".", padded(DOT)).
              gsub(",", padded(COMMA)).
              gsub("  ", " ").
              split(" ")
    }
  end

  def strip_special_characters text
    text.gsub(padded(DOT), ". ").
         gsub(" #{COMMA}", ",")
  end

  def add_sequence words
    bank = @words
    words.each do |next_word|
      bank = bank.add_next_word next_word
    end
  end

  def predict_next_words_after string, num_of_words
    word_array = (prepare_text string).flatten
    # Collect the output
    output = []
    # Get the words we are using for prediction
    current_words = word_array.last(MAX_NUM_WORDS - 1)
    num_of_words.times do
      next_word = get_next_word_for_sequence current_words
      break unless next_word
      # We got a new word, use it
      output << next_word
      current_words << next_word
      current_words = current_words.last(MAX_NUM_WORDS - 1)
    end
    strip_special_characters output.join(" ")
  end

  def get_next_word_for_sequence sequence
    # If we can't predict a next word, then stop.
    return nil if sequence == []

    bank = @words
    sequence.each do |word|
      next_bank = bank.object_for_word word
      if next_bank
        bank = next_bank
      else
        break
      end
    end
    unless bank
      try_shorter sequence
    else
      next_prediction = bank.predict_next
      next_prediction = try_shorter sequence unless next_prediction
      return next_prediction
    end
  end

  def try_shorter sequence
    get_next_word_for_sequence sequence.last(sequence.length - 1)
  end

private
  def padded string
    " #{string} "
  end
end
