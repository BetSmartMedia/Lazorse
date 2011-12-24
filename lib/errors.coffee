exports.types = {}
exports.types.Redirect = (@location, @code=301, @message) ->
  @message ?= "Redirecting to #{@location}"
  Error.captureStackTrace @, exports.types.Redirect

exports.handlers =
  Redirect: (err, req, res, next) ->
    res.statusCode = err.code
    res.setHeader 'Location', err.location
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
