require '../lib/uri-template-matchpatch'
parser = require 'uri-template'

assert = require 'assert'

withTemplate = (tpl_string, tests) ->
  tpl = parser.parse tpl_string
  describe "compiled from #{tpl_string}", ->
    for url, expect of tests
      it "matches #{url} to #{JSON.stringify expect}", ->
        {vars} = tpl.match(url)
        if expect
          assert.deepEqual vars, expect
        else
          assert not vars

describe 'A URI template', ->
  withTemplate '/{first}/{second}',
    '/one/two':
      first: 'one'
      second: 'two'

    '//two': false

# Falsy values pass
    '/0/0':
      first: '0'
      second: '0'

  withTemplate '/{path}{?q1}',
    '/one?neat': false

    '/one?q1=named':
      path: 'one'
      q1: 'named'

    '/one':
      path: 'one'

  withTemplate '/{things*}',
    '/one,two,three':
      things: ['one', 'two', 'three']

  withTemplate '/{?things}'
    '/?things=one,two,three':
      things: ['one', 'two', 'three']
    '/?things=one':
      things: 'one'

  withTemplate '/part/{leftovers}'
    '/part/one/two/three': false

  withTemplate '/q{?params*}'
    '/q?a=ok&b=neat&c': {params: {a: 'ok', b: 'neat', c: true}}
    '/q?a=1&b=2': {params: {a: '1', b: '2'}}

  withTemplate '/{a(typeC)}'
    '/ok': {a: 'ok'}
