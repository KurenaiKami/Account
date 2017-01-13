#encoding=UTF-8
require 'rubygems'
require 'sinatra'
require 'mongo'
require 'digest/md5'  
require 'json/ext' # required for .to_json
require 'json'


#连接数据库
$db = Mongo::Client.new([ '127.0.0.1:27017'], :database => 'MGPAY', :user => "admin", :password => "254799")

use Rack::Session::Pool ,:expire_after => 86400 


configure do  
  enable :sessions  
end  

##########################路由##################

get "/" do
	if session[:admin] == true 
		redirect to('index');
	else
		redirect to('login');
	end
end

#登录
get "/login" do
	if session[:admin] then
		redirect to('index')
	else
		erb :login
	end
end


#获取我的数据
get '/getMyAttribute' do
	result = $db[:db_users].find( "user_name" => session[:username]).to_a.first.to_json;
	return result;
end


post "/login" do
	@username = params[:username]
	@password = params[:password]
	result = $db[:db_users].find( "user_name" => @username).to_a.first.to_json
	puts result

	obj = JSON.parse(result);
	session[:permission] = obj['user_promission'];
	if obj['user_name'] == @username && Digest::MD5.hexdigest(obj['user_password']) ==Digest::MD5.hexdigest( @password )
		session[:admin] = true;
		session[:username] = @username;
		redirect to("index");
	else

	end
	erb :login
end

#主页
get "/index" do
	redirect to('login') unless session[:admin] ;
	@current = "dashboard";
	erb :index,:layout => :content_layout #主页共用模板
end


#登出
get '/logout' do
	session.clear
	redirect to('login')
end


#小包激活总接口
post '/active' do
	#渠道
	platform = params[:platform];
	deviceId = params[:deviceId];
	activeTime = Time.now.strftime("%Y/%m/%d");

	checkResult = 'null';
	#检查去重复
	checkResult = $db[:active].find("active_devece_id" => deviceId).to_a.first.to_json;
	puts "**********"
	puts checkResult;
	puts "**********"
	if checkResult == 'null'
		active_data = {"active_time": activeTime,"active_plat_form": platform,"active_devece_id": deviceId};
		$db[:active].insert_one(active_data);
	end

	briskcheck = "null"
	briskcheck = $db[:brisk].find({"brisk_time" => activeTime ,"brisk_device_id" => deviceId}).to_a.first.to_json;

	if briskcheck == "null"
		briskdata = {"brisk_time": activeTime, "brisk_plat_form": platform , "brisk_device_id": deviceId};
	 	$db[:brisk].insert_one(briskdata);
	end


	return 200;
end


post '/getalldata' do
	if session[:permission] == "all"
		result = $db[:active].find().to_a.to_json
	else
		result = $db[:active].find("active_plat_form" => session[:permission]).to_a.to_json
	end
	puts "^^^^^^^^^get all ^^^^^^^^^"
	puts result
	puts "^^^^^^^^^get all ^^^^^^^^^"
	return result
end


#获取 所有渠道
post '/getallplatforms' do
	result = $db[:active].distinct("active_plat_form");
	puts "**********"
	puts result;
	puts "**********"
	return result;
end

get '/getdaycount' do
	time = params[:time]
	if time == "null"
		time = Time.now;
		time = time.strftime("%Y/%m/%d");
	end
	puts "========*****=========="
	puts time
	puts "========******=========="

	if session[:permission] == "all"
		result = $db[:active].find("active_time" => time ).to_a.to_json
		briskresult = $db[:brisk].find("brisk_time" => time ).to_a.to_json
	else
		result = $db[:active].find( {"active_time" => time, "active_plat_form" => session[:permission] } ).to_a.to_json
		briskresult = $db[:brisk].find( {"brisk_time" => time, "brisk_plat_form" => session[:permission] }).to_a.to_json
	end
	res_result = [
		{"active_time": time, "active_count": JSON.parse(result).length},
		{"active_time": time, "brisk_count": JSON.parse(briskresult).length}
	]
	puts "=================="
	puts res_result
	puts "=================="
	return res_result.to_a.to_json;
end