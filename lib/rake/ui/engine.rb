module Rake
  module Ui
    class Engine < ::Rails::Engine
      isolate_namespace Rake::Ui
    end
  end
end
