gitoe
=====
#### a local web app, to show local git changes

gitoe (hopefully) reveals:

- what did I do ?
- what did this `git command` do ?

gitoe can be installed by:

    $ gem install gitoe

And running

    $ gitoe

starts a local web server at [127.0.0.1:12345](127.0.0.1:12345).

it works by
- dig commits out of the repo, and visualize them
- look into `.git/logs/refs`, and parses `reflog` message.

gitoe is build upon

- [sinatra](www.sinatrarb.com)
- [libgit2/rugged](https://github.com/libgit2/rugged)
- [jquery](http://jquery.com/)
- [Raphaël](http://raphaeljs.com/)

