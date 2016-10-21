# Chloride [![Build Status](https://travis-ci.org/highb/chloride.svg?branch=master)](https://travis-ci.org/highb/chloride)

A simple abstraction layer around NetSSH.

Features:
* `Host` allows you to easily SSH/SCP to a host using local SSH defaults
* `Actions` allow you to automate you interactions with `Host`s
* Create a sequence of `Actions` to be performed on `Host`s
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

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/highb/chloride. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.
