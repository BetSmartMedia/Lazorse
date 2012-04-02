Upgrading from earlier versions
===============================

Version 0.5 introduces the following backwards-incompatible API changes:

  * ``@route`` has been renamed to ``@resource`` but otherwise behaves the
    same as before. Additionally, ``@routeIndex`` has been renamed to
    ``@resourceIndex``, and ``@routingTable`` has been renamed to ``@routes``

  * ``@coerce`` now takes three parameters (a template parameter name,
    description, and the coercion function), instead of an object mapping
    template parameter names to coercion functions.

  * Another default resource has been added to expose this documentation.

  * The example requests resource and parameter documentation resource are both
    named, and therefore show up in the resource index.
