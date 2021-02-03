RakeUi::Engine.routes.draw do
  resources :rake_tasks, only: [:index, :show] do
    resources :execute, only: [:create]
  end
end
