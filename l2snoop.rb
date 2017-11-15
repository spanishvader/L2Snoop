#!/usr/bin/env ruby
require 'optparse'
require 'ostruct'

class Optparser
	def self.parse(args)
		#Default options
		options = OpenStruct.new
		options.verbose = false
		options.dest = 8080

		
		opt_parser = OptionParser.new do |opts|
			opts.banner = 
				"  _      ___     _____                         \n"\
				" | |    |__ \\   / ____|                        \n"\
				" | |       ) | | (___  _ __   ___   ___  _ __  \n"\
				" | |      / /   \\___ \\| '_ \\ / _ \\ / _ \\| |_ \\ \n"\
				" | |____ / /_   ____) | | | | (_) | (_) | |_) |\n"\
				" |______|____| |_____/|_| |_|\\___/ \\___/| .__/ \n"\
				"                                        | |    \n"\
				"                                        |_|    \n\n"\
				"Transparent man in the middle over an ethernet bridge.\n"\
				"\n"\
				"Usage: l2snoop [options]"
			opts.separator "Options:"

			opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
				options.verbose = v
			end
			opts.on("-m", "--masquerade", "Use iptabes -j MASQUERADE mode instead of SNAT") do |mask|
				options.masquerade = mask
			end

			opts.on("-i", "--interface <interface>", "Bridge interface") do |interface|
				options.interface = interface
			end	
			
			opts.on("-a", "Add ports to be intercepted to an already setup bridge. Use with -p, -i, and -d.") do |addMode|
				options.addMode = addMode
			end	

			opts.on("-p x,y,z","--ports <x,y,z>", Array, "List of ports to intercept. This command flag takes a comma separated list", "(without spaces) of values and turns it into an array. This requires", "at least one argument.") do |ports|
				options.ports = ports
			end	
			
			opts.on("-g","--guided", "Initiates guided mode which will help walk through setting up the bridge", "and ports to be redirected on the local machine") do |guided|
				options.guided = guided
			end

			opts.on("-d","--dest <port>", Integer, "Destination port for the redirected traffic (default 8080)") do |dest|
				if dest < 65535 or dest > 2
					options.dest = dest
				else 
					exit
				end	
			end

			opts.on("-c","--clean", "Flush the ebtables and iptables to clear added ports") do |clean|
				options.clean = clean
			end
			
			opts.on("-r","--remote", "Initiates guided mode for remote forwarding for when the interceptor is on another host") do |remote|
				options.remote = remote
			end	
			
			opts.on_tail("-h", "--help", "Show this message") do
				puts opts
				exit
			end
				
		end
		opt_parser.parse!(args)
		options
	end
end #end class Optparser

#Parse Options and rescue if there is an invalid option
begin
	options = Optparser.parse(ARGV)
rescue OptionParser::InvalidOption => e
	puts e
	puts "Try -h or --help to see all options"
	exit 1
end	
puts options
def which(cmd)
	exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
	ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
		exts.each { |ext|
			exe = File.join(path, "#{cmd}#{ext}")
			return exe if File.executable?(exe) && !File.directory?(exe)
		}
	end
	return nil
end

#Hack to see if the user has superuser privs
user = `id -u`
if(user.to_i != 0)
	puts "Must run this program with super user privileges"
	exit 1
end	

puts "Checking dependancies...";

if(options.verbose) #Verbose output
	puts "Path is #{ENV['PATH']}"
	puts "running as user #{`whoami`}"
end

if(which('brctl') == nil)
    puts "brctl not found. Please install bridge-utils";
    exit 1
end

if(which('iptables') == nil)
    puts "iptables not found. Please install iptables"
    exit 1
end

if(which('ebtables') == nil)
    puts "ebtables not found. Please install ebtables"
    exit 1
end

if(which('ifconfig') == nil)
	puts "ifconfig not found. Please install ifconfig (net-tools)"
    exit 1
end
#echo "Looks like you should be okay..."


if(options.guided)
	
	ifconfig = `ifconfig`
	interfaces = ifconfig.scan(/(^[a-z0-9]+):|\n([a-z0-9]+):/)
	interfaces.flatten!.compact!
	puts "Select the two interfaces you would like to bridge"
	puts "Interfaces:"
	interfaces.each_with_index do |interface, index|
		puts "#{index} => #{interface}"
	end
#TODO regex for numbers only and add loop to prevent bad input
	interface1 = gets.chomp
	puts "Which other interface would you like to bridge"
	interface2 = gets.chomp
	interface1 = interfaces[interface1.to_i]
	interface2 = interfaces[interface2.to_i]

	
	puts "Would you like to set up the bridge with DHCP? (recommended) Y/n"
	dhcp = gets.chomp
	if( /^n|N$/ =~ $dhcp )
		puts "Enter the network IP address to give the bridge:"
		ip = gets.chomp
#TODO change to a loop so user has the ability to re-enter a valid IP
		if( /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/ =~ ip)
			$ipaddr=ip
		else
			puts "The ip entered doesnt seem valid... exiting"
			exit 1
		end	

		puts "Enter the default gateway for the network:"
		gate = gets.chomp
#TODO change to a loop so user has the ability to re-enter a valid IP
		if( /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/ =~ gate )
			$gateway=gate
		else
			puts "The ip entered for the gateway doesnt seem valid... exiting"
			exit 1
		end
	end

#TODO figure out if ip forwarding is needed ( I don't think it is)
	#Setting up the bridge
	`ifconfig #{interface1} 0.0.0.0 promisc up`
	`ifconfig #{interface2} 0.0.0.0 promisc up`
	`brctl addbr br0`
	`brctl addif br0 #{interface1}`
	`brctl addif br0 #{interface2}`
	`ip link set br0 up`
	if( /^n|N$/ =~ $dhcp )
		`ip addr add #{$ipaddr}/24 brd + dev br0`
		`route add default gw #{$gateway} dev br0`
	else
		`dhclient br0`
#TODO change from using sed to plain old regex		
		$ipaddr=`ifconfig br0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\\2/p'`
	end	

	puts 'Please enter the **number of ports** you would like to intercept'
	number = gets.chomp
	number.to_i.times do  
		puts "Enter the destination port to redirect:";
		$srcPort = gets.chomp
		puts ""
		puts "Enter the port on local host you would like #{$srcPort} redirected to:"
		$destPort = gets.chomp
		puts ""
		puts "Redirecting *:#{$srcPort} ---> #{$ipaddr}:#{$destPort}"
		puts ""

		#here is where the magic happens
		`ebtables -t broute -A BROUTING -p IPv4 --ip-protocol 6 --ip-destination-port #{$srcPort} -j redirect --redirect-target ACCEPT`
		`iptables -t nat -A PREROUTING -i br0 -p tcp --dport #{$srcPort} -j REDIRECT --to-port #{$destPort}`
	end

	puts "Here are your iptables and ebtables rules:"
	`ebtables -t broute -L`
	`iptables -t nat -L`

	puts "You should be set to intercept. Make sure you have your interceptors listening on #{$ipaddr} not localhost. Happy sniffing."
end


if(options.remote)
	
	ifconfig = `ifconfig`
	interfaces = ifconfig.scan(/(^[a-z0-9]+):|\n([a-z0-9]+):/)
	interfaces.flatten!.compact!
	puts "Select the two interfaces you would like to bridge"
	puts "Interfaces:"
	interfaces.each_with_index do |interface, index|
		puts "#{index} => #{interface}"
	end	
#TODO regex for numbers only and add loop to prevent bad input
	interface1 = gets.chomp
	puts "Which other interface would you like to bridge"
	interface2 = gets.chomp
	interface1 = interfaces[interface1.to_i]
	interface2 = interfaces[interface2.to_i]

	
	puts "Would you like to set up the bridge with DHCP? (recommended) Y/n"
	dhcp = gets.chomp
	if( /^n|N$/ =~ $dhcp )
		puts "Enter the network IP address to give the bridge:"
		ip = gets.chomp
#TODO change to a loop so user has the ability to re-enter a valid IP
		if( /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/ =~ ip)
			$ipaddr=ip
		else
			puts "The ip entered doesnt seem valid... exiting"
			exit 1
		end	

		puts "Enter the default gateway for the network:"
		gate = gets.chomp
#TODO change to a loop so user has the ability to re-enter a valid IP
		if( /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/ =~ gate )
			$gateway=gate
		else
			puts "The ip entered for the gateway doesnt seem valid... exiting"
			exit 1
		end
	end

	# Enable IP forwarding since host is remote
	if(options.verbose)
		puts "Enabling ipforwarding"
	end	
		puts `sysctl -w net.ipv4.ip_forward=1`
	#Setting up the bridge
	`ifconfig #{interface1} 0.0.0.0 promisc up`
	`ifconfig #{interface2} 0.0.0.0 promisc up`
	`brctl addbr br0`
	`brctl addif br0 #{interface1}`
	`brctl addif br0 #{interface2}`
	`ip link set br0 up`
	if( /^n|N$/ =~ $dhcp )
		`ip addr add #{$ipaddr}/24 brd + dev br0`
		`route add default gw #{$gateway} dev br0`
	else
		`dhclient br0`
#TODO change from using sed to plain old regex		
		$ipaddr=`ifconfig br0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\\2/p'`
		$ipaddr.chomp!
	end
	
	puts 'Please enter the destination host ip address where you plan on running you intercepter'
	$destHost = gets.chomp
#TODO add logic for typoed ip addresses

	puts 'Please enter the **number of ports** you would like to intercept'
	number = gets.chomp
	number.to_i.times do  
		puts "Enter the destination port to redirect:";
		$srcPort = gets.chomp
		puts ""
		puts "Enter the port on #{$destHost} you would like #{$srcPort} redirected to:"
		$destPort = gets.chomp
		puts ""
		puts "Redirecting *:#{$srcPort} ---> #{$destHost}:#{$destPort}"
		puts ""

		#TODO tons of rules below. Look into them more for mistakes		
		if(options.masquerade) 
			#Experiment this method works without SNAT'ing the packets but will probably be a little slower due to more overhead
			puts `ebtables -t broute -A BROUTING -p IPv4 --ip-protocol 6 --ip-destination-port #{$srcPort} -j redirect --redirect-target ACCEPT`
			puts `iptables -t nat -A PREROUTING -i br0 -p tcp ! -s #{$ipaddr} --dport #{$srcPort} -j DNAT --to-destination #{$destHost}:#{$destPort}`
			puts `iptables -A FORWARD -p tcp -d #{$destHost} --dport #{$destPort} -j ACCEPT`
		else
			`ebtables -t broute -A BROUTING -p IPv4 --ip-protocol 6 --ip-destination-port #{$srcPort} -j redirect --redirect-target ACCEPT`
			`iptables -t nat -A PREROUTING -i br0 -p tcp --dport #{$srcPort} -j DNAT --to-destination #{$destHost}:#{$destPort}`
			`iptables -A FORWARD -p tcp -d #{$destHost} --dport #{$destPort} -j ACCEPT`
			`iptables -t nat -A POSTROUTING -p tcp -d #{$destHost} --dport #{$destPort} -j SNAT --to-source #{$ipaddr}`
		end	
		
	end
		if(options.masquerade)
			puts `iptables -t nat -A POSTROUTING -j MASQUERADE`
		end	

	puts "Here are your iptables and ebtables rules:"
	puts `ebtables -t broute -L`
	puts `iptables -t nat -L`

	puts "You should be set to intercept. Make sure you have your interceptors listening on #{$destHost} not localhost. Happy sniffing."
end


if(options.clean)
	puts "Cleaning up..."
	`ip link set br0 down`
	`brctl delbr br0`
	`ebtables -t broute -F`
	`iptables -t nat -F`
	`iptables -F`
	`iptables -X`
	if(options.verbose)
		puts "Disabling IP Forwarding"
	end	
	puts `sysctl -w net.ipv4.ip_forward=0`
end

if(options.addMode)
	#Checking for correct flags
end	


=begin


	r)

		if ! [ $(id -u) = 0 ]; then
		   echo "Sorry but to do all the cool stuff you need to run this as root"
		   exit 1
		fi

		echo "Checking dependancies...";

		hash brctl &> /dev/null
		if [ $? -eq 1 ]; then
		    echo >&2 "brctl not found. Please install bridge-utils";
		    exit 1
		fi

		hash iptables &> /dev/null
		if [ $? -eq 1 ]; then
		    echo >&2 "iptables not found. Please install iptables"
		    exit 1
		fi

		hash ebtables &> /dev/null
		if [ $? -eq 1 ]; then
		    echo >&2 "ebtables not found. Please install ebtables"
		    exit 1
		fi

		echo "Looks like you should be okay..."

		echo "Enter the first interface to bridge:"
		read interface1
		echo "Enter the second interface:"
		read interface2
		echo "Would you like to set up the bridge with DHCP? (recommended) Y/n"
		read dhcp
		if [[ $dhcp =~ ^n|N$ ]]; then
			echo "Enter the network IP address to give the bridge:"
			read ip

			if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
				ipaddr="$ip"
			else
				echo "The ip entered doesnt seem valid... exiting"
				exit 1
			fi	

			echo "Enter the default gateway for the network:"
			read gate

			if [[ $gate =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
				gateway="$gate"
			else
				echo "The ip entered doesnt seem valid... exiting"
				exit 1
			fi
		fi


		#Setting up the bridge
		ifconfig $interface1 0.0.0.0 promisc up
		ifconfig $interface2 0.0.0.0 promisc up
		brctl addbr br0
		brctl addif br0 $interface1
		brctl addif br0 $interface2
		ip link set br0 up
		sysctl -w net.ipv4.ip_forward=1
		if [[ $dhcp =~ ^n|N$ ]]; then
			ip addr add $ipaddr/24 brd + dev br0
			route add default gw $gateway dev br0
		else
			dhclient br0
			ipaddr="$(ifconfig br0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')"
		fi

		echo 'Please enter the destination host ip address where you plan on running you intercepter'
		read destHost	

		echo 'Please enter the **number of ports** you would like to redirect'
		read number

		for ((i = 1; i <= number; i++))
		do 
			echo "Enter the destination port to redirect:";
			read srcPort
			echo ""
			echo "Enter the port on the remote host you would like $srcPort redirected to:"
			read destPort
			echo ""
			echo "Redirecting *:$srcPort ---> $destHost:$destPort"
			echo ""

			#here is where the magic happens
			ebtables -t broute -A BROUTING -p IPv4 --ip-protocol 6 --ip-destination-port $srcPort -j redirect --redirect-target ACCEPT
			iptables -t nat -A PREROUTING -i br0 -p tcp --dport $srcPort -j DNAT --to-destination "$destHost:$destPort"
			iptables -A FORWARD -p tcp -d $destHost --dport $destPort -j ACCEPT
			iptables -t nat -A POSTROUTING -p tcp -d $destHost --dport $destPort -j SNAT --to-source $ipaddr

		done

		echo "Here are your iptables and ebtables rules:"
		ebtables -t broute -L
		iptables -t nat -L
		iptables -L

		echo "You should be set to intercept. Make sure you have your interceptors listening on "$destHost". Happy sniffing."

		;;

	a)
		echo "Enter the destination port to redirect:"
	        read srcPort
		echo ""
		echo "Enter the port on local host you would like $srcPort redirected to:"
		read destPort
		echo ""
		echo "Redirecting *:$srcPort ---> $ipaddr:$destPort"
		echo ""
		#here is where the magic happens
		ebtables -t broute -A BROUTING -p IPv4 --ip-protocol 6 --ip-destination-port $srcPort -j redirect --redirect-target ACCEPT
		iptables -t nat -A PREROUTING -i br0 -p tcp --dport $srcPort -j REDIRECT --to-port $destPort
		;;



	\?)

		echo "Invalid option: -$OPTARG" >&2
		;;


	esac
=end

