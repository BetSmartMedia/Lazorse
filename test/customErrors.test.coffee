lazorse = require '../'
client = require('./client')
assert = require('assert')

TeapotError = ->
  @code = 418
  @message = "I'm a teapot"
  Error.captureStackTrace @, TeapotError

server = lazorse ->
  @port = 0
  @resource '/byNameUnregistered':
    GET: -> @error "TeapotError"

  @resource '/byNameRegistered':
    GET: -> @error "TeapotError"

  @resource '/usingConstructor':
    GET: -> @error TeapotError

describe "An app that uses custom errors", ->
  before -> client.usePort server.address().port
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
