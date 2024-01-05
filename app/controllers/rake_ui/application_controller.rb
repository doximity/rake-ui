# frozen_string_literal: true

module RakeUi
  class ApplicationController < ActionController::Base
    before_action :black_hole_production
    skip_before_action :verify_authenticity_token

    private

    def black_hole_production
      return if Rails.env.test? || Rails.env.development? || RakeUi.configuration.allow_production

      raise ActionController::RoutingError, "Not Found"
    end
  end
end
