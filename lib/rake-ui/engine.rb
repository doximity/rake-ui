# frozen_string_literal: true

require "rake"
require "fileutils"
require "open3"
require "rake-ui/storage/file_store"
require "rake-ui/storage/database_store"

module RakeUi
  class Engine < ::Rails::Engine
    isolate_namespace RakeUi
  end
end
