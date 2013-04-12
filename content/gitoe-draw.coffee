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
    if @parents[id]
      throw "<#{id}> added more than once"
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
    @position[id] = pos

  query_parents: (id)=>
    @parents[id]
  query_pos: (id)=>{
    layer  : @layer[id]
    pos    : @position[id]
  }

class GitoeCanvas
  @CONST  : {
    canvas_width : 2000
    canvas_height: 1200
    padding_left: 60
    padding_top : 40
    outer_width : 80
    outer_height: 60
    commit_handle: 10
    box_style: {
      width:  60
      height: 20
      fill: "transparent"
      strokeWidth: 1
      stroke: 'blue'
    }
    text_style: {
      fontFamily: 'mono'
      fontSize: 11
    }
    path_style: {
      fill: 'pink'
      strokeWidth: 3
    }
  }

  constructor: ( id_canvas, @div, @cb )->
    @dag = new DAGLayout(draw_node: @draw_async)
    @constant = GitoeCanvas.CONST
    @init_canvas(id_canvas)
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
    @dag.add_node( commit.sha1, commit.parents )

  draw: (sha1,layer,pos)->
    if @objs[sha1]
      @destroy sha1
    objs = @objs[sha1] = []
    parents = @dag.query_parents(sha1).map( @dag.query_pos )
    group = @draw_group(sha1,layer,pos)
    commit = @draw_commit(sha1)
    paths = @draw_paths(layer,pos,parents)

    for from in [commit,paths]
      for obj in from
        objs.push obj
        group.add obj

    objs.push   group
    @canvas.add group

  draw_group: (sha1,layer,pos)->
    group_pos = {
      left : @constant.padding_left + layer * @constant.outer_width
      top  : @constant.padding_top + pos * @constant.outer_height
    }
    if group_pos.left > @canvas_width
      @canvas_inc_width()
      scroll = true
    if group_pos.top > @canvas_height
      @canvas_inc_height()
      scroll = true
    if scroll
      @div.scrollTo {
        left: group_pos.left - 200
        top: group_pos.top - 200
      }
    group = new fabric.Group([], group_pos)

  draw_commit: (sha1)->
    rect = new fabric.Rect @constant.box_style
    text = new fabric.Text sha1[0..7], @constant.text_style
    [rect, text]

  draw_paths: (layer,pos,parents_pos)->
    paths = []
    for p in parents_pos
      # the line
      coord_sets = []
      coord_sets.push [
        - @constant.inner_width / 2
        0
        - (@constant.inner_width / 2 + @constant.commit_handle)
        0
      ] # handle
      coord_sets.push [
        - (@constant.inner_width / 2 + @constant.commit_handle)
        0
        -(layer - p.layer) * @constant.outer_width + @constant.inner_width/2
        -(pos - p.pos) * @constant.outer_height
      ] # the path
      for coords in coord_sets
        paths.push(new fabric.Line coords, @constant.path_style)
    paths

  destroy: (sha1)->
    # TODO remove sha1's related fabric objects

  init_canvas: (id_canvas)->
    canvas = new fabric.Canvas id_canvas, {
      interactive: false
      selection: false
    }
    canvas.on 'mouse:down', (options,target)->
      console.log canvas.getPointer(options.e)
    @canvas_height = @constant.canvas_height
    @canvas_width  = @constant.canvas_width
    canvas.setHeight @canvas_height
    canvas.setWidth  @canvas_width
    @canvas = canvas

  canvas_inc_width: ()->
    console.log 'inc width'
    @canvas.setWidth  @canvas_width *= 1.2
  canvas_inc_height: ()->
    console.log 'inc height'
    @canvas.setHeight @canvas_height *= 1.2
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
