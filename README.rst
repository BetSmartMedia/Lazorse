Lazorse!
========

Lazorse is a web-framework with a strong emphasis on extensibility and
seperation of various concerns into independant middleware layers.

It includes middleware to route requests, coerce parameters, dispatch to handlers,
and render a response.  
It borrows heavily from `other <zappa>`_ `awesome <coffeemate>`_ nodejs 
`web frameworks <express>`_ but with a couple of twists designed to make writing 
machine-consumable ReSTful APIs a little easier. Because it's all "just 
middleware", you can also pull out and re-arrange the various pieces to better 
suit the needs of your application.

Be sure to check out the guide_ and `API docs`_!

What's the deal with the name?
------------------------------

While it *could* be viewed as a portmentaeu of Lazy and Resource, I prefer to
think of it as horses with lasers.

License
-------

MIT

.. _uri template rfc: http://tools.ietf.org/html/draft-gregorio-uritemplate-07
.. _express: http://expressjs.com
.. _zappa: http://zappajs.org
.. _coffeemate: https://github.com/kadirpekel/coffeemate

.. _guide: http://betsmartmedia.github.com/Lazorse/guide.html
.. _API docs: http://betsmartmedia.github.com/Lazorse/api.html
