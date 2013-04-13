$ = jQuery or throw "demand jQuery"
R = Raphael or throw "demand Raphael"

clone = (obj)->
  $.extend({},obj)

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
    canvas: {
      width : 2000
      height: 1200
    }
    padding_left: 60
    padding_top : 40
    outer_width : 80
    outer_height: 60
    commit_handle: 10
    box: {
      width:  60
      height: 20
      radius: 2
      attr: {
        fill          : "lightblue"
        "stroke-width": 2
        stroke        : 'black'
      }
    }
    text_attr: {
      'font-family': 'mono'
      'font-size': 12
    }
    path_style: {
      fill: 'pink'
      strokeWidth: 3
    }
  }

  constructor: ( id_canvas, @div, @cb )->
    @dag = new DAGLayout(draw_node: @draw_async)
    @constant = clone GitoeCanvas.CONST
    @init_canvas(id_canvas)
    @objs = {}    # { sha1 : canvas objs }

  add_commit_async: (commit)=>
    setTimeout( @add_commit.bind( @, commit )  ,0 )

  draw_async: (sha1, layer, pos)=>
    setTimeout( @draw.bind(@,sha1,layer,pos), 0 )

  # TODO
  # ref_on_commit: (ref)
  # ref_on_ref:    (ref1, ref2)
  # destroy: (sha1)->
    # remove sha1's canvas objects

  add_commit: (commit)->
    @dag.add_node( commit.sha1, commit.parents )

  draw: (sha1,layer,pos)->
    if @objs[sha1]
      @destroy sha1
    coord = @commit_coord(layer, pos)
    parents = @dag.query_parents(sha1).map( @dag.query_pos )

    commit_box = @draw_commit_box(coord)
    text = @draw_commit_text(coord, sha1)
    paths = @draw_paths(coord, parents)
    if coord.left > @canvas_size.width
      @canvas_inc_width()
      @focus(coord)
    else if coord.top > @canvas_size.height
      @canvas_inc_height()
      @focus(coord)
    @objs[sha1] = {
      commit_box: commit_box
      text: text
      paths: paths
    }

  commit_coord: (layer,pos)->{
    # left and top coord of cell
    left: (@constant.padding_left + @constant.outer_width  * pos)
    top : (@constant.padding_top  + @constant.outer_height * layer)
  }

  draw_commit_box: (coord)->
    @canvas.rect(
      coord.left,
      coord.top,
      @constant.box.width,
      @constant.box.height,
      @constant.box.radius
    ).attr(@constant.box.attr)

  draw_commit_text: (coord,sha1)->
    @canvas.text(
      coord.left + @constant.box.width/2,
      coord.top  + @constant.box.height/2,
      sha1[0..6]
    ).attr(@constant.text_attr)

  draw_paths: (coord, parents_pos)->
    paths = []
    start = [
      'M'
      coord.left + @constant.box.width/2
      coord.top
    ].join ' '
    for p in parents_pos
      coord_p = @commit_coord(p.layer, p.pos)
      path_command = start + [
        'L'
        coord_p.left + @constant.box.width/2
        coord_p.top  + @constant.box.height
      ].join ' '
      paths.push @canvas.path( path_command )
    paths

  focus: (coord)->
    @div.scrollTo {
      left: coord.left - 500
      top : coord.top  - 300
    }

  init_canvas: (id_canvas)->
    @canvas_size = clone @constant.canvas
    @canvas = R(
      id_canvas,
      @canvas_size.width,
      @canvas_size.height
    )

  canvas_inc_width: ()->
    @canvas_size.width *= 1.1
    @canvas_resize()
  canvas_inc_height: ()->
    @canvas_size.height *= 1.1
    @canvas_resize()
  canvas_resize: ()->
    @canvas.setSize(
      @canvas_size.width,
      @canvas_size.height,
    )

@exports ?= { gitoe: {} }
exports.gitoe.GitoeCanvas = GitoeCanvas
