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
    #   open_success  :()->
    #   open_fail     :()->
    #   status        :(string)->
    # TODO change to support ordered cache
    @commits_by_sha1 = {}

  open: (path,cb)=>
    # open_cb:
    #   success: ()->
    #   fail   : ()->
    $.post("#{repo_root}/new",{path: path})
      .fail(@ajax_error,open_cb.fail)
      .done(@ajax_open_success, open_cb.success)

  fetch: (external_cb)=>
    self = @
    self.fetch_commits ()->
      self.fetch_refs ()->
        external_cb?()

  fetch_commits: (after_fetch_commits)->
    throw "not opened" unless @path
    # TODO only fetch new commits
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
    @canvas = $("##{id_canvas}") or throw "##{id_control} not found"

class GitoeController

  constructor: (selectors)->
    @init_repo()
    #@init_vis(selectors)
    @init_control_repo(selectors.repo)

  init_repo: ()->
    @repo = new GitoeRepo()

  init_vis:(id_canvas)->
    @vis = new GitoeCanvas( id_canvas , {} )

  init_control_repo: (selector)->
    control_repo = $(selector)
    unless control_repo.length > 0
      throw "'#{selector}' not found"
    find = (s)-> control_repo.find(s)
    find('#button-open-repo').on 'click',->
      flash "opening #{find('#input-repo-path').val()}"

  open_repo: ()=>
    path = @control.input_repo_path.val()
    @repo.open(path, @open_repo_success)

  open_repo_success: (response)=>
    log response
    flash "opened repository #{response.path}"

@gitoe =
  Repo: GitoeRepo

$ ->
  ids = {
    repo: '#control-repo'
  }
  c = new GitoeController( ids )
  #flash 'hello'
