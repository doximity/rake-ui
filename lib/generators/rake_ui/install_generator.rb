# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RakeUi
  class InstallGenerator < Rails::Generators::Base
    include ActiveRecord::Generators::Migration

    source_root File.expand_path("templates", __dir__)

    desc "Creates the migration for RakeUi database storage backend."

    def copy_migration
      migration_template(
        "create_rake_ui_task_logs.rb.erb",
        "db/migrate/create_rake_ui_task_logs.rb"
      )
    end

    def display_post_install_message
      say ""
      say "RakeUi database storage migration has been created.", :green
      say ""
      say "Next steps:"
      say "  1. Run `rails db:migrate`"
      say "  2. Configure RakeUi to use database storage in an initializer:"
      say ""
      say "     RakeUi.configuration do |config|"
      say "       config.storage_backend = :database"
      say "     end"
      say ""
    end
  end
end

