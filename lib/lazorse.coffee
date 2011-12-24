# Lazorse: lazy resources, lazers, and horses.

METHODS = ['DELETE', 'GET', 'HEAD', 'PATCH', 'POST', 'PUT']

require './uri-template-matchpatch'
parser = require 'uri-template'
# Used for loading example request JSON files
{readFileSync} = require 'fs'

###
The function exported by the module creates a ``LazyApp`` instance with it's
arguments and a default connect server, then listens on app.port (3000 by default)
###
module.exports = exports = ->
  app = new LazyApp arguments...
  connect = require 'connect'
  server = connect.createServer()
  server.use connect.favicon()
  server.use connect.logger()
  server.use connect.bodyParser()
  server.use app
  server.use connect.errorHandler()
  server.listen app.port

# Export a function to allow creating apps without starting a server
exports.app = -> new LazyApp arguments...

# Re-export the exception types and renderer registry for extension
exports.errors = errors = 

###
The main application class, contains and manages five connect middleware:
  
  - ``@router``: Finds the handler function for a request.
  - ``@coerceAll``: Validates/translates incoming URI parameters into objects.
  - ``@dispatch``: Calls the handler function found by the router.
  - ``@renderer``: Writes data back to the client.
  - ``@errorHandler``: Handles known error types.

Each of these middleware can be ``use``d individually, or the app itself can act
as a single connect middleware.

For modifying the configuration of the first two middleware, the app object has
the functions ``@route`` and ``@coerce`` that allow you to register
new callbacks at each of these stages. Additionally, it maintains a set of hl

template, in the case of ``@route``) and the values the object or function to be
registered.
###
class LazyApp
  constructor: (builder) ->
    app = @ # Needed by some of the callback defined here

    # Defaults
    @port = 3000
    @renderer[type] = func for type, func of require './render'
    @errors = {}
    @errors[name] = err for name, err of require './errors'
    @passErrors = false
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

    # Internal state
    @routeIndex = {}
    @coercions = {}
    @routeTable = {}
    @routeTable[method] = [] for method in METHODS

    @_prefix = ''

    # Set up the default index route
    indexPath = init.indexPath or '/'
    defaultRoutes = {}
    defaultRoutes[indexPath] =
      description: "Index of all routes"
      GET: ->
        specs = for shortName, route of app.routeIndex
          {template, shortName, description} = route
          methods = (k for k of route when k in METHODS)
          template = String template
          spec = {shortName, description, methods, template}
          spec.examples = "/examples/#{shortName}" if route.examples
          spec
        specs.sort (a, b) ->
          [a, b] = (s.template for s in [a, b])
          return 0 if a == b
          if a < b then -1 else 1
        @ok specs

    defaultRoutes['/examples/{shortName}'] =
      description: "Get example requests for a route"
      GET: ->
        unless (route = app.routeIndex[@shortName]) and route.examples
          return @error errors.NotFound, 'examples', @shortName
        needsResponse = []
        examples = for example in route.examples
          ex = method: example.method, path: @link @shortName, example.vars
          ex.body = example.body if example.body?
          ex
        @ok examples

    @route defaultRoutes

    builder.call @ if 'function' == typeof builder

  ###
  Register one or more routes. The ``specs`` object should map URI templates to
  an object describing the route. For example::

      @route '/{category}/{thing}':
        shortName: "nameForClientsAndDocumentation"
        description: "a longer description"
        examples: [
          {method: 'GET', vars: {category: 'cats', thing: 'jellybean'}}
        ]
  ###
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

  ###
  Register one or more helper functions. The ``helpers`` parameter should be an
  object that maps helper names to callback functions.
  
  The helpers will be made available in the context used be coercions and
  request handlers (see ``buildContext``). So if you register a helper named
  'fryEgg' it will be available as ``@fryEgg``.
  ###
  helper: (helpers) ->
    for name, helper of helpers
      @helpers[name] = helper

  ###
  Register one or more coercions with the app. The coercions parameter should be
  an object that maps parameter names to callback functions.
  
  The callbacks will be run in a special context (see ``buildContext``) when a
  parameter with the same name is matched by a URI template. They will be passed
  the string value from the URL and a continuation expecting (err, coercedValue)
  ###
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

  ###
  Find the first route template for the request, and assign it to ``req.route``
  
  This function is bound to the app and can be used as a separate middleware.
  ###
  router: (req, res, next) =>
    try
      i = 0
      routes = @routeTable[req.method]
      nextHandler = (err) ->
        return next err if err? and err != 'route'
        r = routes[i++]
        return next(new errors.NotFound 'route', req.url) unless r?
        vars = r.template.match req.url
        return nextHandler() unless vars
        req.route = r
        req.vars = vars
        next()
      nextHandler()
    catch err
      next err

  ###
  Walk through ``req.vars`` call any registered coercions that apply.
  
  This function is bound to the app and can be used as a separate middleware.
  ###
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


  ###
  Calls the handler function for the matched route if it exists.

  This function is bound to the app and can be used as a separate middleware.
  ###
  dispatch: (req, res, next) =>
    return next() unless req.route?
    ctx = @buildContext req, res, next
    # the route handler should call next()
    req.route[req.method].call ctx, ctx

  ###
  Renders the data in ``req.data`` to the client.
  
  Inspects the ``accept`` header and falls back to JSON if
  it can't find a type it knows how to render. To install or override the
  renderer for a given content/type add it to

      @renderer['text/html'] = (req, res, next) ->
        # do stuff ...
        res.end()

  This function is bound to the app and can be used as a separate middleware.
  ###
  renderer: (req, res, next) =>
    return next new errors.NotFound if not req.route
    return next new errors.NoResponseData if not res.data
    if req.headers.accept and [types, _] = req.headers.accept.split ';'
      for type in types.split ','
        if @renderer[type]?
          res.setHeader 'Content-Type', type
          return @renderer[type] req, res, next
    # Fall back to JSON
    res.setHeader 'Content-Type', 'application/json'
    @renderer['application/json'] req, res, next
 
  ###
  Intercept known errors types and return an appropriate response. If
  ``@passErrors`` is set to false (the default) any unknown error will send
  a generic 500 error.

  This function is bound to the app and can be used as a separate middleware.
  ###
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
          statusCode = err.code or 500
          if typeof err is 'string'
            sendError statusCode, error: err
          else
            sendError statusCode, error: "Internal error"

  ###
  Used internally to build the context that coercions, request handlers, and
  helpers run in. The context is made up of 2 objects in a delegation chain:

      1. An object containing URI Template variables, which delegates to:
      2. Request context, contains:

         * ``app``: The lazorse app
         * ``req``: The request object from node (via connect)
         * ``res``: The response object from node (via connect)
         * ``errors``: An object containing Error constructors
         * ``next``: The next callback from connect

  Because this is a delegation chain, you need to be careful not to mask out helper
  names with variable names.
  ###
  buildContext: (req, res, next) ->
    ctx = {req, res, next}
    ctx.app = @
    vars = req.vars
    vars.__proto__ = ctx
    ctx.errors = errors
    for n, h of @helpers
      ctx[n] = if 'function' == typeof h then h.bind vars else h
    vars


  ###
  Extend a connect server with the default middleware stack from this app
  ###
  extend: (server) ->
    for mw in [@router, @coerceAll, @dispatch, @renderer, @errorHandler]
      server.use mw

  ###
  Act as a single connect middleware
  ###
  handle: (req, res, goodbyeLazorse) ->
    stack = [@router, @coerceAll, @dispatch, @renderer]
    nextMiddleware = =>
      mw = stack.shift()
      return goodbyeLazorse() unless mw?
      mw req, res, (err) =>
        return @errorHandler err, req, res, goodbyeLazorse if err?
        nextMiddleware()
    nextMiddleware()

# vim: set et:
