class SimplySearchableGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      m.template "search.html.erb", "app/views/#{plural_name}/search.html.erb"
    end
  end
end
