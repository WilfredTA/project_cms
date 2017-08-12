require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'


configure do
	enable :sessions
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def base
	File.expand_path('..', __FILE__)
end


def markdown?(file_path)
	File.extname(file_path) == ".md"
end

def render_markdown_file(file)
	markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
	file = markdown.render(file)
end

def load_file_content(file_path)
	file_content = File.read(file_path)
	if File.extname(file_path) == ".txt"
		headers["Content-Type"] = "text/plain"
		file_content
	elsif File.extname(file_path) == ".md"
		erb render_markdown_file(file_content)
	end
end

def load_user_credentials
	if ENV["RACK_ENV"] == "test"
		user_path = File.expand_path("../test/users.yml", __FILE__)
	else
		user_path = File.expand_path("../users.yml", __FILE__)
	end
	YAML.load_file(user_path)
end

def valid_credentials?(username, password)
	credentials = load_user_credentials
	stored_password = credentials[username]

	if credentials.keys.include?(username)
		hashed_password = BCrypt::Password.new(stored_password) # constructor makes sure the hash is valid otherwise raises error
		hashed_password == password # makes sure the validated stored hash is the same as input password
	else
		false
	end
end

# Since the username key is never added unless the credentials are valid,
# it is sufficient to test whether the key even exists to see whether the user
# is logged in, or not.
def signed_in?
	session.key?(:username)
end

def redirect_non_users
	if !signed_in?
		session[:message] = "You must be signed in to do that"
		redirect '/'
	end
end


helpers do
	def path_to(file, dir)
		File.expand_path(file, dir)
	end
end



get '/' do
	redirect '/users/signin' if !signed_in?
	pattern = File.join(data_path, "*")
	@contents = Dir.glob(pattern).map do |path|
		File.basename(path)
	end

	erb :contents, layout: :layout
end


get '/:text_file' do
	file_name = params[:text_file]
	file_path = File.join(data_path, file_name)

	@contents = Dir.glob(base).map do |path|
		File.basename(path)
	end

	if File.exist?(file_path)
		load_file_content(file_path)
	else
		session[:message] = "#{file_name} does not exist"
		redirect '/'
	end
end

get '/:text_file/edit' do
	redirect_non_users
	@file_name = params[:text_file]
	file_path = File.join(data_path, @file_name)
	@content = File.read(file_path)

	erb :edit, layout: :layout
end

post '/:text_file' do
	redirect_non_users
	file_path = File.join(data_path, params[:text_file])
	new_content = params[:new_content]
	File.write(file_path, new_content)
	session[:message] = "#{params[:text_file]} has been updated!"
	redirect '/'
end

get '/document/new' do
	redirect_non_users
	erb :new, layout: :layout
end

post '/document/new' do
	redirect_non_users
	document_name = params[:new_doc]
	file_name = File.join(data_path, document_name)
	new_file = File.new(file_name, 'w+')
	if File.extname(new_file) == ".md" || File.extname(new_file) == ".txt"
		session[:message] = "#{document_name} has been created"
		redirect '/'
	else
		session[:message] = "File extension must be .md or .txt"
		erb :new, layout: :layout
	end
end

post '/:file/delete' do
	redirect_non_users
	file_name = File.join(data_path, params[:file])
	File.delete(file_name)
	session[:message] = "#{params[:file]} was deleted"
	redirect '/'
end

get '/users/signin' do
	erb :signin, layout: :layout
end

post '/users/signin' do
	username, password = params[:username], params[:password]
	
	if valid_credentials?(username, password)
		session[:username] = username
		session[:message] = "Welcome!"
		redirect '/'
	else
		session[:message] = "Invalid credentials"
		status 422
		erb :signin, layout: :layout
	end
end

post '/users/signout' do
	session.delete(:username)
	session.delete(:password)
	session[:message] = "You have been signed out"
	redirect '/users/signin'
end



