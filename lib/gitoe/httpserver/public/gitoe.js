(function() {
  var $, F, GitoeController, Repo, flash, log, repo_root,
    __slice = [].slice,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  $ = jQuery;

  F = fabric;

  log = function() {
    var args;

    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return console.log.apply(console, args);
  };

  flash = function(text) {
    return $("#flash").text(text);
  };

  repo_root = "/repo";

  Repo = (function() {
    function Repo(cb) {
      this.cb = cb;
      this.ajax_open_success = __bind(this.ajax_open_success, this);
    }

    Repo.prototype.open = function(path) {
      return $.post("" + repo_root + "/new", {
        path: path
      }).done(this.ajax_open_success).fail(this.ajax_error);
    };

    Repo.prototype.ajax_open_success = function(json) {
      if (this.path) {
        throw "already opened";
      }
      return this.path = "" + repo_root + "/" + json.id;
    };

    Repo.prototype.ajax_error = function(jqXHR) {
      return flash(JSON.parse(jqXHR.responseText).error_message);
    };

    return Repo;

  })();

  GitoeController = (function() {
    function GitoeController(id_container, id_control) {
      this.open_repo = __bind(this.open_repo, this);
      var kanvas;

      kanvas = new GitoeVis(id_container);
      this.control = $("#" + id_control) || (function() {
        throw "#" + id_control + " not found";
      })();
      this.init_control();
    }

    GitoeController.prototype.init_control = function() {
      this.repo_path = $("<input>").attr({
        value: "/home/mono/config"
      }).one("click", function() {
        return $(this).attr({
          value: ""
        });
      });
      this.open_repo = $("<button>").text("OPEN").on("click", this.open_repo);
      return this.control.append(this.repo_path, this.open_repo);
    };

    GitoeController.prototype.open_repo = function() {
      return $.post("" + repo_root + "/new", {
        path: this.repo_path.val()
      }).done(update_flash.from_json).fail(update_flash.from_jqXHR);
    };

    return GitoeController;

  })();

  this.gitoe = {
    Repo: Repo
  };

  $(function() {
    return flash('hello');
  });

}).call(this);
