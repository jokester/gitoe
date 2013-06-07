$ = jQuery or throw "demand jQuery"
moment or throw "demand moment"

url_root = "/repo"

exec_callback = (context,fun,args)->
  fun.apply(context, args)

clone = (obj)->
  $.extend {}, obj

local = '##??!'

uniq = ( old_array, ignore_list=['0000000000000000000000000000000000000000'] )->
  # leave only first occurances

  ignore = {}
  for i in ignore_list
    ignore[ i ] = true

  new_array = []
  for elem in old_array
    if not ignore[elem]
      ignore[elem] = true
      new_array.push elem
  new_array

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

class OrderedSet
  # a FIFO queue while guarantees uniqueness
  constructor: ()->
    @elems = []
    @hash  = {}
  push: (new_elem)->
    if not @hash[new_elem]
      @hash[new_elem] = true
      @elems.push new_elem
      true
    else
      false
  length: ()->
    @elems.length
  shift: ()->
    throw "empty" unless @elems.length > 0
    ret = @elems.shift()
    delete @hash[ret]
    ret

class DAGtopo
  # TODO
  #   modify to a persistent object, for reverse-order toposort
  #   respond to
  #     #depth()
  #     #add_edge(u,v)
  #   callback on
  #     yield: (commit,layer)
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
  # changes in ONE repo
  @parse: ( repos )-># [ changes ]
    # repo :: { ref: logs }

    # collect changes
    changes = []
    for repo_name, repo_content of repos
      for ref_name, ref_content of repo_content
        for change in ref_content.log
          change['repo_name'] = repo_name
          change["ref_name"] = ref_name
          changes.push change

    # sort by time and ref_name
    changes.sort (a,b)->
      ( a.committer.time - b.committer.time )               \
      or strcmp(a.repo_name, b.repo_name)                   \
      or -((a.ref_name == "HEAD") - (b.ref_name == "HEAD")) \
      or strcmp(a.ref_name, b.ref_name)

    grouped_changes = @group changes
    console.log changes, grouped_changes

    grouped_changes.map (group)->
      new GitoeChange(group)

  @group : (changes)-> # [ [group_of_changes] ]
    # TODO group changes with some maintainable grammer rules
    groups = []
    begin = 0
    for change, end in changes
      next = changes[ end + 1 ]
      if (change.ref_name isnt "HEAD")  \      # change in named branch
      or ( /^rebase: aborting/.test change.message) \ # rebase --abort
      or (end == changes.length - 1 )   \      # last change in all changes
      or (next.repo_name != change.repo_name)\ # last change in consecutive changes of the same repo
      or ( /^checkout:/.test(change.message) and not /^(rebase|cherry-pick)/.test(next.message) ) # last checkout before rebase
        groups.push changes[ begin .. end ]
        begin = end+1
    groups

  constructor: ( changes )->
    @main = changes[ changes.length - 1 ]
    if changes.length > 1
      @rest = changes[ 0 .. (changes.length - 2) ]
    else
      @rest = []
    if @main.repo_name is local
      @is_local = true
    else
      @is_local = false

  to_html: ()-># [ changes_as_li ]
    rules = GitoeChange.message_rules
    html = GitoeChange.html
    for pattern, regex of rules.patterns
      if matched = @main.message.match(regex)
        return rules.actions[pattern].apply(html,[matched, @main, @rest]).addClass("reflog")
    console.log "not recognized change : ", @main, @rest
    $('<li>').text("???").addClass("unknown")

  on_click: ->
    # closure
    refs = {}
    ref_fullname = GitoeChange.html.ref_fullname
    for change in @rest
      fullname = ref_fullname change
      refs[ fullname ] ?= []
      refs[ fullname ].push change.oid_old
      refs[ fullname ].push change.oid_new
    fullname = ref_fullname @main
    refs[ fullname ] ?= []
    refs[ fullname ].push @main.oid_old
    refs[ fullname ].push @main.oid_new

    for fullname, sha1_s of refs
      refs[fullname] = uniq(sha1_s)

    -># in GitoeCanvas context
      @set_refs refs

  @html = {
    # a singleton obj to eval html DSL with
    span: (text,classes)->
      $("<span>").text(text).addClass(classes)
    li: (content, classes)->
      $("<li>").append(content).addClass(classes)
    ref: (text)->
      @span text, 'ref_name'
    ref_fullname: ( change )-> # span "repo/ref"
      if change.repo_name is local
        change.ref_name
      else
        "#{change.repo_name}/#{change.ref_name}"
    git_command: (text)->
      @span text, "git_command"
    ref_realname: (ref_name)-> # "repo/ref"
      splited = ref_name.split "/"
      if splited[0] == "HEAD"
        "HEAD"
      else if splited[0] == "refs"
        switch splited[1]
          when "heads"   # refs/heads/<branch>
            splited[2]
          when "remotes" # refs/remotes/<repo>/<branch>
            "#{ splited[2] }/#{ splited[3] }"
          when "tags"    # refs/tags/<tag>
            splited[2]
          else
            console.log "not recognized", ref_name
            "???"
      else
        console.log "not recognized", ref_name
        "???"
    sha1_commit: (sha1)->
      @span sha1, "sha1_commit"
    br: ->
      $('<br>')
    pretty_abs_time: (change)->
      @span moment.unix( change.committer.time ).format(), "git_abs_time"
    pretty_relative_time: (change)->
      @span moment.unix( change.committer.time ).fromNow(), "git_rel_time"
    p_with_time: (change, elems)->
      @p [
        elems...
        @span " at "
        @pretty_abs_time change
        @span " / "
        @pretty_relative_time change
      ]
    p: ( elements )->
      ret = $('<p>')
      for e in elements
        ret.append e
      ret
  }

  @message_rules = {
    patterns: {
      clone:  /^clone: from (.*)/
      branch: /^branch: Created from (.*)/
      commit: /^commit: /
      commit_amend: /^commit \(amend\): /
      merge_commit: /^commit \(merge\): Merge branch '?([^ ]+)'? into '?([^ ]+)'?$/
      merge_ff:  /^merge ([^:]*):/
      reset:  /^reset: moving to (.*)/
      push :  /^update by push/
      pull :  /^pull: /
      fetch:  /^fetch/
      checkout: /^checkout: moving from ([^ ]+) to ([^ ]+)/
      rename_remote: /^remote: renamed ([^ ]+) to ([^ ]+)/
      rebase_finish: /^rebase (-[^ ]+)? \(finish\): returning to (.*)/
      rebase_finish2:/^rebase (-[^ ]+)? \(finish\): ([^ ]+) onto/
      rebase_finish3:/^rebase (-[^ ]+ )?finished: ([^ ]+) onto/
      rebase_abort: /^rebase: aborting/
    }
    actions : {
      clone: (matched,change)->
        @li [
          @p_with_time change, [
            @git_command "git clone"
          ]
          @p [
            @span "create "
            @ref (@ref_fullname change)
            @span " at "
            @sha1_commit change.oid_new
          ]
        ]
      branch: (matched, change)->
        # TODO show position better
        @li [
          @git_command "git branch"
          @span ": branch out "
          @ref (@ref_fullname change)
          @span " at "
          @sha1_commit change.oid_new
          if /^refs/.test matched[1]
            @span " (was "
          if /^refs/.test matched[1]
            @ref @ref_realname(matched[1])
          if /^refs/.test matched[1]
            @span " )"
        ]
      commit: (matched, change)->
        @li [
          @p_with_time change, [
            @git_command "git commit"
          ]
          @span ": move "
          @ref (@ref_fullname change)
          @span " from "
          @sha1_commit change.oid_old
          @span " to "
          @sha1_commit change.oid_new
        ]
      merge_commit: (matched, change)->
        @li [
          @git_command "git merge"
          @span ": move "
          @span matched[2], "ref_name"
          @span ' to '
          @sha1_commit change.oid_new
          @span ' by merging '
          @span matched[1], "ref_name"
        ]
      commit_amend: (matched, change)->
        @li [
          @git_command "git commit --amend"
          @span ": move "
          @ref (@ref_fullname change)
          @span " from "
          @sha1_commit change.oid_old
          @span " to "
          @sha1_commit change.oid_new
        ]
      merge_ff: (matched, change)->
        @li [
          @git_command "git merge"
          @span ": move "
          @ref (@ref_fullname change)
          @span ' to '
          @sha1_commit change.oid_new
          @span ' by merging '
          @span matched[1], "ref_name"
        ]
      reset: (matched, change)->
        @li [
          @git_command "git reset"
          @span ": point "
          @ref (@ref_fullname change)
          @span " to "
          @sha1_commit change.oid_new
          @span " ( was "
          @sha1_commit change.oid_old
          @span " )"
        ]
      push: (matched, change)->
        @li [
          @git_command "git push"
          @span ": update "
          @ref (@ref_fullname change)
          @span " to "
          @sha1_commit change.oid_new
          if change.oid_old isnt "0000000000000000000000000000000000000000"
            @span " ( was "
          if change.oid_old isnt "0000000000000000000000000000000000000000"
            @sha1_commit change.oid_old
          if change.oid_old isnt "0000000000000000000000000000000000000000"
            @span " )"
        ]
      fetch: (matched, change)->
        @li [
          @git_command "git fetch"
          @span ": update "
          @ref (@ref_fullname change)
          @span " to "
          @sha1_commit change.oid_new
          if change.oid_old isnt "0000000000000000000000000000000000000000"
            @span " ( was "
          if change.oid_old isnt "0000000000000000000000000000000000000000"
            @sha1_commit change.oid_old
          if change.oid_old isnt "0000000000000000000000000000000000000000"
            @span " )"
        ]
      pull: (matched, change)->
        @li [
          @git_command "git pull"
          @span ": update "
          @ref (@ref_fullname change)
          @span " from "
          @sha1_commit change.oid_old
          @span " to "
          @sha1_commit change.oid_new
        ]
      checkout: (matched, change, rest)->
        # TODO handle remaining "checkout SHA1" message of removed branch
        @li [
          @git_command "git checkout"
          @span ": checkout "
          @ref matched[2]
          @span " at "
          @sha1_commit change.oid_new
        ]
      rename_remote: (matched, change)->
        @li [
          @git_command "git remote rename"
          @span ": rename "
          @ref @ref_realname(matched[1])
          @span " to "
          @ref @ref_realname(matched[2])
        ]
      rebase_finish: (matched, change)->
        @li [
          if matched[1]
            @git_command "git rebase #{matched[1]}"
          else
            @git_command "git rebase"
          @span ": rebase "
          @ref @ref_realname(matched[2])
          @span " to "
          @sha1_commit change.oid_new
        ]
      rebase_finish2: (matched, change)->
        @li [
          if matched[1]
            @git_command "git rebase #{matched[1]}"
          else
            @git_command "git rebase"
          @span ": rebase "
          @ref (@ref_fullname change)
          @span " to "
          @sha1_commit change.oid_new
        ]
      rebase_finish3: (matched, change)->
        @li [
          if matched[1]
            @git_command "git rebase #{matched[1]}"
          else
            @git_command "git rebase"
          @span ": rebase "
          @ref (@ref_fullname change)
          @span " to "
          @sha1_commit change.oid_new
        ]
      rebase_abort: (matched, change, rest)->
        if rest.length > 0
          if matched_head = rest[0].message.match /^checkout: moving from ([^ ]+)/
            real_ref = matched_head[1]
        @li [
          @git_command "git rebase --abort"
          @span ": didn't rebase "
          if real_ref
            @ref real_ref
        ]
    }
  }

class GitoeHistorian
  constructor: ()->
    @cb               = {} # { name: fun }

  set_cb: (new_cb)->
    # cb:
    #   update_reflog   : ( changes )
    #   update_num_tags : ( num_tags )
    for name, fun of new_cb
      @cb[name] = fun

  parse: ( refs )-> # [ changes of all repos ]
    classified = @classify( clone refs )
    console.log classified
    @cb.update_num_tags? Object.keys( classified.tags ).length

    changes = GitoeChange.parse( classified.repos )
    @cb.update_reflog?( changes )

  classify: (refs)-> # { repos: {}, tags: {} }
    repos = {}
    tags = {}
    for ref_name, ref_content of refs
      splited = ref_name.split "/"
      if splited[0] == "HEAD" and splited.length == 1
        repos[ local ] ?= {}
        repos[ local ]["HEAD"] = ref_content
      else if splited[0] == "refs"
        switch splited[1]
          when "heads"   # refs/heads/<branch>
            repos[ local ] ?= {}
            repos[ local ][ splited[2] ] = ref_content
          when "remotes" # refs/remotes/<repo>/<branch>
            repos[ splited[2] ] ?= {}
            repos[ splited[2] ][ splited[3] ] = ref_content
          when "tags"    # refs/tags/<tag>
            tags[ splited[2] ] = ref_content
            # do nothing
          else
            console.log "not recognized", ref_name
      else
        console.log "not recognized", ref_name
    {
      repos: repos
      tags: tags
    }

class GitoeRepo
  # TODO
  #   queue commits with OrderedSet
  #   reverse-toposort with DAGtopo
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
exports.gitoe.strcmp         = strcmp
exports.gitoe.GitoeRepo      = GitoeRepo
exports.gitoe.GitoeHistorian = GitoeHistorian
