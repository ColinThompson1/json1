util = require 'util'
# Simple idea: Think of the process in a set of phases which happen in order:
#
# First the pickup phase marks objects for pickup. After the pickup phase runs,
# we go through and pick up all the objects. (Notably, you can still decend
# into picked up objects after marking them during the pickup phase).
#
# Then maybe we have an edit phase where we make all the normal edits.
#
# Finally we have a drop phase where we go through and insert back all the
# things we picked up.

mappingChild = (mapping, key) ->
  if typeof key is 'number'
    mapping.clist ||= []
    mapping.clist[key] ||= {}
  else
    mapping.cobj ||= {}
    mapping.cobj[key] ||= {}

fillMapping = (mapping, path, fn) ->
  stack = []

  for c in path
    #console.log 'at', container, 'looking at', key
    value = c.v
    switch c.t
      when 'in'
        stack.push {mapping, value}
        # Decend
        mapping = mappingChild mapping, value

      when 'skip'
        throw Error 'Cannot skip at root' unless stack.length
        topstack = stack[stack.length - 1]
        {mapping:parent, value:prevValue} = topstack

        if typeof c.v is 'number'
          value += prevValue
        else
          throw Error 'invalid skip' unless value > prevValue

        mapping = mappingChild parent, value
        topstack.value = value

      when 'out'
        value ||= 1
        {mapping} = stack.pop() for [0...value]

      else
        fn mapping, c

  return


opToMap = (op) ->
  map = {}

  pickups = [] # map from pickup id -> pickup mapping.
  fillMapping map, op.pick, (mapping, {t, v}) ->
    if t is 'pickup'
      mapping.pickid = pickups.length
      pickups.push(mapping) - 1 # push returns new length
    else if t is 'del'
      mapping.del = true

  fillMapping map, op.drop, (mapping, {t, v}) ->
    if t is 'drop'
      pickMap = pickups[v]
      throw Error "Component #{v} already dropped" unless pickMap
      pickups[v] = null
      mapping.dropid = v

      #pickMap.moveTo = mapping
      #mapping.moveFrom = pickMap
    else if t is 'insert'
      mapping.insert = v

  console.log util.inspect map, depth:10, colors:true
  return map


C = (type, value) -> {t:type, v:value}

#apply {x:5, y:[10,11,12]},
#  pick:[C('in', 'x'), C('pickup'), C('skip', 'y'), C('in', 1), C('pickup')]
#  drop:[C('in', 'a'), C('drop', 1), C('skip', 'z'), C('drop', 0)]


# {x:5, y:[10,11,12]} -> {a:11, z:5, y:[10,11,12]}
opToMap
  pick:[C('in', 'x'), C('pickup'), C('skip', 'y'), C('in', 1), C('pickup')]
  drop:[C('in', 'a'), C('drop', 1), C('skip', 'z'), C('drop', 0)]


# Swap items
#apply {x:{y:5}},
opToMap
  pick: [C('in','x'), C('pickup'), C('in', 'y'), C('pickup')]
  drop: [C('in','y'), C('drop',1), C('in', 'x'), C('drop',0)]


# Swap items
#console.log {x:{y:{was:'y'}, was:'x'}}
#apply {x:{y:{was:'y'}, was:'x'}, was:'root'},
#  pick: [C('in','x'), C('pickup'), C('in', 'y'), C('pickup')]
#  drop: [C('in','x'), C('drop',1), C('in', 'y'), C('drop',0)]

