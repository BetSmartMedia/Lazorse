The context is made up of 2 objects in a delegation chain:

    1. An object containing URI Template variables, which delegates to:
    2. A request context object containing:

       * All helpers defined for the app using :meth:`~lazorse::LazyApp.helper`.
       * ``app``: The lazorse app
       * ``req``: The request object from node (via connect)
       * ``res``: The response object from node (via connect)
       * ``error``: A callback that will return an error to the client.
       * ``next``: A callback that will pass this request to the next middleware
                   in the chain (via connect).

Because this is a delegation chain, you need to be careful not to mask out helper
names with variable names.
