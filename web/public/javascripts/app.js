(function() {
  var Reader, Segment, StoryBreak, StorySegment, Writer, unsupportedKey, _const_computer, _const_user, _key_backspace, _key_delete, _key_enter;
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  };
  _key_enter = 13;
  _key_delete = 46;
  _key_backspace = 8;
  _const_user = "me";
  _const_computer = "computer";
  unsupportedKey = function() {
    return alert("unsupported key");
  };
  Writer = (function() {
    function Writer() {
      this.currentSegment = __bind(this.currentSegment, this);
      this.performInternetWrite = __bind(this.performInternetWrite, this);
      this.preInternetWrite = __bind(this.preInternetWrite, this);
      this.getStoryFromComputer = __bind(this.getStoryFromComputer, this);
      this.words_left = __bind(this.words_left, this);
      this.set_word_allowance = __bind(this.set_word_allowance, this);
      this.keySupressor = __bind(this.keySupressor, this);
      this.insertEnter = __bind(this.insertEnter, this);
      this.deleteCharacter = __bind(this.deleteCharacter, this);
      this.shareStory = __bind(this.shareStory, this);
      this.addToStory = __bind(this.addToStory, this);
      this.keyHandler = __bind(this.keyHandler, this);      this.storySegments = [];
      this.newStorySegment(_const_user);
      this.waitingForOtherParty = false;
      this.allowedWordsForCurrentSegment = 0;
      this.set_word_allowance();
      this.updateWordsLeft();
    }
    Writer.prototype.keyHandler = function(e) {
      var char, code;
      code = e.which;
      char = String.fromCharCode(code);
      return this.addToStory(char);
    };
    Writer.prototype.addToStory = function(character) {
      if (this.words_left() > -1) {
        this.checkForNewWord(character);
        return this.currentSegment().addContent(character);
      } else {
        return console.log("Not enought words left");
      }
    };
    Writer.prototype.shareStory = function() {
      var all_stories, complete_story, part, post_share_callback;
      post_share_callback = __bind(function(id) {
        var localUrl;
        localUrl = encodeURI("http://writewithme.kle.io/read/" + id);
        return window.location = "http://www.facebook.com/sharer.php?u=" + localUrl + "&t=" + encodeURI("My WriteWithMe story");
      }, this);
      all_stories = (function() {
        var _i, _len, _ref, _results;
        _ref = this.storySegments;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          part = _ref[_i];
          _results.push(part.json());
        }
        return _results;
      }).call(this);
      complete_story = {
        complete_story: JSON.stringify(all_stories)
      };
      return ($.post("/create_facebook_share", complete_story)).success(post_share_callback);
    };
    Writer.prototype.deleteCharacter = function() {
      this.currentSegment().removeCharacter();
      return this.updateWordsLeft();
    };
    Writer.prototype.insertEnter = function() {
      return this.newStoryBreak().newStorySegment(_const_user);
    };
    Writer.prototype.keySupressor = function(e) {
      switch (e.keyCode) {
        case _key_enter:
          this.insertEnter();
          return e.preventDefault();
        case _key_backspace:
        case _key_delete:
          this.deleteCharacter();
          return e.preventDefault();
      }
    };
    Writer.prototype.set_word_allowance = function() {
      var extraWords;
      extraWords = Math.floor(Math.random() * 11);
      return this.allowedWordsForCurrentSegment = 7 + extraWords;
    };
    Writer.prototype.words_left = function() {
      return this.allowedWordsForCurrentSegment - this.currentSegment().num_words_written();
    };
    Writer.prototype.getStoryFromComputer = function() {
      var userContent;
      userContent = {
        content: this.currentSegment().raw_story()
      };
      this.preInternetWrite();
      return ($.post("/story_contribution", userContent)).success(this.performInternetWrite);
    };
    Writer.prototype.preInternetWrite = function() {
      ($("#cursor")).hide();
      return ($("#thinking_cursor")).show();
    };
    Writer.prototype.performInternetWrite = function(computerStory) {
      ($("#thinking_cursor")).hide();
      this.set_word_allowance();
      this.newStorySegment(_const_computer);
      this.currentSegment().addContent(computerStory);
      this.newStorySegment(_const_user);
      this.waitingForOtherParty = false;
      this.updateWordsLeft();
      return ($("#cursor")).show();
    };
    Writer.prototype.isSpecialCharacter = function(code) {
      switch (code) {
        case _key_enter:
          this.newStoryBreak().newStorySegment(_const_user);
          return true;
        case _key_backspace:
          this.currentSegment().removeCharacter();
          this.updateWordsLeft();
          return true;
        default:
          return false;
      }
    };
    Writer.prototype.currentSegment = function() {
      return this.storySegments[this.storySegments.length - 1];
    };
    Writer.prototype.checkForNewWord = function(char) {
      switch (char) {
        case " ":
        case ",":
        case ".":
          this.updateWordsLeft();
          if (!(this.words_left() > 0)) {
            return this.getStoryFromComputer();
          }
      }
    };
    Writer.prototype.newStorySegment = function(author) {
      this.storySegments.push(new StorySegment(author));
      return this;
    };
    Writer.prototype.newStoryBreak = function() {
      this.storySegments.push(new StoryBreak);
      return this;
    };
    Writer.prototype.updateWordsLeft = function() {
      var text;
      text = this.words_left() > 0 ? "You have " + this.words_left() + " words left to write before the internet takes over" : "The internet is writing";
      return ($(".words_left_text")).text(text);
    };
    return Writer;
  })();
  Segment = (function() {
    function Segment(pre_content) {
      this.json = __bind(this.json, this);
      this.render = __bind(this.render, this);      ($(".current_words")).removeClass("current_words");
      ($("#cursor")).before(pre_content);
    }
    Segment.prototype.render = function() {
      ($(".current_words")).remove();
      return ($("#cursor")).before(this.content());
    };
    Segment.prototype.json = function() {
      switch (this.type) {
        case "text":
          return {
            type: "text",
            text: this.story,
            author: this.author
          };
        case "break":
          return {
            type: "break"
          };
      }
    };
    return Segment;
  })();
  StoryBreak = (function() {
    __extends(StoryBreak, Segment);
    function StoryBreak() {
      StoryBreak.__super__.constructor.call(this, $("</p><p>"));
      this.type = "break";
    }
    return StoryBreak;
  })();
  StorySegment = (function() {
    __extends(StorySegment, Segment);
    function StorySegment(author) {
      this.author = author;
      this.num_words_written = __bind(this.num_words_written, this);
      this.calculate_words_written = __bind(this.calculate_words_written, this);
      this.removeCharacter = __bind(this.removeCharacter, this);
      this.raw_story = __bind(this.raw_story, this);
      this.addContent = __bind(this.addContent, this);
      StorySegment.__super__.constructor.call(this, $("<span class='story-segment author-" + this.author + "'></span>"));
      this.story = "";
      this.calculate_words_written();
      this.type = "text";
    }
    StorySegment.prototype.addContent = function(content) {
      this.story = this.story + content;
      this.calculate_words_written();
      return this.render();
    };
    StorySegment.prototype.content = function() {
      var output, word, _i, _len, _ref;
      output = "";
      _ref = this.story.split(" ");
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        word = _ref[_i];
        output += "<span class='story-word current_words author-" + this.author + "'>" + word + "</span>";
      }
      return output;
    };
    StorySegment.prototype.raw_story = function() {
      return this.story;
    };
    StorySegment.prototype.removeCharacter = function() {
      this.story = this.story.substring(0, this.story.length - 1);
      this.calculate_words_written();
      return this.render();
    };
    StorySegment.prototype.calculate_words_written = function() {
      this.words_written = (this.story.split(" ")).length;
      if (this.story === "") {
        return this.words_written = 0;
      }
    };
    StorySegment.prototype.num_words_written = function() {
      return this.words_written;
    };
    return StorySegment;
  })();
  Reader = (function() {
    function Reader(storyId) {
      this.storyId = storyId;
      this.finishedLoadingStory = __bind(this.finishedLoadingStory, this);
      this.readStory = __bind(this.readStory, this);
      this.readStory();
    }
    Reader.prototype.readStory = function() {
      console.log("Loading story");
      return ($.getJSON("/story/" + this.storyId + ".json")).success(this.finishedLoadingStory).error(this.errorLoadingStory);
    };
    Reader.prototype.finishedLoadingStory = function(storyData) {
      var element, _i, _len, _results;
      console.log("Got story data");
      ($("#story-paragraph")).html($("<div id='cursor' style='display:none'></div>"));
      _results = [];
      for (_i = 0, _len = storyData.length; _i < _len; _i++) {
        element = storyData[_i];
        _results.push(this.setupStoryElement(element));
      }
      return _results;
    };
    Reader.prototype.setupStoryElement = function(element) {
      var b, s;
      switch (element.type) {
        case "text":
          s = new StorySegment(element.author);
          return s.addContent(element.text);
        case "break":
          return b = new StoryBreak;
      }
    };
    Reader.prototype.errorLoadingStory = function() {
      return ($("#story-paragraph")).text("Oh no! I don't know that story! Please make sure the address is correct.");
    };
    return Reader;
  })();
  window.setupRead = function() {
    return new Reader(storyId);
  };
  window.setupWrite = function() {
    var callback, writer;
    callback = function() {
      return ($("#cursor")).toggleClass("blackCursor");
    };
    window.setInterval(callback, 500);
    writer = new Writer;
    if (document.layers) {
      document.captureEvents(Event.KEYPRESS);
    }
    ($(document)).keypress(writer.keyHandler);
    ($(document)).keydown(writer.keySupressor);
    return ($("#share_story_btn")).click(function() {
      return writer.shareStory();
    });
  };
  ($(document)).ready(function() {
    if (typeof storyId !== "undefined" && storyId !== null) {
      return setupRead();
    } else {
      return setupWrite();
    }
  });
}).call(this);
