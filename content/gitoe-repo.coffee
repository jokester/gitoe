$ = jQuery or throw "demand jQuery"

url_root = "/repo"

exec_callback = (context,fun,args)->
  fun.apply(context, args)

clone = (obj)->
  $.extend {}, obj

strcmp = (str1, str2, pos = 0)->
  c1 = str1.charAt( pos )
  c2 = str2.charAt( pos )
  if c1 < c2
    return 1
  else if c1 > c2
    return -1
  else if c1 == '' # which means c2 == ''
    return 0
  else
    return strcmp(str1, str2, pos+1)

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

class GitoeChange
  @parse_repo : (repo)-> # [ changes ]
    # repo :: { ref: logs }

    # classify into HEAD / non-HEAD
    changes_in_head     = []
    changes_in_branches = []
    for branch, content of repo
      cumulator = \
      if branch is 'HEAD'
        changes_in_head
      else
        changes_in_branches
      for change in content.log
        change["branch"] = branch
        cumulator.push change

    # group changes in HEAD into non-HEAD, by commit time
    # TODO recognize not-on-branch changes
    changes_in_branches.sort (a,b)->( a.time - b.time )
    for change in changes_in_branches
      change.head = []
      while changes_in_head.length > 0 and changes_in_head[0].time <= change.time
        change.head.push changes_in_head.shift()

    parsed_repo = []
    for change in changes_in_branches
      parsed_change = @parse_change(change)
      parsed_change.head = change.head.map @parse_change
      parsed_repo.push(parsed_change)

    parsed_repo

  @message_patterns = {}
  @message_patterns.head = {
    patterns: {
      clone: /^clone: from (.*)/
    }
    actions : {
      clone: (matched,change)->[
        "clone from #{matched[1]}"
      ]
    }
  }
  @message_patterns.branch = {
    patterns: {
      clone: /^clone: from (.*)/
    }
    actions : {
      clone: (matched,change)->[
        "clone from #{matched[1]}"
      ]
    }
  }

  constructor: ( change_in_branch, changes_in_head )->
  parse_change: (change)=>
    message = change.message
    if change.branch is "HEAD"
      rule = GitoeChange.message_patterns.head
    else
      rule = GitoeChange.message_patterns.branch

    matched = @match_message message, rule.patterns
    if matched.num is 1
      type =  matched.last
      match = matched[type]
      rule.actions[type]( match, change )
    else
      [
        {
          type:    "dump"
          message: message
          change : change
        }
      ]

  match_message : (message, patterns)-> # { case => matched }
    matched = {
      num  : 0
      last : null
    }
    for type, regex of patterns
      if match = regex.exec message
        matched.last = type
        matched[type] = match
        matched.num++
    matched

  to_dom : ()->

class GitoeHistorian
  constructor: ()->
    @cb               = {} # { name: fun }

  set_cb: (new_cb)->
    # cb:
    #   update_status : (key, num)
    #   reflog        : (name, logs) where name=false means local repo
    for name, fun of new_cb
      @cb[name] = fun

  parse: ( refs_raw )-> # [ changes of all repos ]
    repos = @classify (clone refs_raw)
    @update_status repos

    changes = []

    for change in GitoeChange.parse_repo repos.local
      change["repo"] = "local"
      changes.push change

    for repo_name, repo of repos.remote
      for change in GitoeChange.parse_repo repo
        change["repo"] = repo_name
        changes.push parsed_change

    @cb.reflog?( changes )

  classify: (reflog_raw)-> # { reflog classified by repo }
    repos = {
      tags            : {} # { name : sha1 }
      local           : {} # { branch :  {}  }
      remote          : {} # { remote : { branch: {} } }
    }
    for ref_name, reflog of reflog_raw
      splited = ref_name.split "/"
      if splited[0] == "HEAD" and splited.length == 1
        repos.local["HEAD"] = reflog
      else if splited[0] == "refs"
        switch splited[1]
          when "heads"
            repos.local[ splited[2] ] = reflog
          when "tags"
            repos.tags[  splited[2] ]  = reflog
          when "remotes"
            repos.remote[ splited[2] ] ?= {}
            repos.remote[ splited[2] ][ splited[3] ] =reflog
          else
            console.log "not recognized", ref_name
      else
        console.log "not recognized", ref_name
    repos

  update_status: ( refs )->
    @cb.update_status? "tags", Object.keys(refs.tags).length
    @cb.update_status? "local_branches", Object.keys(refs.local).length
    @cb.update_status? "remote_repos", Object.keys(refs.remote).length

class GitoeRepo
  constructor: ()->
    @commits_to_fetch = {} # { sha1: true }
    @commits_fetched  = {} # { sha1: commit }
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
        if not (@commits_fetched[ sha1 ] or @commits_ignored[ sha1 ])
          @commits_to_fetch[ sha1_parent ] = true
    to_fetch = Object.keys(@commits_to_fetch).length
    fetched  = Object.keys(@commits_fetched ).length
    @cb.fetched_commit?(to_fetch, fetched)

  ajax_fetch_status_success: (response)=>
    for ref_name, ref of response.refs
      # dig commits with log
      # TODO also dig from annotated tags
      for change in ref.log
        for field in ['oid_new', 'oid_old']
          sha1 = change[ field ]
          if not (@commits_fetched[ sha1 ] or @commits_ignored[ sha1 ])
            @commits_to_fetch[ sha1 ] = true
    @cb.fetch_status? response

  ajax_error: (jqXHR)=>
    @cb.ajax_error? jqXHR

@exports ?= { gitoe: {} }
exports.gitoe.GitoeRepo      = GitoeRepo
exports.gitoe.GitoeHistorian = GitoeHistorian
