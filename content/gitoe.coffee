$ = jQuery
F = fabric

log = (args...)->
  console.log args...

doc = document

repo_root = "/repo"

flash =
  banner: (text)->
    $("#flash .banner").text(text)

update_flash = {
  banner: (banner)->
    log $("#flash .banner").text(banner)
  from_jqXHR: (jqXHR)->
    response = $.parseJSON(jqXHR.responseText)
    @from_json( response )
  from_json: (obj...)=>
    log obj...
    log @
    update_flash.banner(obj.succeed)
    #this.banner(obj.succeed)
  
}


class Repo
  constructor: (repo_path,cb)->
    @k
  after_open: (cb)->
    cb?()

class GitoeRepo extends Repo
  constructor: (clone_json)->
    super

class GitoeVis
  constructor: (id_container)->

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


$ ()->
  vis = new GitoeController("gitoe-canvas", "control")
