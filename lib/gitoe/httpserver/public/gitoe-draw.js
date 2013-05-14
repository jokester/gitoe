(function() {
  var $, DAGLayout, GitoeCanvas, R, clone, strcmp, _ref,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  $ = jQuery || (function() {
    throw "demand jQuery";
  })();

  R = Raphael || (function() {
    throw "demand Raphael";
  })();

  clone = function(obj) {
    return $.extend({}, obj);
  };

  strcmp = exports.gitoe.strcmp;

  DAGLayout = (function() {
    function DAGLayout(cb) {
      this.cb = cb;
      this.query_pos = __bind(this.query_pos, this);
      this.query_parents = __bind(this.query_parents, this);
      this.add_node = __bind(this.add_node, this);
      this.children = {};
      this.parents = {};
      this.layer = {};
      this.position = {};
      this.grid = {};
      this.layer_span = {};
    }

    DAGLayout.prototype.add_node = function(id, parents) {
      var layer, layer_span, pos;

      this.topo(id, parents);
      layer = this.get_layer(id);
      layer_span = this.get_layer_span(id, layer);
      pos = this.get_position(id, layer, layer_span);
      return this.cb.draw_node(id, layer, pos, layer_span);
    };

    DAGLayout.prototype.get_layer = function(id) {
      var layer, parent, parent_layer, _base, _i, _len, _ref, _ref1;

      layer = 0;
      _ref = this.parents[id];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        parent = _ref[_i];
        parent_layer = this.layer[parent];
        if (parent_layer >= layer) {
          layer = parent_layer + 1;
        }
      }
      if ((_ref1 = (_base = this.grid)[layer]) == null) {
        _base[layer] = [];
      }
      return this.layer[id] = layer;
    };

    DAGLayout.prototype.get_layer_span = function(id, layer) {
      var l, layer_span, parent, parent_layer, _i, _len, _ref;

      layer_span = 1;
      l = {};
      _ref = this.parents[id];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        parent = _ref[_i];
        parent_layer = this.layer[parent];
        l[parent] = parent_layer;
        if (parent_layer + layer_span < layer) {
          layer_span = layer - parent_layer;
        }
      }
      return this.layer_span[id] = layer_span;
    };

    DAGLayout.prototype.get_position = function(id, layer, layer_span) {
      var conflict, grid, layers_to_check, occupied, position, _i, _j, _len, _ref, _ref1, _results;

      position = -1;
      conflict = true;
      layers_to_check = (function() {
        _results = [];
        for (var _i = _ref = layer - layer_span + 1, _ref1 = layer; _ref <= _ref1 ? _i <= _ref1 : _i >= _ref1; _ref <= _ref1 ? _i++ : _i--){ _results.push(_i); }
        return _results;
      }).apply(this);
      grid = this.grid;
      while (conflict) {
        position++;
        occupied = layers_to_check.filter(function(layer) {
          return grid[layer][position];
        });
        if (occupied.length === 0) {
          conflict = false;
        }
      }
      for (_j = 0, _len = layers_to_check.length; _j < _len; _j++) {
        layer = layers_to_check[_j];
        this.grid[layer][position] = id;
      }
      return this.position[id] = position;
    };

    DAGLayout.prototype.topo = function(id, parents) {
      var cs, parent, _i, _len;

      for (_i = 0, _len = parents.length; _i < _len; _i++) {
        parent = parents[_i];
        cs = this.children[parent];
        if (cs === void 0) {
          throw "<" + id + "> added before its parent <" + parent + ">";
        } else {
          cs.push(id);
        }
      }
      if (this.parents[id]) {
        throw "<" + id + "> added more than once";
      }
      this.parents[id] = parents;
      return this.children[id] = [];
    };

    DAGLayout.prototype.query_parents = function(id) {
      return this.parents[id];
    };

    DAGLayout.prototype.query_pos = function(id) {
      return {
        layer: this.layer[id],
        pos: this.position[id]
      };
    };

    return DAGLayout;

  })();

  GitoeCanvas = (function() {
    GitoeCanvas.CONST = {
      canvas: {
        width: 300,
        height: 100
      },
      padding_left: 60,
      padding_top: 40,
      outer_width: 80,
      outer_height: 60,
      commit_handle: 10,
      box: {
        width: 60,
        height: 20,
        radius: 2,
        attr: {
          fill: "lightblue",
          "stroke-width": 2,
          stroke: 'black'
        }
      },
      text_attr: {
        'font-family': 'mono',
        'font-size': 12
      },
      path_style: {
        fill: 'pink',
        strokeWidth: 3
      }
    };

    function GitoeCanvas(id_container) {
      this.draw_async = __bind(this.draw_async, this);
      this.add_commit_async = __bind(this.add_commit_async, this);      this.dag = new DAGLayout({
        draw_node: this.draw_async
      });
      this.constant = clone(GitoeCanvas.CONST);
      this.init_canvas(id_container);
      this.objs = {};
      this.div = $("#" + id_container);
      this.ref_objs = {};
    }

    GitoeCanvas.prototype.add_commit_async = function(commit) {
      return setTimeout(this.add_commit.bind(this, commit), 500);
    };

    GitoeCanvas.prototype.draw_async = function(sha1, layer, pos) {
      return setTimeout(this.draw.bind(this, sha1, layer, pos), 0);
    };

    GitoeCanvas.prototype.add_commit = function(commit) {
      return this.dag.add_node(commit.sha1, commit.parents);
    };

    GitoeCanvas.prototype.draw = function(sha1, layer, pos) {
      var commit_box, coord, need_focus, parents, paths, text;

      if (this.objs[sha1]) {
        this.destroy(sha1);
      }
      coord = this.commit_coord(layer, pos);
      parents = this.dag.query_parents(sha1).map(this.dag.query_pos);
      commit_box = this.draw_commit_box(coord);
      text = this.draw_commit_text(coord, sha1);
      paths = this.draw_paths(coord, parents);
      need_focus = !!(this.canvas_inc_height(coord.top) + this.canvas_inc_width(coord.left));
      if (need_focus) {
        this.focus(coord);
      }
      return this.objs[sha1] = {
        commit_box: commit_box,
        text: text,
        paths: paths
      };
    };

    GitoeCanvas.prototype.clear_refs = function() {
      var obj, objs, ref_name, _ref, _results;

      _ref = this.ref_objs;
      _results = [];
      for (ref_name in _ref) {
        objs = _ref[ref_name];
        _results.push((function() {
          var _i, _len, _ref1, _results1;

          _ref1 = objs || [];
          _results1 = [];
          for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
            obj = _ref1[_i];
            _results1.push(obj.remove());
          }
          return _results1;
        })());
      }
      return _results;
    };

    GitoeCanvas.prototype.set_refs = function(refs) {
      var ref_index, ref_name, ref_names_sorted, _i, _len, _results;

      this.clear_refs();
      ref_names_sorted = Object.keys(refs).sort(strcmp);
      _results = [];
      for (ref_index = _i = 0, _len = ref_names_sorted.length; _i < _len; ref_index = ++_i) {
        ref_name = ref_names_sorted[ref_index];
        _results.push(this.ref_objs[ref_name] = this.draw_ref(ref_index, ref_name, refs[ref_name]));
      }
      return _results;
    };

    GitoeCanvas.prototype.draw_ref = function(ref_index, ref_name, sha1s) {
      var coord_last, p_last, sha1_last;

      sha1_last = sha1s[sha1s.length - 1];
      p_last = this.dag.query_pos(sha1_last);
      coord_last = this.commit_coord(p_last.layer, p_last.pos);
      this.focus(this.commit_coord(p_last.layer, p_last.pos));
      return [this.draw_ref_path(ref_index, sha1s), this.draw_ref_text(ref_index, coord_last, ref_name), this.draw_ref_pointer(ref_index, coord_last)];
    };

    GitoeCanvas.prototype.draw_ref_pointer = function(ref_index, p_last) {
      return this.canvas.path();
    };

    GitoeCanvas.prototype.draw_ref_text = function(ref_index, coord_last, ref_name) {
      console.log(ref_index, coord_last, ref_name);
      return this.canvas.text(coord_last.left + this.constant.box.width + (0.6 + ref_index) * 30 + ref_name.length * 2, coord_last.top + this.constant.box.height * (1 + ref_index) / 3, ref_name).attr(this.constant.text_attr);
    };

    GitoeCanvas.prototype.draw_ref_path = function(ref_index, sha1s, textbox_width) {
      var command_array, current, handler_top, index, prev, sha1, _i, _len;

      command_array = [];
      current = prev = null;
      handler_top = this.constant.box.height * (1 + ref_index) / 3;
      for (index = _i = 0, _len = sha1s.length; _i < _len; index = ++_i) {
        sha1 = sha1s[index];
        prev = current;
        current = this.commit_coord_by_sha1(sha1);
        if (index === 0) {
          command_array.push.apply(command_array, ['M', current.left + this.constant.box.width, current.top + handler_top]);
        } else {
          command_array.push.apply(command_array, ['Q', 50 + ref_index * 40 + this.constant.box.width + Math.max(current.left, prev.left), (current.top + prev.top) / 2 + handler_top - 35, this.constant.box.width + current.left, current.top + handler_top]);
        }
      }
      return this.canvas.path(command_array.join(' '));
    };

    GitoeCanvas.prototype.commit_coord = function(layer, pos) {
      return {
        left: this.constant.padding_left + this.constant.outer_width * pos,
        top: this.constant.padding_top + this.constant.outer_height * layer
      };
    };

    GitoeCanvas.prototype.commit_coord_by_sha1 = function(sha1) {
      var p;

      p = this.dag.query_pos(sha1);
      return this.commit_coord(p.layer, p.pos);
    };

    GitoeCanvas.prototype.draw_commit_box = function(coord) {
      return this.canvas.rect(coord.left, coord.top, this.constant.box.width, this.constant.box.height, this.constant.box.radius).attr(this.constant.box.attr);
    };

    GitoeCanvas.prototype.draw_commit_text = function(coord, sha1) {
      return this.canvas.text(coord.left + this.constant.box.width / 2, coord.top + this.constant.box.height / 2, sha1.slice(0, 8)).attr(this.constant.text_attr);
    };

    GitoeCanvas.prototype.draw_paths = function(coord, parents_pos) {
      var coord_p, p, path_command, paths, start, _i, _len;

      paths = [];
      start = ['M', coord.left + this.constant.box.width / 2, coord.top].join(' ');
      for (_i = 0, _len = parents_pos.length; _i < _len; _i++) {
        p = parents_pos[_i];
        coord_p = this.commit_coord(p.layer, p.pos);
        path_command = this.path_command(coord, coord_p);
        if (path_command) {
          paths.push(this.canvas.path(start + path_command));
        }
      }
      return paths;
    };

    GitoeCanvas.prototype.path_command = function(coord, coord_p) {
      var bottom_of_parent, ratio, top_of_highest_fake_node, vertical_distance;

      bottom_of_parent = {
        x: coord_p.left + this.constant.box.width / 2,
        y: coord_p.top + this.constant.box.height
      };
      top_of_highest_fake_node = {
        x: coord.left + this.constant.box.width / 2,
        y: coord_p.top + this.constant.outer_height
      };
      if (coord.left === coord_p.left) {
        return ['L', bottom_of_parent.x, bottom_of_parent.y].join(' ');
      } else {
        vertical_distance = this.constant.outer_height - this.constant.box.height;
        ratio = 0.3;
        return ['L', top_of_highest_fake_node.x, top_of_highest_fake_node.y, 'C', top_of_highest_fake_node.x, this.mix(top_of_highest_fake_node.y, bottom_of_parent.y, ratio), bottom_of_parent.x, this.mix(top_of_highest_fake_node.y, bottom_of_parent.y, 1 - ratio), bottom_of_parent.x, bottom_of_parent.y].join(' ');
      }
    };

    GitoeCanvas.prototype.mix = function(a, b, ratio) {
      return a * ratio + b * (1 - ratio);
    };

    GitoeCanvas.prototype.focus = function(coord) {
      return this.div.scrollTo({
        left: coord.left - 200,
        top: coord.top - 200
      });
    };

    GitoeCanvas.prototype.init_canvas = function(id_canvas) {
      this.canvas_size = clone(this.constant.canvas);
      return this.canvas = R(id_canvas, this.canvas_size.width, this.canvas_size.height);
    };

    GitoeCanvas.prototype.canvas_inc_width = function(left) {
      if (left + this.constant.outer_width > this.canvas_size.width) {
        this.canvas_size.width += 1 * this.constant.outer_width;
        this.canvas_resize();
        return true;
      } else {
        return false;
      }
    };

    GitoeCanvas.prototype.canvas_inc_height = function(top) {
      if (top + this.constant.outer_height > this.canvas_size.height) {
        this.canvas_size.height += 1 * this.constant.outer_height;
        this.canvas_resize();
        return true;
      } else {
        return false;
      }
    };

    GitoeCanvas.prototype.canvas_resize = function() {
      return this.canvas.setSize(this.canvas_size.width, this.canvas_size.height);
    };

    return GitoeCanvas;

  })();

  if ((_ref = this.exports) == null) {
    this.exports = {
      gitoe: {}
    };
  }

  exports.gitoe.GitoeCanvas = GitoeCanvas;

}).call(this);
