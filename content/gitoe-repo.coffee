$ = jQuery or throw "demand jQuery"

url_root = "/repo"

exec_callback = (context,fun,args)->
  fun.apply(content, args)

clone = (obj)->
  $.extend {}, obj

class DAGtopo
  constructor: ()->
    @edges = {}  # { u: [v] } for edges < u → v >

  add_edge: (from,to)-> # nil
    @edges[from] ?= []
    @edges[to]   ?= []
    @edges[from].push to

  sort: ()-> # [nodes] , in topological order

    in_degree = {}
    for from, to_s of @edges
      in_degree[from] ?= 0
      for to in to_s
        in_degree[to] ?= 0
        in_degree[to]++

    sorted =  []
    nodes_whose_in_degree_is_0 =
      Object.keys(in_degree).filter (node)->
        in_degree[node] is 0
    while nodes_whose_in_degree_is_0.length > 0
      node = nodes_whose_in_degree_is_0.shift()
      delete in_degree[node] # not really necessary, keep it clean
      sorted.push node
      for to in @edges[node]
        if --in_degree[to] == 0
          nodes_whose_in_degree_is_0.push to
    return sorted

class GitoeHistorian
  constructor: (@cb)->
    # cb:
    #   clear_refs   : ()->
    #   tags         : ()
    #   local_reflog : ()
    #   remote_reflog: ()
  analysis_repo: (repo)-> # [ change ]

  parse: ( refs_classified )=>
    @cb.local? aaaaa
    @cb.tags? refs_classified.tags
    console.log refs_classified

class GitoeRepo
  constructor: ()->
    @commits_to_fetch = {} # { sha1: true }
    @commits_fetched  = {} # { sha1: commit }
    @reflog           = {} # { ref_name :info }
    @cb               = {} # { name: fun }
    @commits_ignored  = { "0000000000000000000000000000000000000000" : true }

  set_cb: (new_cb)->
    # cb: triggered unconditionally
    #   ajax_error    : ( jqXHR )->
    #   fetched_commit: ( to_fetch, fetched )->
    #   yield_reflogs : ( refs )->
    #   yield_commit  : ( content )->
    for name, fun of new_cb
      @cb[name] = fun

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
    to_query = Object.keys(@commits_to_fetch)[0..9]
    # TODO find a more efficient formula
    param = { limit: 1000 }
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

  fetch_alldone:  ()->
    sorter = new DAGtopo
    for child,content of @commits_fetched
      for parent in content.parents
        sorter.add_edge( parent, child )
    sorted_commits = sorter.sort()
    for sha1 in sorted_commits
      @cb.yield_commit? @commits_fetched[sha1]

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
    if to_fetch == 0
      @fetch_alldone()

  ajax_fetch_status_success: (response)=>
    refs_classified = @classify_ref response.refs
    for ref_name, ref of response.refs
      # dig commits with log
      # TODO also dig from annotated commits
      for change in ref.log
        for field in ['oid_new', 'oid_old']
          sha1 = change[ field ]
          if not (@commits_fetched[ sha1 ] or @commits_ignored[ sha1 ])
            @commits_to_fetch[ sha1 ] = true
    @cb.yield_reflogs?( refs_classified )

  ajax_error: (jqXHR)=>
    @cb.ajax_error? jqXHR

  classify_ref: (reflog)-> # { refs_dict }
    refs = {
      tags            : {} # { name : sha1 }
      local           : {} # { branch :  {}  }
      remote          : {} # { remote : { branch: {} } }
    }
    for ref_name, ref of reflog
      splited = ref_name.split "/"
      if splited[0] == "HEAD" and splited.length == 1
        refs.local["HEAD"] = ref
      else if splited[0] == "refs"
        switch splited[1]
          when "heads"
            refs.local[ splited[2] ] = ref
          when   "tags"
            refs.tags[  splited[2] ]  = ref
          when   "remotes"
            refs.remote[ splited[2] ] ?= {}
            refs.remote[ splited[2] ][ splited[3] ] =ref
          else
            console.log "not recognized", ref_name
      else
        console.log "not recognized", ref_name
    refs

@exports ?= { gitoe: {} }
exports.gitoe.GitoeRepo      = GitoeRepo
exports.gitoe.GitoeHistorian = GitoeHistorian
