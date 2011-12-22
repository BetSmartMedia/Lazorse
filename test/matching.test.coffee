vows = require 'vows'
require '../lib/uri-template-matchpatch'
parser = require 'uri-template'

assert = require 'assert'

withTemplate = (tpl_string, tests) ->
  tpl = parser.parse tpl_string
  describe "With template #{tpl_string}", ->
    for url, result of tests
      it "check input #{url}", ->
        vars = tpl.match(url)
        assert.deepEqual vars, result
        if vars
          assert.equal tpl.expand(vars), url

suite = vows.describe 'URI Template Matching'

withTemplate '/{first}/{second}',
  '/one/two':
    first: 'one'
    second: 'two'

  '//two': false

  '/0/0':
    first: '0'
    second: '0'

withTemplate '/{path}{?q1}',
  '/one?neat': false

  '/one?q1=named':
    path: 'one'
    q1: ['named']

  '/one':
    path: 'one'

withTemplate '/{things*}',
  '/one,two,three':
    things: ['one', 'two', 'three']

withTemplate '/{?things}'
  '/?things=one,two,three':
    things: ['one', 'two', 'three']
  '/?things=one':
    things: ['one']

withTemplate '/part/{leftovers}'
  '/part/one/two/three': false

