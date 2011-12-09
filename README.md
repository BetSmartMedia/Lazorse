# LAZORSE!

What do lazers and horses have in common? They will both kill you without a second thought (or a first thought).

Also, they share a few phonemes with "lazy" and "resource", which is what Lazorse is all about.

## K, wtf is it?

Lazorse is a connect middleware stack that routes requests, coerces parameters,
dispatches to handlers, and renders a response. It borrows heavily from
[other][zappa] [awesome][coffeemate] [web frameworks][express] but with a couple
of twists designed to make writing machine-consumable ReSTful APIs a little
easier.

### Routing

First and foremost of these is the route syntax: it's the same syntax as the 
[draft spec][uri template rfc] for URI templates, but extends them with
parameter matching semantics as well. See the bottom of this document for more
details.

Lazorse by default owns the index (`/`) route. The index route responds to GET
a mapping of all registered URI templates to their route specification, including
a description and examples if they are available. So an app with a single route
like:

```coffee
greetingLookup = english: "Hi", french: "Salut"

@route '/{language}/greeting':
  description: "Retrieve or store per-language greetings"
  shortName: 'localGreeting'
  GET: -> @ok greetingLookup[@language]
  POST: -> greetingLookup[@language] = @req.body; @ok()
```

Will return a spec object like:

```json
{
  "/{language}/greetings": {
    "description": "Retrieve or store per-language greetings",
    "shortName": "localGreeting",
    "methods": ["GET", "POST"]
  }
}
```

All of the keys are optional, but chances are you want to include at least one
HTTP method handler, or your route will be unreachable. Additionally, the
shortname can be nice for giving clients an easy way to refer to the URI.

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
 - `data` and `ok`: Callbacks that will set `res.data` for the rendering layer.
    (Don't worry, that's next). The only difference is that `ok` does
    _not_ handle errors, it only accepts a single argument and assumes that's
    what you want to return to the client. `data` on the other hand, will treat
    the first argument as an error in the idiomatic node style.
 - `link`: Takes a route shortName and a context object and returns the result
    of expanding the corresponding URI template in that context.

Although the example handlers have taken no parameters, lazorse does pass them
one parameter: the request context. This is meant to enable fat-arrow handlers
in situations where that's more convenient.

### Rendering

Lazorse includes no templating. Instead, rendering is handled as another
middleware in the stack. The default rendering middleware supports JSON and
(very ugly) HTML. It inspects the `Accept` header to see what the client wants,
and falls back to JSON when it can't provide it. You can easily add or override
the renderer for a new content type like so:

```coffee
render = require('lazorse/render')
render['application/vnd.wonka-ticket'] = (req, res, next) ->
	ticket = res.data
	res.write bufferOverflowThatTransportsClientToTheChocolateFactory()
	res.end "pwnd"
```

Obviously, your own renderers would do something actually useful. In addition to
`res.data`, Lazorse will add a `req.route` property that is the route object
that serviced the request. This could be used to do something like look up a
template or XML schema with `req.route.shortName`.

### Including Example Requests

Lazorse can load a JSON file defining example requests against your API, and
attach that information to the routes themselves so that it will be included in
the route index.

Given the example greeting API listed above, the examples file would look
something like this:

```json
{
  "localGreeting": [
    {
      "method": "GET",
      "path": "/greeting/english"
    }
  ]
}
```

Additionally lazorse ships with a script `lzrs-gen-examples` that will read a
file in this format, perform the requests, and then update the file with
responses in-line, so that it ends up looking like this:

```json
{
  "localGreeting": [
    {
      "method": "GET",
      "path": "/greeting/english",
      "response": {
        "greeting": "Hi",
        "language": "english"
      }
    }
  ]
}
```

To include this example data into your app, use the `@loadExamples` method,
which takes an object or filename as it's argument and attaches each array of
example requests to the corresponding route.

### More info on URI Template matching

The matching semantics for URI templates are an addition to the RFC that
specifies their expansion algorithm. Unfortunately, the nature of the expansion
algorithm makes round-trip expansion and parsing of URIs inconsistent unless the
following rules are followed:

  * All parameters, excepting query string parameters, are required.
  * Query string parameters cannot do positional matching. E.g. ?one&two&three
		will always fail. You must use named parameters in a query string.
  * Query string parameters with an explode modifier (e.g. {?list*}) currently
		will parse differently than they expand. I strongly recommend not to use
		the explode modifier for query string params.

## TODO

* More tests, as always.
* Factor different operators into different Expression specializations,
	hopefully this will help clean up some of the logic in Expression::match

## License

MIT

[express]: http://expressjs.com
[zappa]: http://zappajs.org
[coffeemate]: https://github.com/kadirpekel/coffeemate
[uri template rfc]: http://tools.ietf.org/html/draft-gregorio-uritemplate-07
