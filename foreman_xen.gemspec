$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'foreman_xen/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'foreman_xen'
  s.version     = ForemanXen::VERSION
  s.authors     = ['Pavel Nemirovsky', 'Michal Piotrowski', 'Avi Israeli']
  s.email       = ['operations@oovoo.com']
  s.homepage    = 'http://github.com/theforeman/foreman-xen'
  s.summary     = 'Provision and manage XEN Server from Foreman'
  s.description = 'Provision and manage XEN Server from Foreman.'
  s.licenses    = ['GPL-3']

  s.add_dependency 'fog-xenserver', '~> 0.2'
  s.add_development_dependency('rake')

  s.files = Dir['{app,config,db,lib,locale}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  s.test_files = Dir['test/**/*']
end
