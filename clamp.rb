require 'clamp'

class SpeakCommand < Clamp::Command
  option '--loud', :flag, 'say it loud'
  option ['-n', '--iterations'], 'N', 'say it N times', default: 1 do |s|
    Integer(s)
  end

  parameter 'WORDS ...', 'the thing to say', attribute_name: :words

  def execute
    the_truth = words.join(' ')
    the_truth.upcase! if loud?
    iterations.times do
      puts the_truth
    end
  end
end

SpeakCommand.run
