# frozen_string_literal: true

Rails.application.routes.draw do
  mount RakeUi::Engine => "/rake-ui"
end
