# frozen_string_literal: true

require "rake-ui/engine"

module RakeUi
  mattr_accessor :allow_production
  self.allow_production = false

  mattr_accessor :current_user_method
  self.current_user_method = nil

  mattr_accessor :whitelisted_prefixes
  self.whitelisted_prefixes = []

  # Storage backend: :file (default) or :database
  mattr_accessor :storage_backend
  self.storage_backend = :file

  def self.configuration
    yield(self) if block_given?
    self
  end

  def self.store
    @store = nil if @last_storage_backend != storage_backend
    @last_storage_backend = storage_backend

    @store ||= case storage_backend.to_sym
    when :file
      RakeUi::Storage::FileStore.new
    when :database
      RakeUi::Storage::DatabaseStore.new
    else
      raise ArgumentError, "Unknown RakeUi storage_backend: #{storage_backend}. Use :file or :database."
    end
  end
end
