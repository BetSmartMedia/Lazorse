# Patch in .match methods to the uri-template Template and Expression prototypes
{Template, Expression} = require 'uri-template/lib/classes'

queryStringOps = ['?', '&']

Template::match = (input) ->
  if @prefix
    return false unless m = input.match '^' + @prefix
    input = input.substring m[0].length
  vars = {}
  for expr in @expressions
    inQS = expr.op.first in queryStringOps
    remaining = expr.match input, vars
    if remaining is false  and not inQS
      return false
    input = remaining
  if input and not inQS
    return false
  return vars

# Matches an input string against the expression, assigning matched expression
# parameter names as properties of the passed in `vars` object.
#
# Returns false if the match failed, or the remaining input if the match succeeds
Expression::match = (input, vars) ->
  console.log "Matching #{input} against #{@params.map (p) -> p.name}"
  len = 0 # The total length of matched input
  if @op.first not in queryStringOps
    input = input.split('?').shift()

  if @op.first
    return false unless input.substring(0,1) is @op.first
    input = input.substring 1
    len++

  if @suffix
    console.log "Checking for suffix #{@suffix}"
    return false unless m = input.match @suffix
    len += @suffix.length
    matchable = input.substring 0, m.index
  else
    matchable = input
  
  len += matchable.length
  i = 0
  named = {}
  ordered = []
  for part in matchable.split @op.sep
    [n, v] = part.split '='
    if not v?
      ordered.push unescape n
    else if named[n]?
      named[n].push unescape v
    else
      named[n] = [unescape v]
  
  for p in @params
    if (v = named[p.name])?
      # Got a named parameter, nothing else to do
    else
      if p.explode
        if ordered.length then v = ordered; ordered = null
        else v = named; named = null
      else
        v = ordered.shift()
    return false unless v or @op.first in queryStringOps
    vars[p.name] = v || []
  remaining = input.substring len
  console.log "Remaining: #{remaining}"
  remaining
