lazorse = require '../'
client = require('./client')
assert = require('assert')

describe "With URL parameters", ->
  ###
  Each of these resources that will be added to the test server, with a handler
  that returns the matched vars. 

  Then each path below the resource is requested and the client asserts that what
  was matched what we expected.
  ###
  testResources =
    '/simple/{param}':
      '/simple/blah': {param: 'blah'}

    '/simpleList/{things*}':
      '/simpleList/one,two,three': {things: ['one', 'two', 'three']}
      '/simpleList/just-one': {things: ['just-one']}

    "/path{/scope,action,id}":
      '/path/cats/manage/petra': {scope: 'cats', action: 'manage', id: 'petra'}

    "/suffixed/{param}.suffix":
      '/suffixed/value.suffix': {param: 'value'}

    "/qsExplode{?params*}":
      '/qsExplode?a=ok&b=neat': {params: {a: 'ok', b: 'neat'}}
      '/qsExplode?a=ok&b=neat&c': {params: {a: 'ok', b: 'neat', c: true}}

    "/qs{?param}":
      '/qs?param=blarg': {param: 'blarg'}
      '/qs?param=one,two,three': {param: 'one,two,three'}


  server = lazorse.server port: 0, host: '127.0.0.1', ->
    # The handler to be used by all resources above
    echo = -> @ok @req.vars
    resources = {}
    resources[tpl] = {GET: echo} for tpl of testResources
    @resource resources

  before -> client.usePort server.address().port
  after -> server.close()

  for _, exp of testResources then do (exp) ->
    for path, vars of exp
      do (path, vars) ->
        it "GET #{path}", (done) ->
          client.GET path, (res, data) ->
            assert.equal res.statusCode, 200
            assert.deepEqual vars, data
            done()
