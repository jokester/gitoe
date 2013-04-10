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
    id_canvas = $(@selectors.canvas).attr("id")
    id_canvas or throw "canvas not found"
    @canvas = new GitoeCanvas id_canvas, { }

  init_repo: ()->
    canvas = @canvas
    @repo = new GitoeRepo {
      ajax_error    : (arg...)->
        log 'ajax_error',arg... # TODO actual error handling
      new_commit    : canvas.add_commit_async
      new_reflogs   : (arg...)->
        log 'TODO handle these new_reflogs:',arg...
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
            success: ()->     # fetch refs
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

  $("#button-open-repo").click() # TODO remove this in normal version
