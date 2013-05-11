$ = jQuery or throw "demand jQuery"

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

GitoeHistorian   = @exports.gitoe.GitoeHistorian or throw "GitoeHistorian not found"
GitoeRepo   = @exports.gitoe.GitoeRepo   or throw "GitoeRepo not found"
GitoeCanvas = @exports.gitoe.GitoeCanvas or throw "GitoeCanvas not found"

class GitoeUI

  constructor: ( id )->
    @historian = new GitoeHistorian()
    @cb = {}
    @root = $( "##{ id }" )
    @init_dom()
    @bind_events()

  set_cb: (new_cb)->
    #   repo_open     : ( path )->
    for name, fun of new_cb
      @cb[name] = fun

  init_dom: ()->
    cb = @cb
    @sections = {}
    @elems = {}

    repo_address = @elems.repo_address = $("<input>").val("/home/mono/config")
    @elems.repo_open    = $("<input>").attr( type: "button" ).val("open").on "click", ->
      cb.repo_open? repo_address.val()
    @elems.status  = $("<ul>")
    @elems.history = $("<ul>")

    @root.append [
      @sections.open = $("<div>").append [
        $("<h3>").text("open repo")
        $("<hr>")
        @elems.repo_address
        @elems.repo_open
      ]
      @sections.status = $("<div>").hide().append [
        $("<h3>").text("status")
        $("<hr>")
        @elems.status
      ]
      @sections.history= $("<div>").hide().append [
        $("<h3>").text("history")
        $("<hr>")
        @elems.history
      ]
    ]

  open_success: ()->
    @slideUp "open"
    @slideDown "status"
    @slideDown "history"

  update_status: ( status )=>
    console.log status

  update_reflog: (changes)=>
    cb = @cb
    return
    list_branches = @elem "branches", "list"
    list_changes  = @elem "history",  "list"
    list_branches.empty()
    list_changes.empty()
    for change in changes
      list_changes.append

    console.log reflogs

  slideDown: (section)=>
    @section( section ).slideDown()
  slideUp: (section)->
    @section( section ).slideUp()

  section: (name)->
    @sections[ name ]

  elem: (name)->
    @elems[ name ]

  bind_events: ()->
    cb              = @cb

    @historian.set_cb {
      update_reflog: @update_reflog
    }

class GitoeController
  constructor: ( ids )->
    @init_repo()
    @init_historian()
    # @init_canvas( ids.graph )
    @init_control( ids.control )
    @bind_events()

  init_repo: ()->
    @repo = new GitoeRepo()

  init_historian: ()->

  init_canvas:( id )->
    @canvas = new GitoeCanvas id

  init_control: ( id )->
    @ui = new GitoeUI( id )

  bind_events: ()->
    repo      = @repo
    canvas    = @canvas
    ui        = @ui

    repo.set_cb {
      ajax_error      : (arg...)->
        log 'ajax_error',arg... # TODO actual error handling

      fetched_commit  : (to_fetch, fetched)->
        flash "#{to_fetch} commits to fetch", 1000
        if to_fetch > 0
          repo.fetch_commits()
        else
          repo.fetch_alldone()

      fetch_status    : (status)->
        repo.fetch_commits()

      yield_commit    : ()-> #canvas.add_commit_async
    }

    ui.set_cb {
      repo_open : (path)->
        flash "opening #{path}",false
        repo.open path, {
          fail:    (wtf)->
            flash "error opening #{path}"
          success: (response)-> # opened
            flash "opened #{path}", 2000

            repo.fetch_status {
              success: ( status )->
                ui.open_success()
                ui.update_status( status )
            }
        }
      show_change: (fun)->
        fun( canvas )
    }

$ ->
  ids = { # todo move this to Controller class
    control: 'control'
    graph:   'graph'
  }

  c = new GitoeController( ids )
