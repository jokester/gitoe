$ = jQuery or throw "demand jQuery"
fabric or throw "demand fabric.js"

class DAGLayout
  constructor: (@cb)->
    # @cb:
    #   init_node : (id, layer,     pos    )
    #   move_point: (id, new_layer, new_pos)
    @children = {}
    @parents  = {}
  add_node: (id, parents)->
    #








class GitoeCanvas
  @CONST  : {
    inner_width : 4
    inner_height: 10
    outer_width : 9
    outer_height: 20
  }
  constructor: ( id_canvas, @cb )->
    @fab = new fabric.Canvas id_canvas, {
      # TODO find a way, to make @fab not *interactive*
      a: 1
    }
    @fab.setHeight 600
    @fab.setWidth 900
    @constant = GitoeCanvas.CONST
    @commits = {}   # { sha1 : content }

    # topo
    @children = {}  # { sha1 : [ children ] }

    # layout
    @layer    = {}  # { sha1 : layer }
    @position = {}  # { sha1 : position }
    @grid     = {}  # { layer: { sha1: position } }

  add_commit_async: (commit)=>
    setTimeout( @add_commit.bind( @, commit )  ,0 )

  add_commit: (commit)->
    throw "already added <#{commit.sha1}>" if @commits[commit.sha1]
    @commits[commit.sha1] = commit
    @children[commit.sha1] = []
    for parent in commit.parents
      @children[parent].push commit
    @place(commit)
    @draw_group(commit.sha1)

  draw_group: (sha1)->
    layer = @layer[sha1]
    pos   = @position[sha1]
    group = new fabric.Group [], {
      left : (1+layer) * @constant.outer_width
      top  : (1+pos )  * @constant.outer_height
    }
    inner = @draw_commit(sha1)
    group.add(inner)
    @fab.add(group)

  draw_commit: (sha1)->
    rect = new fabric.Rect {
      width:  @constant.inner_width
      height: @constant.inner_height
      right: 0
      top : 0
      fill: "blue"
    }

  place: (commit)->
    layer_no = @layer[commit.sha1] \
      = @layer_no commit
    @grid[layer_no] ?= {}
    @position[commit.sha1] = @grid[layer_no][commit.sha1] \
      = @position_of(commit, layer_no)

  layer_no: (commit)->
    # layer = 1 + max[ parent.layer ]
    layer_no = 0
    for parent in commit.parents
      parent_layer = @layer[parent]
      unless isFinite(parent_layer)
        throw "illegal layer for parent"
      if parent_layer >= layer_no
        layer_no = parent_layer + 1
    layer_no
  position_of: (commit,layer_no)->
  # TODO a more proper placement, for
  #   - less crossing
  #   - better looking
  #   want: referencing to position of parents
    existing_commits = Object.keys( @grid[layer_no] )
    existing_commits.length

@exports ?= { gitoe: {} }
exports.gitoe.GitoeCanvas = GitoeCanvas
