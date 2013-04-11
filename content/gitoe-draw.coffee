$ = jQuery or throw "demand jQuery"
fabric or throw "demand fabric.js"

class DAGLayout
  # TODO a more proper placement, for
  #   - less crossing
  #   - better looking
  #   want: referencing to position of parents
  constructor: (@cb)->
    # @cb:
    #   draw_node : (id, layer, pos)
    #   move_node : (id, layer, pos) # TODO yet

    # topo
    @children = {}  # { id: [ children ] }
    @parents  = {}  # { id: [ parents ] }

    # layout
    @layer    = {}  # { id : layer }
    @position = {}  # { id : position }
    @grid     = {}  # { layer: { id: position } }

  add_node: (id, parents)=>
    for parent in parents
      cs = @children[parent]
      if cs is undefined
        throw "<#{id}> added before its parent <#{parent}>"
      else
        cs.push id
    @parents[id]  = parents
    @children[id] = []
    layer = @layer_of(id)
    pos   = @position_of(id,layer)
    @cb.draw_node(id,layer,pos)

  layer_of: (id)->
    # layer = 1 + max[ parent.layer ]
    layer_no = 0
    for parent in @parents[id]
      parent_layer = @layer[parent]
      if parent_layer >= layer_no
        layer_no = parent_layer + 1
    @layer[id] = layer_no

  position_of: ( id, layer )->
    @grid[layer] ?= {}
    existing_commits = Object.keys( @grid[layer] )
    pos = existing_commits.length
    @grid[layer][id] = pos


class GitoeCanvas
  @CONST  : {
    canvas_width : 2000
    canvas_height: 1200
    inner_width : 12
    inner_height: 10
    outer_width : 20
    outer_height: 16
  }
  constructor: ( id_canvas, @cb )->
    @dag = new DAGLayout {
      draw_node: @draw_async
    }
    @constant = GitoeCanvas.CONST
    @init_canvas(id_canvas)
    @commits = {}   # { sha1 : content }
    @objs = {}      # { sha1 : fabric objs }

  add_commit_async: (commit)=>
    setTimeout( @add_commit.bind( @, commit )  ,0 )

  draw_async: (sha1, layer, pos)=>
    setTimeout( @draw.bind(@,sha1,layer,pos),0 )

  # TODO
  # focus: (sha1)->
  # ref_on_commit: (ref)
  # ref_on_ref:    (ref1, ref2)
  add_commit: (commit)->
    if @commits[commit.sha1]
      throw "already added <#{commit.sha1}>"
    else
      @commits[commit.sha1] = true # TODO contents
      @dag.add_node( commit.sha1, commit.parents )

  draw: (sha1,layer,pos)->
    group_pos = {
      left : (1+layer) * @constant.outer_width
      top  : (1+pos )  * @constant.outer_height
    }
    if group_pos.left > @canvas.getWidth()
      @canvas_inc_width()
    if group_pos.top > @canvas.getHeight()
      @canvas_inc_height()
    group = new fabric.Group [ @draw_commit sha1 ], group_pos
    @canvas.add(group)

  draw_commit: (sha1)->
    rect = new fabric.Rect {
      width:  @constant.inner_width
      height: @constant.inner_height
      right: 0
      top : 0
      fill: "blue"
    }

  init_canvas: (id_canvas)->
    @canvas = new fabric.Canvas id_canvas, {
      interactive: false
      selection: false
    }
    @canvas.setHeight @constant.canvas_height
    @canvas.setWidth  @constant.canvas_width

  canvas_inc_width: ()=>
    @canvas.setWidth  @canvas.getWidth() *(5/4)
  canvas_inc_height: ()=>
    @canvas.setHeight @canvas.getHeight()*(5/4)
  freeze: (fabric_obj)->
    attrs = [
      'lockMovementX'
      'lockMovementY'
      'lockScalingX'
      'lockScalingY'
      'lockUniScaling'
      'lockRotation'
    ]
    for attr in attrs
      fabric_obj[attr] = true
    fabric_obj



@exports ?= { gitoe: {} }
exports.gitoe.GitoeCanvas = GitoeCanvas
