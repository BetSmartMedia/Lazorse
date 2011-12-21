# Lazorse: lazy resources, lazers, and horses.

METHODS = ['DELETE', 'GET', 'HEAD', 'PATCH', 'POST', 'PUT']

require './uri-template-matchpatch'
parser = require 'uri-template'
# Used for loading example request JSON files
{readFileSync} = require 'fs'

errors = require './errors'

class LazyApp
  constructor: (init, builder) ->
    if 'function' == typeof init
      builder = init
      init = {}

    app = @

    @passErrors = false
    @renderer = contentTypeRenderer
    @helpers =
      ok: (data) ->
        @res.statusCode = 200
        @res.data = data
        @next()
      data: (err, data) -> return @next err if err?; @ok data
      link: (name, ctx) -> app.routeIndex[name].template.expand(ctx or @)
      error: (name, args...) ->
        if 'function' == typeof name
          @next new name args...
        else
          @next new errors[name](args...)

    @routeIndex = {}
    @schemas = {}
    @coercions = {}
    @routeTable = {}

    for method in METHODS
      @routeTable[method] = []

    @_prefix = ''

    # Set up the default index route
    indexPath = init.indexPath or '/'
    defaultRoutes = {}
    defaultRoutes[indexPath] =
      description: "Index of all routes"
      GET: ->
        specs = for shortName, route of app.routeIndex
          {template, shortName, description, examples} = route
          methods = (k for k of route when k in METHODS)
          template = String template
          spec = {template, shortName, description, methods}
          spec.examples = examples if examples?
          spec
        specs.sort (a, b) ->
          [a, b] = [a, b].map (s) -> s.template
          return 0 if a == b
          if a < b then -1 else 1
        @ok specs

    @route defaultRoutes

    builder.call @ if 'function' == typeof builder
    @loadExamples init.examples

  loadExamples: (examples) ->
    if not examples? then return
    if 'string' == typeof examples
      try
        examples = JSON.parse readFileSync examples
      catch e
        console.warn "Failed to load examples from #{examples}"
    for shortName, exs of examples
      @routeIndex[shortName]?.examples = exs

  route: (specs) ->
    for template, spec of specs
      if spec.shortName and @routeIndex[spec.shortName]?
        throw new Error "Duplicate short name '#{spec.shortName}'"

      @register template, spec

  register: (template, spec) ->
    spec.template = parser.parse @_prefix + template
    @routeIndex[spec.shortName] = spec if spec.shortName
    for method in METHODS when handler = spec[method]
      @routeTable[method].push spec

  helper: (helpers) ->
    for name, helper of helpers
      @helpers[name] = helper

  schema: (specs) ->
    for name, spec of specs
      @schemas[name] = spec

  # Register a coercion with the app
  coerce: (coercions) ->
    for name, cb of coercions
      throw new Error "Duplicate coercion name: #{name}" if @coercions[name]?
      @coercions[name] = cb

  # Stealing yet another idea from zappa
  include: (path, mod) ->
    if typeof path.include == 'function'
      mod = path
      path = ''
    if typeof mod.include != 'function'
      throw new Error "#{mod} does not have a .include method"
    restorePrefix = @_prefix
    @_prefix = path
    mod.include.call @
    @_prefix = restorePrefix

# Finds a matching route, then attaches it and the matched URI vars to the request
  router: (req, res, next) =>
    try
      i = 0
      routes = @routeTable[req.method]
      nextHandler = (err) ->
        return next err if err? and err != 'route'
        r = routes[i++]
        return next() unless r?
        vars = r.template.match req.url
        return nextHandler() unless vars
        req.route = r
        req.vars = vars
        next()
      nextHandler()
    catch err
      next err

# Run any registered coercion callbackes against matched template parameters
  coerceAll: (req, res, next) =>
    return next() unless req.vars
    ctx = @buildContext req, res, next
    varNames = (k for k in Object.keys req.vars when @coercions[k]?)
    return next() unless varNames.length
    varNames.sort (a, b) -> req.url.indexOf(a) - req.url.indexOf(b)
    i = 0
    nextCoercion = =>
      name = varNames[i++]
      return next() unless name?
      coercion = @coercions[name]
      coercion.call ctx, req.vars[name], (e, newValue) ->
        return next e if e?
        #if e == 'drop' then delete req.vars[name] else
        req.vars[name] = newValue
        nextCoercion()
    nextCoercion()


# Call the route handler
  dispatch: (req, res, next) =>
    return next() unless req.route?
    ctx = @buildContext req, res, next
    # the route handler should call next()
    req.route[req.method].call ctx, ctx

# Catch any Lazorse specific errors and return an appropriate response
  errorHandler: (err, req, res, next) =>
    sendError = (code, errData) ->
      res.statusCode = code
      res.end JSON.stringify errData
    switch err.constructor
      when errors.Redirect
        res.setHeader 'Location', err.location
        sendError err.code, err.message
      when errors.NotFound, errors.InvalidParameter, errors.NoResponseData
        sendError err.code, error: err.message, more: err.more
      when SyntaxError
        sendError 400, error: "Malformed JSON"
      else
        if @passErrors
          next err
        else
          res.statusCode = 500
          if typeof err is 'string'
            console.error "Generic Error:", err
            sendError 500, error: err
          else
            console.error "Error:", err.stack
            sendError 500, error: "Internal error"

# Build a 'this' context for middleware handlers (dispatch and coerceAll)
# The context is made up of 2 objects in a delegation chain:
#
#   1. An object containing URI Template variables, which delegates to:
#   2. Request context, contains:
#      - `app`: The lazorse app
#      - `req`: The request object from node (via connect)
#      - `res`: The response object from node (via connect)
#      - `errors`: An object containing Error constructors
#      - `next`: The next callback from connect
#
# Because this is a delegation chain, you need to be careful not to mask out helper
# names with variable names.
  buildContext: (req, res, next) ->
    ctx = {req, res, next}
    ctx.app = @
    vars = req.vars
    vars.__proto__ = ctx
    ctx.errors = errors
    for n, h of @helpers
      ctx[n] = if 'function' == typeof h then h.bind vars else h
    vars


# Extend a connect server with the default middleware stack from this app
  extend: (server) ->
    for mw in [@router, @coerceAll, @dispatch, @renderer, @errorHandler]
      server.use mw

# Or act as a single connect middleware
  handle: (req, res, goodbyeLazorse) ->
    stack = [@router, @coerceAll, @dispatch, @renderer]
    nextMiddleware = =>
      mw = stack.shift()
      return goodbyeLazorse() unless mw?
      mw req, res, (err) =>
        return @errorHandler err if err?
        nextMiddleware()
    nextMiddleware()

# The renderer middleware
contentTypeRenderer = (req, res, next) ->
  return next new errors.NotFound if not req.route
  return next new errors.NoResponseData if not res.data
  render = require './render'
  if req.headers.accept and [types, _] = req.headers.accept.split ';'
    for type in types.split ','
      if render[type]?
        res.setHeader 'Content-Type', type
        return render[type] req, res, next
  res.setHeader 'Content-Type', 'application/json'
  return render['application/json'] req, res, next

module.exports = lazy = (args...) ->
  app = new LazyApp args...
  connect = require 'connect'
  server = connect.createServer()
  server.use connect.favicon()
  server.use connect.logger()
  server.use connect.bodyParser()
  server.use app
  server.use connect.errorHandler()
  server.listen app.port or 3000

lazy.app = (args...) -> new LazyApp args...

# Export the exception types
lazy.errors = errors

# Export the renderers
lazy.render = require './render'

# vim: set et:
