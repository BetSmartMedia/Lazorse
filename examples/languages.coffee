lazorse = require '../'
lazorse ->
  greetingLookup = english: "Hi", french: "Salut"

  # This defines a route that accepts both GET and POST
  @route "/greeting/{language}":
    description: "Per-language greetings"
    shortName: 'localGreeting'
    GET:  -> @ok greeting: greetingLookup[@language], language: @language
    POST: -> greetingLookup[@language] = @req.body; @ok()
    examples: [
      {method: 'GET', vars: {language: 'english'}}
      {method: 'POST', vars: {language: 'english'}, body: "howdy"}
    ]

  # Define a coercion that restricts input languages to the
  # ones we have pre-defined
  @coerce language: (language, next) ->
    language = language.toLowerCase()
    if language not in greetings
      errName = @req.method is 'GET' and 'NotFound' or 'InvalidParameter'
      @error errName, 'language', language
    else
      next null, language

  # Define a custom error type and register it with the app
  TeapotError = (@code=418) ->
  @error TeapotError, (err, req, res, next) ->
    res.end """
      I'm a little teapot, short and stout.
      Here is my handle, here is my spout.
      When I get all steamed up, here me shout!
      Tip! me over and pour me out!
    """

  @route '/teapot': GET: -> @error 'TeapotError'
