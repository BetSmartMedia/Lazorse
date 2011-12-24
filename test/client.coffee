http = require 'http'

port = 0
exports.usePort =  (newport) -> port = newport

exports.METHODS = ['GET', 'POST', 'DELETE', 'PUT', 'HEAD']
for method in exports.METHODS
  do (method) ->
    exports[method] = (path, opts={}, cb) ->
      if not cb then cb = opts
      accept='application/json'
      req = {method, host: 'localhost', port, path, headers: {accept}}
      req.headers[k] = v for k, v of opts.headers if opts.headers
      rawBody = ""
      req = http.request req, (res) ->
        res.on 'data', (chnk) -> rawBody += chnk
        res.on 'end', ->
          cb res, JSON.parse(rawBody or null)
      if body = opts.body
        if 'string' != typeof body
          body = JSON.stringify body
      req.end body
