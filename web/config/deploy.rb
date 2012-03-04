deploy_path = "/webapps/writewithme"

task :production do
  role :web, "kleio.xen.prgmr.com"
end

task :staging do
  role :web, "ub.lan"
end

set :application, "writewithme"

# Must be set for the password prompt from git to work
default_run_options[:pty] = true  

set :repository,  "git@github.com:sebastian/Write-With-Me.git"
set :scm, "git"
set :branch, "master"
set :deploy_via, :copy
set :git_enable_submodules, 1

set :deploy_to, deploy_path
set :use_sudo, false
set :user, "writewithme-deploy"

after "deploy:symlink", :upload_db, :restart_unicorn, :symlink_stories

desc "Symlinking the story folder"
task "symlink_stories" do
	story_folder_path = "#{deploy_path}/shared/story"
	current_deploy_path = "#{deploy_path}/current/public/story"
	run "ln -s #{story_folder_path} #{current_deploy_path}"
end

desc "Uploading database and/or symlink it"
task "upload_db" do
  db_path = "#{deploy_path}/shared/db/bank.sqlite"
  check_sh = <<-EOC
    if test -e #{db_path};
    then
      echo "ok";
    else 
      echo "upload";
    fi
  EOC
  link_sh = "ln -s #{db_path} #{deploy_path}/current/lib/bank.sqlite"
  result = capture check_sh
  case result.chomp
  when "ok"
    run link_sh
  when "upload"
    local_db = File.expand_path(File.dirname(__FILE__) + "/../lib/bank.sqlite")
    # Upload
    upload(local_db, db_path)
    run link_sh
  else
    puts "########### WRONG RESULT: #{result}"
  end
end

desc "Restarting unicorn"
task "restart_unicorn" do
  pid_path = "#{deploy_path}/shared/pids/unicorn.pid"
  sh = <<-EOC
    if test -e #{pid_path};
    then kill -HUP `cat #{pid_path}`;
    fi
  EOC
  run sh
end

desc "Uploading database file"
after "deploy" do
end

desc "Supressed deploy:migrate"
task "deploy:migrate" do
  # nothing
end
