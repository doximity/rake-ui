# frozen_string_literal: true

namespace :double_nested do
  namespace :inside_double_nested do
    desc "Doubley Nested Task"
    task :double_nested_task, [:user_id] => [:environment] do |_t, args|
      puts "double_nested_task start"
      puts args
      puts "double_nested_task end"
    end
    namespace :something_esle do
      desc "Something specific and stuff"
      task :double_nested_taskdouble_nested_taskdouble_nested_task, [:user_id, :foo_id] => [:environment] do |_t, args|
        puts "double_nested_task start"
        puts args
        puts "double_nested_task end"
      end
    end
  end
end
