# frozen_string_literal: true

module RakeUi
  class ApplicationController < ActionController::Base
    before_action :black_hole_production

    STAGING_OK = (Rails.env.staging? && RakeUi.configuration.allow_staging)
    PROD_OK = RakeUi.configuration.allow_production

    private

    def black_hole_production
      return if Rails.env.test? || Rails.env.development? || STAGING_OK || PROD_OK

      raise ActionController::RoutingError, "Not Found"
    end
  end
end
