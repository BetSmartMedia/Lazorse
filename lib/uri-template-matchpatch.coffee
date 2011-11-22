# Patch in .match methods to the uri-template Template and Expression prototypes

{Template, Expression} = require 'uri-template/lib/classes'

Template::match = (string) ->
  if @prefix
    return false unless m = string.match '^' + @prefix
    string = string.substring m[0].length
  vars = {}
  for expr in @expressions
    inQS = expr.op.first in queryStringOps
    unless len = expr.match(string, vars) or inQS
      return false
    string = string.substring(len)
  if string and not inQS
    return false
  return vars

Expression::match = (input, vars) ->
    string = input
    len = 0
    if @op.first isnt '?'
      [string] = string.split '?'
      pathPart = string

    if @op.first
      return false unless string.match '^\\' + @op.first
      string = string.substring ++len

    if @suffix
      return false unless m = string.match @suffix
      len += @suffix.length
      string = string.substring 0, m.index
    
    len += string.length
    i = 0
    named = {}
    ordered = []
    for part in string.split @op.sep
      [n, v] = part.split '='
      if not v?
        ordered.push unescape(n)
      else if named[n]?
        named[n].push unescape(v)
      else
        named[n] = [unescape(v)]
    
    for p in @params
      unless (v = named[p.name])?
        if p.explode
          if ordered.length then v = ordered; ordered = null
          else v = named; named = null
        else
          v = ordered.shift()
      return false unless v? or @op.first in queryStringOps
      vars[p.name] = v || []
      console.dir [p.name, vars]
    return len

tpl = parser.parse('/{first}/{second}{?q1,q2}')

vars = tpl.match('/first/second?q1=cheesy&q2=cheese')

assert.deepEqual(vars, {
	first: 'first',
	second: 'second',
	q1: ['cheesy'],
	q2: ['cheese'],
})

sys.puts("Match test passed")
