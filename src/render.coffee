exports['text/html'] = (req, res, next) ->
  res.setHeader 'Content-Type', 'text/html'
  title  = req.resource.shortName || 'Un-named route'
  res.write "<html><head><title>#{title}</title></head><body>"
  writeHtml res, res.data
  res.end "</body></html>"

writeHtml = (res, data) ->
  if Array.isArray(data) then htmlList res, data
  else if typeof data is 'undefined' then res.write '<em>undefined</em>'
  else if not data? then res.write '<em>null</em>'
  else if typeof data is 'object' then htmlDict res, data
  else if typeof data is 'string' then res.write data
  else if typeof data is 'number' then res.write data.toString()
  else
    console.log "Can't write this data as html"
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

# vim: set et:
