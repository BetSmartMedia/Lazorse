client = require('./client')
server = require('connect').createServer()
assert = require('assert')

TeapotError = ->
  @code = 418
  @message = "I'm a teapot"
  Error.captureStackTrace @, TeapotError

CoffeepotError = ->
  @code = 418
  @message = "I'm a coffeepot"
  Error.captureStackTrace @, TeapotError

server.use require('../lib/lazorse').app ->
  @route '/byNameUnregistered':
    GET: -> @error "TeapotError"

  @route '/byNameRegistered':
    GET: -> @error "TeapotError"

  @route '/usingConstructor':
    GET: -> @error TeapotError

describe "An app that uses custom errors", ->
  before (start) ->
    server.listen 0, 'localhost', ->
      client.usePort server.address().port
      start()

  after -> server.close()

  it "can't find errors by name when they aren't registered", (done) ->
    client.GET '/byNameUnregistered', (res) ->
      assert.equal res.statusCode, 500
      done()

  it "can find errors by name when they are registered", (done) ->
    client.GET '/byNameRegistered', (res) ->
      assert.equal res.statusCode, 500
      done()


  it 'treats functions as constructors regardless of registration', (done) ->
    client.GET '/usingConstructor', (res) ->
      assert.equal res.statusCode, 418
      done()
