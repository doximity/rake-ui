# standardrb

You're probably looking for the
[Standard Ruby](https://github.com/testdouble/standard) repo.

This gem is effectively an alias of the gem
"[standard](https://rubygems.org/gems/standard)", whose binary is named
`standardrb` to avoid PATH collisions with [StandardJS](https://standardjs.org).
Anyone who runs `gem install standardrb` as a result, will have the `standard`
gem installed as an unpinned transitive dependency and—with it—the actual
`standardrb` executable.
