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

class GitoeHistorian
  @message_patterns = {}
  @message_patterns.head = {
    patterns: {
      clone: /^clone: from (.*)/
    }
    actions : {
      clone: (matched,change)->[
        "clone from #{matched[1]}"
        {
          type:    "dump"
          change : change
        }
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
        {
          type:    "dump"
          change : change
        }
      ]
    }
  }
  constructor: ()->
    @cb               = {} # { name: fun }

  set_cb: (new_cb)->
    # cb:
    #   update_status : (key, num)
    #   reflog        : (name, logs) where name=false means local repo
    for name, fun of new_cb
      @cb[name] = fun

  parse: ( refs_raw )->
    refs = @classify (clone refs_raw)
    @update_status refs
    reflog = {}
    if refs.local
      reflog["local"] = @parse_repo refs.local

    for reponame, content of refs.remote
      if reflog[reponame]
        console.log "warning : duplicate reponame {#{reponame}}"
      reflog[ reponame ] = @parse_repo content
    @cb.reflog?( reflog )

  classify: (reflog)-> # { refs_dict }
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
          when "tags"
            refs.tags[  splited[2] ]  = ref
          when "remotes"
            refs.remote[ splited[2] ] ?= {}
            refs.remote[ splited[2] ][ splited[3] ] =ref
          else
            console.log "not recognized", ref_name
      else
        console.log "not recognized", ref_name
    refs

  update_status: ( refs )->
    @cb.update_status? "tags", Object.keys(refs.tags).length
    @cb.update_status? "local_branches", Object.keys(refs.local).length
    @cb.update_status? "remote_repos", Object.keys(refs.remote).length

  parse_repo : (repo)->
    # repo :: { ref: logs }
    reflog_head     = []
    reflog_branches = []
    for branch, content of repo
      if branch is 'HEAD'
        cumulator = reflog_head
      else
        cumulator = reflog_branches
      for change in content.log
        change["branch"] = branch
        cumulator.push {
          time: change.committer.time
          branch: branch
          message: change.message
          oid_old: change.oid_old
          oid_new: change.oid_new
          # orig: change
        }
    reflog_branches.sort (a,b)->( a.time - b.time )
    for change in reflog_branches
      change.head = []
      while reflog_head.length > 0 and reflog_head[0].time <= change.time
        change.head.push reflog_head.shift()
    @convert_repo reflog_branches

  convert_repo: (reflog_branches)->
    # convert reflogs to DSL
    self = @
    converted_repo = []
    for change in reflog_branches
      converted_change = @convert_change change
      converted_repo.push converted_change
      if change.head
        converted_change.head = change.head.map @convert_change
    return converted_repo

  convert_change: (change)=>
    message = change.message
    if change.branch is "HEAD"
      @parse_message( message, change, GitoeHistorian.message_patterns.head )
    else
      @parse_message( message, change, GitoeHistorian.message_patterns.branch )

  parse_message: ( message, change, rule )->
    matched = @match_message message, rule.patterns
    if matched.num is 1
      type =  matched.last
      match = matched[type]
      rule.actions[type]( match, change )
    else
      [
        "not recognized message"
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
