client = require('./client')
server = require('connect').createServer()
assert = require('assert')

errors = require '../lib/errors'

errors["teapot"] = TeapotError = ->
  @code = 418
  Error.captureStackTrace @, errors.TeapotError

server.use require('../lib/lazorse').app ->
  @route '/usingString':
    GET: -> @error "teapot"

  @route '/usingConstructor':
    GET: -> @error TeapotError


describe "A basic app", ->
  port = null
  before (start) ->
    server.listen 0, 'localhost', ->
      client.usePort server.address().port
      start()

  after -> server.close(); delete errors['TeapotError']

  it 'can find errors by name', (done) ->
    client.GET '/usingString', (res, rawBody) ->
      assert.equal res.statusCode, 418
      done()

  it 'treats functions as constructors', (done) ->
    client.GET '/usingConstructor', (res, rawBody) ->
      assert.equal res.statusCode, 418
      done()
