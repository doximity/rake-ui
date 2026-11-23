# frozen_string_literal: true

require "rake-ui/engine"

module RakeUi
  mattr_accessor :allow_production
  self.allow_production = false

  mattr_accessor :log_directory
  mattr_accessor :log_reader
  mattr_accessor :log_list
  mattr_accessor :log_writer

  def self.configuration
    yield(self) if block_given?
    self
  end
end
