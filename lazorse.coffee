# Lazorse: lazy resources, lasers, and horses.

METHODS = ['DELETE', 'GET', 'HEAD', 'PATCH', 'POST', 'PUT', 'OPTIONS']

connect = require 'connect'
parser = require 'uri-template'
require './lib/uri-template-matchpatch'
errors = require './lib/errors'

module.exports = exports = (builder) -> new LazyApp builder

exports.connect = (builder) -> connect().use(exports(builder))

exports.server = (address, builder) ->
  app = exports.connect(builder)
  require('http').createServer(app).listen address.port or 0, address.host

class LazyApp
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

  constructor: (builder) ->
    app = @ # Needed by some of the callbacks defined here

    # Defaults
    @renderers = {}
    @renderers[type] = func for type, func of require './lib/render'

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
    @routes = {}
    @routes[method] = [] for method in METHODS

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
            if resource.examples and examplePath
              spec.examples = @link 'exampleRequests', {shortName}
            spec
          specs.sort (a, b) ->
            [a, b] = (s.template for s in [a, b])
            return 0 if a == b
            if a < b then -1 else 1
          @ok specs

    if examplePath
      defaultResources[examplePath+'/{shortName}'] =
        shortName: 'exampleRequests'
        description: "Example requests for a named resource"
        GET: ->
          unless resource = app.resourceIndex[@shortName]
            return @error 'NotFound', 'resource', @shortName
          unless resource.examples
            return @error 'NotFound', 'Examples for resource', @shortName
          examples = for example in resource.examples
            ex = method: example.method, path: @link @shortName, example.vars
            ex.body = example.body if example.body?
            ex
          @ok examples

    if parameterPath
      defaultResources[parameterPath+'/'] = GET: -> @ok app.coercionDescriptions
      defaultResources[parameterPath+'/{parameterName}'] =
        shortName: 'parameterDocumentation'
        description: "The documentation for a specific template parameter."
        GET: ->
          unless (coercion = app.coercions[@parameterName])
            return @error 'NotFound', 'parameters', @parameterName
          @ok app.coercionDescriptions[@parameterName]

    @resource defaultResources

  resource: (specs) ->
    ###
    Register one or more resources. The ``specs`` object should map URI templates to
    an object describing the resource. For example::

        @resource '/{category}/{thing}':
          shortName: "categorizedThing" # for internal linking and client libs.
          description: "Things that belong to a category" # for documentation.
          GET: -> ...
          POST: -> ...
          PUT: -> ...
          examples: [
            {method: 'GET', vars: {category: 'cats', thing: 'jellybean'}}
          ]
    ###
    for template, spec of specs
      if spec.shortName and @resourceIndex[spec.shortName]?
        throw new Error "Duplicate short name '#{spec.shortName}'"

      spec.template = parser.parse @_prefix + template
      @resourceIndex[spec.shortName] = spec if spec.shortName
      for method in METHODS when handler = spec[method]
        @routes[method].push spec

  helper: (helpers) ->
    ###
    Register one or more helper objects. The ``helpers`` parameter should be an
    object that maps helper names to objects/functions.

    The helpers will be made available in the context used by coercions and
    request handlers (see :meth:`lazorse::LazyApp.buildContext`). So if you
    register a helper named 'fryEgg' it will be available as ``@fryEgg``. If
    your helper is a function, it will be bound to the request context.
    ###
    for name, helper of helpers
      @helpers[name] = helper

  coerce: (name, description, coercion) ->
    ###
    Register a new template parameter coercion with the app.

    :param name: The name of the template parameter to be coerced.
    :param description: A documentation string for the parameter name.
    :param coercion: a ``(value, next) -> next(err, coercedValue)`` function that will
      be called with ``this`` set to the request context. If not given, the
      value will be passed through unchanged (useful for documentation purposes).

    See :rst:ref:`coercions` in the guide for an example.
    ###
    throw new Error "Duplicate coercion name: #{name}" if @coercions[name]?
    @coercionDescriptions[name] = description
    @coercions[name] = coercion or (v, n) -> n(null, v)

  error: (errType, cb) ->
    ###
    Register an error constructor with the app. The callback wlll be called by
    :meth:`lazorse::LazyApp.handleErrors` when an error of this type is
    encountered.

    Additionally, errors of this type will be available to the ``@error`` helper
    in handler/coercion callback by it's stringified name.

    See :rst:ref:`named errors <named-errors>` in the guide for an example.

    .. note::
      *Named functions are required*. You must use a class for your errors in
      CoffeeScript as it's the only way to generate a named function.
    ###
    errName = errType.name
    @errors[errName] = errType
    @errorHandlers[errName] = cb if cb?


  render: (contentType, renderer) ->
    ###
    Register a new renderer function with the app.

    :param contentType: The content type this renderer handles
    :param renderer: A middleware that will render data to this content type.

    See :rst:ref:`Rendering` in the guide for an example of a custom renderer.
    ###
    if typeof contentType is 'object'
      @renderers[ct] = r for ct, r of contentType
    else
      @renderers[contentType] = renderer

  include: (path, obj) ->
    ###
    Call ``obj.include`` in the context of the app. The (optional) ``path``
    parameter will be prefixed to all resources defined by the include.
    ###
    if typeof path.include == 'function'
      obj = path
      path = ''
    if typeof obj.include != 'function'
      throw new Error "#{obj} does not have a .include method"
    restorePrefix = @_prefix
    @_prefix = path
    obj.include.call @
    @_prefix = restorePrefix

  before: (existing, new_middle...) ->
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
    i = @_stack.indexOf(existing)
    if i < 0
      throw new Error "Middleware #{existing} does not exist in the app"

    # If we receive an array, add each sub-array in order
    if Array.isArray(new_middle[0])
      for nm in new_middle[0]
        @before existing, nm...
      return

    if typeof new_middle[0] is 'string'
      [name, args...] = new_middle
      if not connect[name]?
        throw new Error "Can't find middleware by name #{name}"
      new_middle = [ connect[name](args...) ]
    @_stack.splice i, 0, new_middle...

  findResource: (req, res, next) =>
    ###
    Find the first resource with a URI template that matches ``req.url``.

    Sets ``req.resource`` to the spec passed to :meth:`~lazorse::LazyApp.resource`,
    and ``req.vars`` to the extracted URL parameters.
    ###
    try
      i = 0
      resources = @routes[req.method]
      nextHandler = (err) =>
        return next err if err? and err != 'resource'
        r = resources[i++]
        return next(new @errors.NotFound 'resource', req.url) unless r?
        {vars, aliases} = r.template.match req.url
        return nextHandler() unless vars
        req.resource = r
        req.vars = vars
        req.aliases = aliases
        next()
      nextHandler()
    catch err
      next err

  coerceParams: (req, res, next) =>
    ###
    Walk through ``req.vars`` and call any registered coercions that apply.
    ###
    return next() unless req.vars
    toCoerce = []
    for name, value of req.vars
      if coercion = @coercions[req.aliases[name] or name]
        toCoerce.push [name, value, coercion]

    return next() unless toCoerce.length

    toCoerce.sort (a, b) -> req.url.indexOf(a[0]) - req.url.indexOf(b[0])
    i = 0
    req._ctx ?= buildContext @, req, res, next
    nextCoercion = ->
      n_v_c = toCoerce[i++]
      return next() unless n_v_c
      [name, value, coercion] = n_v_c
      coercion.call req._ctx, value, (e, newValue) ->
        return next e if e?
        req.vars[name] = newValue
        nextCoercion()
    nextCoercion()


  dispatchHandler: (req, res, next) =>
    ###
    Calls the handler function for the matched resource if it exists.
    ###
    return next() unless req.resource?
    req._ctx ?= buildContext @, req, res, next
    # the resource handler should call next()
    req.resource[req.method].call req._ctx, req._ctx

  renderResponse: (req, res, next) =>
    ###
    Renders the data in ``req.data`` to the client.

    Inspects the ``accept`` header and falls back to JSON if
    it can't find a type it knows how to render. To install or override the
    renderer for a given content/type use :meth:`lazorse::LazyApp.render`
    ###
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

  handleErrors: (err, req, res, next) ->
    ###
    Intercept known errors types and return an appropriate response. If
    ``@passErrors`` is set to false (the default) any unknown error will send
    a generic 500 error.
    ###
    errName = err.constructor.name
    if @errorHandlers[errName]?
      @errorHandlers[errName](err, req, res, next)
    else if @passErrors and not (err.code and err.message)
      next err, req, res
    else
      res.statusCode = err.code or 500
      message = ('string' is typeof err and err) or err.message or "Internal error"
      res.data = error: message
      # @renderer will re-error if req.resource isn't set (e.g. no resource matched)
      req.resource ?= true
      @renderResponse req, res, next

  # Private
  buildContext = (app, req, res, next) ->
    ctx = {req, res, next, app}
    vars = req.vars
    for n, h of app.helpers
      ctx[n] = if typeof h is 'function' then h.bind(vars) else h
    vars.__proto__ = ctx
    vars

  handle: (req, res, goodbyeLazorse) ->
    ### Act as a single connect middleware ###
    stack = (mw for mw in @_stack)
    nextMiddleware = =>
      mw = stack.shift()
      return goodbyeLazorse() unless mw?
      mw req, res, (err) =>
        return @handleErrors err, req, res, goodbyeLazorse if err?
        nextMiddleware()
    nextMiddleware()

# vim: set et:
