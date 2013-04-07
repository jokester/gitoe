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
    @commits_by_sha1 = {}

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
    new_commits =
      sha1: []
      content: []
    for sha1,content of json.commits
      if not @commits_by_sha1[ sha1 ]
        @commits_by_sha1[ sha1 ] = content
        new_commits.sha1.push( sha1 )
        new_commits.content.push( content )
    @cb.new_commits?( new_commits )

  ajax_fetch_refs_success: (response)=>
    @cb.new_reflogs?( response.status.refs )

  ajax_error: (jqXHR)=>
    flash JSON.parse(jqXHR.responseText).error_message

class GitoeCanvas
  constructor: ( id_canvas, @cb )->
    @fab = new fabric.Canvas( id_canvas )
    @commits = {}  # { sha1 : {row,col} }
  #TODO
  add_commits: (commits)=>
    log commits

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
        canvas.add_commits commits
      new_reflogs   : (arg...)->
        log 'new_reflogs:',arg...
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
