VIEW_P = "viewabc"
ZONE_P = "123.com"
def zone_cnt(zone, rrs=1000)
    if (zone[-1] != ".")
        zone += "."
    end
    content = "#{zone} 3600 IN SOA ns.#{zone} mail.#{zone} 100 2000 2000 2000 2000
#{zone} 3600 IN NS ns1.#{zone}
ns1.#{zone} 3600 IN A 127.0.0.1\n"
    (rrs-3).times do |i|
       content += "www#{i}.#{zone} 3600 IN A 202.#{rand(255)}.#{rand(255)}.#{rand(255)}\n"
    end
    content
end

def gen_acl_conf(acls = 100)
    a = ""
    acls.times do |i|
         a += "acl \"acl#{i}\" {\n"
         1000.times do |j|
            net = rand(255)
            while 1 do
                if (net == 202 )
                   net = rand(255)
                else
                    break
                end
            end
            a += "\t#{net}.#{rand(255)}.#{rand(255)}.0/24;\n"
         end
         a += "};\n"
   end
   a
end

def gen_key_conf(views, view_p)
    view_list = []
    views.times do |i|
       view_list <<  "#{view_p}#{i}"
    end
    
    view_list << "default"
    keyconf = ""
    view_list.each do |keyname|
   res = `rndc-confgen -k #{keyname} -r /dev/urandom`
   keyconf += res.split("\n")[1..4].join("\n")
   keyconf += "\n"
   end
   keyconf
end

def gen_zone_conf(zone_dir, zone_name, zones, rrs, rezone=false)
    z = ""
    zones.times do |i|
                  if (rezone == true)
                     if (i < 3)
                     zone_conf = zone_cnt(zone_name + i.to_s + ".", 10000)
                     else
                     zone_conf = zone_cnt(zone_name + i.to_s + ".", rrs)
                     end
                     output_to_file(zone_dir + "/" + zone_name + i.to_s, zone_conf)
                  end
                  z += "\tzone #{zone_name}#{i} {
                     \ttype master;
                     \tfile \"#{zone_dir}/#{zone_name}#{i}\";
                   \t};\n"
   end
   z
end

def gen_shared_zone_conf(shared_view, zone_name, zones, rrs=0)
    z = ""
    zones.times do |i|
                  z += "\tzone #{zone_name}#{i} {
                     \tin-view \"#{shared_view}\";
                   \t};\n"
   end
   z
end

def gen_options(main_dir)
    options = "options {
         directory \"#{main_dir}/etc\";
         listen-on port 9993 {any; };
         recursion no;
         allow-new-zones yes;
    };\n"
    logs = "logging {
    channel query_log {
        file \"#{main_dir}/log/query.log\" versions 5 size 100m;
        print-time yes;
        severity info;
    };  
    category queries { query_log;};
    channel general_log {
        file \"#{main_dir}/log/general.log\" versions 5 size 20m;
        print-time yes;
        print-category yes;
        print-severity yes;
        severity info;
    };  
    category default   { general_log; };
    category general   { general_log; };
};

key \"rndc-key\" {
    algorithm hmac-md5;
    secret \"gu+GC1MkNNY6OaHWfooaJA==\";
};
controls {
    inet 127.0.0.1 port 9998
    allow { 127.0.0.1; } keys {\"rndc-key\";};
};
"
   options + logs
end 
def gen_view_conf(zone_dir, views, zones, rrs, share_zone=false, regenerate_zone_file=false)
    view_p = VIEW_P
    zone_p = ZONE_P
    viewconf = ""
    view_list = []
    views.times do |i|
       view_list <<  "#{view_p}#{i}"
    end
    
    view_list << "default"
    idx = 0
    view_list.each do |view|
          viewconf += "view #{view} {\n"
          _zone_dir = zone_dir + "/" + view
         if view == "#{view_p}0"
          `mkdir -p #{_zone_dir}`
           viewconf += "\tmatch-clients {acl#{idx}; key #{view};};\n"
           viewconf += "\tallow-update { key #{view};};\n"
           viewconf += gen_zone_conf(_zone_dir, zone_p, zones, rrs, regenerate_zone_file)
         elsif view == "default"
          `mkdir -p #{_zone_dir}`
           viewconf += "\tmatch-clients {any; key #{view};} ;\n"
           viewconf += "\tallow-update { key #{view};};\n"
           viewconf += gen_zone_conf(_zone_dir, zone_p, zones, rrs, regenerate_zone_file)
         else
           viewconf += "\tmatch-clients {acl#{idx}; key #{view};};\n"
           viewconf += "\tallow-update { key #{view};};\n"
           if share_zone 
              viewconf += gen_shared_zone_conf("#{view_p}0", zone_p, zones, rrs)
           else
              viewconf += gen_zone_conf(_zone_dir, zone_p, zones, rrs, regenerate_zone_file)
           end
         end
         viewconf += "};\n"
		 idx += 1
    end
    viewconf  
end

def gen_rndc_file(filename)
    cnt = "
key \"rndc-key\" {
    algorithm hmac-md5;
    secret \"gu+GC1MkNNY6OaHWfooaJA==\";
};
options {
    default-key \"rndc-key\";
    default-server 127.0.0.1;
    default-port 9998;
};
" 
    output_to_file(filename, cnt)
end

def output_to_file(filename, cnt)
	dir=filename[0..filename.rindex("/")-1]
	`mkdir #{dir}` unless File.exists?(dir)
    fp = open(filename, "w")
    fp.puts cnt
    fp.close
end

views = 100
zones = 10
rrs = 10
share_zone = false
regenerate_zone_file = true
bind_dir = "/root/lgr/named_test"
log_dir = bind_dir + "/zone"
named_conf = bind_dir + "/etc/named.conf" 
rndc_conf = bind_dir + "/etc/rndc.conf" 
`mkdir -p #{bind_dir}/etc`
`mkdir -p #{bind_dir}/log`
`mkdir -p #{bind_dir}/zone`
conf = gen_options(bind_dir)
conf += gen_acl_conf(views)
conf += gen_key_conf(views, VIEW_P)
conf += gen_view_conf(log_dir, views, zones, rrs, share_zone, regenerate_zone_file)
output_to_file(named_conf, conf)
gen_rndc_file(rndc_conf)

