Rails.application.routes.draw do
  mount Rake::Ui::Engine => "/rake-ui"
end
