(function() {
  var $, GitoeCanvas, GitoeController, GitoeHistorian, GitoeRepo, GitoeUI, flash, log,
    __slice = [].slice,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  $ = jQuery || (function() {
    throw "demand jQuery";
  })();

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

  GitoeHistorian = this.exports.gitoe.GitoeHistorian || (function() {
    throw "GitoeHistorian not found";
  })();

  GitoeRepo = this.exports.gitoe.GitoeRepo || (function() {
    throw "GitoeRepo not found";
  })();

  GitoeCanvas = this.exports.gitoe.GitoeCanvas || (function() {
    throw "GitoeCanvas not found";
  })();

  GitoeUI = (function() {
    function GitoeUI(id) {
      this.slideDown = __bind(this.slideDown, this);
      this.update_reflog = __bind(this.update_reflog, this);
      this.update_num_tags = __bind(this.update_num_tags, this);
      this.update_num_commits = __bind(this.update_num_commits, this);
      this.update_status = __bind(this.update_status, this);      this.historian = new GitoeHistorian();
      this.cb = {};
      this.root = $("#" + id);
      this.init_dom();
      this.bind_events();
    }

    GitoeUI.prototype.set_cb = function(new_cb) {
      var fun, name, _results;

      _results = [];
      for (name in new_cb) {
        fun = new_cb[name];
        _results.push(this.cb[name] = fun);
      }
      return _results;
    };

    GitoeUI.prototype.init_dom = function() {
      var cb, repo_path;

      cb = this.cb;
      this.sections = {};
      this.elems = {};
      repo_path = this.elems.repo_path = $("<input>").val("/home/mono/gitoe");
      this.elems.repo_open = $("<input>").attr({
        type: "button"
      }).val("open").on("click", function() {
        return typeof cb.repo_open === "function" ? cb.repo_open(repo_path.val()) : void 0;
      });
      this.elems.num_commits = $("<span>").text(0);
      this.elems.num_tags = $("<span>").text(0);
      this.elems.history = $("<ol>");
      this.elems.repo_title = $("<h3>");
      return this.root.append([this.sections.open = $("<div>").append([$("<h3>").text("open repo"), $("<hr>"), this.elems.repo_path, this.elems.repo_open]), this.sections.status = $("<div>").hide().append([this.elems.repo_title, $("<hr>"), $("<ul>").append([$("<li>").text(" commits").prepend(this.elems.num_commits), $("<li>").text(" tags").prepend(this.elems.num_tags)])]), this.sections.history = $("<div>").hide().append([$("<h3>").text("history"), $("<hr>"), this.elems.history])]);
    };

    GitoeUI.prototype.open_success = function() {
      this.slideUp("open");
      this.slideDown("status");
      return this.slideDown("history");
    };

    GitoeUI.prototype.update_status = function(status) {
      console.log(status);
      this.elem("repo_title").text(status.path);
      return this.historian.parse(status.refs);
    };

    GitoeUI.prototype.update_num_commits = function(num_commits) {
      return this.elem("num_commits").text(num_commits);
    };

    GitoeUI.prototype.update_num_tags = function(num_tags) {
      return this.elem("num_tags").text(num_tags);
    };

    GitoeUI.prototype.update_reflog = function(changes) {
      var cb, change, li, list_changes, _fn, _i, _len, _results;

      cb = this.cb;
      list_changes = this.elem("history");
      list_changes.empty();
      _fn = function(change, li) {
        return li.on("click", function() {
          return typeof cb.show_change === "function" ? cb.show_change(change.on_click()) : void 0;
        });
      };
      _results = [];
      for (_i = 0, _len = changes.length; _i < _len; _i++) {
        change = changes[_i];
        li = change.to_html();
        _fn(change, li);
        _results.push(list_changes.append(li));
      }
      return _results;
    };

    GitoeUI.prototype.slideDown = function(section) {
      return this.section(section).slideDown();
    };

    GitoeUI.prototype.slideUp = function(section) {
      return this.section(section).slideUp();
    };

    GitoeUI.prototype.section = function(name) {
      return this.sections[name];
    };

    GitoeUI.prototype.elem = function(name) {
      return this.elems[name];
    };

    GitoeUI.prototype.bind_events = function() {
      return this.historian.set_cb({
        update_reflog: this.update_reflog,
        update_num_tags: this.update_num_tags
      });
    };

    return GitoeUI;

  })();

  GitoeController = (function() {
    function GitoeController(ids) {
      this.init_repo();
      this.init_canvas(ids.graph);
      this.init_control(ids.control);
      this.bind_events();
    }

    GitoeController.prototype.init_repo = function() {
      return this.repo = new GitoeRepo();
    };

    GitoeController.prototype.init_canvas = function(id) {
      return this.canvas = new GitoeCanvas(id);
    };

    GitoeController.prototype.init_control = function(id) {
      return this.ui = new GitoeUI(id);
    };

    GitoeController.prototype.bind_events = function() {
      var canvas, repo, ui;

      repo = this.repo;
      canvas = this.canvas;
      ui = this.ui;
      repo.set_cb({
        ajax_error: function() {
          var arg;

          arg = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          return log.apply(null, ['ajax_error'].concat(__slice.call(arg)));
        },
        fetched_commit: function(to_fetch, fetched) {
          flash("" + to_fetch + " commits to fetch", 1000);
          ui.update_num_commits(fetched);
          if (to_fetch > 0) {
            return repo.fetch_commits();
          } else {
            return repo.fetch_alldone();
          }
        },
        fetch_status: function(status) {
          return repo.fetch_commits();
        },
        yield_commit: canvas.add_commit_async
      });
      return ui.set_cb({
        repo_open: function(path) {
          flash("opening " + path, false);
          return repo.open(path, {
            fail: function(wtf) {
              return flash("error opening " + path);
            },
            success: function(response) {
              flash("opened " + path, 2000);
              return repo.fetch_status({
                success: function(status) {
                  ui.open_success();
                  return ui.update_status(status);
                }
              });
            }
          });
        },
        show_change: function(fun) {
          return fun.apply(canvas);
        }
      });
    };

    return GitoeController;

  })();

  $(function() {
    var c, ids;

    ids = {
      control: 'control',
      graph: 'graph'
    };
    return c = new GitoeController(ids);
  });

}).call(this);
