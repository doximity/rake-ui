# frozen_string_literal: true

require "rake"
require "fileutils"
require "open3"

module RakeUi
  class Engine < ::Rails::Engine
    isolate_namespace RakeUi
  end
end
