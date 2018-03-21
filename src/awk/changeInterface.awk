function writeStatic(device, fields, orders) {

    # Create the order as original
    for (o = 0; o in orders; o++) {
    field = orders[o];
    value = fields[field];
    delete fields[field];
    if (length(value)) {
        printf("    %s %s\n", field, value);
    }
    }

    # additional items have no order
    for (f in fields) {
    value = fields[f];
    if (length(value)) {
        printf("    %s %s\n", f, value);
    }
    }
    print "";
}

function usage() {
        print "awk -f changeInterfaces.awk <interfaces file> dev=<eth device> \n" \
            "       [mode=dhcp|static|manual] [action=add|remove] \n" \
            "       [address=<ip addr> networkmask=<ipaddress> <name=value> ]\n" \
        "       [arg=debug]\n"
}

BEGIN { start = 0;
    setting_defaultgateway = 0;
    gateway_replaced=0
    defaultgateway=0
    order = 0
    
    if (ARGC < 3 || ARGC > 16) {
        usage();
        exit 1;
    }

    for (i = 2; i < ARGC; i++) {
        num = split(ARGV[i], pair, "=");
        if (pair[1] == "arg" && pair[2] == "debug") {
            debug = 1;
	} else if (pair[1] == "mode") {
        mode = pair[2];
    } else if (pair[1] == "action" && pair[2] == "remove")
            remove = 1;
        else if (pair[1] == "action" && pair[2] == "add")
            add = 1;
    else if (pair[1] == "device" || pair[1] == "dev") {
	if (pair[2] == "N/A") {
	    setting_defaultgateway = 1;
	} else {
	    device = pair[2];
	}
    } else if (num == 2) {
	if (pair[1] == "defaultgateway") {
	    defaultgateway = pair[2];
	}
        if (pair[1] == "dns") {
        pair[1] = "dns-nameservers";
        }
        if (pair[1] == "bond_updelay") {
        pair[1] = "bond-updelay";
        }
        if (pair[1] == "bond_downdelay") {
        pair[1] = "bond-downdelay";
        }
        if (pair[1] == "xmit_hash_policy") {
        pair[1] = "xmit-hash-policy";
        }
        settings[pair[1]] = pair[2];
    } else {
        usage();
        exit 1;
    }
    }

    # Sort out the logic of argument
    if (mode == "dhcp" && (length(network) || length(gateway) || length(address) || length(netmask))) {
        print "Both DHCP and static properties are defined";
        usage();
        exit 1;
    } else if (!mode && !remove) {
    print "Missing mode input";
    usage();
    exit 1;
    }

    if (debug) {
    for (f in settings) {
        print f, ": ", settings[f];
    }
    }
} 

{
    if (setting_defaultgateway == 0) {
    # auto <device> line
    if ($1 == "auto") {
    if ($2 != device) {
        # We come to different device
        # Good place to write all the settings
        if (targetDev) {
        targetDev = 0;
        if (!add && !remove) {
            if (mode == "static" || mode == "manual") {
            writeStatic(device, settings, fieldOrders);
            }
        }       
        }
        print $0;
        next;
    } else if (!remove) {
        print $0;
        add = 0;
        next;
    }
    # Remove - don't print
    next;
    }
    # iface <device> .. line
    else if ($1 == "iface") {

    if ($2 != device) {
        # We come to different device
        # Good place to write all the settings
        if (targetDev) {
        targetDev = 0;
        if (!add && !remove) {
            if (mode == "static" || mode == "manual") {
            writeStatic(device, settings, fieldOrders);
            }
        }       
        }
        print $0;
        next;       
    } else {

        # If already specified 'add' and found an existing entry
        # cancel it
        add = 0;
        
        # Go to different condition in next loop
        targetDev = 1;

        if (!remove) {
        printf("iface %s inet %s\n", device, mode);
        }       
        next;
    }   
    }
    
    # Matched device found - working through each line
    # until found a 'auto' line or end of file 
    else if (targetDev) {

    # Comment line - leave it
    if (substr($1, 0, 1) == "#") {
        print $0;
        next;
    }
    
    field = $1;
    if (field in settings) {
        # It means we specify the argument in command line
        # as preference over the file content
    } else {
        # field not in the command line
        # copy it over
        settings[field] = substr($0, index($0, $2))
    }
    fieldOrders[order] = field
    order++;
    next;

    # Other type of lines e.g. comment
    } else {
    print $0;
    next;
    }
    } else { # here we set the default gateway
	# If there is already a default gateway, then replace it with a new instruction.
	if ($1 == "up" && $2 == "route" && $3 == "add" && $4 == "default" && $5 == "gw") {
	    printf("up route add default gw %s", defaultgateway)
	    gateway_replaced=1
	}
    }
}

END {

    # Come to the last line and we may not print out the
    # matched device settings
    if (!remove) {
    if (add || targetDev) {
        if (add) {
        printf("auto %s\n", device);
        printf("iface %s inet %s\n", device, mode);
        }
        if (mode != "dhcp") {
        writeStatic(device, settings, fieldOrders);
        }
    }
    }

    # If there was not already a default gateway, this will
    # add a new entry
    if (setting_defaultgateway == 1 && gateway_replaced == 1) {
	printf("up route add default gw %s", defaultgateway)
    }
}
