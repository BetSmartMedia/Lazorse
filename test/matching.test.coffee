vows = require 'vows'
require '../lib/uri-template-matchpatch'
parser = require 'uri-template'

assert = require 'assert'

withTemplate = (tpl_string, tests) ->
  tpl = parser.parse tpl_string
  ctx = {}
  ctx["Checking template #{tpl_string}"] = subctx = {}
  for url, result of tests
    do (url, result) ->
      subctx["against #{url}"] = -> assert.deepEqual tpl.match(url), result
  return ctx

suite = vows.describe 'URI Template Matching'

suite.addBatch withTemplate '/{first}/{second}',
  '/one/two':
    first: 'one'
    second: 'two'

  '//two': false

suite.export(module)
