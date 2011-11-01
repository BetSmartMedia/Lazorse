exports['text/html'] = (req, res, next) ->
  res.setHeader 'Content-Type', 'text/html'
  title  = req.route.shortName || 'Un-named route'
  res.write "<html><head><title>#{title}</title>"
  if req.route.template.toString() == '/'
    console.dir "Rendering doc page"
    res.write '<link rel="stylesheet" type="text/css" href="/docs.css"/>'
    res.write "</head><body>"
    for tpl, route of res.data
      console.dir template: tpl, route: route
      res.write '<div class="route">'
      res.write "<h1>#{route.shortName}</h1>" if route.shortName
      res.write "<h2>#{tpl}</h2>"
      delete route.shortName
      examples = route.examples
      delete route.examples
      htmlDict res, route
      if examples?
        res.write "<h3>Examples</h3>"
        for request, response of examples
          res.write "<pre class='example'>#{request}\n#{JSON.stringify response}</pre>"
      res.write '</div>'
  else
    res.write "</head><body>"
    writeHtml res, res.data
  res.end "</body></html>"

writeHtml = (res, data) ->
  if Array.isArray(data) then htmlList res, data
  else if typeof data is 'object' then htmlDict res, data
  else if typeof data is 'string' then res.write data
  else if typeof data is 'undefined' then res.write '&nbsp;'
  else
    console.dir "Can't write this data as html"
    console.dir data

htmlList = (res, ol) ->
  res.write '<ol>'
  for li in ol
    res.write '<li>'
    writeHtml res, li
    res.write '</li>'
  res.write '</ol>'

htmlDict = (res, array) ->
  res.write '<dl>'
  for dt, dd of array
    res.write "<dt>#{dt}</dt>"
    res.write '<dd>'
    writeHtml res, dd
    res.write '</dd>'
  res.write '</dl>'

exports['application/json'] = (req, res, next) ->
  res.setHeader 'Content-Type', 'application/json'
  res.end JSON.stringify res.data
