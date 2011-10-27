# Lazy, for when you're feeling ReSTful

METHODS = ['DELETE', 'GET', 'HEAD', 'PATCH', 'POST', 'PUT']

{parser} = require 'uri-template'

class LazyApp
	constructor: (builder) ->
		if 'function' == typeof opts
			builder = opts
			opts = {}
		app = @
		@renderer = renderJSON
		@helpers =
			ok:   (data) ->
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

		# Set up the default routes / and /schema/{name}
		@route
			index:
				template: '/'
				description: "Index of all routes"
				GET: (ctx) =>
					specObject = {}
					for name, spec of @routes
						specObject[name] =
							URI: spec.template.toString()
							description: spec.description
					ctx.ok specObject
			schemas:
				template: '/schema/{name}'
				GET: (ctx) =>
					console.dir schemasCtx: ctx, ok: ctx.ok
					if s = @schemas[ctx.name]
						return ctx.ok s
					ctx.next()

		builder.call @

	route: (specs) ->
		for name, spec of specs
			spec.template ?= "/#{name}"

			if @routes[name]?
				throw new Error "Duplicate path name #{name}"
			if spec.template in @templates
				throw new Error "Duplicate template #{template}"

			@register name, spec

	register: (name, spec) ->
		spec.name = name
		spec.template = parser.parse spec.template
		for method in METHODS when handler = spec[method]
			@routeTable[method].push spec
		@routes[name] = spec

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

	coerceAll: (vars, callback) ->
		varNames = (k for k in Object.keys vars when @coercions[k]?)
		i = 0
		nextCoercion = (err) =>
			return callback err if err?
			name = varNames[i++]
			return callback null unless name?
			coercion = @coercions[name]
			coercion vars[name], (e, newValue) ->
				return callback e if e?
				vars[name] = newValue
				nextCoercion()
		nextCoercion()

routeMiddleware = (app) ->
	(req, res, next) ->
		try
			ctx =
				req: req, res: res, next: next
			ctx.__proto__ = app.helpers

			i = 0
			routes = app.routeTable[req.method]
			nextHandler = (err) ->
				return next err if err? and err != 'route'
				r = routes[i++]
				return next() unless r?
				vars = r.template.match(req.url)
				return nextHandler() unless vars
				vars.__proto__ = ctx
				app.coerceAll vars, (err) ->
					return nextHandler err if err?
					vars.req.route = r
					r[req.method].call vars, vars
			nextHandler()
		catch err
			next err

renderJSON = (req, res, next) ->
	if not res.data and res.route
		return next new Error "No data for response"
	res.setHeader('Content-Type', 'application/json')
	res.data.routeName = req.route.name
	res.end JSON.stringify(res.data)

module.exports = lazy = (args...) ->
	app = new LazyApp args...
	connect = require 'connect'
	server = connect.createServer()
	server.use connect.logger()
	server.use routeMiddleware(app)
	server.use app.renderer
	server.listen 3000

lazy.app = (args...) -> new LazyApp args
