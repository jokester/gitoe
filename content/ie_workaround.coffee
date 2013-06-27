
if navigator.userAgent.match /msie/i
  alert "
This page doesn't work in IE. Please consider recent version of modern browsers like Chrome / Mozilla Firefox.\n
本ソフトはInternet Explorerで作動しません。最近バージョンのChromeかMozilla Firefoxで試してみてください。
"

# $ = jQuery or throw "demand jQuery"
# do ->
#   if "object" == typeof(console.log)
#     old_log = console.log
#     console.log = (args...)->
#       old_log( args )
#     console.log "ie sax"

# do ->
#   Array::map ||= (fun)->
#     $.map @, fun

#   Array::filter ||= (fun)->
#     $(@).filter fun

