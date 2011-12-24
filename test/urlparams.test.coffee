client = require('./client')
server = require('connect').createServer()
assert = require('assert')

###
Each of these routes that will be added to the test server, with a handler that
returns the matched vars. 

Then each path below the route is requested and the client asserts that what was
matched what we expected.
###
testRoutes =
  '/simple/{param}': {
    '/simple/blah': {param: 'blah'}
  }
  '/simpleList/{things*}': {
    '/simpleList/one,two,three': {things: ['one', 'two', 'three']}
    '/simpleList/just-one': {things: ['just-one']}
  }
  "/path{/scope,action,id}": {
    '/path/cats/manage/petra': {scope: 'cats', action: 'manage', id: 'petra'}
  }
  "/suffixed/{param}.suffix": {
    '/suffixed/value.suffix': {param: 'value'}
  }
  "/qsExplode{?params*}": {
    '/qsExplode?a=ok&b=neat': {params: {a: 'ok', b: 'neat'}}
    '/qsExplode?a=ok&b=neat&c': {params: {a: 'ok', b: 'neat', c: true}}
  }
  "/qs{?param}": {
    '/qs?param=blarg': {param: 'blarg'}
    '/qs?param=one,two,three': {param: 'one,two,three'}
  }

# The handler to be used by all routes above
echo = -> @ok @req.vars

server.use require('../lib/lazorse').app ->
  routes = {}
  routes[tpl] = {GET: echo} for tpl of testRoutes
  @route routes

describe "With URL parameters", ->
  before (start) ->
    server.listen 0, 'localhost', ->
      client.usePort server.address().port
      start()

  after -> server.close()

  for _, exp of testRoutes
    do (exp) ->
      for path, vars of exp
        do (path, vars) ->
          it "GET #{path}", (done) ->
            client.GET path, (res, data) ->
              assert.equal res.statusCode, 200
              assert.deepEqual vars, data
              done()
