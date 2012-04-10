lazorse = require '../'
client = require('./client')
assert = require('assert')

describe "An app with examples", ->
  server = lazorse.server port: 0, host: '127.0.0.1', ->
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

  before -> client.usePort server.address().port
  after -> server.close()

  it 'has a link to /frob/examples in the index', (done) ->
    client.GET '/', (res, resources) ->
      assert.equal res.statusCode, 200
      resource = null
      resources.some (r) -> r.shortName is 'frob' and resource = r
      assert.equal resource?.examples, '/examples/frob'
      done()

  it 'returns expanded paths in the examples', (done) ->
    client.GET '/examples/frob', (res, examples) ->
      assert.deepEqual examples, [
        {method: 'GET', path: '/frob/hem/haw'}
        {method: 'GET', path: '/frob/ni/cate', body: {thing: 'is'}}
      ]
      done()
