# Patch in .match methods to the uri-template Template and Expression prototypes
tpl_classes = require 'uri-template/lib/classes'
{Template, SimpleExpression} = tpl_classes

queryStringOps = ['?', '&']

Template::match = (input) ->
  if @prefix
    return {} unless m = input.match '^' + @prefix
    input = input.substring m[0].length
  vars = {}
  aliases = {}
  for expr in @expressions
    inQS = expr.first in queryStringOps
    remaining = expr.match input, vars, aliases
    if remaining is null
      return {}
    if remaining is false and not inQS
      return {}
    input = remaining
  if input and not inQS
    return {}
  return {vars, aliases}

# Matches an input string against the expression, assigning matched expression
# parameter names as properties of the passed in `vars` object.
#
# This has a somewhat ugly tri-state return:
#   * false if the match failed 
#   * null if the enclosing template should be forced to fail as well
#   * the remaining input if the match succeeds
SimpleExpression::match = (input, vars, aliases) ->
  len = 0 # The total length of matched input
  inQS = @first in queryStringOps
  if not inQS
    [input, qs] = input.split '?'
    qs = if qs then '?'+qs else ''
  else
    qs = ''

  if @first
    return false unless input.substring(0,1) is @first
    input = input.substring 1
    len++

  if @suffix
    return false unless m = input.match @suffix
    len += @suffix.length
    matchable = input.substring 0, m.index
  else
    matchable = input
  
  len += matchable.length
  i = 0
  named = {}
  ordered = []
  for part in matchable.split @sep
    if part.match(/\//) and @allow isnt 'U+R'
      return null
    [n, v] = part.split '='
    if not v?
      if inQS
        named[n] = true
      else
        ordered.push unescape n
    else
      named[n] = unescape v
  
  for p in @params
    if (v = named[p.name])?
      #if inQS and v.match ',' then v = v.split ','
    else
      if p.explode
        if ordered.length then v = ordered; ordered = null
        else v = named; named = null
      else
        v = ordered.shift()
    return false unless v or inQS
    if p.extended
      aliases[p.name] = p.extended
    vars[p.name] = v or []
  remaining = input.substring len
  remaining + qs

