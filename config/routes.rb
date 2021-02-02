RakeUi::Engine.routes.draw do
  resources :rake_tasks, only: [:index, :show]
end
