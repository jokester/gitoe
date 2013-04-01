$ = jQuery
F = fabric

log = (args...)->
  console.log(args...)

flash = (text)->
  $("#flash").text(text)

repo_root = "/repo"

class GitoeRepo
  constructor: (@cb)->
    @cb ?= {}
    # @cb:
    #   ajax_error    :(jqXHR)->
    #   open_success  :()->
    #   clone_success :()->
    @commits_by_sha1 = {}
  open: (path)->
    $.post("#{repo_root}/new",{path: path})
      .fail(@ajax_error)
      .done(@ajax_open_success)
  clone: ()->
    $.get("#{@path}/commits")
      .fail(@ajax_error)
      .done(@ajax_clone_success)
  ajax_open_success: (json)=>
    throw "already opened" if @path
    @path = "#{repo_root}/#{json.id}"
    @cb.open_success?()
  ajax_clone_success: (json)=>
    commit_count = 0
    for sha1,content of json.commits
      @commits_by_sha1[ sha1 ] = content
      commit_count++
    log commit_count, @commits_by_sha1

  ajax_error: (jqXHR)=>
    flash JSON.parse(jqXHR.responseText).error_message

class GitoeCanvas
  constructor: (@cb)->

class GitoeController
  constructor: (id_container, id_control)->
    @vis = new Vis( id_container )
    @repo = new Repo {
    }
    @control = $("##{id_control}") or throw ("##{id_control} not found")
    @init_control()

  init_control: ()->
    @repo_path = $("<input>")
      .attr( value: "/home/mono/config" )
      .one "click", ()->
        $(@).attr( value:"" )
    @open_repo = $("<button>")
      .text("OPEN")
      .on("click", @open_repo)
    @control.append( @repo_path, @open_repo )
  open_repo: ()=>
    $.post("#{repo_root}/new", { path: @repo_path.val() })
      .done(update_flash.from_json)
      .fail(update_flash.from_jqXHR)

@gitoe =
  Repo: GitoeRepo

$ ()->
  flash 'hello'
