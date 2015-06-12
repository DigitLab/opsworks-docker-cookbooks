include_recipe 'deploy'

node[:deploy].each do |application, deploy|

  unless node[:opsworks][:instance][:layers].include?(deploy[:environment_variables][:layer])
    Chef::Log.info("Skipping docker::deploy application #{application} as it is not deployed to this layer")
    next
  end

  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  opsworks_deploy do
    deploy_data deploy
    app application
  end

  bash "docker-build" do
    user "root"
    cwd "#{deploy[:deploy_to]}/current"
    code <<-EOH
     docker build -t=#{deploy[:application]} . > #{deploy[:application]}-docker.out
    EOH
  end

  bash "docker-stop" do
    user "root"
    code <<-EOH
      if docker ps | grep #{deploy[:application]};
      then
        docker stop #{deploy[:application]}
        sleep 3
        docker rm #{deploy[:application]}
        sleep 3
      fi
    EOH
  end

  dockeropts = ""
  dockerenvs = ""
  deploy[:environment_variables].each do |key, value|
    if key.start_with?('__')
      dockeropts = dockeropts + " --" + key[2..-1] + "=" + value
    elsif key.start_with?('_')
      dockeropts = dockeropts + " -" + key[1..-1] + " " + value
    else
      dockerenvs = dockerenvs + " -e " + key + "=" + value
    end
  end

  bash "docker-run" do
    user "root"
    cwd "#{deploy[:deploy_to]}/current"
    code <<-EOH
      docker run #{dockeropts} #{dockerenvs} --name #{deploy[:application]} -d #{deploy[:application]}
    EOH
  end

  bash "docker-cleanup" do
    user "root"
    code <<-EOH
     docker images -f "dangling=true" -q | xargs --no-run-if-empty docker rmi
    EOH
  end

end