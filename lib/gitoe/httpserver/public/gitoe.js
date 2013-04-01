(function() {
  var $, F, GitoeCanvas, GitoeController, GitoeRepo, flash, log, repo_root,
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

  GitoeRepo = (function() {
    function GitoeRepo(cb) {
      var _ref;

      this.cb = cb;
      this.ajax_error = __bind(this.ajax_error, this);
      this.ajax_clone_success = __bind(this.ajax_clone_success, this);
      this.ajax_open_success = __bind(this.ajax_open_success, this);
      if ((_ref = this.cb) == null) {
        this.cb = {};
      }
      this.commits_by_sha1 = {};
    }

    GitoeRepo.prototype.open = function(path) {
      return $.post("" + repo_root + "/new", {
        path: path
      }).fail(this.ajax_error).done(this.ajax_open_success);
    };

    GitoeRepo.prototype.clone = function() {
      return $.get("" + this.path + "/commits").fail(this.ajax_error).done(this.ajax_clone_success);
    };

    GitoeRepo.prototype.ajax_open_success = function(json) {
      var _base;

      if (this.path) {
        throw "already opened";
      }
      this.path = "" + repo_root + "/" + json.id;
      return typeof (_base = this.cb).open_success === "function" ? _base.open_success() : void 0;
    };

    GitoeRepo.prototype.ajax_clone_success = function(json) {
      var commit_count, content, sha1, _ref;

      commit_count = 0;
      _ref = json.commits;
      for (sha1 in _ref) {
        content = _ref[sha1];
        this.commits_by_sha1[sha1] = content;
        commit_count++;
      }
      return log(commit_count, this.commits_by_sha1);
    };

    GitoeRepo.prototype.ajax_error = function(jqXHR) {
      return flash(JSON.parse(jqXHR.responseText).error_message);
    };

    return GitoeRepo;

  })();

  GitoeCanvas = (function() {
    function GitoeCanvas(cb) {
      this.cb = cb;
    }

    return GitoeCanvas;

  })();

  GitoeController = (function() {
    function GitoeController(id_container, id_control) {
      this.open_repo_success = __bind(this.open_repo_success, this);
      this.open_repo = __bind(this.open_repo, this);      this.vis = new Vis(id_container);
      this.repo = new Repo({});
      this.control = $("#" + id_control) || (function() {
        throw "#" + id_control + " not found";
      })();
      this.init_control();
    }

    GitoeController.prototype.init_control = function() {
      this.repo_path = $("<input>").attr("value", "/home/mono/config");
      this.open_repo = $("<button>").text("OPEN").on("click", this.open_repo);
      return this.control.append(this.repo_path, this.open_repo);
    };

    GitoeController.prototype.open_repo = function() {
      return $.post("" + repo_root + "/new", {
        path: this.repo_path.val()
      }).done(update_flash.from_json).fail(update_flash.from_jqXHR);
    };

    GitoeController.prototype.open_repo_success = function() {};

    return GitoeController;

  })();

  this.gitoe = {
    Repo: GitoeRepo
  };

  $(function() {
    return flash('hello');
  });

}).call(this);
