===========
Guide
===========

In this document we walk through the features of Lazorse, using it to create a
simple API to store and retrieve language specific greetings. The full app can be
viewed at https://github.com/BetSmartMedia/Lazorse/blob/master/examples/languages.coffee.

Creating an App
---------------

Lazorse uses a "builder" pattern for creating app objects. You supply the function exported by Lazorse with a callback, and it runs that callback in the context of a newly created :class:`lazorse::LazyApp` instance. So most apps end up looking something like this:

.. sourcecode:: coffeescript

    lazorse = require 'lazorse'
    lazorse ->
      # Various LazyApp methods here

(This pattern is lifted from Zappa, which lifted it from Sinatra and/or Rack)

Routing
-------

The most unusual piece of lazorse is the routing syntax: it's the same as the
`draft spec`_ for URI templates, but adds parameter matching
semantics on top. (:ref:`Details and disclaimers <uri-template-matching>`).

You declare routes to resources using the :meth:`lazorse::LazyApp.resource` method:

.. literalinclude:: ../examples/languages.coffee
  :language: coffeescript
  :start-after: require
  :end-before: examples

All of the keys are optional, but chances are you want to include at least one
HTTP method handler, or your resource will be unreachable. The handlers are
called with ``this`` set to a special context that contains all of the matched
URI template parameters and a few other things (see
:ref:`handler-and-coercion-contexts` below for details)

Lazorse also creates a default index (``/``) resource. This resource responds to
GET with an array of all named resources with their URI template and other
metadata, such as a description and examples if they are available. So our app
will return an array that looks like this:

.. sourcecode:: javascript

    [
      {
        "template": "/{language}/greetings",
        "description": "Per-language greetings",
        "shortName": "localGreeting",
        "methods": ["GET", "POST"]
      }
    ]

A resource with no ``shortName`` property will *not* show up in the index.

.. _coercions:

Coercions
---------

`Coercions are a direct rip-off of the app.param() functionality of Express`

Coercion callbacks can be added anywhere in your app using the
:meth:`~lazorse::LazyApp.coerce` method. The coercion will be called if a URI
template matches ``req.url`` and captures a parameter of the same name. This
example adds a coercion to our greeting app that will restrict the ``language``
parameter to only pre-defined languages:

.. literalinclude::  ../examples/languages.coffee
    :language: coffeescript
    :start-after: pre-defined
    :end-before: custom render

This example also makes use of :ref:`named errors <named-errors>`.

.. _handler-and-coercion-contexts:

Handler and coercion contexts
------------------------------

Each handler and coercion is called back in a specially prepared context.

.. include:: handler_context.rst

Although the example handlers have taken no parameters, lazorse does pass them
one parameter: this request context. This is meant to enable fat-arrow handlers
in situations where that's more convenient.

.. _rendering:

Rendering
---------

Lazorse includes no templating. Instead, rendering is handled as another
middleware in the stack. The default rendering middleware supports JSON and
(very ugly) HTML. It inspects the ``Accept`` header to see what the client wants,
and falls back to JSON when it can't provide it. You can easily add or override
the renderer for a new content type like so:

.. literalinclude:: ../examples/languages.coffee
  :language: coffeescript
  :start-after: custom rendering
  :end-before: custom error

With this in place, we could add a ``view`` property to any resource and have it
rendered to html using a template:

.. sourcecode:: coffeescript

  # a room with a view
  @resource '/room/{id}':
    view: {engine: 'eco', path: 'room.eco'}
    GET: -> ...

Error handling
--------------

The default error handler middleware will recognize any error with a ``code``
and ``message`` property and return an appropriate response.

If an error does not have these properties and the ``passErrors`` property of the
app is set to false (the default), a generic 500 response will be returned. If
``passErrors`` is true, then the error will be passed to the next middleware in
the stack.

.. _named-errors:

There is also an ``@error`` helper function made available to handlers and
coercions to help with returning errors. It can look up errors by name so that
you don't need to manually import your error types if you don't want to.

To register a new error type with a callback, we use the
:meth:`lazorse::LazyApp.error` method:

.. literalinclude::  ../examples/languages.coffee
    :language: coffeescript
    :start-after: custom error

Now our handlers (and coercions) can return 418s easily, no matter what file they
are defined in.

Including Example Requests
--------------------------

You can include an array of example requests for a named route "inline" with the
``examples`` property. Each example should be an object with a ``method``,
``vars``, and (optional) ``body`` property. In our example app that would look
like:

.. literalinclude:: ../examples/languages.coffee
  :language: coffeescript
  :start-after: require
  :end-before: coercion

The route ``/examples/{shortName}`` will respond with the example request
expanded into a full URI path, so ``GET /examples/localGreeting`` would return:

.. sourcecode:: javascript

    [
        {
          "method": GET",
          "path": "/english/greetings"
        },
        {
          "method": "POST",
          "path": "/english/greetings",
          "body": "howdy"
        }
    ]

.. _draft spec: http://tools.ietf.org/html/draft-gregorio-uritemplate-08
