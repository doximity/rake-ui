lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name = "standardrb"
  spec.version = "1.0.1"
  spec.authors = ["Justin Searls"]
  spec.email = ["searls@gmail.com"]

  spec.summary = "Alias for the standard gem, which has a standardrb binary"
  spec.homepage = "https://github.com/testdouble/standardrb"
  spec.license = "MIT"

  spec.files = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "standard"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
end
