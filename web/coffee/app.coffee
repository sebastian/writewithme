# Key codes
_key_enter = 13
_key_delete = 46
_key_backspace = 8

_const_user = "me"
_const_computer = "computer"

unsupportedKey = ->
  alert "unsupported key"

#---------------------------------
class Writer
  #------------------
  # Public
  #------------------
  
  constructor: ->
    @storySegments = []
    @newStorySegment(_const_user)
    @waitingForOtherParty = false
    @allowedWordsForCurrentSegment = 0
    @set_word_allowance()
    @updateWordsLeft()

  keyHandler: (e) =>
    code = e.which
    char = String.fromCharCode(code)
    @addToStory char

  addToStory: (character) =>
    if @words_left() > -1
      @checkForNewWord character
      @currentSegment().addContent character
    else
      console.log "Not enought words left"

  shareStory: =>
    post_share_callback = (id) =>
      localUrl = encodeURI("http://writewithme.kle.io/read/" + id)
      window.location = "http://www.facebook.com/sharer.php?u=" + localUrl + "&t=" + encodeURI("My WriteWithMe story")
    all_stories = (part.json() for part in @storySegments)
    complete_story = complete_story: JSON.stringify(all_stories)
    ($.post "/create_facebook_share", complete_story).
      success post_share_callback

  deleteCharacter: =>
    @currentSegment().removeCharacter()
    @updateWordsLeft()

  insertEnter: =>
    @newStoryBreak().newStorySegment(_const_user)

  keySupressor: (e) =>
    switch e.keyCode
      when _key_enter
        @insertEnter()
        e.preventDefault()
      when _key_backspace, _key_delete
        @deleteCharacter()
        e.preventDefault()

  #------------------
  # Private
  #------------------

  set_word_allowance: =>
    extraWords = Math.floor(Math.random()*11)
    @allowedWordsForCurrentSegment = 7 + extraWords

  words_left: =>
    @allowedWordsForCurrentSegment - @currentSegment().num_words_written()

  getStoryFromComputer: =>
    # Find the last content written by the user
    userContent = content: @currentSegment().raw_story()
    # Get story from computer
    @preInternetWrite()
    ($.post "/story_contribution", userContent).
      success @performInternetWrite

  preInternetWrite: =>
    # disable cursor
    ($ "#cursor").hide()
    # enable internet writing symbol
    ($ "#thinking_cursor").show()

  performInternetWrite: (computerStory) =>
    # diable internet thinking cursor
    ($ "#thinking_cursor").hide()
    # set new word allowance for the next part
    @set_word_allowance()
    # add content
    @newStorySegment(_const_computer)
    @currentSegment().addContent computerStory
    @newStorySegment(_const_user)
    @waitingForOtherParty = false
    @updateWordsLeft()
    # enable normal cursor
    ($ "#cursor").show()
    
  isSpecialCharacter: (code) ->
    switch code
      when _key_enter
        @newStoryBreak().newStorySegment(_const_user)
        true
      when _key_backspace
        @currentSegment().removeCharacter()
        @updateWordsLeft()
        true
      else
        false

  currentSegment: =>
    @storySegments[@storySegments.length - 1]

  checkForNewWord: (char) ->
    switch char
      when " ", ",", "."
        @updateWordsLeft()
        @getStoryFromComputer() unless @words_left() > 0

  newStorySegment: (author) ->
    @storySegments.push(new StorySegment(author))
    @

  newStoryBreak: ->
    @storySegments.push(new StoryBreak)
    @

  updateWordsLeft: ->
    text = if @words_left() > 0
      "You have " + @words_left() + " words left to write before the internet takes over"
    else
      "The internet is writing"
    ($ ".words_left_text").text text

#---------------------------------
class Segment
  constructor: (pre_content) ->
    # Remove tags from the words that were previously written to
    ($ ".current_words").removeClass("current_words")
    # Now we are ready to write new words :)
    # First though, we insert the precontent, if there is any
    ($ "#cursor").before pre_content

  render: =>
    # Remove all the words currently in this segment
    ($ ".current_words").remove()
    ($ "#cursor").before @content()

  json: =>
    switch @type
      when "text"
        type: "text"
        text: @story
        author: @author
      when "break"
        type: "break"


#---------------------------------
class StoryBreak extends Segment
  constructor: ->
    super($("</p><p>"))
    @type = "break"

#---------------------------------
class StorySegment extends Segment
  constructor: (@author) ->
    super($("<span class='story-segment author-" + @author + "'></span>"))
    @story = ""
    @calculate_words_written()
    @type = "text"

  addContent: (content) =>
    @story = @story + content
    @calculate_words_written()
    @render()

  content: ->
    output = ""
    for word in @story.split " "
      output += "<span class='story-word current_words author-" + @author + "'>" + word + "</span>"
    output

  raw_story: => @story

  removeCharacter: =>
    @story = @story.substring(0, @story.length-1)
    @calculate_words_written()
    @render()

  calculate_words_written: =>
    @words_written = (@story.split " ").length
    @words_written = 0 if @story == ""

  num_words_written: => @words_written

#---------------------------------
class Reader
  constructor: (@storyId) -> @readStory()

  readStory: =>
    console.log "Loading story"
    ($.getJSON "/story/" + @storyId + ".json").
      success(@finishedLoadingStory).
      error(@errorLoadingStory)

  finishedLoadingStory: (storyData) =>
    console.log "Got story data"
    ($ "#story-paragraph").html $("<div id='cursor' style='display:none'></div>")
    @setupStoryElement element for element in storyData

  setupStoryElement: (element) ->
    switch element.type
      when "text"
        s = new StorySegment(element.author)
        s.addContent element.text
      when "break"
        b = new StoryBreak

  errorLoadingStory: ->
    ($ "#story-paragraph").text "Oh no! I don't know that story! Please make sure the address is correct."


###############################
# Setup
###############################

window.setupRead = ->
  new Reader storyId

window.setupWrite = ->
  # Make the cursor blink
  callback = ->
    ($ "#cursor").toggleClass "blackCursor"

  window.setInterval callback, 500

  writer = new Writer
  if document.layers
    document.captureEvents Event.KEYPRESS
  # Handle text input
  ($ document).keypress writer.keyHandler
  # Handle special keys
  ($ document).keydown writer.keySupressor
  # Handle sharing of stories
  ($ "#share_story_btn").click ->
    writer.shareStory()

# Document main
($ document).ready ->
  if storyId?
    setupRead()
  else
    setupWrite()
