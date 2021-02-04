RakeUi::Engine.routes.draw do
  resources :rake_tasks, only: [:index, :show]

  post "/rake_tasks/:id/execute", to: "rake_tasks#execute", as: "rake_task_execute"
end
