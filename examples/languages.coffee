lazorse = require '../'
lazorse ->
  greetingLookup = english: "Hi", french: "Salut"

  # This defines a resource that accepts both GET and POST
  @resource "/greeting/{language}":
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
  @coerce "language", """
    A language to use for localized greetings. Valid values: #{Object.keys(greetingLookup).join(', ')}.
  """, (language, next) ->
    language = language.toLowerCase()
    if language not in greetingLookup
      errName = @req.method is 'GET' and 'NotFound' or 'InvalidParameter'
      @error errName, 'language', language
    else
      next null, language

  # Extend the app with a custom rendering engine
  # Uses https://github.com/visionmedia/consolidate.js
  # and a non-standard resource property ``view``
  cons = require 'consolidate'
  @render 'text/html', (req, res, next) ->
    res.setHeader 'Content-Type', 'text/html'
    engine = req.resource.view?.engine or 'swig'
    path   = req.resource.view?.path or req.resource.shortName or 'fallback.html'
    cons[engine] path, res.data, (err, html) ->
      if err? then next err else res.end html

  # Define a custom error type and register it with the app
  TeapotError = -> @code = 418

  @error TeapotError, (err, req, res, next) ->
    res.end """
      I'm a little teapot, short and stout.
      Here is my handle, here is my spout.
      When I get all steamed up, hear me shout!
      Tip! me over and pour me out!
    """

  @resource '/teapot': GET: -> @error 'TeapotError'
