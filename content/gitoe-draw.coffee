$ = jQuery or throw "demand jQuery"
R = Raphael or throw "demand Raphael"

clone = (obj)->
  $.extend({},obj)

strcmp = exports.gitoe.strcmp

class DAGLayout
  # TODO a more proper placement, for
  #   - less crossing
  #   - better looking
  #   want: referencing to position of parents
  # XXX Maybe re-layouting
  # XXX Maybe layout in layer --- how to trigger?
  constructor: (@cb)->
    # @cb:
    #   draw_node : ( id, layer, pos )

    # topo
    @children = {}  # { id: [ children ] }
    @parents  = {}  # { id: [ parents ] }

    # layout
    @layer    = {}  # { id : layer }
    @position = {}  # { id : position }
    @grid     = {}  # { layer: [ position: id ] }
    @layer_span = {}# { id : num }

  add_node: ( id, parents )=>
    @topo( id, parents )

    layer      = @get_layer( id )
    layer_span = @get_layer_span( id, layer )
    pos        = @get_position( id, layer, layer_span )

    @cb.draw_node( id, layer, pos, layer_span )

  get_layer: (id)->
    # layer = 1 + max[ parent.layer ]
    layer = 0
    for parent in @parents[id]
      parent_layer = @layer[parent]
      if parent_layer >= layer
        layer = parent_layer + 1
    @grid[layer] ?= []
    @layer[id] = layer

  get_layer_span: (id, layer)->
    layer_span = 1
    l = {}
    for parent in @parents[id]
      parent_layer = @layer[parent]
      l[parent] = parent_layer
      if parent_layer + layer_span < layer
        layer_span = layer - parent_layer
    @layer_span[id] = layer_span

  get_position: ( id, layer, layer_span )->
    # first appropriate position,
    #   which
    #   - is not occupied, on layers of <id> and all fake nodes
    #   - TODO and preferably shorten edges
    position   = -1
    conflict   = true
    layers_to_check = [(layer-layer_span+1)..(layer)]
    grid = @grid
    while conflict
      position++
      occupied = layers_to_check.filter (layer)->
        grid[layer][position]
      if occupied.length == 0
        conflict = false

    for layer in layers_to_check
      @grid[layer][position] = id
    @position[id] = position

  topo: ( id, parents )->
    for parent in parents
      cs = @children[ parent ]
      if cs is undefined
        throw "<#{id}> added before its parent <#{parent}>"
      else
        cs.push id
     if @parents[id]
      throw "<#{id}> added more than once"
    @parents[id]  = parents
    @children[id] = []

  query_parents: (id)=>
    @parents[id]
  query_pos: (id)=>{
    layer  : @layer[id]
    pos    : @position[id]
  }

class GitoeCanvas
  @CONST  : {
    canvas: {
      width : 300
      height: 100
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

  constructor: ( id_container )->
    @dag = new DAGLayout(draw_node: @draw_async)
    @constant = clone GitoeCanvas.CONST
    @init_canvas( id_container )
    @objs = {}     # { sha1 : canvas objs }
    @div = $("##{id_container}")
    @ref_objs = {} # { ref_name: canvas objs }

  add_commit_async: (commit)=>
    setTimeout( @add_commit.bind( @, commit )  , 500 )

  draw_async: (sha1, layer, pos)=>
    setTimeout( @draw.bind( @,sha1,layer,pos ), 0 )

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
    need_focus = !!(@canvas_inc_height(coord.top) + @canvas_inc_width(coord.left) )
    if need_focus
      @focus(coord)
    @objs[sha1] = {
      commit_box : commit_box
      text       : text
      paths      : paths
    }

  clear_refs: ()->
    for ref_name, objs of @ref_objs
      for obj in (objs or [])
        obj.remove()

  set_refs: (refs)->
    # refs: { ref_name : [ sha1 ] }
    @clear_refs()
    # console.log refs

    ref_names_sorted = Object.keys(refs).sort( strcmp )

    for ref_name, ref_index in ref_names_sorted
      @ref_objs[ ref_name ] = @draw_ref( ref_index, ref_name, refs[ref_name] )

  draw_ref: ( ref_index, ref_name, sha1s )-> # [ canvas objs ]
    # TODO
    sha1_last = sha1s[ sha1s.length - 1 ]
    p_last = @dag.query_pos(sha1_last)
    coord_last = @commit_coord( p_last.layer, p_last.pos )
    @focus @commit_coord( p_last.layer, p_last.pos )
    [
      @draw_ref_path( ref_index, sha1s )
      @draw_ref_text( ref_index, coord_last, ref_name )
      @draw_ref_pointer( ref_index, coord_last )
    ]

  draw_ref_pointer: ( ref_index, p_last )->
    @canvas.path(

    )

  draw_ref_text: ( ref_index, coord_last, ref_name )->
    console.log ref_index, coord_last, ref_name
    @canvas.text(
      coord_last.left + @constant.box.width + (0.6+ref_index) * 30 + ref_name.length * 2,
      coord_last.top  + @constant.box.height * (1+ref_index)/3
      ref_name
    ).attr(@constant.text_attr)

  draw_ref_path: ( ref_index, sha1s, textbox_width )-> # path
    command_array = []
    current = prev = null
    handler_top = @constant.box.height * (1+ref_index)/3
    for sha1, index in sha1s
      prev = current
      current = @commit_coord_by_sha1( sha1 )
      if index is 0 # first comit in path
        command_array.push [
          'M'
          current.left + @constant.box.width
          current.top + handler_top
        ]...
      else
        command_array.push [
          'Q'
          50 + ref_index * 40 + @constant.box.width + Math.max(current.left, prev.left)
          (current.top + prev.top)/2 + handler_top - 35
          @constant.box.width + current.left
          current.top + handler_top
        ]...
    @canvas.path(command_array.join(' '))

  commit_coord: (layer,pos)->{
    # left and top coord of commit-box
    left: (@constant.padding_left + @constant.outer_width  * pos)
    top : (@constant.padding_top  + @constant.outer_height * layer)
  }
  commit_coord_by_sha1: (sha1)->
    p = @dag.query_pos(sha1)
    @commit_coord( p.layer, p.pos )

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
      sha1[0..7]
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
      path_command = @path_command(coord, coord_p)
      if path_command
        paths.push @canvas.path( start + path_command )
    paths

  path_command: ( coord, coord_p )->
    # command string to draw path,
    # ref http://www.w3.org/TR/SVG/paths.html#PathDataLinetoCommands
    bottom_of_parent = {
      x: coord_p.left + @constant.box.width / 2
      y: coord_p.top  + @constant.box.height
    }
    top_of_highest_fake_node = {
      x: coord.left  + @constant.box.width / 2
      y: coord_p.top + @constant.outer_height
    }
    if coord.left == coord_p.left # same column
      [
        'L'
        bottom_of_parent.x
        bottom_of_parent.y
      ].join ' '
    else
      vertical_distance = @constant.outer_height - @constant.box.height
      ratio = 0.3
      [
        'L'
        top_of_highest_fake_node.x
        top_of_highest_fake_node.y
        'C'
        top_of_highest_fake_node.x
        @mix( top_of_highest_fake_node.y, bottom_of_parent.y , ratio)
        bottom_of_parent.x
        @mix( top_of_highest_fake_node.y, bottom_of_parent.y , 1-ratio)
        bottom_of_parent.x
        bottom_of_parent.y
      ].join ' '

  mix: (a,b,ratio)->
    a*ratio + b*(1-ratio)
  focus: (coord)->
    @div.scrollTo {
      left: coord.left - 200
      top : coord.top  - 200
    }

  init_canvas: (id_canvas)->
    @canvas_size = clone @constant.canvas
    @canvas = R(
      id_canvas,
      @canvas_size.width,
      @canvas_size.height
    )

  canvas_inc_width: (left)->
    if left + @constant.outer_width > @canvas_size.width
      @canvas_size.width += 1*@constant.outer_width
      @canvas_resize()
      true
    else
      false
  canvas_inc_height: (top)->
    if top + @constant.outer_height > @canvas_size.height
      @canvas_size.height += 1*@constant.outer_height
      @canvas_resize()
      true
    else
      false
  canvas_resize: ()->
    @canvas.setSize(
      @canvas_size.width,
      @canvas_size.height,
    )

@exports ?= { gitoe: {} }
exports.gitoe.GitoeCanvas = GitoeCanvas
