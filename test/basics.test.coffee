lazorse = require '../'
client = require './client'
assert = require 'assert'

describe "A basic app", ->
  server = lazorse.server port: 0, host: '127.0.0.1', ->
    for method in client.METHODS
      resource = {}
      uri = "/#{method}me"
      resource[uri] = {}
      resource[uri][method] = if method is 'HEAD'
        -> @res.end()
      else
        -> @ok "#{method}"

      @resource resource

    @resource '/indexed':
      shortName: 'discoverableResource'
      GET: -> @ok 'found it'

    @resource '/404':
      GET: -> @error 'NotFound', 'string error name', 'works'

    @resource '/500':
      GET: -> @next new Error "I'm an unknown error type"

    @resource '/422':
      GET: -> @error 'InvalidParameter', 'bad param'

  before -> client.usePort server.address().port
  after  -> server.close()

  it "has an index with three resources", (done) ->
    client.GET '/', (res, resources) ->
      assert.equal res.statusCode, 200, res.headers
      assert.equal resources.length, 3
      assert 'discoverableResource' in (r.shortName for r in resources)
      done()
    

  it "will return 404 if no resource matches", (done) ->
    client.GET "/the-nonexistant-resource", (res) ->
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

