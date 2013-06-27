gitoe
=====
#### a local web app, to show local git changes

gitoe (hopefully) reveals changes done in a local repository, like:

- what did I do ?
- what did this `git command` do ?

gitoe can be installed by:

    $ gem install gitoe

And running

    $ gitoe

By default, it starts a local web server at [127.0.0.1:12345](http://127.0.0.1:12345/). Interface and port can be specified, run `gitoe -h` for complete usage.

It works by
- dig commits out of the repo, and visualize them
- look into `.git/logs/refs`, and parses `reflog` message.

Gitoe is build upon

- [sinatra](http://www.sinatrarb.com)
- [libgit2/rugged](https://github.com/libgit2/rugged)
- [jquery](http://jquery.com/)
- [jquery.scrollTo](https://github.com/flesler/jquery.scrollTo)
- [Raphaël](http://raphaeljs.com/)

