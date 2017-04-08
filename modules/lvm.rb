require "net/ssh"

###############
# settings
DOMAIN = CONFIG.params["domain"]
SSH_USER = CONFIG.params["ssh_user"]
SSH_PASS = CONFIG.params["ssh_pass"]
SSH_KEY = CONFIG.params["ssh_key"]

# lvm
VGS_CMD = "sudo vgs --noheadings --unbuffered --units b 2>&1 | grep volumes | awk '{print $1\" \"$6\" \"$7}'"
LVM_FREE_SPACE = CONFIG.params["lvm_free_space"]
POOLS = Hash[]
###############


def getLVMStorage(host)
	# ssh to specific host & execute lvm commands
	begin
		ssh = Net::SSH.start(host, SSH_USER, :keys => [SSH_KEY], :password => SSH_PASS, :timeout => 30)
	rescue Exception
		return nil
	end

	vgs_data = ssh.exec!("#{VGS_CMD}").split("\n")
	ssh.close

	# lvm hash structure
	lvm = Hash["pools" => Hash.new, "total" => 0, "used" => 0]
	# parse `vgs` stdout from host
	vgs_data.each do |line|
		line = line.split(" ")
		# parse VG name & transform it to Cinder type name
		pool_vg = line[0]
		pool_name = POOLS[pool_vg]
		pool_name = pool_vg if pool_name == nil

		# parse total & free space
		pool_total = line[1].gsub("b", "").to_i
		pool_free = line[2].gsub("b", "").to_i
		# calculate used space & substract Cinder backlog space
		pool_used = pool_total - pool_free + LVM_FREE_SPACE

		lvm["total"] = lvm["total"] + pool_total
		lvm["used"] = lvm["used"] + pool_used

		# hash of VG pools
		lvm["pools"][pool_name] = Hash["total" => pool_total, "used" => pool_used ]
	end

	return lvm
end


def getBlockStorage
	# our resulting hash structure
	data = Hash["zones" => Hash.new, "total" => 0, "used" => 0]

	# get all zones from cinder-manage
	zones = `sudo cinder-manage service list | grep "cinder-volume" | grep -vE "XXX" | awk '{print $3" "$2}' | sort -k1,1 -t ' ' --unique`
	zones = zones.split("\n")
	# parse zones & corresponding cmps
	zones.each do |line|
		zone_info = line.split(" ")
		zone = zone_info[0]
		cmp = zone_info[1].split("@")[0]
		data["zones"][zone] = Hash["cmp" => cmp, "total" => 0, "used" => 0]
	end

	# get lvm storage for each zone
	cur_zone = 0
	data["zones"].each do |zone, volumes|
		cmp = volumes["cmp"]
		total_zones = data["zones"].count
		cur_zone += 1
		begin
			shout("[#{cur_zone}/#{total_zones}] trying to get lvm data on #{cmp}", "INFO", "LVM")
			lvm = getLVMStorage("#{cmp}.#{DOMAIN}")
			data["total"] = data["total"] + lvm["total"]
			data["used"] = data["used"] + lvm["used"]
			volumes["total"] = lvm["total"]
			volumes["used"] = lvm["used"]

			volumes["pools"] = lvm["pools"]
		rescue Exception => e
			shout("problem collect lvm data on #{cmp}: #{e}", "ERR", "LVM")
		end
	end

	return data
end
