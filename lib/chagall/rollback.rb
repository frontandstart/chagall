module Chagall
  class Rollback < Base
    option [ "--steps" ], "STEPS", "Number of steps to rollback", default: "1" do |s|
      Integer(s)
    end

    def execute
      puts "Rollback functionality not implemented yet"
    end
  end
end
