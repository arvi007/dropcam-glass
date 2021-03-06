class TimelineController < ApplicationController
  def index
  end

  def send_dropcam_picture

		dropcam_info = get_dropcam_info

  	credentials = User.get_credentials(session[:user_id])

  	data = {
   		:client_id => ENV["GLASS_CLIENT_ID"],
   		:client_secret => ENV["GLASS_CLIENT_SECRET"],
   		:refresh_token => credentials[:refresh_token],
   		:grant_type => "refresh_token"
		}

  	@response = ActiveSupport::JSON.decode(RestClient.post "https://accounts.google.com/o/oauth2/token", data)
  	if @response["access_token"].present?
    	credentials[:access_token] = @response["access_token"]

    	@client = Google::APIClient.new
   		hash = { :access_token => credentials[:access_token], :refresh_token => credentials[:refresh_token] }
    	authorization = Signet::OAuth2::Client.new(hash)
    	@client.authorization = authorization

    	@mirror = @client.discovered_api('mirror', 'v1')
    	
    	insert_subscription( {
      	"kind" => "mirror#subscription",
      	"collection" => "timeline",
      	"userToken" => session[:user_id],
      	"verifyToken" => "monkey",
      	"operation" => ["UPDATE"],
				"callbackUrl" => ENV['GOOGLE_SUBSCRIPTION_PROXY'] + ENV['HOSTNAME'] + '/update_dropcam_card'
			})
      
			puts 'Callback URL' + ENV['GOOGLE_SUBSCRIPTION_PROXY'] + ENV['HOSTNAME'] + '/update_dropcam_card'
			puts 'User session ID' + session[:user_id].to_s

    	insert_timeline_item( {
      	text: dropcam_info[:title] + " Dropcam",
      	notification: { level: 'DEFAULT' },
      	sourceItemId: 1001,
      	menuItems: [
        	{ 
						action: 'CUSTOM',
						id: 'update',
						values: [ {
							displayName: "Update",
							iconUrl: 'http://i.imgur.com/DRZUngH.png'
						} ]
					},
        	{ action: 'DELETE' },
					{ action: 'TOGGLE_PINNED' } ]
      	},
      dropcam_info[:filename],
      "image/jpeg")

    	if (@result)
      	redirect_to(root_path, :notice => "All Timelines inserted")
    	else
      	redirect_to(root_path, :alert => "Timelines failed to insert. Please try again.")
    	end

    	if File.exist?(dropcam_info[:filename])
      	File.delete(dropcam_info[:filename])
    	end
    
  		else
    		Rails.logger.debug "No access token"
  	end
	end

  def update_dropcam_card

		dropcam_info = get_dropcam_info

		credentials = User.get_credentials(session[:user_id])

  	data = {
   		:client_id => ENV["GLASS_CLIENT_ID"],
   		:client_secret => ENV["GLASS_CLIENT_SECRET"],
   		:refresh_token => credentials[:refresh_token],
   		:grant_type => "refresh_token"
		}

  	@response = ActiveSupport::JSON.decode(RestClient.post "https://accounts.google.com/o/oauth2/token", data)
  	if @response["access_token"].present?
    	credentials[:access_token] = @response["access_token"]

    	@client = Google::APIClient.new
   		hash = { :access_token => credentials[:access_token], :refresh_token => credentials[:refresh_token] }
    	authorization = Signet::OAuth2::Client.new(hash)
    	@client.authorization = authorization

    	@mirror = @client.discovered_api('mirror', 'v1')
    
    	patch_timeline_item( {
      	text: dropcam_info[:title] + " Dropcam",
      	notification: { level: 'DEFAULT' },
      	sourceItemId: 1001,
				menuItems: [
        	{ 
						action: 'CUSTOM',
						id: 'update',
						values: [ {
							displayName: "Update",
							iconUrl: 'http://i.imgur.com/DRZUngH.png'
						} ]
					},
        	{ action: 'DELETE' },
					{ action: 'TOGGLE_PINNED' } ]
				},
      dropcam_info[:filename],
      "image/jpeg")

    	if File.exist?(dropcam_info[:filename])
      	File.delete(dropcam_info[:filename])
    	end
  	end
  end

	private
  # Creates dropcam image
  def get_dropcam_info
		require 'dropcam'
  	dropcam = Dropcam::Dropcam.new(ENV["DROPCAM_USERNAME"],ENV["DROPCAM_PASSWORD"])
  	camera = dropcam.cameras.second

		# returns jpg image data of the latest frame captured
		screenshot = camera.screenshot.current
		filename = "#{camera.title}.jpg"

		# write data to disk
		File.open(filename, 'wb') {|f| f.write(screenshot) }

		# access and modify settings
		# this disables the watermark on your camera stream
		settings = camera.settings
		settings["watermark.enabled"].set(false)

	  return {filename: filename, title: camera.title}
	end


	def insert_timeline_item(timeline_item, attachment_path = nil, content_type = nil)
 		method = @mirror.timeline.insert

		# If a Hash was passed in, create an actual timeline item from it.
 		if timeline_item.kind_of?(Hash)
 			timeline_item = method.request_schema.new(timeline_item)
 		end

 		if attachment_path && content_type
 			media = Google::APIClient::UploadIO.new(attachment_path, content_type)
 			parameters = { 'uploadType' => 'multipart' }
 		else
 			media = nil
 			parameters = nil
 		end

 		@result = @client.execute!(
 			api_method: method,
 			body_object: timeline_item,
 			media: media,
 			parameters: parameters
 		).data
 	end

  def patch_timeline_item(timeline_item, attachment_path = nil, content_type = nil)
		method = @mirror.timeline.update

		# If a Hash was passed in, create an actual timeline item from it.
 		if timeline_item.kind_of?(Hash)
 			timeline_item = method.request_schema.new(timeline_item)
 		end

 		if attachment_path && content_type
 			media = Google::APIClient::UploadIO.new(attachment_path, content_type)
 			parameters = { 'uploadType' => 'multipart' }
 		else
 			media = nil
 			parameters = nil
 		end

 		@result = @client.execute!(
 			api_method: method,
 			body_object: timeline_item,
 			media: media,
 			parameters: parameters
 		).data
	end


	def insert_subscription(timeline_item, attachment_path = nil, content_type = nil)
 		method = @mirror.subscriptions.insert

 		# If a Hash was passed in, create an actual timeline item from it.
 		if timeline_item.kind_of?(Hash)
 			timeline_item = method.request_schema.new(timeline_item)
 		end

 		if attachment_path && content_type
 			media = Google::APIClient::UploadIO.new(attachment_path, content_type)
 			parameters = { 'uploadType' => 'multipart' }
 		else
 			media = nil
 			parameters = nil
 		end

 		@result = @client.execute!(
 			api_method: method,
 			body_object: timeline_item,
 			media: media,
 			parameters: parameters
 		).data
 	end

end
