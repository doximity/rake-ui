require 'rake'
require 'fileutils'

module RakeUi
  class Engine < ::Rails::Engine
    isolate_namespace RakeUi
  end
end
