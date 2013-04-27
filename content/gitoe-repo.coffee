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

    parsed_repo = []
    changes_in_branches.sort (a,b)->( a.committer.time - b.committer.time )
    # group changes in HEAD into non-HEAD, by commit time
    # TODO recognize not-on-branch changes
    for from_branch in changes_in_branches
      from_head = []
      while changes_in_head.length > 0 and changes_in_head[0].committer.time <= from_branch.committer.time
        from_head.push changes_in_head.shift()
      parsed_repo.push new @( from_branch, from_head )

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

  constructor: ( change_from_branch, changes_from_head )->
    @branch = change_from_branch.branch
    @self = @parse_change( change_from_branch, )
    @children = \
    (@parse_change(change, false) for change in changes_from_head)

  parse_change: (change, is_branch)->
    message = change.message
    if is_branch
      rule = GitoeChange.message_patterns.branch
    else
      rule = GitoeChange.message_patterns.head

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

  to_li : ()->
    outer = $("<li>")
    for elem in @convert_elem @self
      outer.append elem
    if @children.length > 0
      toggle = $("<i>").addClass("icon-plus")
      inner = $("<ol>").hide()
      for change in @children
        for elem in @convert_elem change
          inner.append elem
      toggle.on "click", ()->
        toggle.toggleClass("icon-plus icon-minus")
        inner.slideToggle()
      outer.prepend toggle
      outer.append inner
    else
      toggle = $("<i>").addClass("icon-minus")
      # outer.prepend toggle
    outer

  convert_elem: (change)->
    elems = []
    for part in change
      switch typeof(part)
        when "string"
          elems.push $("<span>").text(part)
        when "object"
          switch part.type
            when "dump"
              elems.push $("<span>").addClass("unknown").text(part.message)
            else
              console.log part
        else
          console.log part
    elems


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

    changes = {} # { (branchname | local) : reflogs }

    for change in GitoeChange.parse_repo repos.local
      changes[ "local" ] ?= []
      changes[ "local" ].push change

    for repo_name, repo of repos.remote
      for change in GitoeChange.parse_repo repo
        changes[ repo_name ] ?= []
        changes[ repo_name ].push change

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
