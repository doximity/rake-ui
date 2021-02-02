json.rake_tasks do
  json.array! @rake_tasks, partial: 'rake_ui/rake_tasks/rake_task', as: :rake_task
end
