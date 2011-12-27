# Lazorse: lazy resources, lazers, and horses.

METHODS = ['DELETE', 'GET', 'HEAD', 'PATCH', 'POST', 'PUT']

require './uri-template-matchpatch'
errors = require './errors'
parser = require 'uri-template'
# Used for loading example request JSON files
{readFileSync} = require 'fs'

###
The main export is a function that constructs a ``LazyApp`` instance and
starts it listening on the port defined by the apps ``port`` property (default
is 3000)
###
module.exports = exports = (builder) ->
  app = new LazyApp builder
  connect = require 'connect'
  server = connect.createServer()
  server.use connect.favicon()
  server.use connect.logger()
  server.use connect.bodyParser()
  server.use app
  server.use connect.errorHandler()
  server.listen app.port

###
The module also exports a function that constructs an app without starting a
server
###
exports.app = (builder) -> new LazyApp builder

###
The main application class, groups together five connect middleware:
  
  - :meth:`lazorse::LazyApp.router`: Finds the handler function for a request.
  - :meth:`lazorse::LazyApp.coerceAll`: Validates/translates incoming URI
                                        parameters into objects.
  - :meth:`lazorse::LazyApp.dispatch`: Calls the handler function found by the
                                       router.
  - :meth:`lazorse::LazyApp.renderer`: Writes data back to the client.
  - :meth:`lazorse::LazyApp.errorHandler`: Handles known error types.

Each of these methods is bound to the ``LazyApp`` instance, so they can be used
as standalone middleware without needing to wrap them in another callback.
###
class LazyApp
  ###
  The constructor takes a `builder` function as it's sole argument. This
  function will be called in the context of the app object `before` the default
  index and examples routes are created. The builder can change the location of
  these routes by setting ``@indexPath`` and ``@examplePath``, or disable them
  by setting the path to ``false``.
  ###
  constructor: (builder) ->
    app = @ # Needed by some of the callbacks defined here

    # Defaults
    @port = 3000
    @renderer[type] = func for type, func of require './render'
    @errors = {}
    @errors[name] = err for name, err of errors.types
    @errorHandler[name] = handler for name, handler of errors.handlers
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
        else if @app.errors[name]?
          @next new @app.errors[name](args...)
        else
          @next name

    # Internal state
    @routeIndex = {}
    @coercions = {}
    @routeTable = {}
    @routeTable[method] = [] for method in METHODS

    @_prefix = ''

    # Call the builder before installing default routes so it can override
    # the index and examples path.
    builder.call @ if 'function' == typeof builder

    indexPath = @indexPath ? '/'
    examplePath = @examplePath ? '/examples'

    defaultRoutes = {}
    if indexPath
      defaultRoutes['/'] =
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

    if examplePath
      defaultRoutes[examplePath+'/{shortName}'] =
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

  ###
  Register one or more routes. The ``specs`` object should map URI templates to
  an object describing the route. For example::

      @route '/{category}/{thing}':
        shortName: "nameForClientsAndDocumentation"
        description: "a longer description"
        GET: -> ...
        POST: -> ...
        PUT: -> ...
        examples: [
          {method: 'GET', vars: {category: 'cats', thing: 'jellybean'}}
        ]
  ###
  route: (specs) ->
    for template, spec of specs
      if spec.shortName and @routeIndex[spec.shortName]?
        throw new Error "Duplicate short name '#{spec.shortName}'"

      @_register template, spec

  _register: (template, spec) ->
    spec.template = parser.parse @_prefix + template
    @routeIndex[spec.shortName] = spec if spec.shortName
    for method in METHODS when handler = spec[method]
      @routeTable[method].push spec

  ###
  Register one or more helper functions. The ``helpers`` parameter should be an
  object that maps helper names to callback functions.
  
  The helpers will be made available in the context used be coercions and
  request handlers (see :meth:`lazorse::LazyApp.buildContext`). So if you
  register a helper named 'fryEgg' it will be available as ``@fryEgg``.
  ###
  helper: (helpers) ->
    for name, helper of helpers
      @helpers[name] = helper

  ###
  Register one or more template parameter coercions with the app. The coercions
  parameter should be an object that maps parameter names to coercion functions.
  
  See :rst:ref:`coercions` in the guide for an example.
  ###
  coerce: (coercions) ->
    for name, cb of coercions
      throw new Error "Duplicate coercion name: #{name}" if @coercions[name]?  @coercions[name] = cb

  ###
  Register an error type with the app. The callback wlll be called by
  ``@errorHandler`` when an error of this type is encountered.
  
  Additionally, errors of this type will be available to the @error helper in
  handler/coercion callback by it's stringified name.
  
  See :rst:ref:`named errors <named-errors>` in the guide for an example.
  ###
  error: (errType, cb) ->
    errName = errType.name
    @errors[errName] = errType
    @errorHandler[errName] = cb
  
  ###
  Call ``mod.include`` in the context of the app. The (optional) ``path``
  parameter will be prefixed to all routes defined by the include.
  ###
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
  Find the first matching route template for the request, and assign it to
  ``req.route``
  
  `Connect middleware, remains bound to the app object.`
  ###
  router: (req, res, next) =>
    try
      i = 0
      routes = @routeTable[req.method]
      nextHandler = (err) =>
        return next err if err? and err != 'route'
        r = routes[i++]
        return next(new @errors.NotFound 'route', req.url) unless r?
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
  
  `Connect middleware, remains bound to the app object.`
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

  `Connect middleware, remains bound to the app object.`
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

  `Connect middleware, remains bound to the app object.`
  ###
  renderer: (req, res, next) =>
    return next new @errors.NotFound if not req.route
    return next new @errors.NoResponseData if not res.data
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

  `Connect middleware, remains bound to the app object.`
  ###
  errorHandler: (err, req, res, next) =>
    errName = err.constructor.name
    if @errorHandler[errName]?
      @errorHandler[errName](err, req, res, next)
    else if @passErrors and not (err.code and err.message)
      next err, req, res, next
    else
      res.statusCode = err.code or 500
      message = 'string' == typeof err and err or err.message or "Internal error"
      res.data = error: message
      # @renderer will re-error if req.route isn't set (e.g. no route matched)
      req.route ?= true
      @renderer req, res, next

  ###
  .. include:: handler_context.rst
  ###
  buildContext: (req, res, next) ->
    ctx = {req, res, next}
    for n, h of @helpers
      ctx[n] = if 'function' == typeof h then h.bind vars else h
    ctx.app = @
    vars = req.vars
    vars.__proto__ = ctx
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
