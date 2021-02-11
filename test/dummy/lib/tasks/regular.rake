# frozen_string_literal: true

desc "This is a regular rake task with no environment"
task :regular do |args|
  30.times do |i|
    puts "Iterating! #{i}"
    sleep 1
  end
end
