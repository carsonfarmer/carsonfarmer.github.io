require 'fileutils'
require 'liquid'
require 'yaml'

if File.exist?("config.yml")
    config = YAML.load_file("config.yml")
else
    raise "Error: config.yml not found."
end

settings = YAML.load_file("config.yml") || {}

#
source_dir = "./themes/#{settings["theme"] || "default"}"
destination_dir = "./_output/"

# Clean _output folder
if Dir.exist?(destination_dir)
    Dir.foreach(destination_dir) do |file|
        next if file == '.' || file == '..' || file == 'AUTO_GEN_FOLDER_DO_NOT_EDIT_FILE_HERE'
        file_path = File.join(destination_dir, file)

        if File.file?(file_path)
            FileUtils.rm(file_path)
        end
    end
else
    FileUtils.mkdir_p(destination_dir)
end

# Copy all files and directories while preserving the structure
Dir.glob("#{source_dir}/**/*").each do |entry|
  relative_path = entry.sub("#{source_dir}/", '')

  new_location = File.join(destination_dir, relative_path)

  if File.directory?(entry)
    FileUtils.mkdir_p(new_location)
  else
    FileUtils.cp(entry, new_location)
  end
end


template_file = "#{destination_dir}/index.html"
if !File.exist?(template_file)
    raise "Error: #{template_file} file not found."
end


template_content = File.read(template_file)

settings["vars"] = {}
if !settings["plugins"].nil?
  settings["plugins"].each do |plugin|
    pluginFileName = plugin.keys[0]
    if File.exist?("./plugins/#{pluginFileName}.rb")
      require_relative "./plugins/#{pluginFileName}.rb"
      pluginObject = Object.const_get(pluginFileName).new(plugin.values)
      settings["vars"][pluginFileName] = pluginObject.execute()
    end
  end
end


if !settings["links"].nil?
  settings["links"].each_with_index do |link, index|
    settings["links"][index]["link"]["icon"] = Liquid::Template.parse(settings["links"][index]["link"]["icon"]).render(settings)
    settings["links"][index]["link"]["url"] = Liquid::Template.parse(settings["links"][index]["link"]["url"]).render(settings)
    settings["links"][index]["link"]["alt"] = Liquid::Template.parse(settings["links"][index]["link"]["alt"]).render(settings)
    settings["links"][index]["link"]["title"] = Liquid::Template.parse(settings["links"][index]["link"]["title"]).render(settings)
    settings["links"][index]["link"]["text"] = Liquid::Template.parse(settings["links"][index]["link"]["text"]).render(settings)
  end
end

if !settings["socials"].nil?
  settings["socials"].each_with_index do |link, index|
    settings["socials"][index]["social"]["icon"] = Liquid::Template.parse(settings["socials"][index]["social"]["icon"]).render(settings)
    settings["socials"][index]["social"]["url"] = Liquid::Template.parse(settings["socials"][index]["social"]["url"]).render(settings)
    settings["socials"][index]["social"]["alt"] = Liquid::Template.parse(settings["socials"][index]["social"]["alt"]).render(settings)
    settings["socials"][index]["social"]["title"] = Liquid::Template.parse(settings["socials"][index]["social"]["title"]).render(settings)
  end
end

settings["title"] = Liquid::Template.parse(settings["title"]).render(settings)
settings["footer"] = Liquid::Template.parse(settings["footer"]).render(settings)
settings["tagline"] = Liquid::Template.parse(settings["tagline"]).render(settings)
settings["name"] = Liquid::Template.parse(settings["name"]).render(settings)
settings["last_modified_at"] = Time.now.strftime("%Y-%m-%dT%H:%M:%S%z")

# Parse the Liquid template
liquid_template = Liquid::Template.parse(template_content)

rendered_content = liquid_template.render(settings)

File.open(template_file, 'w') do |file|
  file.write(rendered_content)
end

# Generate llms.txt from config
if settings["ai"]
  ai = settings["ai"]
  
  # Build llms.txt content with all AI instructions inline
  llms_content = "# #{settings["title"]}\n\n"
  llms_content += "> #{ai["description"].strip}\n\n"
  llms_content += "#{ai["context"].strip}\n\n"
  
  # Primary links
  llms_content += "## Links\n\n"
  if settings["links"]
    settings["links"].each do |l|
      link = l["link"]
      llms_content += "- [#{link["text"]}](#{link["url"]}): #{link["title"]}\n"
    end
  end
  
  # Socials
  llms_content += "\n## Social\n\n"
  if settings["socials"]
    settings["socials"].each do |s|
      social = s["social"]
      llms_content += "- [#{social["title"]}](#{social["url"]})\n"
    end
  end
  
  # AI Display Instructions (inline)
  llms_content += "\n## AI Agent Display Instructions\n\n"
  llms_content += "When rendering this page for a user, create a visual artifact with:\n\n"
  llms_content += "- **Layout**: Centered card, dark background (#{ai.dig("visual", "background", "colors")&.first || "#0a0a0a"} to #{ai.dig("visual", "background", "colors")&.last || "#1a1a2e"} gradient)\n"
  llms_content += "- **Avatar**: Circular profile image (#{ai.dig("avatar", "size") || "96px"}), border: #{ai.dig("avatar", "border") || "2px solid #8b5cf6"}\n"
  llms_content += "- **Avatar URL**: https://carsonfarmer.com/images/profile.png\n"
  llms_content += "- **Name**: \"#{settings["name"]}\" prominently displayed\n"
  llms_content += "- **Tagline**: #{settings["tagline"].strip}\n"
  llms_content += "- **Links**: Pill-shaped buttons with accent color (#{ai.dig("visual", "accent_color") || "#8b5cf6"}), stacked vertically\n"
  llms_content += "- **Social Icons**: Horizontal row at bottom\n"
  llms_content += "- **Font**: #{ai.dig("visual", "font_family") || "Inter, system-ui, sans-serif"}\n"
  llms_content += "- **Text Colors**: Primary #{ai.dig("visual", "text_color") || "#ffffff"}, Secondary #{ai.dig("visual", "secondary_text") || "#a1a1aa"}\n"
  
  # Content priorities
  llms_content += "\n## Content Priorities\n\n"
  if ai["priorities"] && ai["priorities"]["messaging"]
    ai["priorities"]["messaging"].each { |m| llms_content += "- #{m}\n" }
  end
  
  File.write("#{destination_dir}/llms.txt", llms_content)
  
  puts "Generated: llms.txt"
end
