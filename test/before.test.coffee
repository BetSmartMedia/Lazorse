###
Tests that the @before builder function inserts new middleware into the correct
position in the internal middleware stack
###

client = require './client'
lazorse = require '../'
assert = require 'assert'

describe "An app with @before middleware", ->
  stack = ['findResource', 'coerceParams', 'dispatchHandler', 'renderResponse']

  server = lazorse.server port: 0, host: '127.0.0.1', ->
    response_data = word: 'up'

    # Assert various attributes of the req/res state before each middleware
    extraAsserts =
      findResource: (req, res) -> assert.ok not req.resource
      coerceParams: (req, res) -> assert.ok req.resource; assert.deepEqual req.vars, {}
      renderResponse: (req, res) -> assert.equal res.data, response_data

    for mw, i in stack then do (i, mw) =>
      @before @[mw], (req, res, next) ->
        if i > 0
          assert.equal stack[i-1], req.lastLayer
        extraAsserts[mw]?(req, res)
        res.allLayers ?= []
        res.allLayers.push mw
        req.lastLayer = mw
        next()

    @before @renderResponse, (req, res, next) ->
      res.setHeader 'cool', res.allLayers.join ','
      next()

    @resource '/ok': GET: -> @ok response_data

  before -> client.usePort server.address().port
  after  -> server.close()

  it 'calls extra middleware at the right times', (done) ->
    client.GET "/ok", (res) ->
      assert.ok res.headers.cool
      assert.deepEqual res.headers.cool.split(','), stack
      done()
