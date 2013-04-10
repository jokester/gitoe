$ = jQuery or throw "demand jQuery"
fabric or throw "demand fabric.js"

log = (args...)->
  console.log(args...)

flash = do->
  flash_counter = 0
  (text,delay=5000)->
    # delay :: number      -> clear flash after x ms
    #          unspecified -> clear flash after (default) ms
    #          false       -> do not clear
    flash_div = $("#flash")
    current_counter = ++flash_counter
    clear = ()->
      if current_counter==flash_counter
        flash_div.text("")
    flash_div.text(text)
    setTimeout(clear, delay) if delay

url_root = "/repo"
class GitoeRepo
  constructor: (@cb={})->
    # @cb: triggered unconditionally
    #   ajax_error    :(jqXHR)->
    #   new_commits   :(commit)->
    #   new_reflogs   :(reflogs)->
    #   status        :(string)->
    # TODO change to support ordered cache
    @commits = {}

  open: (path,cb)=>
    # cb:
    #   success: ()->
    #   fail   : ()->
    $.post("#{url_root}/new",{path: path})
      .fail(@ajax_error, cb.fail)
      .done(@ajax_open_success, cb.success)

  fetch_commits: (cb)->
    # cb:
    #   success: ()->
    #   fail   : ()->
    throw "not opened" unless @path
    # TODO only fetch new commits
    $.get("#{@path}/commits")
      .fail(@ajax_error, cb.fail)
      .done(@ajax_fetch_commits_success, cb.success)

  fetch_refs: (cb)->
    # cb:
    #   success: ()->
    #   fail   : ()->
    $.get("#{@path}/")
      .fail(@ajax_error, cb.fail)
      .done(@ajax_fetch_refs_success, cb.success)

  ajax_open_success: (json)=>
    throw "already opened" if @path
    @path = "#{url_root}/#{json.id}"
    @cb.open_success?()

  ajax_fetch_commits_success: (json)=>
    new_commits = {}
    for commit_no,content of json.commits
      if not @commits[ commit_no ]
        new_commits[ commit_no ] = content
        @commits[ commit_no ] = true
    @cb.new_commits?( new_commits )

  ajax_fetch_refs_success: (response)=>
    @cb.new_reflogs?( response.status.refs )

  ajax_error: (jqXHR)=>
    flash JSON.parse(jqXHR.responseText).error_message

class GitoeCanvas
  @constant  : {
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
    @constant = GitoeCanvas.constant
    @commits = {}   # { sha1 : content }

    # topo
    @children = {}  # { sha1 : [ children ] }

    # layout
    @layer    = {}  # { sha1 : layer }
    @position = {}  # { sha1 : position }
    @grid     = {}  # { layer: { sha1: position } }

  add_commit: (commit)->
    throw "already added <#{commit.sha1}>" if @commits[commit.sha1]
    @commits[commit.sha1] = commit
    @children[commit.sha1] = []
    for parent in commit.parents
      @children[parent].push commit
    @place(commit)

  draw_group: (sha1)->
    layer = @layer[sha1]
    pos   = @position[sha1]
    #log { layer: layer, pos: pos}
    group = new fabric.Group [], {
      left : (1+layer) * @constant.outer_width
      top  : pos   * @constant.outer_height
    }
    inner = @draw_commit(sha1)
    group.add(inner)
    @fab.add(group)

    @fab.add group
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



class GitoeController
  constructor: (@selectors)->
    @init_canvas()
    @init_repo()
    @init_control()
    @init_control_repo()

  init_canvas:()->
    id_canvas = $(@selectors.canvas).attr("id")
    id_canvas or throw "canvas not found"
    @canvas = new GitoeCanvas id_canvas, { }

  init_repo: ()->
    canvas = @canvas
    @repo = new GitoeRepo {
      ajax_error    : (arg...)->
        log 'ajax_error',arg... # TODO actual error handling
      new_commits   : (commits)->
        commit_nos =
          Object.keys(commits)
          .map( (str)-> parseInt str )
          .sort( (a,b)-> a-b )
        for commit_no in commit_nos
          commit = commits[commit_no]
          du = do (commit,commit_no)->()->
            @add_commit commit
            @place      commit
            @draw_group commit.sha1
            flash "drawing commit #{commit_no}/#{commit_nos.length}",1
          setTimeout(du.bind(canvas),0)
      new_reflogs   : (arg...)->
        log 'TODO hand these new_reflogs:',arg...
    }

  init_control: ()=>
    for to_hide in [
      'repo_status'
      'refs'
      'history'
    ]
      $(@selectors[to_hide].root)
        .hide()

  init_control_repo: ()->
    # binding
    repo = @repo
    s = @selectors.repo_open
    s_all = @selectors
    update = @update_control_repo_status

    $(s.button_open).on 'click',->
      repo_path = $(s.input_repo_path).val()
      flash "opening #{repo_path}",false
      repo.open repo_path, {
        success: (response)-> # fetch commits
          update 'path', response.path
          repo.fetch_commits {
            success: ()-> # fetch refs
              repo.fetch_refs {
                success: (response)->
                  update 'commits', response.status.commits
                  update 'branches', \
                    Object.keys(response.status.refs).length
                  flash "successfully loaded #{repo_path}",1000
                  $(s.root).hide()
                  for other in [
                    'repo_status'
                    'refs'
                    'history'
                  ]
                    $(s_all[other].root)
                      .slideDown()
              }
            }
      }

  update_control_repo_status: (key,value)=>
    unless key in [
      'path'
      'commits'
      'branches'
    ]
      throw "illigal key '#{key}'"
    $(@selectors.repo_status[key]).text(value)

$ ->
  ids = {
    repo_open:   {
      root           : '#control-repo_open'
      button_open    : '#button-open-repo'
      input_repo_path: '#input-repo-path'
    }
    repo_status: {
      root: '#control-repo_status'
      path: '#control-repo_status .path'
      commits: '#control-repo_status .commits'
      branches: '#control-repo_status .branches'
    }
    refs: {
      root: '#control-refs'
    }
    history: {
      root: '#control-history'
    }
    canvas:  "#graph"
  }
  c = new GitoeController( ids )

  # TODO remove this in normal version
  $("#button-open-repo").click()
