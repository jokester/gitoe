$ = jQuery or throw "demand jQuery"

url_root = "/repo"

class GitoeRepo
  constructor: (@cb={})->
    # @cb: triggered unconditionally
    #   ajax_error    :(jqXHR)->
    #   new_commit    :(commit,commit_no)->
    #   new_reflogs   :(reflogs)->
    #   status        :(string)->
    # TODO change to support incremental fetching
    @retrived = {} # { sha1: commit_retrived | undefined }
    @last = -1

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
    new_commits_no = []
    for commit_no,content of json.commits
      if not @retrived[ commit_no ]
        @retrived[ commit_no ] = true
        new_commits_no.push parseInt(commit_no)
    for commit_no in new_commits_no.sort( (a,b)-> a-b )
      @cb.new_commit?( json.commits[ commit_no ], commit_no )

  ajax_fetch_refs_success: (response)=>
    @cb.new_reflogs?( response.status.refs )

  ajax_error: (jqXHR)=>
    flash JSON.parse(jqXHR.responseText).error_message

@exports ?= { gitoe: {} }
exports.gitoe.GitoeRepo = GitoeRepo
