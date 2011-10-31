# LAZORSE!

What do lazers and horses have in common? They will both kill you without a second thought.

Also, they share a few phonemes with "lazy" and "resource", which is what Lazorse is all about.

## K, wtf is it?

Lazorse borrows heavily from [other][zappa] [awesome][coffeemate]
[web frameworks][express] but with a couple of twists designed to make writing
machine-consumable APIs a little easier.

### Routing

First and foremost of these is the route syntax. It's an implementation of the
[draft spec][uri template rfc] for URI templates. Lazorse by default owns the
`/` and `/schema/*` routes. The root route will respond with an object that maps
all registered routes/URI templates to a specifications object. These
specifications are introspected from your route definition, so a route like:

```coffee
greetingLookup = english: "Hi", french: "Salut"

@route '/greeting/{language}':
  description: "Retrieve or store per-language greetings"
  shortName: 'localGreeting'
  GET: -> @ok greetingLookup[language]
  POST: -> greetingLookup[language] = @body; @ok()
```

Will return a spec object like:

```json
{
  "/greetings/{language}": {
    "description": "Retrieve or store per-language greetings",
    "shortName": "localGreeting",
    "methods": ["GET", "POST"]
  }
}
```

All of the keys are optional, but chances are you want to include at least one
HTTP method handler, or your route will be unreachable. Additionally, the
shortname can be nice for making the 

### Coercions

Coercions are a direct rip-off of [Express'][express] `app.param` functionality.
You can declare a coercion callback anywhere in your app, and it will be called
whenever a URI template matches a parameter of the same name. For example:

```coffee
@coerce language: (lang, next) ->
  lang = lang.toLowerCase()
  if lang not in greetings
    next new Error "Invalid language!"
  else
    next null, lang
```

Will ensure that only pre-defined languages are allowed to reach the actual
handler functions.

### Handlers and environments

Of course you're probably wondering about those handler functions. Each handler
function is called with `this` bound to a context containing the following keys:

	- `req` and `res`: request and response objects direct from connect.
	- `data` and `ok`: Callbacks that will set the data property for the rendering
		layer. (Don't worry, that's next). The only difference is that `ok` does
		_not_ handle errors, it only accepts a single argument and assumes that's
		what you want to return to the client. `data` on the other hand, will treat
		the first argument as an error in typical node callback style.
	- `link`: Takes a route shortName and a context object and returns the result
		of expanding the corresponding URI template in that context.

Although the examples have taken no parameters, handlers _do_ get one parameter:
the request context. This means you can use fat-arrow handlers if necessary.

### Rendering

Lazorse include zero templating. Instead, rendering is handled as another
middleware in the stack. By default Lazorse renders whatever is in
response.data as JSON. To over-ride this behaviour, replace this.renderer inside
your app builder. Patches that do things like inspect the 'Accept' header are
more than welcome!

### Schemas

TODO - Determine if these are even useful.

## TODO

The above, oh and tests would be good.

## License

MIT
