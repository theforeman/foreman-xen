require 'fog'
require 'pp'


conn = Fog::Compute.new({
  :provider => 'XenServer',
  :xenserver_url => '192.168.110.10',
  :xenserver_username => 'root',
  :xenserver_password => 'root1234',
})
             
storages = conn.storage_repositories.new

puts storages

storages.each do |sr|
	#puts sr.introduced_by;
	#puts sr.name;
	#puts sr.description
	#puts sr.type
	#puts sr.uuid
	print "=============";
# in bytes
#puts sr.physical_size
#puts sr.physical_utilisation
# sum of virtual_sizes of all VDIs in this storage repository (in bytes)
#puts sr.virtual_allocation

end
