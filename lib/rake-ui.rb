# frozen_string_literal: true

require "rake-ui/engine"

module RakeUi
  mattr_accessor :allow_production
  mattr_accessor :allow_staging

  self.allow_production = false
  self.allow_staging = true

  def self.configuration
    yield(self) if block_given?
    self
  end
end
