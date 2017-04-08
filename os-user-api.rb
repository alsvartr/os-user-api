require "socket"
require "cgi"
require "json"
require "syslog"
require __dir__ + "/lib/parseconfig.rb"

###############
# settings
CONFIG = ParseConfig.new()
if File.exist?("/etc/os-user-api/config")
	CONFIG.parse_file("/etc/os-user-api/config")
else
	CONFIG.parse_file( __dir__ + "/config" )
end
CONFIG.types!

BIND = CONFIG.params["bind"]
PORT = CONFIG.params["port"]
UPDATE_INT = CONFIG.params["update_int"]
TOKEN = CONFIG.params["token"]
###############

# requiring modules
require __dir__ + "/modules/" + CONFIG.params["storage_backend"]


def updateOSData
	shout("updating OpenStack data")

	data = getBlockStorage
	data["updated"] = Time.now
	return data
end

def response(client, text)
	headers = ["http/1.1 200 ok",
		"date: #{CGI.rfc1123_date(Time.now)}",
		"server: ruby",
		"content-type: text/html; charset=iso-8859-1",
		"content-length: #{text.length}\r\n\r\n"].join("\r\n")

	client.puts headers
	client.puts text
	client.close
end

def shout(text, prior = "INFO", component = "main")
	prior = Syslog::LOG_INFO	if prior == "INFO"
	prior = Syslog::LOG_ERR		if prior == "ERR"

	syslog = Syslog.open("os-user-api", Syslog::LOG_PID, Syslog::LOG_DAEMON)
	syslog.log(prior, "#{component} => #{text}")
	syslog.close

	date = Time.now().strftime("%Y-%m-%d %H:%M:%S")
	puts "[#{date}]: #{component} => #{text}"
end


### main program starts here
blocks = updateOSData
server = TCPServer.new(BIND, PORT)
shout("server listening on #{BIND}:#{PORT}")

# starting new thread for periodic updates
Thread.new do
	loop {
		sleep(UPDATE_INT)
		blocks = updateOSData
	}
end


# main server loop
loop {
	client = server.accept
	addr = client.addr[3]
	resp = client.gets

	# parsing request from client
	begin
		uri = resp.split(" ")[1]
		uri = uri.split("/")
		uri.shift
		token = uri[0]
		uri.shift
	rescue
		shout("bad request: #{addr}, #{resp}", "ERR")
		response(client, "bad request")
		next
	end

	# check auth token
	if token != TOKEN
		shout("unauthorized request: #{addr}, #{uri}", "ERR")
		response(client, "unauthorized")
		next
	end

	# forming response
	if uri[0] == "block"
		# on update
		if uri[1] == "update"
			blocks = updateOSData
			shout("new request: #{addr}, #{uri}")
			response(client, blocks.to_json)
		# on get
		elsif uri[1] == "get"
			shout("new request: #{addr}, #{uri}")
			response(client, blocks.to_json)
		else
			shout("bad request: #{addr}, #{uri}", "ERR")
			response(client, "bad request")
		end
	else
		shout("bad request: #{addr}, #{uri}", "ERR")
		response(client, "bad request")
	end
}
