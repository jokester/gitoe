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

  constructor: (@selectors)->
    @cb = {}
    for to_hide in [ "status", "refs", "history" ]
      @section(to_hide).hide()
    @bind_events()

  set_cb: (new_cb)->
    #   repo_open     : ( path )->
    for name, fun of new_cb
      @cb[name] = fun

  update_status: (key,value)=>
    unless @selectors.status[key]
      throw "illigal key '#{key}'"
    # console.log key,value
    $(@selectors.status[key]).text(value)

  slideDown: (section)=>
    @section( section ).slideDown()
  slideUp: (section)->
    @section( section ).slideUp()

  section: (name)->
    $( @selectors[name].here )

  elem:    (section, name)->
    selector = [
      @selectors.here
      @selectors[section].here
      @selectors[section][name]
    ].join( " " )
    selected = $(selector)
    if selected.length != 1
      throw "<#{selector}> gives #{selected.length} results"
    else
      selected

  bind_events: ()->
    cb              = @cb
    input_repo_path = @elem "open", "path"
    btn_repo_open   = @elem "open", "open"
    btn_repo_open.on "click", ()->
      path = input_repo_path.val()
      cb.repo_open? path

class GitoeController
  constructor: (selectors)->
    @init_repo()
    @init_historian()
    @init_canvas( selectors.canvas.id, selectors.canvas.here )
    @init_control( selectors.control )
    @bind_events()

  init_repo: ()->
    @repo = new GitoeRepo()

  init_historian: ()->
    @historian = new GitoeHistorian

  init_canvas:( id_canvas, canvas_container )->
    @canvas = new GitoeCanvas id_canvas, canvas_container, { }

  init_control: ( selectors_in_control )->
    @control = new GitoeUI( selectors_in_control )

  bind_events: ()->
    repo      = @repo
    canvas    = @canvas
    historian = @historian
    control   = @control

    repo.set_cb {
      ajax_error      : (arg...)->
        log 'ajax_error',arg... # TODO actual error handling

      fetched_commit  : (to_fetch, fetched)->
        control.update_status 'commits', fetched + to_fetch
        flash "#{to_fetch} commits to fetch", 1000
        if to_fetch > 0
          repo.fetch_commits()
        else
          repo.fetch_alldone()

      fetch_status    : (status)->
        repo.fetch_commits()
        historian.parse status.refs
        control.update_status "path", status.path

      yield_commit    : canvas.add_commit_async

    }

    control.set_cb {
      repo_open : (path)->
        flash "opening #{path}",false
        repo.open path, {
          fail:    (wtf)->
            flash "error opening #{path}"
          success: (response)-> # opened
            flash "opened #{path}", 2000
            control.slideUp "open"
            repo.fetch_status {
              success: ()->
                control.slideDown "status"
                control.slideDown "refs"
                control.slideDown "history"
            }
        }
    }
    historian.set_cb {
      update_status: control.update_status
      local_reflog : log
    }

$ ->
  selectors = {
    control:  {
      here: '#control'
      open:   {
        here : '.open'
        path : '.path'
        open : '.open-btn'
      }
      status: {
        here           : '.status'
        path           : '.path'
        commits        : '.commits'
        tags           : '.tags'
        local_branches : '.local.branches'
        remote_branches: '.remote.branches'
        remote_repos: '.remote.repos'
      }
      refs: {
        here           : '.refs'
      }
      history: {
        here           : '.history'
        list           : 'ul'
      }
    }
    canvas:  {
      here             : '#canvas-container'
      id               : 'graph'
    }
  }

  c = new GitoeController( selectors )

  $( selectors.control.open.open ).click() # TODO remove this in normal version
