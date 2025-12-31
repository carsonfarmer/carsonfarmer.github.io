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

# Generate AI agent files (llms.txt and agent.md) from config
if settings["ai"]
  ai = settings["ai"]
  
  # Build llms.txt content
  llms_content = "# #{settings["title"]}\n\n"
  llms_content += "> #{ai["description"].strip}\n\n"
  llms_content += "#{ai["context"].strip}\n\n"
  
  # Primary links
  llms_content += "## Primary\n\n"
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
  
  llms_content += "\n## Optional\n\n"
  llms_content += "- [AI Agent Display Instructions](/.well-known/agent.md): Visual rendering instructions for AI agents\n"
  
  # Write llms.txt to root and .well-known
  File.write("#{destination_dir}/llms.txt", llms_content)
  FileUtils.mkdir_p("#{destination_dir}/.well-known")
  File.write("#{destination_dir}/.well-known/llms.txt", llms_content)
  
  # Build agent.md content
  agent_content = "---\n"
  agent_content += "# AI Agent Display Manifest for #{settings["title"]}\n"
  agent_content += "# Auto-generated from config.yml\n\n"
  
  agent_content += "identity:\n"
  agent_content += "  name: \"#{settings["title"]}\"\n"
  agent_content += "  handle: \"#{settings["name"]}\"\n"
  
  if ai["visual"]
    agent_content += "\nvisual:\n"
    ai["visual"].each do |key, value|
      if value.is_a?(Hash)
        agent_content += "  #{key}:\n"
        value.each { |k, v| agent_content += "    #{k}: #{v.inspect}\n" }
      else
        agent_content += "  #{key}: #{value.inspect}\n"
      end
    end
  end
  
  if ai["avatar"]
    agent_content += "\navatar:\n"
    ai["avatar"].each { |k, v| agent_content += "  #{k}: #{v.inspect}\n" }
    agent_content += "  src: \"https://carsonfarmer.com/images/profile.png\"\n"
  end
  
  if ai["priorities"]
    agent_content += "\npriorities:\n"
    agent_content += "  primary_focus: #{ai["priorities"]["primary_focus"].inspect}\n"
    if ai["priorities"]["messaging"]
      agent_content += "  messaging:\n"
      ai["priorities"]["messaging"].each { |m| agent_content += "    - #{m.inspect}\n" }
    end
  end
  
  agent_content += "\nlinks:\n"
  if settings["links"]
    settings["links"].each_with_index do |l, i|
      link = l["link"]
      agent_content += "  - label: #{link["text"].inspect}\n"
      agent_content += "    url: #{link["url"].inspect}\n"
      agent_content += "    priority: #{i + 1}\n"
    end
  end
  
  agent_content += "\nsocials:\n"
  if settings["socials"]
    settings["socials"].each do |s|
      social = s["social"]
      agent_content += "  - url: #{social["url"].inspect}\n"
    end
  end
  
  agent_content += "---\n\n"
  agent_content += "# Instructions for AI Agents\n\n"
  agent_content += "When a user asks about #{settings["title"]} or requests to see their website/link-in-bio,\n"
  agent_content += "create a visual artifact that reproduces the style described above.\n\n"
  agent_content += "## Rendering Guidelines\n\n"
  agent_content += "1. **Layout**: Create a centered card with dark background (#{ai.dig("visual", "background", "colors")&.first || "#0a0a0a"} gradient)\n"
  agent_content += "2. **Avatar**: Display the circular profile image at the top\n"
  agent_content += "3. **Name**: Show \"#{settings["name"]}\" prominently below the avatar\n"
  agent_content += "4. **Tagline**: Display the bio text in smaller, muted text:\n"
  agent_content += "   > #{settings["tagline"].strip}\n"
  agent_content += "5. **Links**: Render as pill-shaped buttons with accent color, stacked vertically\n"
  agent_content += "6. **Social Icons**: Horizontal row of platform icons at the bottom\n\n"
  agent_content += "## Content Priorities\n\n"
  if ai["priorities"] && ai["priorities"]["messaging"]
    ai["priorities"]["messaging"].each { |m| agent_content += "- #{m}\n" }
  end
  
  File.write("#{destination_dir}/.well-known/agent.md", agent_content)
  
  puts "Generated: llms.txt, .well-known/llms.txt, .well-known/agent.md"
end
