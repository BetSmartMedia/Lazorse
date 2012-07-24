=================
API documentation
=================

Exported API
============

The main export is a function that takes a "builder" function and constructs a
`LazyApp <#app-building>`_ instance with it::

  lazorseApp = require('lazorse') ->
    # Build your app here

Or, if you'd rather get back a connect app ready for more ``.use()`` calls::

  connectApp = require('lazorse').connect ->
    # Again, build the app here

Finally, if you'd rather start a server automatically after the app is built::

  require('lazorse').server port: 1234, host: '0.0.0.0', ->
    # A pattern is emerging...

The rest of the API is made up of the methods on ``LazyApp`` which are available
on ``@`` (``this``) to your builder function.

App-building
====================

The builder function is called with it's ``@`` context set to the partially
constructed ``LazyApp`` instance, it builds out the app by calling methods
and/or modifying properties on ``@``

App-building properties
-----------------------

The following properties on ``@`` can be set to alter default behaviours:

``@indexPath``, ``@examplePath`` and ``@parameterPath``:
  Prefixes for the location of the `default resources`_. You can disable
  any of these resources by setting their path prefix to ``false``.

  Defaults: ``'/'``, ``'/examples'``, ``'/parameters'``

``@passErrors``
  Setting this to ``true`` will cause unrecognized errors to be passed to
  ``@next()`` by :meth:`lazorse::LazyApp.handleErrors`.

  Default: false

App-building methods
-----------------------

.. automethod:: lazorse::LazyApp.resource

.. automethod:: lazorse::LazyApp.helper
    
  Lazorse installs 4 default helpers into every app:

    * ``@data`` - Use this as a callback to asynchronous functions that use the
      ``callback(err, result)`` idiom.
    * ``@ok`` - Sets ``@res.data`` and call @next unconditionally.
    * ``@error`` - Given a constructor function or a name registered with
      :meth:`error`, and additional constructor arguments, constructs an error
      and passes it to ``@next``.
    * ``@link`` - Return a URL path to a resource given it's shortName and
      a template expansion context object.

  These are added before the builder function is called, so it's possible
  (though not recommended) to over-ride or remove them by modifying
  ``@helpers``.

.. automethod:: lazorse::LazyApp.coerce
.. automethod:: lazorse::LazyApp.render
.. automethod:: lazorse::LazyApp.error
.. automethod:: lazorse::LazyApp.include
.. automethod:: lazorse::LazyApp.before

Middleware Methods
==================

These methods act as Connect middleware. They remain bound to the app so you
can safely pass them to connects ``.use()`` method without wrapping them in a
callback function.

.. automethod:: lazorse::LazyApp.findResource
.. automethod:: lazorse::LazyApp.coerceParams
.. automethod:: lazorse::LazyApp.dispatchHandler
.. automethod:: lazorse::LazyApp.renderResponse
.. automethod:: lazorse::LazyApp.handleErrors

Default Resources
=================

Lazorse adds three default resources to every app (unless they are disabled_):

Index (default path ``/``):
  Returns metadata for all of the *named* resources in the app, including URI
  templates, descriptions, and supported HTTP methods, and links to example
  requests if any are defined.

Examples (default path ``/examples/{shortName}``):
  Responds with an array of all of the example requests for the named resource.

Parameters (default paths ``/parameters/`` and ``/parameters/{parameterName}``)
  Responds with the documentation string for all, or the specifically named,
  URL parameter coercions given to :meth:`lazorse::LazyApp.coerce`.

.. _disabled:  #app-building-properties

Request Contexts
================

Every request has a special `request context` assigned to it. This context is
shared by all of the coercions, helpers, and handlers used in a single request.

.. include:: handler_context.rst
