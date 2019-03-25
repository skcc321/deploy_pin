module DeployPin::Runner
  def self.pending
    @pending ||= begin
                   binding.pry
                   Dir["/path/to/search/**/*.rb"]
                 end
  end

  def self.run
  end
end
