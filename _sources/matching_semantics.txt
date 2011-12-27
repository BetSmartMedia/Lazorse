.. _uri-template-matching:

URI Template matching
----------------------------------

The matching semantics for URI templates are an addition to the `RFC that
specifies their expansion algorithm`_. Unfortunately, the
nature of the expansion algorithm makes round-trip expansion and parsing of URIs
inconsistent unless the following rules are followed:

  * All parameters, excepting query string parameters, are required.
  * Query string parameters cannot do positional matching. E.g. ?one&two&three
    will always fail. You must use named parameters in a query string.
  * Query string parameters with an explode modifier (e.g. {?list*}) are greedy
    and so will parse differently than they expand. 
    
For these reasons, using explode modified querystring params is strongly
discouraged. The RFC sets aside parenthesis for implementation extensions, so
the tentative plan is to extend the grammar to allow specifying that a
querystring param should be parsed as a list::

    /urlpath{?param1,param2,listParam(sep=,),param3}

.. _RFC that specifies their expansion algorithm:
  http://tools.ietf.org/html/draft-gregorio-uritemplate-07
