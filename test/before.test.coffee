###
Tests that the @before builder function inserts new middleware into the correct
position in the internal middleware stack
###

client = require('./client')
server = require('connect').createServer()
assert = require 'assert'

describe "An app with @before middleware", ->
  stack = ['findRoute', 'coerceParams', 'dispatchHandler', 'renderResponse']
  server = require('../lib/lazorse') ->
    @port = 0

    response_data = word: 'up'

    # Assert various attributes of the req/res state before each middleware
    extraAsserts =
      findRoute: (req, res) -> assert.ok not req.route
      coerceParams: (req, res) -> assert.ok req.route; assert.deepEqual req.vars, {}
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

    @route '/ok': GET: -> @ok response_data
  before -> client.usePort server.address().port
  after  -> server.close()

  it 'calls extra middleware at the right times', (done) ->
    client.GET "/ok", (res) ->
      assert.ok res.headers.cool
      assert.deepEqual res.headers.cool.split(','), stack
      done()
