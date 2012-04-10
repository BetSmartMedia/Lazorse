lazorse = require('../')
client = require('./client')
assert = require 'assert'

describe "Passing a string to @before", ->
  server = lazorse.server port: 0, host: '127.0.0.1', ->
    @before @findResource, 'static', "#{__dirname}/static"

  before -> client.usePort server.address().port
  after  -> server.close()

  it 'uses connect middleware', (done) ->
    client.GET '/data.json', (res, body) ->
      assert.equal res.statusCode, 200
      fs = require 'fs'
      expected = JSON.parse fs.readFileSync "#{__dirname}/static/data.json"
      assert.deepEqual expected, body
      done()
