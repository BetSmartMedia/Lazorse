vows = require 'vows'
require '../lib/uri-template-matchpatch'
parser = require 'uri-template'

assert = require 'assert'

withTemplate = (tpl_string, tests) ->
  tpl = parser.parse tpl_string
  ctx = {}
  ctx["Checking template #{tpl_string}"] = subctx = {}
  for url, result of tests
    msg = result.msg && " (#{result.msg})" || ""
    do (url, result) ->
      subctx["against #{url}#{msg}"] = ->
        vars = tpl.match(url)
        assert.deepEqual vars, result
        if vars
          assert.equal tpl.expand(vars), url
  return ctx

suite = vows.describe 'URI Template Matching'

suite.addBatch withTemplate '/{first}/{second}',
  '/one/two':
    first: 'one'
    second: 'two'

  '//two': false

  '/0/0':
    first: '0'
    second: '0'

suite.addBatch withTemplate '/{path}{?q1}'
  '/one?neat': false

  '/one?q1=named':
    path: 'one'
    q1: ['named']

  '/one':
    path: 'one'
    q1: []

suite.addBatch withTemplate '/{things*}'
  '/one,two,three':
    things: ['one', 'two', 'three']

suite.addBatch withTemplate '/{?things}'
  '/?things=one,two,three':
    things: ['one', 'two', 'three']
suite.export(module)
