lazorse = require '../'
lazorse.server port: 3001, ->
  greetingLookup = english: "Hi", french: "Salut"

  # This defines a resource that accepts both GET and POST
  @resource "/greeting/{language}":
    description: "Per-language greetings"
    shortName: 'localGreeting'
    GET:  -> @ok greeting: greetingLookup[@language], language: @language
    POST: ->
      if @req.body?.greeting
        greetingLookup[@language] = @req.body.greeting
        @ok('ok')
      else
        @error 'InvalidParameter', 'greeting', @req.body?.greeting
    examples: [
      {method: 'GET', vars: {language: 'english'}}
      {method: 'POST', vars: {language: 'english'}, body: "howdy"}
    ]

  # Define a coercion that restricts input languages to the
  # ones we have pre-defined
  @coerce "language", """
    A language to use for localized greetings.
    Valid values: #{Object.keys(greetingLookup).join(', ')}.
  """, (language, next) ->
    language = language.toLowerCase()
    unless greetingLookup[language]
      errName = @req.method is 'GET' and 'NotFound' or 'InvalidParameter'
      @error errName, 'language', language
    else
      next null, language

  # Extend the app with a custom rendering engine
  # Uses https://github.com/visionmedia/consolidate.js
  # and a non-standard resource property ``view``
  consolidate = require 'consolidate'
  @render 'text/html', (req, res, next) ->
    res.setHeader 'Content-Type', 'text/html'
    engine = req.resource.view?.engine or 'swig'
    path   = req.resource.view?.path or req.resource.shortName or 'fallback.html'
    consolidate[engine] path, res.data, (err, html) ->
      if err? then next err else res.end html

  # Define a custom error type, we must use a class in CoffeeScript to get a
  # named function.
  class TeapotError
    constructor: ->

  # and register it with the app
  @error TeapotError, (err, req, res, next) ->
    res.statusCode = 418
    res.end """
      I'm a little teapot, short and stout.
      Here is my handle, here is my spout.
      When I get all steamed up, hear me shout!
      Tip! me over and pour me out!
    """

  @resource '/teapot': GET: -> @error 'TeapotError'
