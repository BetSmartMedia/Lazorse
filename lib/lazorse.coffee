# Lazorse: lazy resources, lasers, and horses.

METHODS = ['DELETE', 'GET', 'HEAD', 'PATCH', 'POST', 'PUT', 'OPTIONS']

require './uri-template-matchpatch'
errors = require './errors'
parser = require 'uri-template'
connect = require 'connect'
# Used for loading example request JSON files
{readFileSync} = require 'fs'

###
The main export is a function that constructs a ``LazyApp`` instance and
starts it listening on the port defined by the apps ``port`` property (default
is 3000)
###
module.exports = exports = (builder) ->
  app = new LazyApp builder
  server = connect.createServer()
  server.use connect.favicon()
  server.use connect.logger()
  server.use connect.bodyParser()
  server.use app
  server.listen app.port
  server

###
The module also exports a function that constructs an app without starting a
server
###
exports.app = (builder) -> new LazyApp builder

###
The main application class groups together five connect middleware:

  :meth:`lazorse::LazyApp.findResource`
    Finds the handler function for a request.

  :meth:`lazorse::LazyApp.coerceParams`
    Validates/translates incoming URI parameters into objects.

  :meth:`lazorse::LazyApp.dispatchHandler`
    Calls the handler function found by the router.

  :meth:`lazorse::LazyApp.renderResponse`
    Writes data back to the client.

  :meth:`lazorse::LazyApp.handleErrors`
    Handles known error types.

Each of these methods is bound to the ``LazyApp`` instance, so they can be used
as standalone middleware without needing to wrap them in another callback.
###
class LazyApp
  ###
  The constructor takes a `builder` function as it's sole argument. This
  function will be called in the context of the app object `before` the default
  index and examples resources are created. The builder can change the location
  of these resources by setting ``@indexPath`` and ``@examplePath``, or disable
  them by setting the path to ``false``.
  ###
  constructor: (builder) ->
    app = @ # Needed by some of the callbacks defined here

    # Defaults
    @port = 3000
    @renderers = {}
    @renderers[type] = func for type, func of require './render'

    @errors = {}
    @errorHandlers = {}
    @errors[name] = err for name, err of errors.types
    @errorHandlers[name] = handler for name, handler of errors.handlers

    # handleErrors must be manually rebound to preserve it's arity.
    # Furthermore, the Function.bind in node ~0.4.12 doesn't preserve arity
    _handleErrors = @handleErrors
    @handleErrors = (err, req, res, next) -> _handleErrors.call app, err, req, res, next

    @passErrors = false
    @helpers =
      ok: (data) ->
        @res.statusCode = 200
        @res.data = data
        @next()
      data: (err, data) -> return @next err if err?; @ok data
      link: (name, ctx) -> app.resourceIndex[name].template.expand(ctx or @)
      error: (name, args...) ->
        if 'function' == typeof name
          @next new name args...
        else if @app.errors[name]?
          @next new @app.errors[name](args...)
        else
          @next name

    # Internal state
    @resourceIndex = {}
    @coercions = {}
    @coercionDescriptions = {}
    @routeTable = {}
    @routeTable[method] = [] for method in METHODS

    @_prefix = ''
    @_stack = [@findResource, @coerceParams, @dispatchHandler, @renderResponse]

    # Call the builder before installing default resources so it can override
    # the index and examples path.
    builder.call @ if 'function' is typeof builder

    indexPath     = @indexPath     ? '/'
    examplePath   = @examplePath   ? '/examples'
    parameterPath = @parameterPath ? '/parameters'

    defaultResources = {}
    if indexPath
      defaultResources['/'] =
        description: "Index of all resources"
        GET: ->
          specs = for shortName, resource of app.resourceIndex
            {template, shortName, description} = resource
            methods = (k for k of resource when k in METHODS)
            template = String template
            spec = {shortName, description, methods, template}
            spec.examples = "/examples/#{shortName}" if resource.examples
            spec
          specs.sort (a, b) ->
            [a, b] = (s.template for s in [a, b])
            return 0 if a == b
            if a < b then -1 else 1
          @ok specs

    if examplePath
      defaultResources[examplePath+'/{shortName}'] =
        description: "Get example requests for a resource"
        GET: ->
          unless (resource = app.resourceIndex[@shortName]) and resource.examples
            return @error errors.NotFound, 'examples', @shortName
          examples = for example in resource.examples
            ex = method: example.method, path: @link @shortName, example.vars
            ex.body = example.body if example.body?
            ex
          @ok examples

    if parameterPath
      defaultResources[parameterPath+'/'] = GET: -> @ok app.coercionDescriptions
      defaultResources[parameterPath+'/{parameterName}'] =
        GET: ->
          unless (coercion = app.coercions[@parameterName])
            return @error errors.NotFound, 'parameters', @parameterName
          @ok app.coercionDescriptions[@parameterName]


    @resource defaultResources

  ###
  Register one or more resources. The ``specs`` object should map URI templates to
  an object describing the resource. For example::

      @resource '/{category}/{thing}':
        shortName: "nameForClientsAndDocumentation"
        description: "a longer description"
        GET: -> ...
        POST: -> ...
        PUT: -> ...
        examples: [
          {method: 'GET', vars: {category: 'cats', thing: 'jellybean'}}
        ]
  ###
  resource: (specs) ->
    for template, spec of specs
      if spec.shortName and @resourceIndex[spec.shortName]?
        throw new Error "Duplicate short name '#{spec.shortName}'"

      spec.template = parser.parse @_prefix + template
      @resourceIndex[spec.shortName] = spec if spec.shortName
      for method in METHODS when handler = spec[method]
        @routeTable[method].push spec

  ###
  Register one or more helper functions. The ``helpers`` parameter should be an
  object that maps helper names to callback functions.

  The helpers will be made available in the context used by coercions and
  request handlers (see :meth:`lazorse::LazyApp.buildContext`). So if you
  register a helper named 'fryEgg' it will be available as ``@fryEgg``.
  ###
  helper: (helpers) ->
    for name, helper of helpers
      @helpers[name] = helper

  ###
  Register a new template parameter coercion with the app. 

  :param name: The name of the template parameter to be coerced.
  :param description: A documentation string for the parameter name.
  :param coercion: a ``(value, next) -> next(err, coercedValue)`` function that
    will be called with ``this`` set to the request context. If not given, the
    value will be passed through unchanged (useful for documentation purposes).

  See :rst:ref:`coercions` in the guide for an example.
  ###
  coerce: (name, description, coercion) ->
    throw new Error "Duplicate coercion name: #{name}" if @coercions[name]?
    @coercionDescriptions[name] = description
    @coercions[name] = coercion or (v, n) -> n(null, v)

  ###
  Register an error type with the app. The callback wlll be called by
  ``@errorHandler`` when an error of this type is encountered.

  Note that this *requires* named functions, so in coffeescript this means
  using classes.

  Additionally, errors of this type will be available to the @error helper in
  handler/coercion callback by it's stringified name.

  See :rst:ref:`named errors <named-errors>` in the guide for an example.
  ###
  error: (errType, cb) ->
    errName = errType.name
    @errors[errName] = errType
    @errorHandlers[errName] = cb if cb?


  ###
  Register a new renderer function with the app. Can be supplied with two
  parameters: a content-type and renderer function, or an object mapping
  content-types to rendering functions.

  See :rst:ref:`Rendering` in the guide for an example of a custom renderer.
  ###
  render: (contentType, renderer) ->
    if typeof contentType is 'object'
      @renderers[ct] = r for ct, r of contentType
    else
      @renderers[contentType] = renderer

  ###
  Call ``mod.include`` in the context of the app. The (optional) ``path``
  parameter will be prefixed to all resources defined by the include.
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
  Find the first matching resource template for the request, and assign it to
  ``req.resource``

  `Connect middleware, remains bound to the app object.`
  ###
  findResource: (req, res, next) =>
    try
      i = 0
      resources = @routeTable[req.method]
      nextHandler = (err) =>
        return next err if err? and err != 'resource'
        r = resources[i++]
        return next(new @errors.NotFound 'resource', req.url) unless r?
        vars = r.template.match req.url
        return nextHandler() unless vars
        req.resource = r
        req.vars = vars
        next()
      nextHandler()
    catch err
      next err

  ###
  Walk through ``req.vars`` call any registered coercions that apply.

  `Connect middleware, remains bound to the app object.`
  ###
  coerceParams: (req, res, next) =>
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
  Calls the handler function for the matched resource if it exists.

  `Connect middleware, remains bound to the app object.`
  ###
  dispatchHandler: (req, res, next) =>
    return next() unless req.resource?
    ctx = @buildContext req, res, next
    # the resource handler should call next()
    req.resource[req.method].call ctx, ctx

  ###
  Renders the data in ``req.data`` to the client.

  Inspects the ``accept`` header and falls back to JSON if
  it can't find a type it knows how to render. To install or override the
  renderer for a given content/type use :meth:`lazorse::LazyApp.render`

  `Connect middleware, remains bound to the app object.`
  ###
  renderResponse: (req, res, next) =>
    return next new @errors.NotFound if not req.resource
    return next new @errors.NoResponseData if not res.data
    if req.headers.accept and [types, _] = req.headers.accept.split ';'
      for type in types.split ','
        if @renderers[type]?
          res.setHeader 'Content-Type', type
          return @renderers[type] req, res, next
    # Fall back to JSON
    res.setHeader 'Content-Type', 'application/json'
    @renderers['application/json'] req, res, next

  ###
  Intercept known errors types and return an appropriate response. If
  ``@passErrors`` is set to false (the default) any unknown error will send
  a generic 500 error.

  `Connect middleware, remains bound to the app object.`
  ###
  handleErrors: (err, req, res, next) ->
    errName = err.constructor.name
    if @errorHandlers[errName]?
      @errorHandlers[errName](err, req, res, next)
    else if @passErrors and not (err.code and err.message)
      next err, req, res
    else
      res.statusCode = err.code or 500
      message = 'string' == typeof err and err or err.message or "Internal error"
      res.data = error: message
      # @renderer will re-error if req.resource isn't set (e.g. no resource matched)
      req.resource ?= true
      @renderResponse req, res, next

  ###
  .. include:: handler_context.rst
  ###
  buildContext: (req, res, next) ->
    ctx = {req, res, next, app: this}
    vars = req.vars
    for n, h of @helpers
      ctx[n] = if 'function' == typeof h then h.bind vars else h
    vars.__proto__ = ctx
    vars

  ###
  Insert one or more connect middlewares into this apps internal stack.

  :param existing: The middleware that new middleware should be inserted in
  front of.

  :param new_middle: The new middleware to insert. This can be *either* one or
  more middleware functions, *or* a string name of a connect middleware and
  additional parameters for that middleware.

  Examples::
    
    @before @findResource, (req, res, next) ->
      res.setHeader 'X-Nihilo', ''
      next()

    @before @findResource, 'static', __dirname + '/public'

  ###
  before: (existing, new_middle...) ->
    i = @_stack.indexOf(existing)
    if i < 0
      throw new Error "Middleware #{existing} does not exist in the app"
    if typeof new_middle[0] is 'string'
      [name, args...] = new_middle
      if not connect[name]?
        throw new Error "Can't find middleware by name #{name}"
      new_middle = [ connect[name](args...) ]
    @_stack.splice i, 0, new_middle...

  ###
  Extend a connect server with the default middleware stack from this app
  ###
  extend: (server) ->
    server.use mw for mw in @_stack

  ###
  Act as a single connect middleware
  ###
  handle: (req, res, goodbyeLazorse) ->
    stack = (mw for mw in @_stack)
    nextMiddleware = =>
      mw = stack.shift()
      return goodbyeLazorse() unless mw?
      mw req, res, (err) =>
        return @handleErrors err, req, res, goodbyeLazorse if err?
        nextMiddleware()
    nextMiddleware()

# vim: set et:
