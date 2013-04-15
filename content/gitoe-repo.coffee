$ = jQuery or throw "demand jQuery"

url_root = "/repo"

class GitoeRepo
  constructor: (@cb={})->
    # @cb: triggered unconditionally
    #   ajax_error    :(jqXHR)->
    #   new_reflogs   :(to_fetch, fetched)->
    #   fetched_commit:(to_fetch, fetched)->
    @commits_to_fetch = {} # { sha1: true }
    @commits_fetched  = {} # { sha1: commit }
    @reflog           = {} # { ref_name :info }

    @commits_ignored = { "0000000000000000000000000000000000000000" : true }

  open: (path,cb = {})=>
    # cb:
    #   success: ()->
    #   fail   : ()->
    $.post("#{url_root}/new",{path: path})
      .fail(@ajax_error, cb.fail)
      .done(@ajax_open_success, cb.success)

  fetch_commits: (cb = {})=>
    # cb:
    #   success: ()->
    #   fail   : ()->
    throw "not opened" unless @path
    to_query = Object.keys(@commits_to_fetch)[0..10]
    param = { limit: 1000 * to_query.length }
    $.get("#{@path}/commits/#{to_query.join()}", param )
      .fail(@ajax_error, cb.fail)
      .done(@ajax_fetch_commits_success, cb.success)

  fetch_status: (cb = {})->
    # cb:
    #   success: ()->
    #   fail   : ()->
    $.get("#{@path}/")
      .fail(@ajax_error, cb.fail)
      .done(@ajax_fetch_status_success, cb.success)

  ajax_open_success: (json)=>
    throw "already opened" if @path
    @path = "#{url_root}/#{json.id}"

  ajax_fetch_commits_success: (json)=>
    for sha1, content of json
      delete @commits_to_fetch[ sha1 ]
      @commits_fetched[ sha1 ] ||= content
      for sha1_parent in content.parents
        if not @commits_fetched[ sha1_parent ]
          @commits_to_fetch[ sha1_parent ] = true
    to_fetch = Object.keys(@commits_to_fetch).length
    fetched  = Object.keys(@commits_fetched).length
    @cb.fetched_commit?(to_fetch, fetched)

  ajax_fetch_status_success: (response)=>
    @reflog = response.refs
    for ref_name, ref of response.refs
      for change in ref.log
        for field in ['oid_new', 'oid_old']
          sha1 = change[ field ]
          if not (@commits_fetched[ sha1 ] or @commits_ignored[ sha1 ])
            @commits_to_fetch[ sha1 ] = true
    @cb.new_reflogs?( response.refs )

  ajax_error: (jqXHR)=>
    @cb.ajax_error? jqXHR

@exports ?= { gitoe: {} }
exports.gitoe.GitoeRepo = GitoeRepo
