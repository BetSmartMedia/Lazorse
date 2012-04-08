lazorse = require '../'
client = require('./client')
assert = require('assert')

errors = require '../lib/errors'

server = lazorse ->
  @_stack.shift() # drop logger
  @port = 0
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
