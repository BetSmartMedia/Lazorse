exports.Redirect = (@location, @code=301, @message) ->
  @message ?= "Redirecting to #{@location}"
  Error.captureStackTrace @, exports.Redirect

exports.NoResponseData = ->
  @message = "Response data is undefined"
  @code = 500
  Error.captureStackTrace @, exports.NoResponseData

exports.InvalidParameter = (type, thing) ->
  @message = "Bad Request: invalid #{type} #{thing}"
  @code = 422
  Error.captureStackTrace @, exports.InvalidParameter

exports.NotFound = (type, value) ->
  @code = 404
  if type? and value?
    @message = "#{type} '#{value}' not found"
  else if type?
    @message = "#{type} not found"
  else
    @message = "Not found"
  Error.captureStackTrace @, exports.NotFound
