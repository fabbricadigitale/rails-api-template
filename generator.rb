def migration_ts
	sleep(1)
	Proc.new { Time.now.strftime("%Y%m%d%H%M%S") }
end   


def copy_from_repo(filename, opts={})
  repo = "https://raw.githubusercontent.com/matteolc/rails-api-template/master/"
  source_filename = filename
  destination_filename = filename  
  destination_filename  = destination_filename.gsub(/create/, "#{migration_ts.call}_create") if opts[:migration_ts]
  begin
    remove_file destination_filename
    get repo + source_filename, destination_filename
  rescue OpenURI::HTTPError
    puts "Unable to obtain #{source_filename} from the repo #{repo}"
  end
end

def ask_default(question, default_answer)
  answer = ask(question) 
  answer.empty? ? default_answer : answer
end

def commit(msg)
  git add: "."
  git commit: "-m '#{msg}'"	
end

git :init
commit "Initial commit"

# Gems
gem 'annotate', group: :development
gem_group :development, :test do
  gem 'awesome_print'
  gem 'faker'
  gem 'factory_girl_rails'
  gem 'rspec-rails'
end
gem 'dotenv-rails'
gem 'default_value_for'
gem 'chronic'
gem 'sidekiq'
gem 'rufus-scheduler'
gem 'daemons'
gem 'rollbar'
gem 'jsonapi-resources'
gem 'pg_search'
gem 'dotenv-rails'
gem 'puma_worker_killer'
gem 'pundit'
gem 'jsonapi-authorization', git: 'https://github.com/venuu/jsonapi-authorization.git'
gem 'rolify'
gem 'jwt'
gsub_file 'Gemfile', "# gem 'rack-cors'", "gem 'rack-cors'"
gsub_file 'Gemfile', "# gem 'bcrypt', '~> 3.1.7'", "gem 'bcrypt', '~> 3.1.7'"
run 'bundle install'

%w(account user role json_web_token).each do |model| copy_from_repo "app/models/#{model}.rb" end
empty_directory 'app/models/concerns' 
copy_from_repo 'app/models/concerns/has_secure_tokens.rb'
copy_from_repo 'app/models/concerns/has_fulltext_search.rb'
empty_directory 'lib/templates/active_record/model'
copy_from_repo "lib/templates/active_record/model/model.rb"
empty_directory 'app/resources/api/v1' 
%w(api user).each do |resource| copy_from_repo "app/resources/api/v1/#{resource}_resource.rb" end
create_file "app/resources/api/v1/account_resource.rb" do
  "class Api::V1::AccountResource < Api::V1::ApiResource
    attributes  :email,
                :username
  end"
end
empty_directory 'app/controllers/api/v1' 
%w(api registrations sessions).each do |controller| copy_from_repo "app/controllers/api/v1/#{controller}_controller.rb" end
create_file "app/controllers/api/v1/accounts_controller.rb" do
  "class Api::V1::AccountsController < Api::V1::ApiController
  end"
end
create_file "app/controllers/api/v1/users_controller.rb" do
  "class Api::V1::UsersController < Api::V1::ApiController
  end"
end
create_file "app/controllers/api/v1/user_processor.rb" do
  "class Api::V1::UserProcessor < JSONAPI::Authorization::AuthorizingProcessor
    after_find do
      unless @result.is_a?(JSONAPI::ErrorsOperationResult)
        @result.meta[:record_total] = User.count
      end
    end
  end"
end
insert_into_file "app/controllers/application_controller.rb", after: "class ApplicationController < ActionController::API" do "
  include Authorization"
end
empty_directory 'app/controllers/concerns' 
copy_from_repo 'app/controllers/concerns/authorization.rb' 
empty_directory 'app/policies' 
%w(application user account).each do |policy| copy_from_repo "app/policies/#{policy}_policy.rb" end
%w(extensions users roles).each do |migration| copy_from_repo "db/migrate/create_#{migration}.rb", {migration_ts: true} end 
%w(redis rollbar cors generators jsonapi_resources).each do |initializer| copy_from_repo "config/initializers/#{initializer}.rb" end
copy_from_repo "config/sidekiq.yml"
copy_from_repo "config/puma.rb"
prepend_to_file 'config/database.yml' do 
  "local: &local
    username: <%= ENV['DATABASE_USER'] %>
    password: <%= ENV['DATABASE_PASSWORD'] %>
    host: <%= ENV['DATABASE_HOST'] %>
  "
end
insert_into_file "config/database.yml", after: "<<: *default\n" do 
"  <<: *local\n" 
end
empty_directory 'db/seeds'
copy_from_repo "db/seeds/users.rb"
application "config.active_record.default_timezone = :utc" 
application "config.active_job.queue_adapter = :sidekiq"       

rakefile("auto_annotate_models.rake") do <<-'TASK'    
if Rails.env.development?
  task :set_annotation_options do
    Annotate.set_defaults({
      'routes'                    => 'false',
      'position_in_routes'        => 'before',
      'position_in_class'         => 'before',
      'position_in_test'          => 'before',
      'position_in_fixture'       => 'before',
      'position_in_factory'       => 'before',
      'position_in_serializer'    => 'before',
      'show_foreign_keys'         => 'true',
      'show_complete_foreign_keys' => 'false',
      'show_indexes'              => 'true',
      'simple_indexes'            => 'false',
      'model_dir'                 => 'app/models',
      'root_dir'                  => '',
      'include_version'           => 'false',
      'require'                   => '',
      'exclude_tests'             => 'true',
      'exclude_fixtures'          => 'true',
      'exclude_factories'         => 'true',
      'exclude_serializers'       => 'false',
      'exclude_scaffolds'         => 'true',
      'exclude_controllers'       => 'true',
      'exclude_helpers'           => 'true',
      'exclude_sti_subclasses'    => 'false',
      'ignore_model_sub_dir'      => 'false',
      'ignore_columns'            => nil,
      'ignore_routes'             => nil,
      'ignore_unknown_models'     => 'false',
      'hide_limit_column_types'   => '<%= AnnotateModels::NO_LIMIT_COL_TYPES.join(",") %>',
      'hide_default_column_types' => '<%= AnnotateModels::NO_DEFAULT_COL_TYPES.join(",") %>',
      'skip_on_db_migrate'        => 'false',
      'format_bare'               => 'true',
      'format_rdoc'               => 'false',
      'format_markdown'           => 'true',
      'sort'                      => 'false',
      'force'                     => 'false',
      'trace'                     => 'false',
      'wrapper_open'              => nil,
      'wrapper_close'             => nil,
      'with_comment'              => true
    })
  end

  Annotate.load_tasks
  
  # Annotate models
  task :annotate do
    puts 'Annotating models...'    
    system 'bundle exec annotate'
  end
  
  # Annotate routes
  task :annotate_routes do
    puts 'Annotating models...'
    system 'bundle exec annotate --routes'
  end

end    
TASK
end

rakefile("app.rake") do <<-'TASK'    
  namespace :app do
    task :setup => :environment do
      Rake::Task['db:drop'].invoke
      Rake::Task['db:create'].invoke
      Rake::Task['db:migrate'].invoke
      Rake::Task['db:seed:users'].invoke
    end
 end    
TASK
end

rakefile("custom_seed.rake") do <<-'TASK'  
namespace :db do
  namespace :seed do
    Dir[Rails.root.join('db', 'seeds', '*.rb')].each do |filename|
      task_name = File.basename(filename, '.rb').intern    
      task task_name => :environment do
        load(filename) if File.exist?(filename)
      end     
    end
  end
end
TASK
end

insert_into_file "config/routes.rb", after: "Rails.application.routes.draw do" do "
   namespace :api do
    namespace :v1 do
      post 'login', to: 'sessions#create'
      delete 'logout', to: 'sessions#destroy'
      post 'signup', to: 'registrations#create'
      jsonapi_resources :accounts, only: [:show, :edit, :update]
      jsonapi_resources :users
    end
  end"
end

if (example_app = yes?("Do you want to add example application files?"))
  %w(authors posts).each do |migration| copy_from_repo "db/migrate/create_#{migration}.rb", {migration_ts: true} end
  create_file 'app/models/author.rb' do "class Author < ApplicationRecord
    has_many :posts
end" end  
  create_file 'app/models/post.rb' do "class Post < ApplicationRecord
    belongs_to :author
end" end
  create_file 'app/controllers/api/v1/authors_controller.rb' do "class Api::V1::AuthorsController < Api::V1::ApiController
end" end
  create_file 'app/controllers/api/v1/posts_controller.rb' do "class Api::V1::PostsController < Api::V1::ApiController
end" end
  %w(authors posts).each do |seed| copy_from_repo "db/seeds/#{seed}.rb" end
  %w(author post).each do |resource| copy_from_repo "app/resources/api/v1/#{resource}_resource.rb" end
  %w(author post).each do |policy| copy_from_repo "app/policies/#{policy}_policy.rb" end
  insert_into_file "config/routes.rb", after: "jsonapi_resources :users" do "
        jsonapi_resources :posts
        jsonapi_resources :authors"
  end
end

create_file "Procfile", "web: bundle exec puma -C config/puma.rb" 

commit "Creation"

db_user = ask_default("Who is the database user (leave empty for dba)?", 'dba') 
db_password = ask_default("What is the database password (leave empty for 12345678)?", '12345678')
db_host = ask_default("Who is the database host (leave empty for localhost)?", 'localhost')
jwt_secret = ask_default("Please choose a JWT secret (leave empty for secret)", 'secret')

create_file '.env' do
  "DATABASE_USER=#{db_user}
  DATABASE_PASSWORD=#{db_password}
  DATABASE_HOST=#{db_host}
  JWT_SECRET=#{jwt_secret}"
end

create_file '.env.production' do
  "DATABASE_USER=
  DATABASE_PASSWORD=
  DATABASE_HOST=
  JWT_SECRET=
  ROLLBAR_TOKEN=
  MAILER_DOMAIN=
  SENDGRID_ACCOUNT=
  SENDGRID_KEY="
end

frontend_ui = ask_default("Which frontend UI do you want to use (material or grommet)? (leave empty for material)?", 'material') 
run "cd public && svn export https://github.com/matteolc/rails-api-template/trunk/public/app-#{frontend_ui} && mv ./app-#{frontend_ui} ./app && cd .."

if (frontend_ui==='grommet')
  create_file 'app/controllers/api/v1/post_processor.rb' do "class Api::V1::PostProcessor < JSONAPI::Authorization::AuthorizingProcessor
  after_find do
    unless @result.is_a?(JSONAPI::ErrorsOperationResult)
      @result.meta[:record_total] = Post.count
    end
  end
end" end
  create_file 'app/controllers/api/v1/author_processor.rb' do "class Api::V1::AuthorProcessor < JSONAPI::Authorization::AuthorizingProcessor
  after_find do
    unless @result.is_a?(JSONAPI::ErrorsOperationResult)
      @result.meta[:record_total] = Author.count
    end
  end
end" end
end

ip_addr = UDPSocket.open {|s| s.connect("4.4.4.4", 1); s.addr.last}
create_file 'public/app/.env' do
  "REACT_APP_NAME=React-Rails-JSON-API
  REACT_APP_API_PROTOCOL=http
  REACT_APP_API_ADDRESS=#{ip_addr}
  REACT_APP_API_PORT=5000"
end

run 'bundle exec rake app:setup'
if example_app
  insert_into_file "app/models/post.rb", after: "class Post < ApplicationRecord" do "
  include HasFulltextSearch
  has_fulltext_search"
  end
  insert_into_file "app/models/author.rb", after: "class Author < ApplicationRecord" do "
  include HasFulltextSearch
  has_fulltext_search"
  end  
  run 'bundle exec rake db:seed:authors'
  run 'bundle exec rake db:seed:posts'
end

commit "Bootstrap"

run 'cd public/app && yarn install'

commit "Client packages"




