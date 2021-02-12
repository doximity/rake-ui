# frozen_string_literal: true

module RakeUi
  class ApplicationController < ActionController::Base
    before_action :black_hole_production

    private

    def black_hole_production
      raise ActionController::RoutingError, 'Not Found' unless Rails.env.test? || Rails.env.development?
    end
  end
end
