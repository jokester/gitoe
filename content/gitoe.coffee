$ = jQuery
F = fabric

log = (args...)->
  console.log(args...)

flash = (text)->
  $("#flash").text(text)

repo_root = "/repo"

class Repo
  constructor: (@cb)->
  open: (path)->
    $.post("#{repo_root}/new",{path: path})
     .done(@ajax_open_success)
     .fail(@ajax_error)
  ajax_open_success: (json)=>
    throw "already opened" if @path
    @path = "#{repo_root}/#{json.id}"
  ajax_error: (jqXHR)->
    flash JSON.parse(jqXHR.responseText).error_message

class GitoeController
  constructor: (id_container, id_control)->
    kanvas = new GitoeVis( id_container )
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
  Repo: Repo

$ ()->
  flash 'hello'
