(function() {
  var $, F, GitoeController, GitoeRepo, GitoeVis, Repo, doc, flash, log, repo_root, update_flash,
    __slice = [].slice,
    _this = this,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  $ = jQuery;

  F = fabric;

  log = function() {
    var args;

    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return console.log.apply(console, args);
  };

  doc = document;

  repo_root = "/repo";

  flash = {
    banner: function(text) {
      return $("#flash .banner").text(text);
    }
  };

  update_flash = {
    banner: function(banner) {
      return log($("#flash .banner").text(banner));
    },
    from_jqXHR: function(jqXHR) {
      var response;

      response = $.parseJSON(jqXHR.responseText);
      return this.from_json(response);
    },
    from_json: function() {
      var obj;

      obj = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      log.apply(null, obj);
      log(_this);
      return update_flash.banner(obj.succeed);
    }
  };

  Repo = (function() {
    function Repo(repo_path, cb) {
      this.k;
    }

    Repo.prototype.after_open = function(cb) {
      return typeof cb === "function" ? cb() : void 0;
    };

    return Repo;

  })();

  GitoeRepo = (function(_super) {
    __extends(GitoeRepo, _super);

    function GitoeRepo(clone_json) {
      GitoeRepo.__super__.constructor.apply(this, arguments);
    }

    return GitoeRepo;

  })(Repo);

  GitoeVis = (function() {
    function GitoeVis(id_container) {}

    return GitoeVis;

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

  $(function() {
    var vis;

    return vis = new GitoeController("gitoe-canvas", "control");
  });

}).call(this);
