# frozen_string_literal: true

namespace :nested do
  desc "nested tasks"
  task :the_nested_task, [:user_id] => [:environment] do |_t, args|

    puts "the_nested_task start"
    puts args
    puts "the_nested_task end" * 10
  end
end
