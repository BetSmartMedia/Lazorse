# Lazorse: lazy resources, lazers, and horses.

METHODS = ['DELETE', 'GET', 'HEAD', 'PATCH', 'POST', 'PUT']

require './uri-template-matchpatch'
parser = require 'uri-template'

class LazyApp
  constructor: (builder) ->
    app = @
    @renderer = contentTypeRenderer
    @helpers =
      ok:   (data) ->
        @res.statusCode = 200
        @res.data = data
        @next()
      data: (err, data) -> return @next err if err?; @ok data
      link: (name, ctx) -> app.routes[name].template.expand(ctx or @)

    @routes = {}
    @schemas = {}
    @coercions = {}
    @routeTable = {}

    for method in METHODS
      @routeTable[method] = []

    @_prefix = ''
    # Set up the default routes / and /schema/{name}
    @route '/':
      shortName: 'routeIndex'
      description: "Index of all routes"
      examples:
        'GET /': {shortName: 'routeIndex', description: "Index of all routes", methods: ["GET"]}
      GET: (ctx) =>
        specs = {}
        for shortName, spec of @routes
          specs[spec.template] =
            shortName: shortName
            description: spec.description
            examples: spec.examples
            methods: (k for k of spec when k in METHODS)
        ctx.ok specs

    builder.call @

  route: (specs) ->
    for template, spec of specs
      if spec.shortName and @routes[spec.shortName]?
        throw new Error "Duplicate path name #{spec.shortName}"

      @register template, spec

  register: (template, spec) ->
    spec.template = parser.parse @_prefix + template
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

  coerceAll: (vars, errBack) ->
    varNames = (k for k in Object.keys vars when @coercions[k]?)
    varNames.sort (a, b) -> vars.req.url.indexOf(a) - vars.req.url.indexOf(b)
    i = 0
    nextCoercion = (err) =>
      return errBack err if err?
      name = varNames[i++]
      return errBack null unless name?
      coercion = @coercions[name]
      coercion.call vars, vars[name], (e, newValue) ->
        return errBack e if e?
        #if e == 'drop' then delete vars[name] else 
        vars[name] = newValue
        nextCoercion()
    nextCoercion()
  
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
  router: (req, res, next) ->
    app = @
    try
      ctx =
        app: app, req: req, res: res, next: next
      ctx.__proto__ = app.helpers

      i = 0
      routes = app.routeTable[req.method]
      nextHandler = (err) ->
        return next err if err? and err != 'route'
        r = routes[i++]
        return next() unless r?
        vars = r.template.match req.url
        return nextHandler() unless vars
        vars.__proto__ = ctx
        app.coerceAll vars, (err) ->
          return nextHandler err if err?
          ctx.req.route = r
          r[req.method].call vars, vars
      nextHandler()
    catch err
      next err

# A default handle function for connect
  handle: (req, res, next) ->
    @router req, res, (err) =>
      if err?
        return next err if err?
      @renderer req, res, next

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
  server.use app
  server.use connect.errorHandler()
  server.listen 3000

lazy.app = (args...) -> new LazyApp args...

lazy.NoResponseData = NoResponseData = ->
  @message = "Response data is undefined"
  @code = 500
  Error.captureStackTrace @

lazy.InvalidParameter = InvalidParameter = (type, thing) ->
  @message = "Bad Request: invalid #{type} #{thing}"
  @code = 400
  Error.captureStackTrace @
