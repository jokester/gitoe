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

GitoeRepo   = @exports.gitoe.GitoeRepo   or throw "GitoeRepo not found"
GitoeCanvas = @exports.gitoe.GitoeCanvas or throw "GitoeCanvas not found"

class GitoeController
  constructor: (@selectors)->
    @init_canvas()
    @init_repo()
    @init_control()
    @init_control_repo()

  init_canvas:()->
    id_canvas = $(@selectors.canvas.canvas).attr("id")
    id_canvas or throw "canvas not found"
    div = $(@selectors.canvas.root)
    @canvas = new GitoeCanvas id_canvas, div, { }

  init_repo: ()->
    @repo = repo = new GitoeRepo()
    update = @update_control_repo_status
    repo.set_cb {
      ajax_error     : (arg...)->
        log 'ajax_error',arg... # TODO actual error handling

      fetched_commit : (to_fetch, fetched)->
        update 'commits', fetched + to_fetch
        flash "#{to_fetch} commits to fetch", 1000
        if to_fetch > 0
          repo.fetch_commits()

      yield_commit : @canvas.add_commit_async

      yield_reflogs   : ( refs )->
        log 'TODO handle these new_reflogs:', refs
        #for to_update in [
        #  'local_branches'
        #  'remote_branches'
        #  'tags'
        #]
        #  update to_update, Object.keys(refs[to_update]).length
      yield_history: log
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
        fail:    (wtf)->
          flash "error opening #{repo_path}"
        success: (response)-> # open success

          update 'path', response.path
          repo.fetch_status {
            success: (response)-> # got status

              flash "opened #{repo_path}", 2000
              $(s.root).hide()
              for other in [
                'repo_status'
                'refs'
                'history'
              ]
                $(s_all[other].root)
                  .slideDown()
              repo.fetch_commits()
          }
      }

  update_control_repo_status: (key,value)=>
    unless @selectors.repo_status[key]
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
      root           : '#control-repo_status'
      path           : '#control-repo_status .path'
      commits        : '#control-repo_status .commits'
      tags           : '#control-repo_status .tags'
      local_branches : '#control-repo_status .local.branches'
      remote_branches: '#control-repo_status .remote.branches'
    }
    refs: {
      root: '#control-refs'
    }
    history: {
      root: '#control-history'
    }
    canvas:  {
      root:   "#canvas-container"
      canvas: "#graph"
    }
  }

  c = new GitoeController( ids )

  $("#button-open-repo").click() # TODO remove this in normal version
