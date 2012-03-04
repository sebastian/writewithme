require File.dirname(__FILE__) + '/spec_helper.rb'

describe WordStore do
  before do
    @word_store = WordStore.new
  end

  it "should allow words to be added and then remember path" do
    @word_store["hello"] = :something
    @word_store["there"] = :something_else
    @word_store.path.should == "hello_there"
  end
end

describe Word do
  before do
    @word = Word.new
  end

  it "should return a frequency of one for new words" do
    @word.frequency.should == 1
  end

  it "training with a word should increase its frequency" do
    @word.frequency_of("hello").should == 0
    @word.add_next_word "hello"
    @word.frequency_of("hello").should == 1
    @word.add_next_word "hello"
    @word.frequency_of("hello").should == 2
  end

  it "should maintain a total count of subword additions" do
    @word.total_next_count.should == 0
    @word.add_next_word "first"
    @word.total_next_count.should == 1
    @word.add_next_word "second"
    @word.total_next_count.should == 2
    @word.add_next_word "second"
    @word.total_next_count.should == 3
  end

  it "should return the word class object for the word that is added" do
    sub_word = @word.add_next_word("word")
    sub_word.frequency.should == @word.frequency_of("word")
    sub_word_2 = @word.add_next_word("word")
    sub_word.frequency.should == sub_word_2.frequency
  end

  it "should know the most popular next word" do
    @word.predict_next.should == nil
    @word.add_next_word "first"
    @word.predict_next.should == "first"
    @word.add_next_word "second"
    @word.predict_next.should == "first"
    @word.add_next_word "second"
    @word.predict_next.should == "second"
  end

  it "should be able to return the word object for a word" do
    @word.object_for_word("first").should == nil
    word_object_for_first = @word.add_next_word "first"
    @word.object_for_word("first").should == word_object_for_first
    @word.add_next_word "second"
    @word.add_next_word "third"
    @word.object_for_word("first").should == word_object_for_first
  end
end

describe Predictor do
  before do
    @predictor = Predictor.new
  end

  it "should have a method for training with new texts" do
    @predictor.add_text <<-eos
      This is my new text that I am adding and feeling awesome about
    eos
    @predictor.add_text <<-eos
      Here is another text. I am not sure if it works.
      Hahaha. It certainly is more dynamic.
    eos
  end

  it "should predict the next N words following a string" do
    @predictor.predict_next_words_after("hello there", 2).should == ""
    @predictor.add_text <<-eos
      Hello there good friend of mine
    eos
    @predictor.predict_next_words_after("hello there", 2).should == "good friend"
    @predictor.predict_next_words_after("hello there", 4).should == "good friend of mine"
  end

  # Testing private methods
  it "should prepare text by splitting it up and removing dots etc" do
    @predictor.prepare_text("blabla blabla").should == [["blabla", "blabla"]]
    @predictor.prepare_text("blabla. blabla").should == [["blabla", DOT, "blabla"]]
    @predictor.prepare_text("This is some awesome SHIT. I know it.").
      should == [["this", "is", "some", "awesome", "shit", DOT, "i", "know", "it", DOT]]
  end

  it "should strip out special characters before presenting the text" do
    @predictor.strip_special_characters("hello #{DOT} there").should == "hello. there"
    @predictor.strip_special_characters("hello #{DOT} #{COMMA} there").should == "hello., there"
    text = "mine my love shall render him [[dot]] and she is mine [[comma]] i may dispose"
    @predictor.strip_special_characters(text).should == 
      "mine my love shall render him. and she is mine, i may dispose"
  end
end
