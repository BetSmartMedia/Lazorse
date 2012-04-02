client = require('./client')
server = require('connect').createServer()
assert = require('assert')

errors = require '../lib/errors'

server.use require('../lib/lazorse').app ->
  @resource '/frob/{foozle}/{whatsit}':
    GET: -> @error "teapot"
    shortName: "frob"
    examples: [
      {
        method: 'GET'
        vars: {foozle: 'hem', whatsit: 'haw'}
      }
      {
        method: 'GET'
        vars: {foozle: 'ni', whatsit: 'cate'}
        body: {
          thing: 'is'
        }
      }
    ]


describe "An app with examples", ->
  before (start) ->
    server.listen 0, 'localhost', ->
      client.usePort server.address().port
      start()

  after -> server.close()

  it 'has a link to /frob/examples in the index', (done) ->
    client.GET '/', (res, resources) ->
      assert.equal res.statusCode, 200
      assert.equal resources[0].examples, '/examples/frob'
      done()

  it 'returns expanded paths in the examples', (done) ->
    client.GET '/examples/frob', (res, examples) ->
      assert.deepEqual examples, [
        {method: 'GET', path: '/frob/hem/haw'}
        {method: 'GET', path: '/frob/ni/cate', body: {thing: 'is'}}
      ]
      done()
