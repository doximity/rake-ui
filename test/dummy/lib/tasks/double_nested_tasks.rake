namespace :double_nested do
  namespace :inside_double_nested do
    desc "Doubley Nested Task"
    task :double_nested_task, [:user_id] => [:environment] do |_t, args|

      puts "double_nested_task start"
      puts args
      puts "double_nested_task end"
    end
  end
end