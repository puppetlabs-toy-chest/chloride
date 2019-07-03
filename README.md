# Chloride
[![Gem Version](https://badge.fury.io/rb/chloride.svg)](https://badge.fury.io/rb/chloride)
[![Build Status](https://travis-ci.org/puppetlabs/chloride.svg?branch=master)](https://travis-ci.org/puppetlabs/chloride)
[![Issue Count](https://codeclimate.com/github/puppetlabs/chloride/badges/issue_count.svg)](https://codeclimate.com/github/puppetlabs/chloride)

A simple abstraction layer around NetSSH.

Features:
* `Host` allows you to easily SSH/SCP to a host using local SSH defaults
* `Actions` allows you to automate your interactions on a `Host`
* Put it all together in order to automate your SSH-based workflows, such as
  installing Puppet.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'chloride'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install chloride

## Usage

Check out the example [`go_execute` command](bin/go_execute)

    $ bundle exec bin/go_execute 'abc123.example.com' 'cat /etc/hosts'

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Release

We use [gem-release](https://github.com/svenfuchs/gem-release) to make the gem release process easier.
```
# First, ensure that all the files in the repo are world-readable
chmod -R ugo+r *

# with any of the following commands, provide --pretend to see what would happen
# Second, bump the lib/chloride/version.rb file, and create a signed commit
bundle exec gem bump -s -v 1.1.1       # Bump to the given, specific version number
bundle exec gem bump -s -v major       # Bump to the next major level (e.g. 0.0.1 to 1.0.0)
bundle exec gem bump -s -v minor       # Bump to the next minor level (e.g. 0.0.1 to 0.1.0)
bundle exec gem bump -s -v patch       # Bump to the next patch level (e.g. 0.0.1 to 0.0.2)

# Finally, tag and release
bundle exec gem release -t -p       # Tag (-t), and push (-p) the gem

# If you want to do it all in one
bundle exec gem bump -v patch -s -t -p
```

## Contributing

[Bug reports](https://github.com/puppetlabs/chloride/issues) and [pull requests](https://github.com/puppetlabs/chloride/pulls) are welcome on GitHub at https://github.com/puppetlabs/chloride. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

See [LICENSE](LICENSE) file.

## Support

We use [semantic version numbers](https://semvar.org) for our releases, and recommend that users stay as up-to-date as possible by upgrading to patch releases and minor releases as they become available.

Bugfixes and ongoing development will occur in minor releases for the current major version.

Technical support is __not__ provided for this library.
