$ = jQuery
F = fabric

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

repo_root = "/repo"

class GitoeRepo
  constructor: (@cb={})->
    # @cb: triggered unconditionally
    #   ajax_error    :(jqXHR)->
    #   new_commit    :(commit)->
    #   new_reflog    :(reflogs)->
    @commits_by_sha1 = {}
  open: (path,after_open)=>
    $.post("#{repo_root}/new",{path: path})
      .fail(@ajax_error)
      .done(@ajax_open_success, after_open)
  fetch: (external_cb)=>
    self = @
    self.fetch_commits ()->
      self.fetch_refs ()->
        external_cb?()
  fetch_commits: (after_fetch_commits)->
    throw "not opened" unless @path
    $.get("#{@path}/commits")
      .fail(@ajax_error)
      .done(@ajax_fetch_commits_success, after_fetch_commits)
  fetch_refs: (after_fetch_refs)->
    $.get("#{@path}/")
      .fail(@ajax_error)
      .done(@ajax_fetch_refs_success, after_fetch_refs)
  ajax_open_success: (json)=>
    throw "already opened" if @path
    @path = "#{repo_root}/#{json.id}"
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
    @new_commit(new_commits)
  ajax_fetch_refs_success: (json)=>
    @new_reflog json
  ajax_error: (jqXHR)=>
    flash JSON.parse(jqXHR.responseText).error_message
  new_commit: (commits)=>
    @cb.new_commit?( commits )
  new_reflog: (reflogs)=>
    @cb.new_reflog?( reflogs )


class GitoeCanvas
  constructor: ( id_canvas, @cb )->

class GitoeController
  constructor: (id_control, id_canvas)->
    @init_repo()
    @init_vis(id_canvas)
    @init_control(id_control)
  init_repo: ()->
    @repo = new Repo()
  init_vis:(id_canvas)->
    @vis = new Vis( id_canvas , {} )
  init_control: (id_control)->
    control = $("##{id_control}") or throw "##{id_control} not found"
    input_repo_path = $("<input>")
      .attr( "value", "/home/mono/config" )
    button_open_repo = $("<button>")
      .text("OPEN")
      .on("click", @open_repo)
    control.append( input_repo_path, button_open_repo )
    @control =
      parent          : control
      input_repopath  : repo_path
      button_openrepo : button_openrepo
  open_repo: (path)=>
    @repo.open path
  open_repo_success: ()=>

@gitoe =
  Repo: GitoeRepo

$ ()->
  window.a = new GitoeRepo {
    new_commit: (commits)->
    new_reflog: ->
  }
