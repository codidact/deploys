require 'bundler'
require 'json'
require 'net/http'

class Deploy
  def self.get_config
    JSON.load(File.read('config.json'))
  end

  def initialize
    @config = Deploy.get_config
  end

  def with_env
    Bundler.with_unbundled_env do
      Dir.chdir '/var/apps/qpixel' do
        yield
      end
    end
  end

  def circle_status
    begin
      pipelines = Net::HTTP.get_response(URI('https://circleci.com/api/v2/pipeline?org-slug=gh/codidact'),
                                         { 'Circle-Token' => @config['api_token'] })
      last_pipeline = JSON.load(pipelines.body)['items'].filter { |i| i['project_slug'] == 'gh/codidact/qpixel' }[0]
      workflow = Net::HTTP.get_response(URI("https://circleci.com/api/v2/pipeline/#{last_pipeline['id']}/workflow"),
                                        { 'Circle-Token' => @config['api_token'] })
      last_workflow = JSON.load(workflow.body)['items'][0]
      jobs = Net::HTTP.get_response(URI("https://circleci.com/api/v2/workflow/#{last_workflow['id']}/job"),
                                    { 'Circle-Token' => @config['api_token'] })
      all_jobs = JSON.load(jobs.body)['items']
      all_jobs.filter { |job| !['rubocop', 'deploy'].include? job['name'] }
              .all? { |job| job['status'] == 'success' }
    rescue
      nil
    end
  end

  def current_rev
    with_env do
      `git rev-parse HEAD`[0..7]
    end
  end

  def git_pull
    with_env do
      `git pull origin develop > deploy_output.log 2>&1`
    end
  end

  def bundle_install
    with_env do
      `/home/ubuntu/.rbenv/shims/bundle check || /home/ubuntu/.rbenv/shims/bundle install --without development test >> deploy_output.log 2>&1`
    end
  end

  def run_migrations
    with_env do
      `RAILS_ENV=production /home/ubuntu/.rbenv/shims/bundle exec rails db:migrate >> deploy_output.log 2>&1`
    end
  end

  def clear_cache
    with_env do
      `RAILS_ENV=production /home/ubuntu/.rbenv/shims/bundle exec rails r scripts/clear_cache.rb >> deploy_output.log 2>&1`
    end
  end

  def create_seeds
    with_env do
      `RAILS_ENV=production /home/ubuntu/.rbenv/shims/bundle exec rails db:seed >> deploy_output.log 2>&1`
    end
  end

  def precompile_assets
    with_env do
      `RAILS_ENV=production /home/ubuntu/.rbenv/shims/bundle exec rails assets:precompile >> deploy_output.log 2>&1`
    end
  end

  def copy_statics
    with_env do
      `cp app/assets/images/* public/assets >> deploy_output.log 2>&1`
    end
  end

  def update_crontab
    with_env do
      `/home/ubuntu/.rbenv/shims/bundle exec whenever --update-crontab >> deploy_output.log 2>&1`
    end
  end

  def restart_server
    with_env do
      `/home/ubuntu/.rbenv/shims/bundle exec pumactl -P tmp/pids/server.pid restart >> deploy_output.log 2>&1`
    end
  end

  def send_webhook(before, after)
    url = "https://github.com/codidact/qpixel/compare/#{before}...#{after}"
    webhook_url = @config['webhook_url']

    params = { content: "<@794974327543300126> deployed [#{before}...#{after}](#{url})" }
    headers = { 'Content-Type': 'application/json' }
    begin
      response = Net::HTTP.post(uri, params.to_json, headers)
      response.is_a? Net::HTTPSuccess
    rescue
      false
    end
  end

  def trigger
    if circle_status
      Thread.new do
        before = current_rev
        git_pull
        bundle_install
        run_migrations
        clear_cache
        create_seeds
        precompile_assets
        copy_statics
        update_crontab
        restart_server
        after = current_rev
        send_webhook before, after
      end
      [true, 'Deploy started successfully.']
    else
      [false, 'CircleCI build failed - unable to deploy.']
    end
  end
end
