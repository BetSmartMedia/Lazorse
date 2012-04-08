lazorse = require('../')
client = require('./client')
assert = require 'assert'

describe "Passing a string to @before", ->
  server = lazorse ->
    @_stack.shift() # drop logger
    @port = 0
    @before @findResource, 'static', "#{__dirname}/static"

  before -> client.usePort server.address().port
  after  -> server.close()

  it 'uses connect middleware', (done) ->
    client.GET '/data.json', (res) ->
      assert.equal res.statusCode, 200
      done()
