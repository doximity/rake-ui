require_relative "lib/rake_ui/version"

Gem::Specification.new do |spec|
  spec.name        = "rake-ui"
  spec.version     = RakeUi::VERSION
  spec.authors     = ["Austin Story"]
  spec.email       = ["lonnieastory@gmail.com"]
  spec.homepage    = "https://github.com/doximity/rake-ui"
  spec.summary     = "A Mountable Rails Engine to manage Rake Tasks through a UI"
  spec.description = "This gem creates a Web Interface for interacting with Rake tasks."
  spec.license     = "Apache-2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/doximity/rake-ui"
  spec.metadata["changelog_uri"] = "https://github.com/doximity/rake-ui/CHANGELOG.md"

  spec.files = Dir["{app,config,db,lib}/**/*", "LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "activesupport"
  spec.add_dependency "actionpack"
  spec.add_dependency "railties"
  spec.add_dependency "rake"
end
