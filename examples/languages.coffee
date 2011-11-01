lazorse = require '../'
lazorse ->
  greetingLookup = english: "Hi", french: "Salut"

  # This defines a route that accepts both GET and POST
  @route "/greeting/{language}":
    description: "Retrieve or store a per-language greeting"
    shortName: 'localGreeting'
    examples: 'GET /greeting/enGLish': greeting: "Hi", language: "english"
    GET:  -> @ok greeting: greetingLookup[@language], language: @language
    POST: -> greetingLookup[@language] = @req.body; @ok()

  # Define a coercion that restricts input languages to the
  # ones we have pre-defined
  @coerce language: (lang, next) ->
    lang = lang.toLowerCase()
    unless greetingLookup[lang]?
      return next new lazorse.InvalidParameter 'language', lang
    next null, lang
