(function() {
  var $, DAGtopo, GitoeChange, GitoeHistorian, GitoeRepo, OrderedSet, clone, exec_callback, local, strcmp, uniq, url_root, _ref,
    __slice = [].slice,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  $ = jQuery || (function() {
    throw "demand jQuery";
  })();

  moment || (function() {
    throw "demand moment";
  })();

  url_root = "/repo";

  exec_callback = function(context, fun, args) {
    return fun.apply(context, args);
  };

  clone = function(obj) {
    return $.extend({}, obj);
  };

  local = '##??!';

  uniq = function(old_array, ignore_list) {
    var elem, i, ignore, new_array, _i, _j, _len, _len1;

    if (ignore_list == null) {
      ignore_list = ['0000000000000000000000000000000000000000'];
    }
    ignore = {};
    for (_i = 0, _len = ignore_list.length; _i < _len; _i++) {
      i = ignore_list[_i];
      ignore[i] = true;
    }
    new_array = [];
    for (_j = 0, _len1 = old_array.length; _j < _len1; _j++) {
      elem = old_array[_j];
      if (!ignore[elem]) {
        ignore[elem] = true;
        new_array.push(elem);
      }
    }
    return new_array;
  };

  strcmp = function(str1, str2, pos) {
    var c1, c2;

    if (pos == null) {
      pos = 0;
    }
    c1 = str1.charAt(pos);
    c2 = str2.charAt(pos);
    if (c1 < c2) {
      return 1;
    } else if (c1 > c2) {
      return -1;
    } else if (c1 === '') {
      return 0;
    } else {
      return strcmp(str1, str2, pos + 1);
    }
  };

  OrderedSet = (function() {
    function OrderedSet() {
      this.elems = [];
      this.hash = {};
    }

    OrderedSet.prototype.push = function(new_elem) {
      if (!this.hash[new_elem]) {
        this.hash[new_elem] = true;
        this.elems.push(new_elem);
        return true;
      } else {
        return false;
      }
    };

    OrderedSet.prototype.length = function() {
      return this.elems.length;
    };

    OrderedSet.prototype.shift = function() {
      var ret;

      if (!(this.elems.length > 0)) {
        throw "empty";
      }
      ret = this.elems.shift();
      delete this.hash[ret];
      return ret;
    };

    return OrderedSet;

  })();

  DAGtopo = (function() {
    function DAGtopo() {
      this.edges = {};
    }

    DAGtopo.prototype.add_edge = function(from, to) {
      var _base, _base1, _ref, _ref1;

      if ((_ref = (_base = this.edges)[from]) == null) {
        _base[from] = [];
      }
      if ((_ref1 = (_base1 = this.edges)[to]) == null) {
        _base1[to] = [];
      }
      return this.edges[from].push(to);
    };

    DAGtopo.prototype.sort = function() {
      var from, in_degree, node, nodes_whose_in_degree_is_0, sorted, to, to_s, _i, _j, _len, _len1, _ref, _ref1, _ref2, _ref3;

      in_degree = {};
      _ref = this.edges;
      for (from in _ref) {
        to_s = _ref[from];
        if ((_ref1 = in_degree[from]) == null) {
          in_degree[from] = 0;
        }
        for (_i = 0, _len = to_s.length; _i < _len; _i++) {
          to = to_s[_i];
          if ((_ref2 = in_degree[to]) == null) {
            in_degree[to] = 0;
          }
          in_degree[to]++;
        }
      }
      sorted = [];
      nodes_whose_in_degree_is_0 = Object.keys(in_degree).filter(function(node) {
        return in_degree[node] === 0;
      });
      while (nodes_whose_in_degree_is_0.length > 0) {
        node = nodes_whose_in_degree_is_0.shift();
        delete in_degree[node];
        sorted.push(node);
        _ref3 = this.edges[node];
        for (_j = 0, _len1 = _ref3.length; _j < _len1; _j++) {
          to = _ref3[_j];
          if (--in_degree[to] === 0) {
            nodes_whose_in_degree_is_0.push(to);
          }
        }
      }
      return sorted;
    };

    return DAGtopo;

  })();

  GitoeChange = (function() {
    GitoeChange.parse = function(repos) {
      var change, changes, grouped_changes, ref_content, ref_name, repo_content, repo_name, _i, _len, _ref;

      changes = [];
      for (repo_name in repos) {
        repo_content = repos[repo_name];
        for (ref_name in repo_content) {
          ref_content = repo_content[ref_name];
          _ref = ref_content.log;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            change = _ref[_i];
            change['repo_name'] = repo_name;
            change["ref_name"] = ref_name;
            changes.push(change);
          }
        }
      }
      changes.sort(function(a, b) {
        return (a.committer.time - b.committer.time) || strcmp(a.repo_name, b.repo_name) || -((a.ref_name === "HEAD") - (b.ref_name === "HEAD")) || strcmp(a.ref_name, b.ref_name);
      });
      grouped_changes = this.group(changes);
      console.log(changes, grouped_changes);
      return grouped_changes.map(function(group) {
        return new GitoeChange(group);
      });
    };

    GitoeChange.group = function(changes) {
      var begin, change, end, groups, next, _i, _len;

      groups = [];
      begin = 0;
      for (end = _i = 0, _len = changes.length; _i < _len; end = ++_i) {
        change = changes[end];
        next = changes[end + 1];
        if ((change.ref_name !== "HEAD") || (/^rebase: aborting/.test(change.message)) || (end === changes.length - 1) || (next.repo_name !== change.repo_name) || (/^checkout:/.test(change.message) && !/^(rebase|cherry-pick)/.test(next.message))) {
          groups.push(changes.slice(begin, +end + 1 || 9e9));
          begin = end + 1;
        }
      }
      return groups;
    };

    function GitoeChange(changes) {
      this.main = changes[changes.length - 1];
      if (changes.length > 1) {
        this.rest = changes.slice(0, +(changes.length - 2) + 1 || 9e9);
      } else {
        this.rest = [];
      }
      if (this.main.repo_name === local) {
        this.is_local = true;
      } else {
        this.is_local = false;
      }
    }

    GitoeChange.prototype.to_html = function() {
      var html, matched, pattern, regex, rules, _ref;

      rules = GitoeChange.message_rules;
      html = GitoeChange.html;
      _ref = rules.patterns;
      for (pattern in _ref) {
        regex = _ref[pattern];
        if (matched = this.main.message.match(regex)) {
          return rules.actions[pattern].apply(html, [matched, this.main, this.rest]).addClass("reflog");
        }
      }
      console.log("not recognized change : ", this.main, this.rest);
      return $('<li>').text("???").addClass("unknown");
    };

    GitoeChange.prototype.on_click = function() {
      var change, fullname, ref_fullname, refs, sha1_s, _i, _len, _ref, _ref1, _ref2;

      refs = {};
      ref_fullname = GitoeChange.html.ref_fullname;
      _ref = this.rest;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        change = _ref[_i];
        fullname = ref_fullname(change);
        if ((_ref1 = refs[fullname]) == null) {
          refs[fullname] = [];
        }
        refs[fullname].push(change.oid_old);
        refs[fullname].push(change.oid_new);
      }
      fullname = ref_fullname(this.main);
      if ((_ref2 = refs[fullname]) == null) {
        refs[fullname] = [];
      }
      refs[fullname].push(this.main.oid_old);
      refs[fullname].push(this.main.oid_new);
      for (fullname in refs) {
        sha1_s = refs[fullname];
        refs[fullname] = uniq(sha1_s);
      }
      return function() {
        return this.set_refs(refs);
      };
    };

    GitoeChange.html = {
      span: function(text, classes) {
        return $("<span>").text(text).addClass(classes);
      },
      li: function(content, classes) {
        return $("<li>").append(content).addClass(classes);
      },
      ref: function(text) {
        return this.span(text, 'ref_name');
      },
      ref_fullname: function(change) {
        if (change.repo_name === local) {
          return change.ref_name;
        } else {
          return "" + change.repo_name + "/" + change.ref_name;
        }
      },
      git_command: function(text) {
        return this.span(text, "git_command");
      },
      ref_realname: function(ref_name) {
        var splited;

        splited = ref_name.split("/");
        if (splited[0] === "HEAD") {
          return "HEAD";
        } else if (splited[0] === "refs") {
          switch (splited[1]) {
            case "heads":
              return splited[2];
            case "remotes":
              return "" + splited[2] + "/" + splited[3];
            case "tags":
              return splited[2];
            default:
              console.log("not recognized", ref_name);
              return "???";
          }
        } else {
          console.log("not recognized", ref_name);
          return "???";
        }
      },
      sha1_commit: function(sha1) {
        return this.span(sha1, "sha1_commit");
      },
      br: function() {
        return $('<br>');
      },
      pretty_abs_time: function(change) {
        return this.span(moment.unix(change.committer.time).format("YYYY-MM-DD HH:mm:ss"), "git_abs_time");
      },
      pretty_relative_time: function(change) {
        return this.span(moment.unix(change.committer.time).fromNow(), "git_rel_time");
      },
      p_with_time: function(change, elems) {
        return this.p([this.pretty_abs_time(change), this.span(" / "), this.pretty_relative_time(change), this.span(" : ")].concat(__slice.call(elems)));
      },
      p: function(elements) {
        var e, ret, _i, _len;

        ret = $('<p>');
        for (_i = 0, _len = elements.length; _i < _len; _i++) {
          e = elements[_i];
          ret.append(e);
        }
        return ret;
      }
    };

    GitoeChange.message_rules = {
      patterns: {
        clone: /^clone: from (.*)/,
        branch: /^branch: Created from (.*)/,
        commit: /^commit: /,
        commit_amend: /^commit \(amend\): /,
        merge_commit: /^commit \(merge\): Merge branch '?([^ ]+)'? into '?([^ ]+)'?$/,
        merge_ff: /^merge ([^:]*):/,
        reset: /^reset: moving to (.*)/,
        push: /^update by push/,
        pull: /^pull: /,
        fetch: /^fetch/,
        checkout: /^checkout: moving from ([^ ]+) to ([^ ]+)/,
        rename_remote: /^remote: renamed ([^ ]+) to ([^ ]+)/,
        rebase_finish: /^rebase (-[^ ]+)? \(finish\): returning to (.*)/,
        rebase_finish2: /^rebase (-[^ ]+)? \(finish\): ([^ ]+) onto/,
        rebase_finish3: /^rebase (-[^ ]+ )?finished: ([^ ]+) onto/,
        rebase_abort: /^rebase: aborting/
      },
      actions: {
        clone: function(matched, change) {
          return this.li([this.p_with_time(change, [this.git_command("git clone")]), this.p([this.span("create "), this.ref(this.ref_fullname(change)), this.span(" at "), this.sha1_commit(change.oid_new)])]);
        },
        branch: function(matched, change) {
          return this.li([this.p_with_time(change, [this.git_command("git branch")]), this.p([this.span("create branch "), this.ref(this.ref_fullname(change)), this.span(" at "), this.sha1_commit(change.oid_new), /^refs/.test(matched[1]) ? this.span(" (was ") : void 0, /^refs/.test(matched[1]) ? this.ref(this.ref_realname(matched[1])) : void 0, /^refs/.test(matched[1]) ? this.span(" )") : void 0])]);
        },
        commit: function(matched, change) {
          return this.li([this.p_with_time(change, [this.git_command("git commit")]), this.p([this.span("move "), this.ref(this.ref_fullname(change)), this.span(" from "), this.sha1_commit(change.oid_old), this.span(" to "), this.sha1_commit(change.oid_new)])]);
        },
        merge_commit: function(matched, change) {
          return this.li([this.p_with_time(change, [this.git_command("git merge")]), this.p([this.span("move "), this.span(matched[2], "ref_name"), this.span(' to '), this.sha1_commit(change.oid_new), this.span(' by merging '), this.span(matched[1], "ref_name")])]);
        },
        commit_amend: function(matched, change) {
          return this.li([this.p_with_time(change, [this.git_command("git commit --amend")]), this.p([this.span("move "), this.ref(this.ref_fullname(change)), this.span(" from "), this.sha1_commit(change.oid_old), this.span(" to "), this.sha1_commit(change.oid_new)])]);
        },
        merge_ff: function(matched, change) {
          return this.li([this.p_with_time(change, [this.git_command("git merge"), this.span(" (fast-forward)", "comment")]), this.p([this.span("move "), this.ref(this.ref_fullname(change)), this.span(' to '), this.sha1_commit(change.oid_new), this.span(' by merging '), this.span(matched[1], "ref_name")])]);
        },
        reset: function(matched, change) {
          return this.li([this.p_with_time(change, [this.git_command("git reset")]), this.p([this.span("point "), this.ref(this.ref_fullname(change)), this.span(" to "), this.sha1_commit(change.oid_new), this.span("(was "), this.sha1_commit(change.oid_old), this.span(")")])]);
        },
        push: function(matched, change) {
          return this.li([this.p_with_time(change, [this.git_command("git push")]), this.p([this.span("update "), this.ref(this.ref_fullname(change)), change.oid_old !== "0000000000000000000000000000000000000000" ? this.span(" from ") : void 0, change.oid_old !== "0000000000000000000000000000000000000000" ? this.sha1_commit(change.oid_old) : void 0, this.span(" to "), this.sha1_commit(change.oid_new)])]);
        },
        fetch: function(matched, change) {
          return this.li([this.p_with_time(change, [this.git_command("git fetch")]), this.p([this.span("update "), this.ref(this.ref_fullname(change)), change.oid_old !== "0000000000000000000000000000000000000000" ? this.span(" from ") : void 0, change.oid_old !== "0000000000000000000000000000000000000000" ? this.sha1_commit(change.oid_old) : void 0, this.span(" to "), this.sha1_commit(change.oid_new)])]);
        },
        pull: function(matched, change) {
          return this.li([this.p_with_time(change, [this.git_command("git pull")]), this.p([this.span("update "), this.ref(this.ref_fullname(change)), this.span(" from "), this.sha1_commit(change.oid_old), this.span(" to "), this.sha1_commit(change.oid_new)])]);
        },
        checkout: function(matched, change, rest) {
          return this.li([this.p_with_time(change, [this.git_command("git checkout")]), this.p([this.span("checkout "), this.ref(matched[2]), this.span(" at "), this.sha1_commit(change.oid_new)])]);
        },
        rename_remote: function(matched, change) {
          return this.li([this.p_with_time(change, [this.git_command("git remote rename")]), this.p([this.span("rename "), this.ref(this.ref_realname(matched[1])), this.span(" to "), this.ref(this.ref_realname(matched[2]))])]);
        },
        rebase_finish: function(matched, change) {
          return this.li([this.p_with_time(change, [matched[1] ? this.git_command("git rebase " + matched[1]) : this.git_command("git rebase")]), this.p([this.span("rebase "), this.ref(this.ref_realname(matched[2])), this.span(" to "), this.sha1_commit(change.oid_new)])]);
        },
        rebase_finish2: function(matched, change) {
          return this.li([this.p_with_time(change, [matched[1] ? this.git_command("git rebase " + matched[1]) : this.git_command("git rebase")]), this.p([this.span("rebase "), this.ref(this.ref_fullname(change)), this.span(" to "), this.sha1_commit(change.oid_new)])]);
        },
        rebase_finish3: function(matched, change) {
          return this.li([this.p_with_time(change, [matched[1] ? this.git_command("git rebase " + matched[1]) : this.git_command("git rebase")]), this.p([this.span(": rebase "), this.ref(this.ref_fullname(change)), this.span(" to "), this.sha1_commit(change.oid_new)])]);
        },
        rebase_abort: function(matched, change, rest) {
          var matched_head, real_ref;

          if (rest.length > 0) {
            if (matched_head = rest[0].message.match(/^checkout: moving from ([^ ]+)/)) {
              real_ref = matched_head[1];
            }
          }
          return this.li([this.p_with_time(change, [this.git_command("git rebase --abort")]), this.p([this.span("didn't rebase "), real_ref ? this.ref(real_ref) : void 0])]);
        }
      }
    };

    return GitoeChange;

  })();

  GitoeHistorian = (function() {
    function GitoeHistorian() {
      this.cb = {};
    }

    GitoeHistorian.prototype.set_cb = function(new_cb) {
      var fun, name, _results;

      _results = [];
      for (name in new_cb) {
        fun = new_cb[name];
        _results.push(this.cb[name] = fun);
      }
      return _results;
    };

    GitoeHistorian.prototype.parse = function(refs) {
      var changes, classified, _base, _base1;

      classified = this.classify(clone(refs));
      console.log(classified);
      if (typeof (_base = this.cb).update_num_tags === "function") {
        _base.update_num_tags(Object.keys(classified.tags).length);
      }
      changes = GitoeChange.parse(classified.repos);
      return typeof (_base1 = this.cb).update_reflog === "function" ? _base1.update_reflog(changes) : void 0;
    };

    GitoeHistorian.prototype.classify = function(refs) {
      var ref_content, ref_name, repos, splited, tags, _name, _ref, _ref1, _ref2;

      repos = {};
      tags = {};
      for (ref_name in refs) {
        ref_content = refs[ref_name];
        splited = ref_name.split("/");
        if (splited[0] === "HEAD" && splited.length === 1) {
          if ((_ref = repos[local]) == null) {
            repos[local] = {};
          }
          repos[local]["HEAD"] = ref_content;
        } else if (splited[0] === "refs") {
          switch (splited[1]) {
            case "heads":
              if ((_ref1 = repos[local]) == null) {
                repos[local] = {};
              }
              repos[local][splited[2]] = ref_content;
              break;
            case "remotes":
              if ((_ref2 = repos[_name = splited[2]]) == null) {
                repos[_name] = {};
              }
              repos[splited[2]][splited[3]] = ref_content;
              break;
            case "tags":
              tags[splited[2]] = ref_content;
              break;
            default:
              console.log("not recognized", ref_name);
          }
        } else {
          console.log("not recognized", ref_name);
        }
      }
      return {
        repos: repos,
        tags: tags
      };
    };

    return GitoeHistorian;

  })();

  GitoeRepo = (function() {
    function GitoeRepo() {
      this.ajax_error = __bind(this.ajax_error, this);
      this.ajax_fetch_status_success = __bind(this.ajax_fetch_status_success, this);
      this.ajax_fetch_commits_success = __bind(this.ajax_fetch_commits_success, this);
      this.ajax_open_success = __bind(this.ajax_open_success, this);
      this.fetch_commits = __bind(this.fetch_commits, this);
      this.open = __bind(this.open, this);      this.commits_to_fetch = {};
      this.commits_fetched = {};
      this.cb = {};
      this.commits_ignored = {
        "0000000000000000000000000000000000000000": true
      };
    }

    GitoeRepo.prototype.set_cb = function(new_cb) {
      var fun, name, _results;

      _results = [];
      for (name in new_cb) {
        fun = new_cb[name];
        _results.push(this.cb[name] = fun);
      }
      return _results;
    };

    GitoeRepo.prototype.open = function(path, cb) {
      if (cb == null) {
        cb = {};
      }
      return $.post("" + url_root + "/new", {
        path: path
      }).fail(this.ajax_error, cb.fail).done(this.ajax_open_success, cb.success);
    };

    GitoeRepo.prototype.fetch_commits = function(cb) {
      var param, to_query;

      if (cb == null) {
        cb = {};
      }
      if (!this.path) {
        throw "not opened";
      }
      to_query = Object.keys(this.commits_to_fetch).slice(0, 10);
      param = {
        limit: 1000
      };
      return $.get("" + this.path + "/commits/" + (to_query.join()), param).fail(this.ajax_error, cb.fail).done(this.ajax_fetch_commits_success, cb.success);
    };

    GitoeRepo.prototype.fetch_status = function(cb) {
      if (cb == null) {
        cb = {};
      }
      return $.get("" + this.path + "/").fail(this.ajax_error, cb.fail).done(this.ajax_fetch_status_success, cb.success);
    };

    GitoeRepo.prototype.fetch_alldone = function() {
      var child, content, parent, sha1, sorted_commits, sorter, _base, _i, _j, _len, _len1, _ref, _ref1, _results;

      sorter = new DAGtopo;
      _ref = this.commits_fetched;
      for (child in _ref) {
        content = _ref[child];
        _ref1 = content.parents;
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          parent = _ref1[_i];
          sorter.add_edge(parent, child);
        }
      }
      sorted_commits = sorter.sort();
      _results = [];
      for (_j = 0, _len1 = sorted_commits.length; _j < _len1; _j++) {
        sha1 = sorted_commits[_j];
        _results.push(typeof (_base = this.cb).yield_commit === "function" ? _base.yield_commit(this.commits_fetched[sha1]) : void 0);
      }
      return _results;
    };

    GitoeRepo.prototype.ajax_open_success = function(json) {
      if (this.path) {
        throw "already opened";
      }
      return this.path = "" + url_root + "/" + json.id;
    };

    GitoeRepo.prototype.ajax_fetch_commits_success = function(json) {
      var content, fetched, sha1, sha1_parent, to_fetch, _base, _base1, _i, _len, _ref;

      for (sha1 in json) {
        content = json[sha1];
        delete this.commits_to_fetch[sha1];
        (_base = this.commits_fetched)[sha1] || (_base[sha1] = content);
        _ref = content.parents;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          sha1_parent = _ref[_i];
          if (!(this.commits_fetched[sha1] || this.commits_ignored[sha1])) {
            this.commits_to_fetch[sha1_parent] = true;
          }
        }
      }
      to_fetch = Object.keys(this.commits_to_fetch).length;
      fetched = Object.keys(this.commits_fetched).length;
      return typeof (_base1 = this.cb).fetched_commit === "function" ? _base1.fetched_commit(to_fetch, fetched) : void 0;
    };

    GitoeRepo.prototype.ajax_fetch_status_success = function(response) {
      var change, field, ref, ref_name, sha1, _base, _i, _j, _len, _len1, _ref, _ref1, _ref2;

      _ref = response.refs;
      for (ref_name in _ref) {
        ref = _ref[ref_name];
        _ref1 = ref.log;
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          change = _ref1[_i];
          _ref2 = ['oid_new', 'oid_old'];
          for (_j = 0, _len1 = _ref2.length; _j < _len1; _j++) {
            field = _ref2[_j];
            sha1 = change[field];
            if (!(this.commits_fetched[sha1] || this.commits_ignored[sha1])) {
              this.commits_to_fetch[sha1] = true;
            }
          }
        }
      }
      return typeof (_base = this.cb).fetch_status === "function" ? _base.fetch_status(response) : void 0;
    };

    GitoeRepo.prototype.ajax_error = function(jqXHR) {
      var _base;

      return typeof (_base = this.cb).ajax_error === "function" ? _base.ajax_error(jqXHR) : void 0;
    };

    return GitoeRepo;

  })();

  if ((_ref = this.exports) == null) {
    this.exports = {
      gitoe: {}
    };
  }

  exports.gitoe.strcmp = strcmp;

  exports.gitoe.GitoeRepo = GitoeRepo;

  exports.gitoe.GitoeHistorian = GitoeHistorian;

}).call(this);
