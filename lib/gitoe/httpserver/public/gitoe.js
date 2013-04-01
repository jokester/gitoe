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

  flash = (function() {
    var flash_counter;

    flash_counter = 0;
    return function(text, delay) {
      var clear, current_counter, flash_div;

      if (delay == null) {
        delay = 5000;
      }
      flash_div = $("#flash");
      current_counter = ++flash_counter;
      clear = function() {
        if (current_counter === flash_counter) {
          return flash_div.text("");
        }
      };
      flash_div.text(text);
      if (delay) {
        return setTimeout(clear, delay);
      }
    };
  })();

  repo_root = "/repo";

  GitoeRepo = (function() {
    function GitoeRepo(cb) {
      this.cb = cb != null ? cb : {};
      this.new_reflog = __bind(this.new_reflog, this);
      this.new_commit = __bind(this.new_commit, this);
      this.ajax_error = __bind(this.ajax_error, this);
      this.ajax_fetch_refs_success = __bind(this.ajax_fetch_refs_success, this);
      this.ajax_fetch_commits_success = __bind(this.ajax_fetch_commits_success, this);
      this.ajax_open_success = __bind(this.ajax_open_success, this);
      this.fetch = __bind(this.fetch, this);
      this.open = __bind(this.open, this);
      this.commits_by_sha1 = {};
    }

    GitoeRepo.prototype.open = function(path, after_open) {
      return $.post("" + repo_root + "/new", {
        path: path
      }).fail(this.ajax_error).done(this.ajax_open_success, after_open);
    };

    GitoeRepo.prototype.fetch = function(external_cb) {
      var self;

      self = this;
      return self.fetch_commits(function() {
        return self.fetch_refs(function() {
          return typeof external_cb === "function" ? external_cb() : void 0;
        });
      });
    };

    GitoeRepo.prototype.fetch_commits = function(after_fetch_commits) {
      if (!this.path) {
        throw "not opened";
      }
      return $.get("" + this.path + "/commits").fail(this.ajax_error).done(this.ajax_fetch_commits_success, after_fetch_commits);
    };

    GitoeRepo.prototype.fetch_refs = function(after_fetch_refs) {
      return $.get("" + this.path + "/").fail(this.ajax_error).done(this.ajax_fetch_refs_success, after_fetch_refs);
    };

    GitoeRepo.prototype.ajax_open_success = function(json) {
      var _base;

      if (this.path) {
        throw "already opened";
      }
      this.path = "" + repo_root + "/" + json.id;
      return typeof (_base = this.cb).open_success === "function" ? _base.open_success() : void 0;
    };

    GitoeRepo.prototype.ajax_fetch_commits_success = function(json) {
      var content, new_commits, sha1, _ref;

      new_commits = {
        sha1: [],
        content: []
      };
      _ref = json.commits;
      for (sha1 in _ref) {
        content = _ref[sha1];
        if (!this.commits_by_sha1[sha1]) {
          this.commits_by_sha1[sha1] = content;
          new_commits.sha1.push(sha1);
          new_commits.content.push(content);
        }
      }
      return this.new_commit(new_commits);
    };

    GitoeRepo.prototype.ajax_fetch_refs_success = function(json) {
      return this.new_reflog(json);
    };

    GitoeRepo.prototype.ajax_error = function(jqXHR) {
      return flash(JSON.parse(jqXHR.responseText).error_message);
    };

    GitoeRepo.prototype.new_commit = function(commits) {
      var _base;

      return typeof (_base = this.cb).new_commit === "function" ? _base.new_commit(commits) : void 0;
    };

    GitoeRepo.prototype.new_reflog = function(reflogs) {
      var _base;

      return typeof (_base = this.cb).new_reflog === "function" ? _base.new_reflog(reflogs) : void 0;
    };

    return GitoeRepo;

  })();

  GitoeCanvas = (function() {
    function GitoeCanvas(id_canvas, cb) {
      this.cb = cb;
    }

    return GitoeCanvas;

  })();

  GitoeController = (function() {
    function GitoeController(id_control, id_canvas) {
      this.open_repo_success = __bind(this.open_repo_success, this);
      this.open_repo = __bind(this.open_repo, this);      this.init_repo();
      this.init_vis(id_canvas);
      this.init_control(id_control);
    }

    GitoeController.prototype.init_repo = function() {
      return this.repo = new Repo();
    };

    GitoeController.prototype.init_vis = function(id_canvas) {
      return this.vis = new Vis(id_canvas, {});
    };

    GitoeController.prototype.init_control = function(id_control) {
      var button_open_repo, control, input_repo_path;

      control = $("#" + id_control) || (function() {
        throw "#" + id_control + " not found";
      })();
      input_repo_path = $("<input>").attr("value", "/home/mono/config");
      button_open_repo = $("<button>").text("OPEN").on("click", this.open_repo);
      control.append(input_repo_path, button_open_repo);
      return this.control = {
        parent: control,
        input_repopath: repo_path,
        button_openrepo: button_openrepo
      };
    };

    GitoeController.prototype.open_repo = function(path) {
      return this.repo.open(path);
    };

    GitoeController.prototype.open_repo_success = function() {};

    return GitoeController;

  })();

  this.gitoe = {
    Repo: GitoeRepo
  };

  $(function() {
    return window.a = new GitoeRepo({
      new_commit: function(commits) {},
      new_reflog: function() {}
    });
  });

}).call(this);
