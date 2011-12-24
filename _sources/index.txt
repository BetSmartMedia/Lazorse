.. include:: ../README.rst

Walkthrough
===========

Routing
-------

The most unusual piece of lazorse is the route syntax: it's the same as the 
`draft spec <uri template rfc>`_ for URI templates, but adds parameter matching
semantics on top. (There are more details and disclaimers at the bottom of this
document).

Lazorse creates a default index (``/``) route. This route responds to GET with
an array of all named routes with their URI template and other metadata, such 
as a description and examples if they are available. So an app with a single 
route like:

.. sourcecode:: coffeescript

    greetingLookup = english: "Hi", french: "Salut"

    @route '/{language}/greeting':
      description: "Per-language greetings"
      shortName: 'localGreeting'
      GET: -> @ok greetingLookup[@language]
      POST: -> greetingLookup[@language] = @req.body; @ok()

Will return an array that looks like this:

.. sourcecode:: javascript

    [
      {
        "template": "/{language}/greetings", 
        "description": "Retrieve or store per-language greetings",
        "shortName": "localGreeting",
        "methods": ["GET", "POST"]
      }
    ]

All of the keys are optional, but chances are you want to include at least one
HTTP method handler, or your route will be unreachable. Also, remember that a
route without a ``shortName`` will *not* show up in the index.

Coercions
---------

Coercions are a direct rip-off of the ``app.param`` functionality of Express_.
You can declare a coercion callback anywhere in your app, and it will be called
whenever a URI template matches a parameter of the same name. For example:

.. sourcecode:: coffeescript

    @coerce language: (lang, next) ->
      lang = lang.toLowerCase()
      if lang not in greetings
        next new Error "Invalid language!"
      else
        next null, lang

Will ensure that only pre-defined languages are allowed to reach the actual
handler functions.

Handlers and contexts
---------------------

Of course you're probably wondering about those handler functions. Each handler
function is called with ``this`` bound to a context containing the following keys:

 - ``req`` and ``res``: request and response objects direct from connect.
 - ``data`` and ``ok``: Callbacks that will set ``res.data`` for the renderer
    (Don't worry, that's next). The only difference is that ``ok`` does
    _not_ handle errors, it only accepts a single argument and assumes that's
    what you want to return to the client. ``data`` on the other hand, will
    treat the first argument as an error in the idiomatic node style.
 - ``link``: Takes a route shortName and a context object and returns the result
    of expanding the corresponding URI template in that context.

Although the example handlers have taken no parameters, lazorse does pass them
one parameter: the request context. This is meant to enable fat-arrow handlers
in situations where that's more convenient.

Rendering
---------

Lazorse includes no templating. Instead, rendering is handled as another
middleware in the stack. The default rendering middleware supports JSON and
(very ugly) HTML. It inspects the ``Accept`` header to see what the client wants,
and falls back to JSON when it can't provide it. You can easily add or override
the renderer for a new content type like so:

.. sourcecode:: coffeescript

  render = require('lazorse/render')
  render['application/vnd.wonka-ticket'] = (req, res, next) ->
    ticket = res.data
    res.write bufferOverflowThatTransportsClientToTheChocolateFactory()
    res.end "pwnd"

Obviously, your own renderers would do something actually useful. In addition to
``res.data``, Lazorse will add a ``req.route`` property that is the route object
that serviced the request. This could be used to do something like look up a
template or XML schema with ``req.route.shortName``.

Error handling
--------------

The default error handler middleware will recognize any error with a ``code``
and ``message`` property. If an error does not have these properties and 
the ``passErrors`` property of the app is set to false (the default), a generic
500 response will be returned. If ``passErrors`` is true, then the error will
be passed to the next middleware in the stack.

There is also an ``@error`` helper function made available to handlers and
coercions to help with returning errors. It can look up errors by name so that
you don't need to manually import your error types if you don't want to. See the
``LazyApp.error`` documentation for details on how to register new error types.

Including Example Requests
--------------------------

You can include an array of example requests for a named route "inline" with the
``examples`` property. Each example should be an object with a ``method``,
``vars``, and (optional) ``body`` property. In our example app that would look
like:

.. sourcecode:: coffeescript

    @route '/{language}/greeting':
      description: "Per-language greetings"
      shortName: 'localGreeting'
      GET: -> @ok greetingLookup[@language]
      POST: -> greetingLookup[@language] = @req.body; @ok()
      examples: [
        {method: 'GET', vars: {language: 'english'}}
        {method: 'POST', vars: {language: 'english'}, body: "howdy"}
      ]
  

The route ``/examples/{shortName}`` will respond with the example request
expanded into a full URI path:

.. sourcecode:: javascript


More info on URI Template matching
----------------------------------

The matching semantics for URI templates are an addition to the RFC that
specifies their expansion algorithm. Unfortunately, the nature of the expansion
algorithm makes round-trip expansion and parsing of URIs inconsistent unless the
following rules are followed:

  * All parameters, excepting query string parameters, are required.
  * Query string parameters cannot do positional matching. E.g. ?one&two&three
    will always fail. You must use named parameters in a query string.
  * Query string parameters with an explode modifier (e.g. {?list*}) currently
    will parse differently than they expand. I strongly recommend 
    not to use the explode modifier for query string params.


API documentation
=================

.. automodule:: lazorse
   :members:

Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`

