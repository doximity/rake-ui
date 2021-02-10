# frozen_string_literal: true

module RakeUi
  class ApplicationController < ActionController::Base
    before_action :guard_not_production

    private

    def guard_not_production
      respond :unauthorized unless (Rails.env.test? || Rails.env.development?)
    end
  end
end
