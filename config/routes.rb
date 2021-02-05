RakeUi::Engine.routes.draw do
  root to: 'rake_tasks#index'

  resources :rake_tasks, only: [:index, :show]

  post "/rake_tasks/:id/execute", to: "rake_tasks#execute", as: "rake_task_execute"

  resources :rake_task_logs, only: [:index, :show]
end
