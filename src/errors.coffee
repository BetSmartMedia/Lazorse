exports.types = {}
exports.types.Redirect = class Redirect
  constructor: (@location, @code=302, @message) ->
    @message ?= "Redirecting to #{@location}"

exports.handlers =
  Redirect: (err, req, res, next) ->
    res.setHeader 'Location', err.location
    res.statusCode = err.code
    res.end err.message

exports.types.NoResponseData = ->
  @message = "Response data is undefined"
  @code = 500
  Error.captureStackTrace @, exports.types.NoResponseData

exports.types.InvalidParameter = (type, thing) ->
  @message = "Bad Request: invalid #{type} #{thing}"
  @code = 422
  Error.captureStackTrace @, exports.types.InvalidParameter

exports.types.NotFound = (type, value) ->
  @code = 404
  if type? and value?
    @message = "#{type} '#{value}' not found"
  else if type?
    @message = "#{type} not found"
  else
    @message = "Not found"
  Error.captureStackTrace @, exports.types.NotFound
