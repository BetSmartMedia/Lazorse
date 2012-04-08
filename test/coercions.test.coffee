lazorse = require('../')
client = require('./client')
assert = require 'assert'

describe "Using coercions", ->
  server = lazorse ->
    @_stack.shift() # drop logger
    @port = 0

    @resource '/hello/{name}': GET: -> @ok "Hello #{@name}"

    @resource '/goodbye/{person(name)}': GET: -> @ok "Goodbye #{@person}"

    @coerce 'name', "Names will be uppercased", (val, next) ->
      next null, val.toUpperCase()

  before -> client.usePort server.address().port
  after  -> server.close()

  it 'modifies parameters', (done) ->
    client.GET '/hello/stephen', (res, body) ->
      assert.equal res.statusCode, 200
      assert.equal body, "Hello STEPHEN"
      done()

  it 'modifies parameters with aliases', (done) ->
    client.GET '/goodbye/stephen', (res, body) ->
      assert.equal res.statusCode, 200
      assert.equal body, "Goodbye STEPHEN"
      done()
