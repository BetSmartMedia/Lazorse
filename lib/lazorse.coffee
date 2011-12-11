# Lazorse: lazy resources, lazers, and horses.

METHODS = ['DELETE', 'GET', 'HEAD', 'PATCH', 'POST', 'PUT']

require './uri-template-matchpatch'
parser = require 'uri-template'
# Used for loading example request JSON files
{readFileSync} = require 'fs'

class LazyApp
  constructor: (init, builder) ->
    if 'function' == typeof init
      builder = init
      init = {}

    app = @

    @passErrors = false

    @renderer = contentTypeRenderer

    @helpers =
      ok:   (data) ->
        @res.statusCode = 200
        @res.data = data
        @next()
      data: (err, data) -> @next err if err?; @ok data
      link: (name, ctx) -> app.routes[name].template.expand(ctx or @)
      error: (name, args...) -> @next new app.errors[name](args...)

    @routes = {}
    @schemas = {}
    @coercions = {}
    @routeTable = {}

    for method in METHODS
      @routeTable[method] = []

    @_prefix = ''

    # Set up the default index route
    indexPath = (init.indexPath? and init.indexPath) or '/'
    defaultRoutes = {}
    defaultRoutes[indexPath] =
      description: "Index of all routes"
      GET: ->
        specs = []
        for shortName, spec of app.routes
          specs.push
            template: String spec.template
            shortName: shortName
            description: spec.description
            examples: spec.examples
            prefix: spec.prefix
            methods: (k for k of spec when k in METHODS)
        specs.sort (a, b) ->
          [a, b] = [a, b].map (i) -> i.prefix + i.shortName
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
      @routes[shortName]?.examples = exs

  route: (specs) ->
    for template, spec of specs
      if spec.shortName and @routes[spec.shortName]?
        throw new Error "Duplicate path name '#{spec.shortName}'"

      @register template, spec

  register: (template, spec) ->
    spec.template = parser.parse @_prefix + template
    spec.prefix = @_prefix
    @routes[spec.shortName] = spec if spec.shortName
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

# The handler is responsible for setting up the environment in which your 
# request handlers will be called. The environment is made up of 3 objects in a 
# delegation chain:
# 
#   1. App helpers, as registered with @helper
#   2. Request context, contains `app`, `req`, `res`, and `next`
#   3. URI Template variables
#
# Because this is a delegation chain, you need to be careful not to mask out helper
# names with variable names.
  router: (req, res, next) =>
    # make sure req.vars is set, as coerceAll() expects it
    req.vars = {}
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
    ctx = @build_context req, res, next
    varNames = (k for k in Object.keys req.vars when @coercions[k]?)
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
    ctx = @build_context req, res, next
    # the route handler should call next()
    req.route[req.method].call ctx, ctx

# Catch any Lazorse specific errors and return an appropriate response
  errorHandler: (err, req, res, next) =>
    sendError = (code, errData) ->
      res.statusCode = code
      res.end JSON.stringify errData
    switch err.constructor
      when Redirect
        res.setHeader 'Location', err.location
        sendError err.code, err.message
      when NotFound, InvalidParameter, NoResponseData
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

  errors:
    NoResponseData: ->
      @message = "Response data is undefined"
      @code = 500
      Error.captureStackTrace @

    InvalidParameter: (type, thing) ->
      @message = "Bad Request: invalid #{type} #{thing}"
      @code = 422
      Error.captureStackTrace @

    NotFound: (type, value) ->
      @code = 404
      if value?
        @message = "#{type} '#{value}' not found"
      else
        @message = "#{type} not found"
      Error.captureStackTrace @, NotFound

# Build a 'this' context for middleware handlers
# that call functions (dispatch, coerceAll)
  build_context: (req, res, next) ->
    ctx = app: @, req: req, res: res, next: next
    ctx.__proto__ = @helpers
    vars = req.vars
    vars.__proto__ = ctx
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
  if not res.data and not req.route
    return next new NoResponseData
  if not req.route
    return next()
  render = require './render'
  if req.headers.accept and [types, _] = req.headers.accept.split ';'
    for type in types.split ','
      if render[type]?
        return render[type] req, res, next
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
for name, ctor of LazyApp.errors
  lazy[name] = ctor
# vim: set et:
