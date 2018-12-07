lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chloride/version'

Gem::Specification.new do |spec|
  spec.name          = 'chloride'
  spec.version       = Chloride::VERSION
  spec.authors       = ['Brandon High', 'Eric Williamson', 'Nick Lewis']
  spec.email         = ['brandon.high@puppet.com', 'eric.williamson@puppet.com', 'nick@puppet.com']

  spec.summary       = 'A simple streaming NetSSH implementation'
  # spec.description   = %q{TODO: More verbose description here.}
  spec.homepage      = 'https://github.com/puppetlabs/chloride'
  spec.license       = 'Apache-2.0'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '~> 2.4'

  spec.add_development_dependency 'bundler', '~> 1'
  spec.add_development_dependency 'pry', '~> 0.10'
  spec.add_development_dependency 'pry-coolline', '~> 0.2'
  spec.add_development_dependency 'rake', '~> 11'
  spec.add_development_dependency 'rspec', '~> 3'
  spec.add_development_dependency 'rubocop', '~> 0.44'
  spec.add_development_dependency 'simplecov', '~> 0.12'
  spec.add_dependency 'net-scp', '~> 1'
  spec.add_dependency 'net-ssh', '~> 4'
end
