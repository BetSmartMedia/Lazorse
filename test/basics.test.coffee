client = require('./client')
server = require('connect').createServer()
assert = require 'assert'

# Test server
server.use require('../lib/lazorse').app ->
  for method in client.METHODS
    route = {}
    uri = "/#{method}me"
    route[uri] = {}
    route[uri][method] = if method is 'HEAD'
      -> @res.end()
    else
      -> @ok "#{method}"

    @route route

  @route '/indexed':
    shortName: 'discoverableResource'
    GET: -> @ok 'found it'

  @route '/404':
    GET: -> @error 'NotFound', 'string error name', 'works'

  @route '/500':
    GET: -> @next new Error "I'm an unknown error type"

  @route '/422':
    GET: -> @error 'InvalidParameter', 'bad param'

# Tests
describe "A basic app", ->
  before (start) ->
    server.listen 0, 'localhost', ->
      client.usePort server.address().port
      start()

  after -> server.close()

  it "has an index with one resource", (done) ->
    client.GET '/', (res, resources) ->
      assert.equal res.statusCode, 200
      assert.equal resources.length, 1
      assert.equal resources[0].shortName, 'discoverableResource'
      done()
    

  it "will return 404 if no route matches", (done) ->
    client.GET "/the-nonexistant-route", (res) ->
      assert.equal res.statusCode, 404
      done()
   
  for errcode in [404, 422, 500]
    do (errcode) ->
      it "can return #{errcode}", (done) ->
        client.GET "/#{errcode}", (res) ->
          assert.equal res.statusCode, errcode
          done()

  for method in client.METHODS
    do (method) ->
      it "can handle the #{method} method", (done) ->
        client[method] "/#{method}me", (res) ->
          assert.equal res.statusCode, 200
          done()

